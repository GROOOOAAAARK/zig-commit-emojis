const std = @import("std");
const models = @import("models.zig");
const data = @import("data.zig");
const picker = @import("picker.zig");
const message = @import("message.zig");
const terminal = @import("terminal.zig");

const STDIN: std.posix.fd_t = 0;
const STDOUT: std.posix.fd_t = 1;

pub const Result = union(enum) {
    picked: []const u8,
    aborted,
    cancelled,
};

const Phase = enum { list, message };

pub fn run(alloc: std.mem.Allocator) !Result {
    if (!terminal.isTty(STDIN) or !terminal.isTty(STDOUT)) {
        return error.NotATty;
    }

    var reader = try terminal.Reader.init(STDIN);
    defer reader.raw.restore() catch {};

    terminal.writeAll(STDOUT, "\x1b[?1049h") catch {};
    defer terminal.writeAll(STDOUT, "\x1b[?1049l\x1b[?25h") catch {};

    var p = try picker.State.init(alloc, &data.data_list);
    defer p.deinit(alloc);

    var msg: ?message.State = null;
    defer if (msg) |*m| m.deinit(alloc);

    var frame = std.ArrayList(u8).empty;
    defer frame.deinit(alloc);

    var phase: Phase = .list;

    while (true) {
        const size = terminal.size(STDIN) catch continue;
        const height: usize = @max(4, @as(usize, @intCast(size.rows)));
        const width: usize = @max(8, @as(usize, @intCast(size.cols)));
        const rows = if (height > 3) height - 3 else 0;

        switch (phase) {
            .list => try p.render(alloc, height, width, &frame),
            .message => try msg.?.render(alloc, width, &frame),
        }
        try terminal.writeAll(STDOUT, frame.items);

        const key = try reader.readKey();
        if (key == .CtrlC) return .cancelled;

        switch (phase) {
            .list => switch (key) {
                .Up => p.move(-1),
                .Down => p.move(1),
                .PageUp => p.page(rows, true),
                .PageDown => p.page(rows, false),
                .Home => p.home(),
                .End => p.end(),
                .Backspace => try p.backspace(alloc),
                .Esc => {
                    if (p.filter_len > 0) {
                        try p.clearFilter(alloc);
                    } else {
                        return .aborted;
                    }
                },
                .Enter => {
                    if (p.items.len == 0) continue;
                    const g = p.items[p.selected];
                    msg = try message.State.init(alloc, g.emoji, g.description);
                    phase = .message;
                },
                .Char => |ch| {
                    if (std.ascii.isAlphanumeric(ch)) try p.typeChar(alloc, ch);
                },
                else => {},
            },
            .message => switch (key) {
                .Left => msg.?.cursorLeft(),
                .Right => msg.?.cursorRight(),
                .Home => msg.?.cursorHome(),
                .End => msg.?.cursorEnd(),
                .Backspace => try msg.?.backspace(alloc),
                .Delete => try msg.?.deleteChar(alloc),
                .Esc => {
                    if (msg) |*m| m.deinit(alloc);
                    msg = null;
                    p.selected = 0;
                    p.viewport_top = 0;
                    phase = .list;
                },
                .Enter => {
                    if (msg.?.bodyEmpty()) {
                        msg.?.error_msg = "message cannot be empty";
                        continue;
                    }
                    const m = msg.?;
                    const text = try alloc.dupe(u8, m.text);
                    return .{ .picked = text };
                },
                .Char => |ch| {
                    if (std.ascii.isPrint(ch)) try msg.?.insertChar(alloc, ch);
                },
                else => {},
            },
        }
    }
}
