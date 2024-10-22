const std = @import("std");
const cli = @import("zig-cli");
const data = @import("./const.zig");
const GitmojiConfig = data.GitmojiConfig;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn run_list() !void {
    const data_list = [_]GitmojiConfig{ GitmojiConfig{ .emoji = "🎨", .description = "Improve structure / format of the code." }, GitmojiConfig{ .emoji = "⚡️", .description = "Improve performance." }, GitmojiConfig{ .emoji = "🔥", .description = "Remove code or files." }, GitmojiConfig{ .emoji = "🐛", .description = "Fix a bug." }, GitmojiConfig{ .emoji = "🚑️", .description = "Critical hotfix." }, GitmojiConfig{ .emoji = "✨", .description = "Introduce new features." }, GitmojiConfig{ .emoji = "📝", .description = "Add or update documentation." }, GitmojiConfig{ .emoji = "🚀", .description = "Deploy stuff." }, GitmojiConfig{ .emoji = "💄", .description = "Add or update the UI and style files." }, GitmojiConfig{ .emoji = "🎉", .description = "Begin a project." }, GitmojiConfig{ .emoji = "✅", .description = "Add, update, or pass tests." }, GitmojiConfig{ .emoji = "🔒️", .description = "Fix security or privacy issues." }, GitmojiConfig{ .emoji = "🔐", .description = "Add or update secrets." }, GitmojiConfig{ .emoji = "🔖", .description = "Release / Version tags." }, GitmojiConfig{ .emoji = "🚨", .description = "Fix compiler / linter warnings." }, GitmojiConfig{ .emoji = "🚧", .description = "Work in progress." }, GitmojiConfig{ .emoji = "💚", .description = "Fix CI Build." }, GitmojiConfig{ .emoji = "⬇️", .description = "Downgrade dependencies." }, GitmojiConfig{ .emoji = "⬆️", .description = "Upgrade dependencies." }, GitmojiConfig{ .emoji = "📌", .description = "Pin dependencies to specific versions." }, GitmojiConfig{ .emoji = "👷", .description = "Add or update CI build system." }, GitmojiConfig{ .emoji = "📈", .description = "Add or update analytics or track code." }, GitmojiConfig{ .emoji = "♻️", .description = "Refactor code." }, GitmojiConfig{ .emoji = "➕", .description = "Add a dependency." }, GitmojiConfig{ .emoji = "➖", .description = "Remove a dependency." }, GitmojiConfig{ .emoji = "🔧", .description = "Add or update configuration files." }, GitmojiConfig{ .emoji = "🔨", .description = "Add or update development scripts." }, GitmojiConfig{ .emoji = "🌐", .description = "Internationalization and localization." }, GitmojiConfig{ .emoji = "✏️", .description = "Fix typos." }, GitmojiConfig{ .emoji = "💩", .description = "Write bad code that needs to be improved." }, GitmojiConfig{ .emoji = "⏪️", .description = "Revert changes." }, GitmojiConfig{ .emoji = "🔀", .description = "Merge branches." }, GitmojiConfig{ .emoji = "📦️", .description = "Add or update compiled files or packages." }, GitmojiConfig{ .emoji = "👽️", .description = "Update code due to external API changes." }, GitmojiConfig{ .emoji = "🚚", .description = "Move or r   ename resources (e.g.: files, paths, routes)." }, GitmojiConfig{ .emoji = "📄", .description = "Add or update license." }, GitmojiConfig{ .emoji = "💥", .description = "Introduce breaking changes." }, GitmojiConfig{ .emoji = "🍱", .description = "Add or update assets." }, GitmojiConfig{ .emoji = "♿️", .description = "Improve accessibility." }, GitmojiConfig{ .emoji = "💡", .description = "Add or update comments in source code." }, GitmojiConfig{ .emoji = "🍻", .description = "Write code drunkenly." }, GitmojiConfig{ .emoji = "💬", .description = "Add or update text and literals." }, GitmojiConfig{ .emoji = "🗃️", .description = "Perform database related changes." }, GitmojiConfig{ .emoji = "🔊", .description = "Add or update logs." }, GitmojiConfig{ .emoji = "🔇", .description = "Remove logs." }, GitmojiConfig{ .emoji = "👥", .description = "Add or update contributor(s)." }, GitmojiConfig{ .emoji = "🚸", .description = "Improve user experience / usability." }, GitmojiConfig{ .emoji = "🏗️", .description = "Make architectural changes." }, GitmojiConfig{ .emoji = "📱", .description = "Work on responsive design." }, GitmojiConfig{ .emoji = "🤡", .description = "Mock things." }, GitmojiConfig{ .emoji = "🥚", .description = "Add or update an easter egg." }, GitmojiConfig{ .emoji = "🙈", .description = "Add or update a .gitignore file." }, GitmojiConfig{ .emoji = "📸", .description = "Add or update snapshots." }, GitmojiConfig{ .emoji = "⚗️", .description = "Perform experiments." }, GitmojiConfig{ .emoji = "🔍️", .description = "Improve SEO." }, GitmojiConfig{ .emoji = "🏷️", .description = "Add or update types." }, GitmojiConfig{ .emoji = "🌱", .description = "Add or update seed files." }, GitmojiConfig{ .emoji = "🚩", .description = "Add, update, or remove feature flags." }, GitmojiConfig{ .emoji = "🥅", .description = "Catch errors." }, GitmojiConfig{ .emoji = "💫", .description = "Add or update animations and transitions." }, GitmojiConfig{ .emoji = "🗑️", .description = "Deprecate code that needs to be cleaned up." }, GitmojiConfig{ .emoji = "🛂", .description = "Work on code related to authorization, roles and permissions." }, GitmojiConfig{ .emoji = "🩹", .description = "Simple fix for a non-critical issue." }, GitmojiConfig{ .emoji = "🧐", .description = "Data exploration/inspection." }, GitmojiConfig{ .emoji = "⚰️", .description = "Remove dead code." }, GitmojiConfig{ .emoji = "🧪", .description = "Add a failing test." }, GitmojiConfig{ .emoji = "👔", .description = "Add or update business logic." }, GitmojiConfig{ .emoji = "🩺", .description = "Add or update healthcheck." }, GitmojiConfig{ .emoji = "🧱", .description = "Infrastructure related changes." }, GitmojiConfig{ .emoji = "🧑‍💻", .description = "Improve developer experience." }, GitmojiConfig{ .emoji = "💸", .description = "Add sponsorships or money related infrastructure." }, GitmojiConfig{ .emoji = "🧵", .description = "Add or update code related to multithreading or concurrency." }, GitmojiConfig{ .emoji = "🦺", .description = "Add or update code related to validation." } };

    for (data_list) |gitmoji| {
        std.log.info("{s} - {s}", .{ gitmoji.emoji, gitmoji.description });
    }
}

fn run_search() !void {
    std.log.info("Not implemented yet !", .{});
}

fn list_command() !cli.Command {
    return cli.Command{
        .name = "list",
        .description = cli.Description{ .one_line = "Display all commit emojis available." },
        .target = cli.CommandTarget{ .action = cli.CommandAction{ .exec = run_list } },
    };
}

fn search_command() !cli.Command {
    return cli.Command{
        .name = "search",
        .description = cli.Description{ .one_line = "Searches for a commit emoji based on a keyword." },
        .target = cli.CommandTarget{ .action = cli.CommandAction{ .exec = run_search } },
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
