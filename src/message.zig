const std = @import("std");

pub const State = struct {
    emoji: []const u8,
    description: []const u8,
    text: []u8,
    cursor: usize,
    error_msg: ?[]const u8 = null,

    pub fn init(alloc: std.mem.Allocator, emoji: []const u8, description: []const u8) !State {
        const prefix_len = emoji.len + 1;
        var text = try alloc.alloc(u8, prefix_len);
        @memcpy(text[0..emoji.len], emoji);
        text[emoji.len] = ' ';
        return .{
            .emoji = emoji,
            .description = description,
            .text = text,
            .cursor = prefix_len,
        };
    }

    pub fn deinit(self: *State, alloc: std.mem.Allocator) void {
        alloc.free(self.text);
    }

    fn prefixLen(self: *const State) usize {
        return self.emoji.len + 1;
    }

    pub fn insertChar(self: *State, alloc: std.mem.Allocator, ch: u8) !void {
        self.error_msg = null;
        var nt = try alloc.alloc(u8, self.text.len + 1);
        @memcpy(nt[0..self.cursor], self.text[0..self.cursor]);
        nt[self.cursor] = ch;
        @memcpy(nt[self.cursor + 1 ..], self.text[self.cursor..]);
        alloc.free(self.text);
        self.text = nt;
        self.cursor += 1;
    }

    pub fn backspace(self: *State, alloc: std.mem.Allocator) !void {
        const p = self.prefixLen();
        if (self.cursor <= p) return;
        self.error_msg = null;
        self.cursor -= 1;
        var nt = try alloc.alloc(u8, self.text.len - 1);
        @memcpy(nt[0..self.cursor], self.text[0..self.cursor]);
        @memcpy(nt[self.cursor..], self.text[self.cursor + 1 ..]);
        alloc.free(self.text);
        self.text = nt;
    }

    pub fn deleteChar(self: *State, alloc: std.mem.Allocator) !void {
        if (self.cursor >= self.text.len) return;
        self.error_msg = null;
        var nt = try alloc.alloc(u8, self.text.len - 1);
        @memcpy(nt[0..self.cursor], self.text[0..self.cursor]);
        @memcpy(nt[self.cursor..], self.text[self.cursor + 1 ..]);
        alloc.free(self.text);
        self.text = nt;
    }

    pub fn moveCursor(self: *State, delta: isize) void {
        const p = self.prefixLen();
        var i: isize = @as(isize, @intCast(self.cursor)) + delta;
        i = @max(@as(isize, @intCast(p)), @min(@as(isize, @intCast(self.text.len)), i));
        self.cursor = @intCast(i);
    }

    pub fn cursorLeft(self: *State) void {
        self.moveCursor(-1);
    }

    pub fn cursorRight(self: *State) void {
        self.moveCursor(1);
    }

    pub fn cursorHome(self: *State) void {
        self.cursor = self.prefixLen();
    }

    pub fn cursorEnd(self: *State) void {
        self.cursor = self.text.len;
    }

    pub fn bodyEmpty(self: *const State) bool {
        const body = self.text[self.prefixLen() ..];
        for (body) |b| {
            if (!std.ascii.isWhitespace(b)) return false;
        }
        return true;
    }

    pub fn render(self: *const State, alloc: std.mem.Allocator, width: usize, buf: *std.ArrayList(u8)) !void {
        buf.clearRetainingCapacity();
        try buf.appendSlice(alloc, "\x1b[H");

        try buf.appendSlice(alloc, "  ");
        try buf.appendSlice(alloc, self.emoji);
        try buf.appendSlice(alloc, " ");
        const desc_max = if (width > 5) width - 5 else 0;
        try buf.appendSlice(alloc, self.description[0..@min(desc_max, self.description.len)]);
        try buf.appendSlice(alloc, "\x1b[K\n");
        try buf.appendSlice(alloc, "\x1b[K\n");


        const max_w = if (width > 2) width - 2 else 0;
        const visible = self.text[0..@min(max_w, self.text.len)];
        try buf.appendSlice(alloc, "  ");
        try buf.appendSlice(alloc, visible);
        try buf.appendSlice(alloc, "\x1b[K\n");

        if (self.error_msg) |err| {
            try buf.appendSlice(alloc, "  ");
            try buf.appendSlice(alloc, err);
        } else {
            try buf.appendSlice(alloc, "  ");
        }
        try buf.appendSlice(alloc, "\x1b[K\n");

        try buf.appendSlice(alloc, "  esc: back to list · enter: commit\x1b[K\n");

        const col: u16 = @intCast(@min(
            width,
            4 + (self.cursor - self.prefixLen()) + 1,
        ));
        var move: [16]u8 = undefined;
        const s = try std.fmt.bufPrint(&move, "\x1b[3;{}H", .{col});
        try buf.appendSlice(alloc, s);
        try buf.appendSlice(alloc, "\x1b[?25h");
        try buf.appendSlice(alloc, "\x1b[J");
    }
};

const testing = std.testing;

test "message: init prefills emoji prefix" {
    const alloc = testing.allocator;
    var m = try State.init(alloc, "🐛", "Fix a bug.");
    defer m.deinit(alloc);
    try testing.expectEqualStrings("🐛 ", m.text);
    try testing.expectEqual(@as(usize, 5), m.cursor);
    try testing.expect(m.bodyEmpty());
}

test "message: insert and backspace" {
    const alloc = testing.allocator;
    var m = try State.init(alloc, "🐛", "Fix a bug.");
    defer m.deinit(alloc);
    try m.insertChar(alloc, 'a');
    try m.insertChar(alloc, 'b');
    try testing.expectEqualStrings("🐛 ab", m.text);
    try m.backspace(alloc);
    try testing.expectEqualStrings("🐛 a", m.text);
    try testing.expectEqual(@as(usize, 6), m.cursor);
}

test "message: prefix is locked" {
    const alloc = testing.allocator;
    var m = try State.init(alloc, "🐛", "Fix a bug.");
    defer m.deinit(alloc);
    m.cursorHome();
    m.cursorLeft();
    try testing.expectEqual(@as(usize, 5), m.cursor);
    try m.backspace(alloc);
    try testing.expectEqualStrings("🐛 ", m.text);
}

test "message: cursor movement" {
    const alloc = testing.allocator;
    var m = try State.init(alloc, "🐛", "Fix a bug.");
    defer m.deinit(alloc);
    try m.insertChar(alloc, 'a');
    try m.insertChar(alloc, 'b');
    try m.insertChar(alloc, 'c');
    m.cursorHome();
    try testing.expectEqual(@as(usize, 5), m.cursor);
    m.cursorRight();
    m.cursorRight();
    try testing.expectEqual(@as(usize, 7), m.cursor);
    m.cursorLeft();
    try testing.expectEqual(@as(usize, 6), m.cursor);
    m.cursorEnd();
    try testing.expectEqual(@as(usize, 8), m.cursor);
    m.cursorRight();
    try testing.expectEqual(@as(usize, 8), m.cursor);
}

test "message: deleteChar removes at cursor" {
    const alloc = testing.allocator;
    var m = try State.init(alloc, "🐛", "Fix a bug.");
    defer m.deinit(alloc);
    try m.insertChar(alloc, 'a');
    try m.insertChar(alloc, 'b');
    m.cursorHome();
    try m.deleteChar(alloc);
    try testing.expectEqualStrings("🐛 b", m.text);
    try m.deleteChar(alloc);
    try testing.expectEqualStrings("🐛 ", m.text);
}

test "message: whitespace-only body is empty" {
    const alloc = testing.allocator;
    var m = try State.init(alloc, "🐛", "Fix a bug.");
    defer m.deinit(alloc);
    try m.insertChar(alloc, ' ');
    try m.insertChar(alloc, ' ');
    try testing.expect(m.bodyEmpty());
    try m.insertChar(alloc, 'x');
    try testing.expect(!m.bodyEmpty());
}

test "message: render shows text and cursor move" {
    const alloc = testing.allocator;
    var m = try State.init(alloc, "🐛", "Fix a bug.");
    defer m.deinit(alloc);
    try m.insertChar(alloc, 'a');
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);
    try m.render(alloc, 80, &buf);
    try testing.expect(std.mem.indexOf(u8, buf.items, "🐛 a") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "\x1b[3;") != null);
    m.error_msg = "message cannot be empty";
    try m.render(alloc, 80, &buf);
    try testing.expect(std.mem.indexOf(u8, buf.items, "message cannot be empty") != null);
}
