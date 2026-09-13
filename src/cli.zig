const std = @import("std");
const cli = @import("cli");
const data = @import("./data.zig");
const search_utils = @import("./search_utils.zig");

var args_definition = struct {
    keyword: []const u8 = undefined,
}{};

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
        if (search_utils.contains(gitmoji.description, keyword)) {
            std.log.info("{s} - {s}", .{ gitmoji.emoji, gitmoji.description });
        }
    }
}

fn print_line(io: std.Io, stream: std.Io.File, line: []const u8) !void {
    var buf: [4096]u8 = undefined;
    var w = stream.writer(io, &buf);
    std.Io.Writer.print(&w.interface, "{s}\n", .{line}) catch return error.WriteFailed;
    std.Io.File.Writer.flush(&w) catch return error.WriteFailed;
}

fn do_git_commit(io: std.Io, alloc: std.mem.Allocator, msg: []const u8, tag: ?[]const u8) !void {
    const argv_plain = [_][]const u8{ "git", "commit", "-m", msg };
    var child = try std.process.spawn(io, .{ .argv = argv_plain[0..] });
    const term = try child.wait(io);
    switch (term) {
        .exited => |code| {
            if (code != 0) std.process.exit(code);
        },
        else => std.process.exit(1),
    }
    if (tag) |t| {
        const argv_tag = [_][]const u8{ "git", "tag", t };
        var tag_child = try std.process.spawn(io, .{ .argv = argv_tag[0..] });
        const tag_term = try tag_child.wait(io);
        switch (tag_term) {
            .exited => |code| {
                if (code != 0) std.process.exit(code);
            },
            else => std.process.exit(1),
        }
    }
    try print_line(io, std.Io.File.stdout(), try std.fmt.allocPrint(alloc, "Committed \"{s}\"", .{msg}));
}

fn run_commit() !void {
    const r = g_runner;
    const res = commit_cmd.run(r.arena.allocator()) catch |err| {
        if (err == error.NotATty) {
            print_line(r.io, std.Io.File.stderr(), "commit requires an interactive terminal") catch {};
        }
        return err;
    };
    switch (res) {
        .aborted => return,
        .cancelled => std.process.exit(130),
        .picked => |msg| {
            const tag = if (commit_args.tag.len > 0) commit_args.tag else null;
            if (commit_args.dry_run) {
                try print_line(r.io, std.Io.File.stdout(), msg);
                if (tag) |t| {
                    try print_line(r.io, std.Io.File.stdout(), try std.fmt.allocPrint(r.arena.allocator(), "would also create tag \"{s}\"", .{t}));
                }
                return;
            }
            try do_git_commit(r.io, r.arena.allocator(), msg, tag);
        },
    }
}

fn list_command() !cli.Command {
    return cli.Command{
        .name = "list",
        .description = cli.Description{ .one_line = "Display all commit emojis available." },
        .target = cli.CommandTarget{ .action = cli.CommandAction{ .exec = run_list } },
    };
}

fn search_command(r: *cli.AppRunner) !cli.Command {
    return cli.Command{
        .name = "search",
        .description = cli.Description{ .one_line = "Searches for a commit emoji based on a keyword." },
        .options = &[_]cli.Option{
            cli.Option{
                .long_name = "keyword",
                .short_alias = 'k',
                .required = true,
                .help = "The keyword to search for in the list.",
                .value_ref = r.mkRef(&args_definition.keyword),
            },
        },
        .target = cli.CommandTarget{ .action = cli.CommandAction{ .exec = run_search } },
    };
}

fn commit_command(r: *cli.AppRunner) !cli.Command {
    return cli.Command{
        .name = "commit",
        .description = cli.Description{ .one_line = "Pick a gitmoji, write a message and commit." },
        .options = &[_]cli.Option{
            cli.Option{
                .long_name = "dry-run",
                .short_alias = 'd',
                .required = false,
                .help = "Print the final message instead of running git commit.",
                .value_ref = r.mkRef(&commit_args.dry_run),
            },
            cli.Option{
                .long_name = "tag",
                .short_alias = 't',
                .required = false,
                .help = "Create a light tag on the produced commit.",
                .value_ref = r.mkRef(&commit_args.tag),
                .value_name = "TAG",
            },
        },
        .target = cli.CommandTarget{ .action = cli.CommandAction{ .exec = run_commit } },
    };
}

pub fn main_cli(r: *cli.AppRunner) cli.AppRunner.Error!cli.ExecFn {
    g_runner = r;
    const main_command = cli.Command{
        .name = "main_command",
        .description = cli.Description{ .one_line = "⚡ zig-commit-emoji helps you use emojis in your commits" },
        .target = cli.CommandTarget{
            .subcommands = &.{
                try list_command(),
                try search_command(r),
                try commit_command(r),
            },
        },
    };

    const app = cli.App{
        .version = "0.3.1",
        .author = "GRK",
        .command = main_command,
    };

    return r.getAction(&app);
}
