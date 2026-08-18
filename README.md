# codesnap.hx

![Screenshot of CodeSnap in action](screenshots/screenshot.png)

A simple plugin for [Helix](https://github.com/helix-editor/helix) (using the [Steel plugin branch](https://github.com/mattwparas/helix)) that takes screenshots of your code and copies them to your clipboard. 

Similar to CodeSnap or Polacode for VS Code, but for Helix. It pipes your current visual selection to [silicon](https://github.com/Aloxaf/silicon) to generate the image.

## The Control Panel

The plugin features a fully interactive TUI control panel for taking snaps and live-previewing settings:

<p align="center">
  <img src="screenshots/menu.png" alt="CodeSnap Main Menu" width="48%" />
  <img src="screenshots/settings.png" alt="CodeSnap Settings Menu" width="48%" />
</p>

## Requirements

1. **Helix with Steel**: You need a build of Helix that includes the Scheme/Steel plugin system.
2. **Silicon**: Does the actual image generation.
   ```bash
   cargo install silicon
   ```
3. **A clipboard tool**: Defaults to `xclip` (X11). If you use Wayland (`wl-copy`) or macOS (`pbcopy`), you'll need to configure the plugin in your `init.scm`.

## Installation & Setup

1. Install the plugin using `forge` (the Steel package manager):

```bash
forge pkg install --git https://github.com/Vyrnexis/codesnap.hx.git
```

2. Add these lines to your `~/.config/helix/helix.scm` file to register the commands:

```scheme
(require (only-in "codesnap/codesnap.scm" codesnap))
(require (only-in "codesnap/codesnap-menu.scm" codesnap-menu))
(provide codesnap codesnap-menu)
```

## Configuration

You can make your favorite settings persist across editor restarts by calling `codesnap-configure!` in your `~/.config/helix/init.scm` file:

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

## Usage

Make a visual selection (`v` or `x`) of the code you want to capture, then open the command palette (`:`) and run:

- `:codesnap-menu` — Opens the interactive TUI control panel.

### The CodeSnap Menu

The `:codesnap-menu` is the main interface for CodeSnap. From here, you can instantly snap pictures or explore different configurations visually.

**Navigation:**
- Use **Up / Down** arrows (or `j` / `k`) to navigate the menu items.
- Use **Enter** to expand submenus or execute "Snap" actions.
- Use **Space** to toggle switches (ON/OFF) or to visually preview a Theme/Background/Padding without closing the menu!
- Use **Right** arrow (or `l`) to expand submenus without executing actions.
- Use **Left** arrow (or `h`) to gently return to the main menu from a submenu.
- Use **Escape** to close the window from anywhere.

**Actions:**
- **Snap to Clipboard**: Captures the selection and copies it to your clipboard.
- **Snap to File...**: Captures the selection and saves it to `~/Pictures/codesnap-$(date +%s).png`.
- **Settings >**: Opens the configuration submenu where you can visually tweak:
  - **Themes** and **Backgrounds** (includes Transparent option!)
  - **Shadow Blur**
  - **Padding** (Horizontal & Vertical)
  - **Toggles** for Window Controls, Titles, and Line Numbers.

*(Note: Settings tweaked in the menu are for live previewing. To persist them, add them to your `init.scm`)*

### Direct Commands

If you prefer to bypass the menu, you can use these commands directly:

- `:codesnap` — Captures the selection and copies it to your clipboard immediately using your current settings.
- `:codesnap <path>` — Saves the screenshot directly to a specific file (e.g. `:codesnap ~/Desktop/code.png`).

## Updating

To pull the latest updates for the plugin, run the install command again with the `--force` flag:

```bash
forge pkg install --git https://github.com/Vyrnexis/codesnap.hx.git --force
```
