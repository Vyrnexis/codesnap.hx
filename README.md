# codesnap.hx

[![Tests](https://github.com/Vyrnexis/codesnap.hx/actions/workflows/test.yml/badge.svg)](https://github.com/Vyrnexis/codesnap.hx/actions/workflows/test.yml)

![Screenshot of CodeSnap in action](screenshots/screenshot.png)

A plugin for [Helix](https://github.com/helix-editor/helix) using the [Steel plugin branch](https://github.com/mattwparas/helix/tree/steel-event-system) that renders selected code as an image.

Similar to CodeSnap or Polacode for VS Code, but for Helix. It pipes your current visual selection to [silicon](https://github.com/Aloxaf/silicon) to generate the image.

## Features

- Copy rendered code directly to the system clipboard.
- Save to a path chosen through the menu or command palette.
- Configure themes, backgrounds, padding, shadows, titles, and line numbers.
- Discover themes from the installed Silicon version.
- Preserve multiple selections as separate lines.
- Render asynchronously without changing the selection or clipboard on cancel.

## Interface

<p align="center">
  <img src="screenshots/menu.png" alt="CodeSnap main menu" width="48%" />
  <img src="screenshots/settings.png" alt="CodeSnap settings menu" width="48%" />
</p>

## Requirements

1. **Helix with Steel**: You need a build of Helix that includes the Scheme/Steel plugin system.
2. **Silicon**: Does the actual image generation.
   ```bash
   cargo install silicon
   ```

Silicon owns clipboard integration. On Linux, install the clipboard tool required by Silicon for your Wayland or X11 session.

## Installation & Setup

1. Install the plugin using `forge` (the Steel package manager):

```bash
forge pkg install --git https://github.com/Vyrnexis/codesnap.hx.git
```

2. Add these lines to your `~/.config/helix/helix.scm` file:

```scheme
(require (only-in "codesnap/codesnap.scm" codesnap codesnap-configure!))
(require (only-in "codesnap/codesnap-menu.scm" codesnap-menu))

;; Optional: Customize default settings (values shown are defaults)
(codesnap-configure! #:theme "Dracula"                 ; Syntax highlighting theme (run `silicon --list-themes` for options)
                     #:background "#aaaaff"            ; Hex color for the background behind the code window
                     #:shadow-blur 15                  ; Size of the drop shadow blur (set to 0 to disable)
                     #:window-controls? #t             ; Show macOS-style window controls
                     #:show-title? #t                  ; Show the filename in the window title bar
                     #:line-numbers? #t                ; Show line numbers on the left side
                     #:pad-horiz 80                    ; Horizontal padding (pixels) around the code window
                     #:pad-vert 100)                   ; Vertical padding (pixels) around the code window

;; Export only the desired typed commands to the Helix command palette
(provide codesnap codesnap-menu)
```

## Usage

Make a visual selection (`v` or `x`) of the code you want to capture, then open the command palette (`:`) and run:

- `:codesnap-menu` — Opens the interactive TUI control panel.

### The CodeSnap Menu

The `:codesnap-menu` is the main interface for captures and interactive settings.

**Navigation:**
- Use **Up / Down** arrows (or `j` / `k`) to navigate items.
- Use **Enter** to execute snap actions, open submenus, or apply a setting and return.
- Use **Space** to apply a Theme/Background/Padding setting immediately without closing, or to toggle switches (ON/OFF).
- Use **Right** arrow (or `l`) to expand submenus.
- Use **Left** arrow (or `h` / `q`) to return to the parent menu or close the menu.
- Use **Escape** to return one level, or close the main menu.

**Actions:**
- **Snap to Clipboard**: Captures the selection and copies it to your clipboard.
- **Snap to File...**: Prompts for a destination path before rendering.
- **Settings >**: Opens the configuration submenu where you can change:
  - **Themes** and **Backgrounds** (includes Transparent option)
  - **Shadow Blur**
  - **Padding** (Horizontal & Vertical)
  - **Toggles** for Window Controls, Titles, and Line Numbers.

Settings take effect immediately for the current editor session. Add them to `helix.scm` to persist them across restarts.

### Direct Commands

If you prefer to bypass the menu, you can use these commands directly:

- `:codesnap` — Captures the selection and copies it to your clipboard immediately using your current settings.
- `:codesnap <path>` — Saves the screenshot directly to a specific file (e.g. `:codesnap ~/Desktop/code.png`).

Quote paths containing spaces, for example `:codesnap "~/Desktop/code sample.png"`.

## Feedback and Errors

CodeSnap displays `rendering...` while Silicon runs and reports success only after the render completes. Missing Silicon, invalid settings, unsupported output paths, and clipboard failures are shown in the Helix status line.

Unsupported Helix language identifiers are retried using the current filename extension and then Markdown syntax.

## Development

Run the dependency-free core checks with:

```bash
steel tests/codesnap-core-test.scm
```

## Updating

To pull the latest updates for the plugin, run the install command again with the `--force` flag:

```bash
forge pkg install --git https://github.com/Vyrnexis/codesnap.hx.git --force
```

## License

[MIT](LICENSE)
