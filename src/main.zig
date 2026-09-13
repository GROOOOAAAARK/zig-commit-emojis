const std = @import("std");
const cli = @import("cli");
const app = @import("./cli.zig");

pub fn main(init: std.process.Init) !void {
    var r = cli.AppRunner.init(&init);
    defer r.deinit();

    const action = try app.main_cli(&r);
    return action();
}

test {
    _ = @import("./search_utils.zig");
    _ = @import("./terminal.zig");
    _ = @import("./picker.zig");
    _ = @import("./message.zig");
}
