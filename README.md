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
(require (only-in "codesnap/codesnap.scm" codesnap codesnap-theme codesnap-bg))
(provide codesnap codesnap-theme codesnap-bg)
```

## Updating

To pull the latest updates for the plugin, run the install command again with the `--force` flag:

```bash
forge pkg install --git https://github.com/Vyrnexis/codesnap.hx.git --force
```

## Usage

Make a visual selection (`v` or `x`) of the code you want to capture, then run one of the following commands:

- `:codesnap` — Captures the selection and copies it to your clipboard.
- `:codesnap <path>` — Saves the screenshot directly to a specific file (e.g. `:codesnap ~/Desktop/code.png`).
- `:codesnap-theme <theme_name>` — Overrides the current syntax highlighting theme (e.g. `:codesnap-theme Nord`). Run `silicon --list-themes` in your terminal to see what's installed.
- `:codesnap-bg <hex>` — Overrides the current background color (e.g. `:codesnap-bg #ffb86c`).

## Configuration

You can configure the plugin's default settings by calling `codesnap-configure!` in your `~/.config/helix/init.scm` file:

```scheme
(require (only-in "codesnap/codesnap.scm" codesnap-configure!))

(codesnap-configure! #:theme "Dracula"
                     #:background "#aaaaff"
                     #:shadow-blur 15
                     #:window-controls? #t
                     #:line-numbers? #t
                     #:pad-horiz 80
                     #:pad-vert 100
                     ;; Change this if you are on Wayland (wl-copy) or macOS (pbcopy)
                     #:clipboard-command "xclip -selection clipboard -t image/png -i")
```
