.PHONY: fmt
fmt:
	stylua --glob lua/**/*.lua -- lua

.PHONY: lint
lint:
	luacheck ./lua

.PHONY: test
test:
	vusted ./lua

.PHONY: integration
integration:
	stylua --check --glob lua/**/*.lua -- lua
	luacheck lua
	vusted lua

