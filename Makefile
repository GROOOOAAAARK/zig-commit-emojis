.PHONY: build install

INSTALL_PATH="${HOME}/.local/bin"
TERMINAL_INTERPRETER="zsh"

build: # Build the project
	@echo "Building..."
	@zig build

build-watch: # Build the project continuously on file changes
	@echo "Building..."
	@watch -i 3 make build

copy-executable:
	@cp ./zig-out/bin/zig-commit-emoji $INSTALL_PATH/

install-path:
	@echo "export PATH=$PATH:$INSTALL_PATH" >> ~/.${TERMINAL_INTERPRETER}env

create-alias:
	@echo "alias zce=zig-commit-emoji" >> ~/.${TERMINAL_INTERPRETER}env

install:
	@mkdir -p $INSTALL_PATH
	@make copy-executable
	@make install-path
	@make create-alias
