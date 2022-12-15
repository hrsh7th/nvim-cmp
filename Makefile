.PHONY: install-stylua
install-stylua:
	@if [ ! -f "./utils/stylua" ]; then \
  		sh ./utils/install_stylua.sh; \
	fi

.PHONY: fmt
fmt: install-stylua
	./utils/stylua --config-path stylua.toml --glob 'lua/**/*.lua' -- lua

.PHONY: lint
lint:
	luacheck ./lua

.PHONY: test
test:
	vusted --output=gtest ./lua

.PHONY: pre-commit
pre-commit: install-stylua
	./utils/stylua --config-path stylua.toml --glob 'lua/**/*.lua' -- lua
	luacheck lua
	vusted lua

.PHONY: integration
integration: install-stylua
	./utils/stylua --config-path stylua.toml --check --glob 'lua/**/*.lua' -- lua
	luacheck lua
	vusted lua

