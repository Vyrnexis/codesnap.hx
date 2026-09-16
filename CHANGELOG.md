# Changelog

## Unreleased

- Keep menu rows stationary until the highlight crosses a visible edge, retaining wraparound navigation.
- Preserve Silicon diagnostics, including exit-zero failures, and retry unsupported clipboard syntaxes.
- Isolate external Silicon configuration and prevent overlapping captures.
- Stage file captures safely, confirm replacements, and preserve existing images on render failure.
- Stop delayed status clearing from erasing unrelated editor messages.
- Preserve selection line endings without inserting duplicate blank lines.
- Complete save paths, suggest unique source/timestamp filenames, and remember the last save directory.
- Open the last saved capture with the system viewer.
- Add searchable themes and fonts, custom settings, responsive menus, reset, and configuration export.
- Add font sizing, editor-aware tab width, optional source line numbers, and common-indent removal.
- Cover process errors, fallback, inherited output handles, and safe replacement in CI.

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
