(require (prefix-in helix. "helix/commands.scm"))
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/ext.scm")

(provide codesnap 
         codesnap-execute 
         codesnap-theme 
         codesnap-bg 
         codesnap-configure!
         capture-selection-to-file!
         *codesnap-theme* 
         *codesnap-background* 
         *codesnap-shadow-blur*
         *codesnap-window-controls* 
         *codesnap-show-title* 
         *codesnap-line-numbers* 
         *codesnap-pad-horiz* 
         *codesnap-pad-vert* 
         *codesnap-clipboard-command*
         get-codesnap-theme 
         get-codesnap-bg 
         get-codesnap-shadow-blur 
         get-codesnap-window-controls 
         get-codesnap-show-title 
         get-codesnap-line-numbers 
         get-codesnap-pad-horiz 
         get-codesnap-pad-vert
         codesnap-set-shadow-blur! 
         codesnap-set-window-controls! 
         codesnap-set-show-title! 
         codesnap-set-line-numbers! 
         codesnap-set-pad-horiz! 
         codesnap-set-pad-vert!)

(define *codesnap-theme* "Dracula")
(define *codesnap-background* "#aaaaff")
(define *codesnap-shadow-blur* 15)
(define *codesnap-window-controls* #true)
(define *codesnap-show-title* #true)
(define *codesnap-line-numbers* #true)
(define *codesnap-pad-horiz* 80)
(define *codesnap-pad-vert* 100)
(define *codesnap-clipboard-command* "auto")

;; Configures default settings across all codesnap operations.
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

;; Normalizes editor language identifiers to Silicon-supported syntax names.
(define (normalize-language lang)
  (cond
   [(not lang) "markdown"]
   [(or (equal? lang "scheme") (equal? lang "scm") (equal? lang "steel")) "lisp"]
   [(or (equal? lang "txt") (equal? lang "text") (equal? lang "plaintext")) "markdown"]
   [else lang]))

;; Extracts the filename component from a path string without shell execution.
(define (path-basename path)
  (if (not path)
      #f
      (let loop ([idx (- (string-length path) 1)])
        (cond
          [(< idx 0) path]
          [(char=? (string-ref path idx) #\/)
           (substring path (+ idx 1) (string-length path))]
          [else (loop (- idx 1))]))))

;; Retrieves active selection text fragments from editor registers.
(define (get-selection-fragments)
  (let ([dot (register->value #\.)])
    (if (and (not (null? dot)) 
             (not (equal? dot '("")))
             (not (equal? dot '())))
        dot
        (let ([plus (register->value #\+)])
          (if (and (not (null? plus))
                   (not (equal? plus '("")))
                   (not (equal? plus '())))
              plus
              (register->value #\"))))))

;; Writes currently selected editor text fragments into a designated file.
(define (capture-selection-to-file! path)
  (let* ([fragments (get-selection-fragments)]
         [out (open-output-file path #:exists 'truncate)])
    (if (null? fragments)
        (display "" out)
        (for-each (lambda (frag) (display frag out)) fragments))
    (close-output-port out)))

;; Retrieves and normalizes the language of the currently focused document.
(define (current-language)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)]
         [lang (editor-document->language focus-doc-id)])
    (normalize-language lang)))

;; Retrieves the absolute path of the currently focused document.
(define (current-filename)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)]
         [path (editor-document->path focus-doc-id)])
    (if path path #f)))

;; Converts boolean state into the corresponding Silicon disable flag.
(define (bool->flag bool flag)
  (if bool "" flag))

;; Resolves clipboard command pipeline, auto-detecting Wayland/X11/macOS providers.
(define (resolve-clipboard-command custom-cmd)
  (if (equal? custom-cmd "auto")
      "if [ -n \"$WAYLAND_DISPLAY\" ] && command -v wl-copy >/dev/null 2>&1; then wl-copy -t image/png < \"$OUT_FILE\"; elif command -v xclip >/dev/null 2>&1; then xclip -selection clipboard -t image/png -i \"$OUT_FILE\"; elif command -v pbcopy >/dev/null 2>&1; then pbcopy < \"$OUT_FILE\"; fi"
      (string-append custom-cmd " \"$OUT_FILE\"")))

;; Constructs the shell command pipeline for Silicon image rendering.
(define (build-silicon-args lang filename in-path out-path)
  (let* ([base-name (path-basename filename)]
         [title-arg (if (and *codesnap-show-title* base-name)
                        (string-append " --window-title \"" base-name "\"")
                        "")]
         [base-args (string-append
                     " " in-path
                     title-arg
                     " --theme \"" *codesnap-theme* "\""
                     " --background \"" *codesnap-background* "\""
                     " --shadow-blur-radius " (number->string *codesnap-shadow-blur*)
                     " --pad-horiz " (number->string *codesnap-pad-horiz*)
                     " --pad-vert " (number->string *codesnap-pad-vert*)
                     " " (bool->flag *codesnap-window-controls* "--no-window-controls")
                     " " (bool->flag *codesnap-line-numbers* "--no-line-number")
                     " -o \"$OUT_FILE\"")])
    (string-append 
     "OUT_FILE=\"" out-path "\" ; "
     "case \"$OUT_FILE\" in \"~\"*) OUT_FILE=\"$HOME${OUT_FILE#\\~}\" ;; esac ; "
     "mkdir -p \"$(dirname \"$OUT_FILE\")\" ; "
     "(silicon -l " lang base-args " 2>/dev/null || silicon -l markdown " base-args ")")))

;; Executes screenshot rendering and clipboard or file export.
(define (codesnap-execute . args)
  (enqueue-thread-local-callback-with-delay
   100
   (lambda ()
     (let* ([lang (current-language)]
            [filename (current-filename)]
            [in-path "/tmp/codesnap_input.txt"]
            [save-to-file? (not (null? args))]
            [out-path (if save-to-file? (car args) "/tmp/codesnap_capture.png")]
            [silicon-cmd (build-silicon-args lang filename in-path out-path)]
            [clip-cmd (resolve-clipboard-command *codesnap-clipboard-command*)]
            [full-cmd (if save-to-file?
                          silicon-cmd
                          (string-append silicon-cmd " && " clip-cmd))])
       (helix.run-shell-command full-cmd)
       (if save-to-file?
           (set-status! (string-append "Snap saved to: " out-path))
           (set-status! (string-append "Snap copied to clipboard. Theme: " *codesnap-theme*)))))))

;; Copies current visual selection to system clipboard and executes capture.
(define (codesnap . args)
  (capture-selection-to-file! "/tmp/codesnap_input.txt")
  (helix.clipboard-yank)
  (apply codesnap-execute args))

;; Sets the active syntax highlighting theme.
(define (codesnap-theme theme)
  (set! *codesnap-theme* theme)
  (set-status! (string-append "CodeSnap theme: " theme)))

;; Sets the active background color hex code.
(define (codesnap-bg hex)
  (set! *codesnap-background* hex)
  (set-status! (string-append "CodeSnap background: " hex)))

;; Retrieves active theme name.
(define (get-codesnap-theme) *codesnap-theme*)

;; Retrieves active background hex color.
(define (get-codesnap-bg) *codesnap-background*)

;; Retrieves window control visibility state.
(define (get-codesnap-window-controls) *codesnap-window-controls*)

;; Retrieves window title bar visibility state.
(define (get-codesnap-show-title) *codesnap-show-title*)

;; Retrieves line number visibility state.
(define (get-codesnap-line-numbers) *codesnap-line-numbers*)

;; Retrieves shadow blur radius.
(define (get-codesnap-shadow-blur) *codesnap-shadow-blur*)

;; Retrieves horizontal padding value.
(define (get-codesnap-pad-horiz) *codesnap-pad-horiz*)

;; Retrieves vertical padding value.
(define (get-codesnap-pad-vert) *codesnap-pad-vert*)

;; Updates window control visibility.
(define (codesnap-set-window-controls! val) (set! *codesnap-window-controls* val))

;; Updates window title visibility.
(define (codesnap-set-show-title! val) (set! *codesnap-show-title* val))

;; Updates line number visibility.
(define (codesnap-set-line-numbers! val) (set! *codesnap-line-numbers* val))

;; Updates shadow blur radius.
(define (codesnap-set-shadow-blur! val) (set! *codesnap-shadow-blur* val))

;; Updates horizontal padding.
(define (codesnap-set-pad-horiz! val) (set! *codesnap-pad-horiz* val))

;; Updates vertical padding.
(define (codesnap-set-pad-vert! val) (set! *codesnap-pad-vert* val))
