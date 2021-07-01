.PHONY: test
test:
	vusted ./lua

.PHONY: lint
lint:
	luacheck ./lua

