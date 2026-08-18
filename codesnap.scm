(require (prefix-in helix. "helix/commands.scm"))
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/ext.scm")

(provide codesnap codesnap-execute codesnap-theme codesnap-bg codesnap-configure! *codesnap-theme*)

;; --- Default Configuration Options ---
(define *codesnap-theme* "Dracula")            ; Syntax highlighting theme (run `silicon --list-themes` for options)
(define *codesnap-background* "#aaaaff")       ; Hex color for the background behind the code window
(define *codesnap-shadow-blur* 15)             ; Size of the drop shadow blur (set to 0 to disable)
(define *codesnap-window-controls* #true)      ; Show macOS-style window controls (red/yellow/green dots)
(define *codesnap-show-title* #true)           ; Show the current filename in the window title bar
(define *codesnap-line-numbers* #true)         ; Show line numbers on the left side
(define *codesnap-pad-horiz* 80)               ; Horizontal padding (pixels) around the code window
(define *codesnap-pad-vert* 100)               ; Vertical padding (pixels) around the code window
(define *codesnap-clipboard-command* "xclip -selection clipboard -t image/png -i") ; Command used to copy to clipboard

;; --- Configuration API ---

;;@doc
;; Configures codesnap defaults. Best called from your init.scm!
(define (codesnap-configure! #:theme [theme *codesnap-theme*]
                             #:background [background *codesnap-background*]
                             #:shadow-blur [shadow-blur *codesnap-shadow-blur*]
                             #:window-controls? [window-controls? *codesnap-window-controls*]
                             #:show-title? [show-title? *codesnap-show-title*]
                             #:line-numbers? [line-numbers? *codesnap-line-numbers*]
                             #:pad-horiz [pad-horiz *codesnap-pad-horiz*]
                             #:pad-vert [pad-vert *codesnap-pad-vert*]
                             #:clipboard-command [clipboard-command *codesnap-clipboard-command*])
  (set! *codesnap-theme* theme)
  (set! *codesnap-background* background)
  (set! *codesnap-shadow-blur* shadow-blur)
  (set! *codesnap-window-controls* window-controls?)
  (set! *codesnap-show-title* show-title?)
  (set! *codesnap-line-numbers* line-numbers?)
  (set! *codesnap-pad-horiz* pad-horiz)
  (set! *codesnap-pad-vert* pad-vert)
  (set! *codesnap-clipboard-command* clipboard-command))

;; --- Internal Helpers ---
(define (normalize-language lang)
  (cond
   [(not lang) "txt"]
   [(equal? lang "scheme") "lisp"]
   [else lang]))

(define (current-language)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)]
         [lang (editor-document->language focus-doc-id)])
    (normalize-language lang)))

(define (current-filename)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)]
         [path (editor-document->path focus-doc-id)])
    (if path path #f)))

(define (bool->flag bool flag)
  (if bool "" flag))

(define (build-silicon-args lang filename out-path)
  (let* ([title-arg (if (and *codesnap-show-title* filename)
                        (string-append " --window-title \"$(basename '" filename "')\"")
                        "")]
         [base-args (string-append
                     " --from-clipboard "
                     title-arg
                     " --theme \"" *codesnap-theme* "\""
                     " --background \"" *codesnap-background* "\""
                     " --shadow-blur-radius " (number->string *codesnap-shadow-blur*)
                     " --pad-horiz " (number->string *codesnap-pad-horiz*)
                     " --pad-vert " (number->string *codesnap-pad-vert*)
                     " " (bool->flag *codesnap-window-controls* "--no-window-controls")
                     " " (bool->flag *codesnap-line-numbers* "--no-line-number")
                     " -o " out-path)])
    (string-append 
     "rm -f " out-path " && "
     "silicon -l " lang base-args " 2>/dev/null ; "
     "[ -f " out-path " ] || silicon -l md " base-args)))

;; --- Commands ---


;; Capture selection. Run `:codesnap` for clipboard, or `:codesnap ~/path.png` to save to file.
(define (codesnap-execute . args)
  (enqueue-thread-local-callback-with-delay
   100
   (lambda ()
     (let* ([lang (current-language)]
            [filename (current-filename)]
            [save-to-file? (not (null? args))]
            [out-path (if save-to-file? (car args) "/tmp/codesnap_capture.png")]
            [silicon-cmd (build-silicon-args lang filename out-path)]
            [full-cmd (if save-to-file?
                          silicon-cmd
                          (string-append silicon-cmd " && " *codesnap-clipboard-command* " " out-path))])
       (helix.run-shell-command full-cmd)
       (if save-to-file?
           (set-status! (string-append "📸 Snap saved to " out-path "!"))
           (set-status! (string-append "📸 Snap saved to clipboard! Theme: " *codesnap-theme*)))))))


;;@doc
;; Capture selection. Run `:codesnap` for clipboard, or `:codesnap ~/path.png` to save to file.
(define (codesnap . args)
  (helix.clipboard-yank)
  (apply codesnap-execute args))


;; Changes the active codesnap theme. Example: :codesnap-theme Nord
(define (codesnap-theme theme)
  (set! *codesnap-theme* theme)
  (set-status! (string-append "🎨 CodeSnap theme set to: " theme)))


;; Changes the background color (Hex). Example: :codesnap-bg #ffb86c
(define (codesnap-bg hex)
  (set! *codesnap-background* hex)
  (set-status! (string-append "🎨 CodeSnap background set to: " hex)))
