# Zig Commit Emoji

## Description

This project is a discovery of Zig through the following usecase: use a service to get a list of emojis usable in commit as well as a search feature to make sure to find the right one in any situation.

## Requirements

- Zig 0.16.0

## Project

```bash
zig build run
```

```bash
./zig-out/bin/zig-commit-emoji --help
```

## Features

### List

#### What does it do ?

Will simply list all emojis available with their description.

#### How to use ?

```bash
./zig-commit-emoji list
```

### Search

#### What does it do ?

Will look for the keyword typed in all emojis descriptions.

#### How to use ?

```bash
./zig-commit-emoji search -k <keyword>
```

```bash
./zig-commit-emoji search -k "feat"
```

### Commit

#### What does it do ?

Interactively pick a gitmoji in a filterable list, then edit the commit
message (pre-filled with the picked emoji) and run `git commit -m "<emoji> <message>"`.

#### How to use ?

```bash
./zig-commit-emoji commit
```

Options:

- `-d, --dry-run` — print the final message (and the tag, when given)
  instead of running `git commit`.
- `-t, --tag <TAG>` — create a light tag on the produced commit.

Key bindings:

| List phase | Message phase |
|---|---|
| letters → filter the list (subsequence match) | printable → insert at cursor |
| Up/Down, PgUp/PgDn, Home/End → move selection | Left/Right/Home/End → move cursor |
| Backspace → remove last filter char | Backspace/Delete → edit text |
| Enter → pick the selected emoji | Enter → commit |
| Esc → clear filter, or abort when the filter is empty | Esc → back to the list |
| Ctrl+C → abort (exit 130) | Ctrl+C → abort (exit 130) |
