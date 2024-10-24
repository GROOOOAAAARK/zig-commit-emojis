const std = @import("std");
const cli = @import("zig-cli");
const data = @import("./data.zig");
const GitmojiConfig = @import("./models.zig").GitmojiConfig;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var args_definition = struct {
    keyword: []const u8 = undefined,
}{};

fn contains_subsequence(haystack: []const u8, needle: []const u8) bool {
    const needle_len = needle.len;
    const haystack_len = haystack.len;
    for (0..haystack_len - needle_len - 1) |i| {
        if (std.mem.eql(u8, haystack[i .. i + needle_len], needle)) {
            return true;
        }
    }
    return false;
}

fn run_list() !void {
    const data_list = data.data_list;

    for (data_list) |gitmoji| {
        std.log.info("{s} - {s}", .{ gitmoji.emoji, gitmoji.description });
    }
}

fn run_search() !void {
    const args = &args_definition;
    const keyword = args.keyword;
    std.log.info("Searching for {s}...", .{keyword});
    const original_list = data.data_list;
    for (original_list) |gitmoji| {
        if (contains_subsequence(gitmoji.description, keyword)) {
            std.log.info("{s} - {s}", .{ gitmoji.emoji, gitmoji.description });
        }
    }
}

fn list_command() !cli.Command {
    return cli.Command{
        .name = "list",
        .description = cli.Description{ .one_line = "Display all commit emojis available." },
        .target = cli.CommandTarget{ .action = cli.CommandAction{ .exec = run_list } },
    };
}

fn free_args_definition() void {
    allocator.free(args_definition.keyword);
    if (gpa.deinit() == .leak) {
        @panic("args definition leaked");
    }
}

pub fn main_cli() cli.AppRunner.Error!cli.ExecFn {
    var alloc = try cli.AppRunner.init(std.heap.page_allocator);

    const main_command = cli.Command{
        .name = "main_command",
        .description = cli.Description{ .one_line = "zig-commit-emoji helps you use emojis in your commits" },
        .target = cli.CommandTarget{
            .subcommands = &.{
                try list_command(),
                cli.Command{
                    .name = "search",
                    .description = cli.Description{ .one_line = "Searches for a commit emoji based on a keyword." },
                    .options = &[_]cli.Option{
                        cli.Option{
                            .long_name = "keyword",
                            .short_alias = 'k',
                            .required = true,
                            .help = "The keyword to search for in the list.",
                            .value_ref = alloc.mkRef(&args_definition.keyword),
                        },
                    },
                    .target = cli.CommandTarget{ .action = cli.CommandAction{ .exec = run_search } },
                },
            },
        },
    };

    const app = cli.App{
        .version = "0.2.0",
        .author = "GRK",
        .command = main_command,
    };

    free_args_definition();

    return alloc.getAction(&app);
}
