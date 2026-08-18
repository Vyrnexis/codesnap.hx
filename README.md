# codesnap.hx

![Screenshot of CodeSnap in action](screenshot.png)

A simple plugin for [Helix](https://github.com/helix-editor/helix) (using the [Steel plugin branch](https://github.com/mattwparas/helix)) that takes screenshots of your code and copies them to your clipboard. 

Similar to CodeSnap or Polacode for VS Code, but for Helix. It pipes your current visual selection to [silicon](https://github.com/Aloxaf/silicon) to generate the image.

## Requirements

1. **Helix with Steel**: You need a build of Helix that includes the Scheme/Steel plugin system.
2. **Silicon**: Does the actual image generation.
   ```bash
   cargo install silicon
   ```
3. **A clipboard tool**: Defaults to `xclip` (X11). If you use Wayland (`wl-copy`) or macOS (`pbcopy`), you'll need to configure the plugin in your `init.scm`.

## Installation

Install the plugin using `forge` (the Steel package manager):

```bash
forge pkg install --git https://github.com/Vyrnexis/codesnap.hx.git
```

Then add these lines to your `~/.config/helix/helix.scm` file to register the commands:

```scheme
(require (only-in "codesnap/codesnap.scm" codesnap))
(require (only-in "codesnap/codesnap-menu.scm" codesnap-menu))
(provide codesnap codesnap-menu)
```

## Updating

To pull the latest updates for the plugin, run the install command again with the `--force` flag:

```bash
forge pkg install --git https://github.com/Vyrnexis/codesnap.hx.git --force
```

## Usage

Make a visual selection (`v` or `x`) of the code you want to capture, then open the command palette (`:`) and run:

- `:codesnap-menu` — Opens the interactive TUI control panel.

### The CodeSnap Menu

The `:codesnap-menu` is the main interface for CodeSnap. From here, you can instantly snap pictures or toggle your configuration.

**Navigation:**
- Use **Up / Down** arrows (or `j` / `k`) to navigate the menu items.
- Use **Right** arrow (or `l` or `Enter`) to toggle switches (ON/OFF) or to expand submenus like `Theme >` and `Background >`.
- Use **Left** arrow (or `h` or `Escape`) to return to the main menu or close the window.

**Actions:**
- **Snap to Clipboard**: Captures the selection and copies it to your clipboard.
- **Snap to File...**: Captures the selection and saves it to `/tmp/codesnap.png`.
- **Theme**: Opens a picker to select a new syntax highlighting theme.
- **Background**: Opens a picker to choose a background color for the image.
- **Toggles**: Toggle Window Controls, Window Titles, or Line Numbers live.

### Direct Commands

If you prefer to bypass the menu, you can use these commands directly:

- `:codesnap` — Captures the selection and copies it to your clipboard immediately using your current settings.
- `:codesnap <path>` — Saves the screenshot directly to a specific file (e.g. `:codesnap ~/Desktop/code.png`).

## Configuration

You can configure the plugin's default settings by calling `codesnap-configure!` in your `~/.config/helix/init.scm` file:

```scheme
(require (only-in "codesnap/codesnap.scm" codesnap-configure!))

(codesnap-configure! #:theme "Dracula"                 ; Syntax highlighting theme (run `silicon --list-themes` for options)
                     #:background "#aaaaff"            ; Hex color for the background behind the code window
                     #:shadow-blur 15                  ; Size of the drop shadow blur (set to 0 to disable)
                     #:window-controls? #t             ; Show macOS-style window controls
                     #:show-title? #t                  ; Show the filename in the window title bar
                     #:line-numbers? #t                ; Show line numbers on the left side
                     #:pad-horiz 80                    ; Horizontal padding (pixels) around the code window
                     #:pad-vert 100                    ; Vertical padding (pixels) around the code window
                     ;; Clipboard tool command: defaults to xclip (X11)
                     ;; Wayland users: "wl-copy -t image/png <"
                     ;; macOS users: "pbcopy <"
                     #:clipboard-command "xclip -selection clipboard -t image/png -i")
```
