(require (prefix-in helix. "helix/commands.scm"))
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/ext.scm")

(provide codesnap codesnap-save codesnap-theme codesnap-bg)

;; --- Configuration Options ---
(define *codesnap-theme* "Dracula")            ; See `silicon --list-themes`
(define *codesnap-background* "#aaaaff")       ; Hex color
(define *codesnap-shadow-blur* 15)             ; Blur radius (0 to disable)
(define *codesnap-window-controls* #true)      ; Show macOS window controls
(define *codesnap-line-numbers* #true)         ; Show line numbers
(define *codesnap-pad-horiz* 80)
(define *codesnap-pad-vert* 100)

;; Set to your clipboard manager of choice (pbcopy, wl-copy, xclip, etc.)
(define *codesnap-clipboard-command* "xclip -selection clipboard -t image/png -i")

;; --- Internal Helpers ---
(define (current-language)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)]
         [lang (editor-document->language focus-doc-id)])
    (if lang lang "txt")))

(define (bool->flag bool flag)
  (if bool "" flag))

(define (build-silicon-args lang out-path)
  (string-append
   "silicon --from-clipboard -l " lang
   " --theme \"" *codesnap-theme* "\""
   " --background \"" *codesnap-background* "\""
   " --shadow-blur-radius " (number->string *codesnap-shadow-blur*)
   " --pad-horiz " (number->string *codesnap-pad-horiz*)
   " --pad-vert " (number->string *codesnap-pad-vert*)
   " " (bool->flag *codesnap-window-controls* "--no-window-controls")
   " " (bool->flag *codesnap-line-numbers* "--no-line-number")
   " -o " out-path))

;; --- Commands ---

;;@doc
;; Captures the selection as an image and copies it to your clipboard
(define (codesnap)
  (helix.clipboard-yank)
  (enqueue-thread-local-callback-with-delay
   100
   (lambda ()
     (let* ([lang (current-language)]
            [tmp-file "/tmp/codesnap_capture.png"]
            [silicon-cmd (build-silicon-args lang tmp-file)]
            [full-cmd (string-append silicon-cmd " && " *codesnap-clipboard-command* " " tmp-file)])
       (helix.run-shell-command full-cmd)
       (set-status! (string-append "📸 Snap saved to clipboard! Theme: " *codesnap-theme*))))))

;;@doc
;; Captures the selection and saves it to a specific file path. Example: :codesnap-save ~/Desktop/code.png
(define (codesnap-save path)
  (helix.clipboard-yank)
  (enqueue-thread-local-callback-with-delay
   100
   (lambda ()
     (let* ([lang (current-language)]
            [silicon-cmd (build-silicon-args lang path)])
       (helix.run-shell-command silicon-cmd)
       (set-status! (string-append "📸 Snap saved to " path "!"))))))

;;@doc
;; Changes the active codesnap theme. Example: :codesnap-theme Nord
(define (codesnap-theme theme)
  (set! *codesnap-theme* theme)
  (set-status! (string-append "🎨 CodeSnap theme set to: " theme)))

;;@doc
;; Changes the background color (Hex). Example: :codesnap-bg #ffb86c
(define (codesnap-bg hex)
  (set! *codesnap-background* hex)
  (set-status! (string-append "🎨 CodeSnap background set to: " hex)))
