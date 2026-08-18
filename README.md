# Helix CodeSnap 📸

A visual, feature-rich plugin for [Helix](https://github.com/helix-editor/helix) (via the [Steel](https://github.com/mattwparas/helix) plugin system) that takes beautiful screenshots of your code and copies them straight to your clipboard! 

Inspired by VS Code's Polacode and CodeSnap extensions.

## Dependencies

1. **Helix with Steel**: You need a build of Helix with the Scheme/Steel plugin system.
2. **[Silicon](https://github.com/Aloxaf/silicon)**: The image rendering engine.
   ```bash
   cargo install silicon
   ```
3. **Clipboard Tool**: Depending on your OS, you need `xclip` (X11), `wl-clipboard` (Wayland), or `pbcopy` (macOS). The plugin defaults to `xclip` but can be easily configured.

## Installation

1. Copy `codesnap.scm` into your Helix configuration folder (`~/.config/helix/`).
2. Open your `~/.config/helix/helix.scm` file and add the following lines:

```scheme
;; Require the functions
(require (only-in "codesnap.scm" codesnap codesnap-save codesnap-theme codesnap-bg))

;; Export them as typed commands in Helix
(provide codesnap codesnap-save codesnap-theme codesnap-bg)
```

## Usage (Commands)

All commands rely on you making a **visual selection** (`v` or `x`) of the code you want to snapshot first!

- `:codesnap` — Captures the selection, generates an image, and copies it to your clipboard.
- `:codesnap-save <path>` — Captures the selection and saves it to a specific file (e.g. `:codesnap-save ~/Desktop/my_code.png`).
- `:codesnap-theme <theme_name>` — Change the syntax highlighting theme on the fly (e.g. `:codesnap-theme Nord`). Check `silicon --list-themes` for a full list.
- `:codesnap-bg <hex>` — Change the background color on the fly (e.g. `:codesnap-bg #ffb86c`).

## Configuration

You can customize the default behavior of CodeSnap by modifying the global variables at the top of the `codesnap.scm` file.

```scheme
;; --- Configuration Options ---
(define *codesnap-theme* "Dracula")            
(define *codesnap-background* "#aaaaff")       
(define *codesnap-shadow-blur* 15)             
(define *codesnap-window-controls* #true)      
(define *codesnap-line-numbers* #true)         

;; Set this to match your OS's clipboard tool!
(define *codesnap-clipboard-command* "xclip -selection clipboard -t image/png -i")
;; For Wayland: "wl-copy -t image/png <"
;; For macOS: "pbcopy <"
```
