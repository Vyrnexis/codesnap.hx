# Changelog

## 0.4.0

- Run Silicon directly with structured arguments instead of shell commands.
- Stream selections through stdin without temporary files or clipboard yanks.
- Use Silicon's native cross-platform image clipboard support.
- Report verified render success and actionable failures asynchronously.
- Prompt for file destinations instead of silently overwriting a fixed path.
- Preserve multiple selections with newline separators.
- Validate themes, colors, toggles, padding, blur, and command arguments.
- Load installed Silicon themes and focus setting pickers on current values.
- Retry unsupported Helix language names using the file extension and Markdown.
- Run dependency-free core checks in GitHub Actions.
- Deprecate and ignore `#:clipboard-command`; Silicon now owns clipboard integration.
