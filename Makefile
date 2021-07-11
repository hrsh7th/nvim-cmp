.PHONY: test
test:
	vusted ./lua

.PHONY: fmt
fmt:
	stylua --glob lua/**/*.lua -- lua

.PHONY: lint
lint:
	luacheck ./lua

