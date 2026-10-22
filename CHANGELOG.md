# Changelog

All notable changes to this project are documented here.

## 0.5.0

### Added

- Persistent settings: **Save Settings** (or `:codesnap-save-config`) writes `codesnap.toml` to the Helix configuration directory, loaded automatically each session. `codesnap-configure!` in `helix.scm` still takes precedence.
- `:codesnap-doctor` and a **Check Setup** menu entry report the Silicon version, clipboard tools, settings file, and invalid saved values.
- `:codesnap-copy` and `:codesnap-save [path]` for key bindings; saving without a path uses the suggested unique filename.
- Save path completion, unique source/timestamp filenames, and a remembered save directory.
- Open the last saved capture with the system viewer.
- Searchable themes and fonts, custom values, responsive menus, reset, and configuration export.
- Font size, editor-aware tab width, optional source line numbers, and common-indent removal.
- A real-Helix smoke test (`tests/helix/smoke.py`), a Helix API contract check, and `CONTRIBUTING.md`.

### Changed

- All Helix editor calls live in `codesnap-compat.scm`.
- Updated ui-utils.hx to its automatic overlay-scaling release.
- CI runs against Steel 0.8.2 and Steel master, and checks the Helix API weekly.
- README rewritten around a quick start; development notes moved to `CONTRIBUTING.md`.

### Fixed

- Refresh the background picker's current colour and active preset marker immediately.
- Keep menu rows stationary until the highlight crosses a visible edge, retaining wraparound.
- Preserve Silicon diagnostics, including exit-zero failures, and retry unsupported clipboard syntaxes.
- Isolate external Silicon configuration and prevent overlapping captures.
- Stage file captures safely, confirm replacements, and keep existing images when rendering fails.
- Stop delayed status clearing from erasing unrelated editor messages.
- Preserve selection line endings without inserting duplicate blank lines.

## 0.4.0

- Run Silicon directly with structured arguments instead of shell commands.
- Stream selections through stdin without temporary source or image files.
- Use Silicon's native cross-platform image clipboard support.
- Report verified render success and actionable failures asynchronously.
- Prompt for file destinations instead of silently overwriting a fixed path.
- Preserve multiple selections with newline separators.
- Validate themes, colors, toggles, padding, blur, and command arguments.
- Load installed Silicon themes and focus setting pickers on current values.
- Retry unsupported Helix language names using the file extension and Markdown.
- Run dependency-free core checks in GitHub Actions.
- Deprecate and ignore `#:clipboard-command`; Silicon now owns clipboard integration.
- Keep menu hints inside their overlays and suppress internal thread handles.
- Complete clipboard status promptly and clear successful messages automatically.
