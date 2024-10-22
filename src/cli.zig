const std = @import("std");
const cli = @import("zig-cli");
const data = @import("./const.zig");
const GitmojiConfig = data.GitmojiConfig;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn run_list() !void {
    const data_list = [_]GitmojiConfig{
        GitmojiConfig{ .description = "Improve structure / format of the code.", .emoji = "🎨" },
        GitmojiConfig{ .description = "Remove code or files.", .emoji = "🔥" },
    };

    for (data_list) |gitmoji| {
        std.log.info("{s} - {s}", .{ gitmoji.emoji, gitmoji.description });
    }
}

fn list_command() !cli.Command {
    return cli.Command{
        .name = "list",
        .description = cli.Description{ .one_line = "Display all commit emojis available." },
        .target = cli.CommandTarget{ .action = cli.CommandAction{ .exec = run_list } },
    };
}

pub fn main_cli() cli.AppRunner.Error!cli.ExecFn {
    var alloc = try cli.AppRunner.init(std.heap.page_allocator);

    const main_command = cli.Command{
        .name = "main_command",
        .description = cli.Description{ .one_line = "zig-commit-emoji helps you use emojis in your commits" },
        .target = cli.CommandTarget{
            .subcommands = &.{
                try list_command(),
                try search_command(),
            },
        },
    };

    const app = cli.App{
        .version = "0.1.0",
        .author = "GRK",
        .command = main_command,
    };
    return alloc.getAction(&app);
}
