# Helix CodeSnap 📸

A visual, fun, and useful plugin for [Helix](https://github.com/helix-editor/helix) (using the new [Steel](https://github.com/mattwparas/helix) plugin system) that takes a beautiful screenshot of your code selection and copies it straight to your clipboard! 

Inspired by VS Code's Polacode and CodeSnap extensions.

## Dependencies

Before using this plugin, you must have the following installed on your system and available in your `$PATH`:

1. **Helix with Steel Plugin System**: You need a build of Helix that supports the Scheme/Steel plugin system.
2. **[Silicon](https://github.com/Aloxaf/silicon)**: The engine that renders the code into a beautiful image.
   ```bash
   cargo install silicon
   ```
3. **xclip**: Used to pipe the generated image back into your system clipboard (Linux/X11).
   ```bash
   # Debian/Ubuntu
   sudo apt install xclip
   ```

## Installation

1. Copy or download the `codesnap.scm` file from this repository into your Helix configuration folder (e.g., `~/.config/helix/`).

2. Open your `~/.config/helix/helix.scm` file. 

3. Add the following lines to require and export the command so it becomes available in the editor:

```scheme
;; Bring the codesnap function into scope
(require (only-in "codesnap.scm" codesnap))

;; Export it so Helix registers it as a typed command
(provide codesnap)
```

## Usage

1. Open a file in Helix.
2. Highlight the block of code you want to snapshot (using `v` or `x`).
3. Open your command palette and run:
   ```
   :codesnap
   ```
4. You will see a `📸 Snap saved! Language: <your_lang>` message in your status bar.
5. Hit `Ctrl+V` to paste your beautiful new code snippet into Discord, Slack, GitHub, or any image editor!

*(Note: The plugin also saves a hard copy of your most recent snapshot to `/tmp/codesnap.png` in case you ever want the raw file!)*
