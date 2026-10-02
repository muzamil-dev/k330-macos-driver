.PHONY: all build install uninstall clean test status

all: build

build:
	@mkdir -p build
	swiftc src/*.swift \
		-framework Foundation \
		-framework CoreGraphics \
		-framework Carbon \
		-framework IOKit \
		-framework AppKit \
		-O \
		-o build/k330d

install: build
	@./scripts/install.sh

uninstall:
	@./scripts/uninstall.sh

test: build
	@./build/k330d test

status: build
	@./build/k330d status

clean:
	@rm -rf build
