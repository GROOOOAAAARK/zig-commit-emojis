const std = @import("std");
const cli = @import("./cli.zig");

pub fn main() !void {
    const action = try cli.main_cli();
    return action();
}
