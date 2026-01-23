# Changelog

## [0.1.0](https://github.com/hrsh7th/nvim-cmp/compare/v0.0.2...v0.1.0) (2026-01-23)


### Features

* `config.view.entries.vertical_positioning = 'above'|'below'|'auto'` ([#1701](https://github.com/hrsh7th/nvim-cmp/issues/1701)) ([5124cdd](https://github.com/hrsh7th/nvim-cmp/commit/5124cdd05549b7dac75b1968cf5f63091bd84b6f))
* add col_offset option for doc view ([de894da](https://github.com/hrsh7th/nvim-cmp/commit/de894daa2dd81f021038e3fe3a185703e7b57642)), closes [#1528](https://github.com/hrsh7th/nvim-cmp/issues/1528)
* icon and icon highlight separation ([#2190](https://github.com/hrsh7th/nvim-cmp/issues/2190)) ([5a7ce31](https://github.com/hrsh7th/nvim-cmp/commit/5a7ce3198d74537be7d9c92825fed00f5b4546e4))
* max_height for completion window ([#2202](https://github.com/hrsh7th/nvim-cmp/issues/2202)) ([d78fb3b](https://github.com/hrsh7th/nvim-cmp/commit/d78fb3b64eedb701c9939f97361c06483af575e0))
* respect winborder variable ([#2206](https://github.com/hrsh7th/nvim-cmp/issues/2206)) ([0aa22f4](https://github.com/hrsh7th/nvim-cmp/commit/0aa22f42e63b4976161433b292db754e2723fa4d))


### Bug Fixes

* `nvim-neorocks/luarocks-tag-release` should be updated ([#2199](https://github.com/hrsh7th/nvim-cmp/issues/2199)) ([106c4bc](https://github.com/hrsh7th/nvim-cmp/commit/106c4bcc053a5da783bf4a9d907b6f22485c2ea0))
* handle winborder in neovim-0.11 ([#2150](https://github.com/hrsh7th/nvim-cmp/issues/2150)) ([30d2593](https://github.com/hrsh7th/nvim-cmp/commit/30d259327208bf2129724e7db22a912d8b9be6a2))
* Outdated completion item with mini.snippets ([#2126](https://github.com/hrsh7th/nvim-cmp/issues/2126)) ([1250990](https://github.com/hrsh7th/nvim-cmp/commit/12509903a5723a876abd65953109f926f4634c30))
* ref-fix backward compatibility ([059e894](https://github.com/hrsh7th/nvim-cmp/commit/059e89495b3ec09395262f16b1ad441a38081d04))
* remove redundant `and true` ([#2207](https://github.com/hrsh7th/nvim-cmp/issues/2207)) ([9a0a90a](https://github.com/hrsh7th/nvim-cmp/commit/9a0a90a6f722c813272cbbd8bde2b350988843a9))
* Type mismatch in nvim-cmp documentation configuration ([#2182](https://github.com/hrsh7th/nvim-cmp/issues/2182)) ([c4f7dc7](https://github.com/hrsh7th/nvim-cmp/commit/c4f7dc770cdebfc9723333175bcd88d9cdbe8408))
* unicode partial char completion ([#2183](https://github.com/hrsh7th/nvim-cmp/issues/2183)) ([2c019de](https://github.com/hrsh7th/nvim-cmp/commit/2c019de76894f2f9b57ce341755ce354f019ec1b))
* Use winborder for window menu and fix scrollbar window ([#2158](https://github.com/hrsh7th/nvim-cmp/issues/2158)) ([686c17a](https://github.com/hrsh7th/nvim-cmp/commit/686c17addb51401fd2d1faf2fcd1f9327797e712))
* **utils:** Only call callback if type(callback) == "function" ([#2038](https://github.com/hrsh7th/nvim-cmp/issues/2038)) ([1deeb87](https://github.com/hrsh7th/nvim-cmp/commit/1deeb87b6816e966115713952078b3a9277e6387))
