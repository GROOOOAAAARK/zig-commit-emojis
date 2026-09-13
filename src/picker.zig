const std = @import("std");
const models = @import("models.zig");
const search_utils = @import("search_utils.zig");

pub const EMOJI_FIELD = 4;
pub const MAX_FILTER = 256;

pub const State = struct {
    all: []const models.GitmojiConfig,
    filter: []u8,
    filter_len: usize,
    items: []const models.GitmojiConfig,
    selected: usize,
    viewport_top: usize,

    pub fn init(alloc: std.mem.Allocator, all: []const models.GitmojiConfig) !State {
        const filter = try alloc.alloc(u8, MAX_FILTER);
        const items = try alloc.dupe(models.GitmojiConfig, all);
        return .{
            .all = all,
            .filter = filter,
            .filter_len = 0,
            .items = items,
            .selected = 0,
            .viewport_top = 0,
        };
    }

    pub fn deinit(self: *State, alloc: std.mem.Allocator) void {
        alloc.free(self.filter);
        alloc.free(self.items);
    }

    pub fn filterStr(self: *const State) []const u8 {
        return self.filter[0..self.filter_len];
    }

    fn recompute(self: *State, alloc: std.mem.Allocator, keep: ?models.GitmojiConfig) !void {
        var tmp = std.ArrayList(models.GitmojiConfig).empty;
        defer tmp.deinit(alloc);
        for (self.all) |g| {
            if (self.filter_len == 0 or search_utils.contains_subsequence(g.description, self.filterStr())) {
                try tmp.append(alloc, g);
            }
        }
        alloc.free(self.items);
        self.items = try tmp.toOwnedSlice(alloc);
        var idx: ?usize = null;
        if (keep) |k| {
            for (self.items, 0..) |g, i| {
                if (std.meta.eql(g, k)) {
                    idx = i;
                    break;
                }
            }
        }
        self.selected = idx orelse 0;
        self.viewport_top = 0;
        self.clampViewport();
    }

    pub fn typeChar(self: *State, alloc: std.mem.Allocator, ch: u8) !void {
        if (self.filter_len == MAX_FILTER) return error.FilterTooLong;
        self.filter[self.filter_len] = ch;
        self.filter_len += 1;
        const keep = if (self.items.len > 0) self.items[self.selected] else null;
        try self.recompute(alloc, keep);
    }

    pub fn backspace(self: *State, alloc: std.mem.Allocator) !void {
        if (self.filter_len == 0) return;
        self.filter_len -= 1;
        self.selected = 0;
        try self.recompute(alloc, null);
    }

    pub fn clearFilter(self: *State, alloc: std.mem.Allocator) !void {
        self.filter_len = 0;
        self.selected = 0;
        try self.recompute(alloc, null);
    }

    pub fn move(self: *State, delta: isize) void {
        if (self.items.len == 0) return;
        const max: isize = @as(isize, @intCast(self.items.len)) - 1;
        var i: isize = @as(isize, @intCast(self.selected)) + delta;
        i = @max(0, @min(max, i));
        self.selected = @intCast(i);
        self.clampViewport();
    }

    pub fn page(self: *State, viewport_rows: usize, up: bool) void {
        const delta: isize = if (up) -@as(isize, @intCast(@max(1, viewport_rows - 1))) else @as(isize, @intCast(@max(1, viewport_rows - 1)));
        self.move(delta);
    }

    pub fn home(self: *State) void {
        self.selected = 0;
        self.clampViewport();
    }

    pub fn end(self: *State) void {
        if (self.items.len > 0) self.selected = self.items.len - 1;
        self.clampViewport();
    }

    fn clampViewport(self: *State) void {
        if (self.items.len == 0) {
            self.viewport_top = 0;
            return;
        }
        if (self.selected < self.viewport_top) {
            self.viewport_top = self.selected;
        }
    }

    pub fn setViewport(self: *State, rows: usize) void {
        if (rows == 0 or self.items.len == 0) {
            self.viewport_top = 0;
            return;
        }
        if (self.selected >= self.viewport_top + rows) {
            self.viewport_top = self.selected + 1 - rows;
        }
    }

    pub fn render(self: *State, alloc: std.mem.Allocator, height: usize, width: usize, buf: *std.ArrayList(u8)) !void {
        buf.clearRetainingCapacity();
        try buf.appendSlice(alloc, "\x1b[H");
        try buf.appendSlice(alloc, "\x1b[?25l");
        self.setViewport(@max(0, height - 1));

        if (self.filter_len == 0) {
            try buf.appendSlice(alloc, "  filter: (type to filter, esc abort)");
        } else {
            try buf.appendSlice(alloc, "  filter: ");
            try buf.appendSlice(alloc, self.filterStr());
        }
        try buf.appendSlice(alloc, "\x1b[K\n");

        const body_rows = @max(0, height - 1);
        const body_width = if (width > 6 + EMOJI_FIELD) width - 6 - EMOJI_FIELD else 0;

        var printed: usize = 0;
        if (self.items.len == 0 and self.filter_len > 0 and body_rows > 0) {
            try buf.appendSlice(alloc, "  no match for \"");
            try buf.appendSlice(alloc, self.filterStr());
            try buf.appendSlice(alloc, "\"\x1b[K\n");
            printed = 1;
        }

        for (printed..body_rows) |r| {
            const i = self.viewport_top + @as(usize, @intCast(r));
            if (self.items.len == 0 or i >= self.items.len) {
                try buf.appendSlice(alloc, "\x1b[K\n");
                continue;
            }
            const g = self.items[i];
            const marker: []const u8 = if (i == self.selected) "> " else "  ";
            try buf.appendSlice(alloc, marker);
            try buf.appendSlice(alloc, g.emoji);
            try buf.appendSlice(alloc, "  ");
            const desc = g.description[0..@min(body_width, g.description.len)];
            try buf.appendSlice(alloc, desc);
            try buf.appendSlice(alloc, "\x1b[K\n");
        }

        try buf.appendSlice(alloc, "\x1b[J");
    }
};

const testing = std.testing;

const test_data: []const models.GitmojiConfig = &.{
    .{ .emoji = "🐛", .description = "Fix a bug." },
    .{ .emoji = "🎨", .description = "Improve structure / format of the code." },
    .{ .emoji = "📝", .description = "Add or update documentation." },
    .{ .emoji = "🚀", .description = "Deploy stuff." },
};

test "picker: empty filter shows full list" {
    const alloc = testing.allocator;
    var p = try State.init(alloc, test_data);
    defer p.deinit(alloc);
    try testing.expectEqual(@as(usize, 4), p.items.len);
    try testing.expectEqual(@as(usize, 0), p.selected);
}

test "picker: filter narrows with subsequence match" {
    const alloc = testing.allocator;
    var p = try State.init(alloc, test_data);
    defer p.deinit(alloc);
    try p.typeChar(alloc, 'x');
    try p.typeChar(alloc, 'b');
    try p.typeChar(alloc, 'g');
    try testing.expectEqual(@as(usize, 1), p.items.len);
    try testing.expectEqualStrings("Fix a bug.", p.items[0].description);
}

test "picker: filter with no match" {
    const alloc = testing.allocator;
    var p = try State.init(alloc, test_data);
    defer p.deinit(alloc);
    try p.typeChar(alloc, 'z');
    try testing.expectEqual(@as(usize, 0), p.items.len);
}

test "picker: backspace and clearFilter" {
    const alloc = testing.allocator;
    var p = try State.init(alloc, test_data);
    defer p.deinit(alloc);
    try p.typeChar(alloc, 'z');
    try p.backspace(alloc);
    try testing.expectEqual(@as(usize, 4), p.items.len);
    try p.typeChar(alloc, 'x');
    try p.typeChar(alloc, 'b');
    try p.clearFilter(alloc);
    try testing.expectEqual(@as(usize, 4), p.items.len);
    try testing.expectEqual(@as(usize, 0), p.selected);
}

test "picker: selection moves and clamps" {
    const alloc = testing.allocator;
    var p = try State.init(alloc, test_data);
    defer p.deinit(alloc);
    p.move(1);
    p.move(1);
    try testing.expectEqual(@as(usize, 2), p.selected);
    p.move(100);
    try testing.expectEqual(@as(usize, 3), p.selected);
    p.move(-100);
    try testing.expectEqual(@as(usize, 0), p.selected);
    p.end();
    try testing.expectEqual(@as(usize, 3), p.selected);
    p.home();
    try testing.expectEqual(@as(usize, 0), p.selected);
}

test "picker: page move" {
    const alloc = testing.allocator;
    var p = try State.init(alloc, test_data);
    defer p.deinit(alloc);
    p.page(2, false);
    try testing.expectEqual(@as(usize, 1), p.selected);
    p.page(2, true);
    try testing.expectEqual(@as(usize, 0), p.selected);
}

test "picker: viewport auto-scroll" {
    const alloc = testing.allocator;
    var p = try State.init(alloc, test_data);
    defer p.deinit(alloc);
    p.end();
    p.setViewport(2);
    try testing.expectEqual(@as(usize, 2), p.viewport_top);
    p.home();
    try testing.expectEqual(@as(usize, 0), p.viewport_top);
}

test "picker: render contains rows and no-match line" {
    const alloc = testing.allocator;
    var p = try State.init(alloc, test_data);
    defer p.deinit(alloc);
    var buf = std.ArrayList(u8).empty;
    try p.render(alloc, 10, 80, &buf);
    defer buf.deinit(alloc);
    try testing.expect(std.mem.indexOf(u8, buf.items, "Fix a bug.") != null);
    try p.typeChar(alloc, 'z');
    try p.render(alloc, 10, 80, &buf);
    try testing.expect(std.mem.indexOf(u8, buf.items, "no match for") != null);
}
