.PHONY: build build-watch

build: # Build the project
	@echo "Building..."
	@zig build

build-watch: # Build the project continuously on file changes
	@echo "Building..."
	@watch -i 3 make build
