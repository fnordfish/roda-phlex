# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## [Unreleased]

### Added

- Support for Phlex 2.0 Component context. (`HelloWorld.new.call(context: {some: :data})`).
- `:delegate_on` plugin option to specify the object to delegate methods to.
  Defaults to `::Phlex::SGML` but its advised to set it to your own subclass of `::Phlex::SGML`.
- `:delegate_name` plugin option to specify name of the method that delegates to the Roda app.
  Defaults to `"app"`.

### Changed

### Deprecated

### Removed

- `delegate: :all` plugin option removed. You need to specify the methods to delegate explicitly.
- `delegate: <Symbol,String>` plugin option removed. Method names need to be specified as an array of
  symbols or strings, even when delegating only one method.

### Fixed

### Security

## [0.2.0] - 2024-12-13

### Added

- Allow `phlex_layout(false)` to be used to reset disable layout.
- Allow `phlex_layout_handler(:default)` to be used to reset to the default layout handler.

### Removed

- Don't delete layout options when deleting layout (eg via `phlex_layout(false)`)

### Fixed

- `phlex_layout` should accept a `Phlex::SGML` class, not instance.
- `phlex_layout_handler` called with `nil` resets it to the default handler.

## [0.1.0] - 2024-08-28

- Initial release based on <https://github.com/benpickles/phlex-sinatra/commit/2e3c9a612cbf6f4b4bf5db880f164b66f008baf8>
  and <https://gist.github.com/RomanTurner/0ce0b8792e4149d152d2af2224cb6407>

________________________________________________________________________________

[Unreleased]: https://github.com/fnordfish/roda-phlex/compare/v0.2.0...main
[0.2.0]: https://github.com/fnordfish/roda-phlex/releases/tag/v0.2.0
[0.1.0]: https://github.com/fnordfish/roda-phlex/releases/tag/v0.1.0

<!-- template for new release:
### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [X.Y.Z] - YYYY-MM-DD
-->