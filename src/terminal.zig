const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

pub const Key = union(enum) {
    Char: u8,
    Up: void,
    Down: void,
    Left: void,
    Right: void,
    PageUp: void,
    PageDown: void,
    Home: void,
    End: void,
    Delete: void,
    Backspace: void,
    Enter: void,
    Esc: void,
    CtrlC: void,
    Unknown: void,
};

pub const Size = struct {
    rows: u16,
    cols: u16,
};

const TIOCGWINSZ: c_int = switch (builtin.os.tag) {
    .linux => 0x5413,
    else => 0x40087468,
};

fn check(rc: c_int) !void {
    const e = std.c.errno(rc);
    if (e == .INTR) return error.Interrupted;
    if (e != .SUCCESS) return error.SysCallFailed;
}

pub fn isTty(fd: posix.fd_t) bool {
    return std.c.isatty(fd) == 1;
}

pub fn size(fd: posix.fd_t) !Size {
    var ws: posix.winsize = undefined;
    try check(std.c.ioctl(fd, TIOCGWINSZ, &ws));
    return .{ .rows = ws.row, .cols = ws.col };
}

pub fn writeAll(fd: posix.fd_t, bytes: []const u8) !void {
    var off: usize = 0;
    while (off < bytes.len) {
        const n = std.c.write(fd, @ptrCast(&bytes[off]), bytes.len - off);
        if (n < 0) {
            if (std.c.errno(n) == .INTR) continue;
            return error.SysCallFailed;
        }
        off += @as(usize, @intCast(n));
    }
}

pub const Raw = struct {
    fd: posix.fd_t,
    orig: std.c.termios = undefined,
    raw: std.c.termios = undefined,
    active: bool = false,

    const VMIN = @intFromEnum(posix.V.MIN);
    const VTIME = @intFromEnum(posix.V.TIME);

    pub fn init(fd: posix.fd_t) Raw {
        return .{ .fd = fd };
    }

    pub fn activate(self: *Raw) !void {
        var t: std.c.termios = undefined;
        try check(std.c.tcgetattr(self.fd, &t));
        self.orig = t;
        t.lflag.ICANON = false;
        t.lflag.ECHO = false;
        t.lflag.ISIG = false;
        t.lflag.IEXTEN = false;
        t.iflag.IXON = false;
        t.iflag.ICRNL = false;
        t.iflag.BRKINT = false;
        t.iflag.INPCK = false;
        t.iflag.ISTRIP = false;
        t.oflag.OPOST = false;
        t.cc[VMIN] = 1;
        t.cc[VTIME] = 0;
        self.raw = t;
        try check(std.c.tcsetattr(self.fd, .NOW, &t));
        self.active = true;
    }

    pub fn restore(self: *Raw) !void {
        if (self.active) {
            try check(std.c.tcsetattr(self.fd, .NOW, &self.orig));
            self.active = false;
        }
    }

    pub fn peekBegin(self: *Raw) !void {
        var t = self.raw;
        t.cc[VMIN] = 0;
        t.cc[VTIME] = 1;
        try check(std.c.tcsetattr(self.fd, .NOW, &t));
    }

    pub fn peekEnd(self: *Raw) !void {
        try check(std.c.tcsetattr(self.fd, .NOW, &self.raw));
    }

    pub fn readByte(self: *Raw) !u8 {
        var b: [1]u8 = .{0};
        while (true) {
            const n = std.c.read(self.fd, &b, 1);
            if (n == -1) {
                if (std.c.errno(n) == .INTR) continue;
                return error.SysCallFailed;
            }
            if (n == 0) return error.EndOfInput;
            return b[0];
        }
    }
};

pub const Reader = struct {
    raw: Raw,
    pending: ?u8 = null,

    pub fn init(fd: posix.fd_t) !Reader {
        var raw = Raw.init(fd);
        try raw.activate();
        return .{ .raw = raw };
    }

    pub fn readKey(self: *Reader) !Key {
        const c0 = if (self.pending) |b| blk: {
            self.pending = null;
            break :blk b;
        } else try self.raw.readByte();
        if (c0 != 27) return parseKeySequence(&[_]u8{c0});
        self.raw.peekBegin() catch return .Esc;
        defer {
            self.raw.peekEnd() catch {};
        }
        var seq: [16]u8 = .{0} ** 16;
        seq[0] = 27;
        var len: usize = 1;
        const b2 = self.raw.readByte() catch return parseKeySequence(seq[0..len]);
        if (b2 == 27) {
            self.pending = 27;
            return .Esc;
        }
        seq[1] = b2;
        len = 2;
        if (b2 == '[' or b2 == 'O') {
            while (len < seq.len) {
                const b = self.raw.readByte() catch break;
                seq[len] = b;
                len += 1;
                if (b == '~' or (b >= 'A' and b <= 'Z')) break;
            }
        }
        return parseKeySequence(seq[0..len]);
    }
};

pub fn parseKeySequence(seq: []const u8) Key {
    switch (seq[0]) {
        3 => return .CtrlC,
        8, 127 => return .Backspace,
        '\r', '\n' => return .Enter,
        27 => {
            if (seq.len < 2) return .Esc;
            return switch (seq[1]) {
                '[' => parseCsiBytes(seq[2..]),
                'O' => parseSs3Bytes(seq[2..]),
                else => .Esc,
            };
        },
        else => return Key{ .Char = seq[0] },
    }
}

fn parseCsiBytes(rest: []const u8) Key {
    var param: ?u8 = null;
    for (rest) |b| {
        if (b >= '0' and b <= '9') {
            if (param == null) param = b;
            continue;
        }
        if (b == '~') {
            return switch (param orelse 0) {
                '1' => .Home,
                '3' => .Delete,
                '4' => .End,
                '5' => .PageUp,
                '6' => .PageDown,
                else => .Unknown,
            };
        }
        if (b == ';') continue;
        return switch (b) {
            'A' => .Up,
            'B' => .Down,
            'C' => .Right,
            'D' => .Left,
            'H' => .Home,
            'F' => .End,
            else => .Unknown,
        };
    }
    return .Unknown;
}

fn parseSs3Bytes(rest: []const u8) Key {
    if (rest.len < 1) return .Unknown;
    return switch (rest[0]) {
        'A' => .Up,
        'B' => .Down,
        'C' => .Right,
        'D' => .Left,
        'H' => .Home,
        'F' => .End,
        else => .Unknown,
    };
}

const testing = std.testing;

test "parseKeySequence: simple keys" {
    switch (parseKeySequence(&[_]u8{'a'})) {
        .Char => |c| try testing.expectEqual(@as(u8, 'a'), c),
        else => return error.UnexpectedKey,
    }
    switch (parseKeySequence(&[_]u8{'Z'})) {
        .Char => |c| try testing.expectEqual(@as(u8, 'Z'), c),
        else => return error.UnexpectedKey,
    }
    try testing.expect(parseKeySequence(&[_]u8{3}) == .CtrlC);
    try testing.expect(parseKeySequence(&[_]u8{8}) == .Backspace);
    try testing.expect(parseKeySequence(&[_]u8{127}) == .Backspace);
    try testing.expect(parseKeySequence(&[_]u8{'\r'}) == .Enter);
    try testing.expect(parseKeySequence(&[_]u8{'\n'}) == .Enter);
    try testing.expect(parseKeySequence(&[_]u8{27}) == .Esc);
}

test "parseKeySequence: CSI arrows and navigation" {
    try testing.expect(parseKeySequence("\x1b[A") == .Up);
    try testing.expect(parseKeySequence("\x1b[B") == .Down);
    try testing.expect(parseKeySequence("\x1b[C") == .Right);
    try testing.expect(parseKeySequence("\x1b[D") == .Left);
    try testing.expect(parseKeySequence("\x1b[H") == .Home);
    try testing.expect(parseKeySequence("\x1b[F") == .End);
}

test "parseKeySequence: CSI tilde codes" {
    try testing.expect(parseKeySequence("\x1b[5~") == .PageUp);
    try testing.expect(parseKeySequence("\x1b[6~") == .PageDown);
    try testing.expect(parseKeySequence("\x1b[3~") == .Delete);
    try testing.expect(parseKeySequence("\x1b[1~") == .Home);
    try testing.expect(parseKeySequence("\x1b[4~") == .End);
    try testing.expect(parseKeySequence("\x1b[2~") == .Unknown);
}

test "parseKeySequence: modifiers and SS3" {
    try testing.expect(parseKeySequence("\x1b[1;5D") == .Left);
    try testing.expect(parseKeySequence("\x1bOA") == .Up);
    try testing.expect(parseKeySequence("\x1bOF") == .End);
    try testing.expect(parseKeySequence("\x1b[9~") == .Unknown);
    try testing.expect(parseKeySequence("\x1b[") == .Unknown);
    try testing.expect(parseKeySequence("\x1bO") == .Unknown);
}
