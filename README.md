# Zig Commit Emoji

## Description

This project is a discovery of Zig through the following usecase: use a service to get a list of emojis usable in commit as well as a search feature to make sure to find the right one in any situation.

## Requirements

- Zig 0.13.0

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
