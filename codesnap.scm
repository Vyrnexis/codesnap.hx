(require (prefix-in helix. "helix/commands.scm"))
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/ext.scm")

(provide codesnap codesnap-save codesnap-theme codesnap-bg codesnap-configure!)

;; --- Default Configuration Options ---
(define *codesnap-theme* "Dracula")
(define *codesnap-background* "#aaaaff")
(define *codesnap-shadow-blur* 15)
(define *codesnap-window-controls* #true)
(define *codesnap-line-numbers* #true)
(define *codesnap-pad-horiz* 80)
(define *codesnap-pad-vert* 100)
(define *codesnap-clipboard-command* "xclip -selection clipboard -t image/png -i")

;; --- Configuration API ---
;;@doc
;; Configures codesnap defaults. Best called from your init.scm!
(define (codesnap-configure! #:theme [theme *codesnap-theme*]
                             #:background [background *codesnap-background*]
                             #:shadow-blur [shadow-blur *codesnap-shadow-blur*]
                             #:window-controls? [window-controls? *codesnap-window-controls*]
                             #:line-numbers? [line-numbers? *codesnap-line-numbers*]
                             #:pad-horiz [pad-horiz *codesnap-pad-horiz*]
                             #:pad-vert [pad-vert *codesnap-pad-vert*]
                             #:clipboard-command [clipboard-command *codesnap-clipboard-command*])
  (set! *codesnap-theme* theme)
  (set! *codesnap-background* background)
  (set! *codesnap-shadow-blur* shadow-blur)
  (set! *codesnap-window-controls* window-controls?)
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

(define (bool->flag bool flag)
  (if bool "" flag))

(define (build-silicon-args lang out-path)
  (let ([base-args (string-append
                    " --from-clipboard "
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
