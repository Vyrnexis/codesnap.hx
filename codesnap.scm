(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/ext.scm")
(require-builtin steel/process)
(require (only-in "codesnap-core.scm"
                  default-themes
                  config-validation-error
                  selection-text
                  path-extension
                  build-silicon-args
                  unsupported-language-error?))

(provide codesnap
         codesnap-execute
         codesnap-theme
         codesnap-bg
         codesnap-configure!
         codesnap-themes
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
(define *codesnap-status-token* 0)

;; Advances and returns the token guarding delayed status updates.
(define (next-status-token!)
  (set! *codesnap-status-token* (+ *codesnap-status-token* 1))
  *codesnap-status-token*)

;; Shows a status that remains until the capture finishes.
(define (set-active-status! message)
  (next-status-token!)
  (set-status! message)
  void)

;; Shows a successful status for three seconds without clearing newer messages.
(define (set-temporary-status! message)
  (let ([token (next-status-token!)])
    (set-status! message)
    (enqueue-thread-local-callback-with-delay
     3000
     (lambda ()
       (when (= token *codesnap-status-token*)
         (set-status! ""))))
    void))

;; Shows a persistent error while preventing older timers from clearing it.
(define (set-active-error! message)
  (next-status-token!)
  (set-error! message)
  void)

;; Validates all settings before updating the active configuration.
(define (codesnap-configure! #:theme [theme *codesnap-theme*]
                             #:background [background *codesnap-background*]
                             #:shadow-blur [shadow-blur *codesnap-shadow-blur*]
                             #:window-controls? [window-controls? *codesnap-window-controls*]
                             #:show-title? [show-title? *codesnap-show-title*]
                             #:line-numbers? [line-numbers? *codesnap-line-numbers*]
                             #:pad-horiz [pad-horiz *codesnap-pad-horiz*]
                             #:pad-vert [pad-vert *codesnap-pad-vert*]
                             #:clipboard-command [_clipboard-command #f])
  (let ([error-message
         (config-validation-error theme background shadow-blur
                                  window-controls? show-title? line-numbers?
                                  pad-horiz pad-vert)])
    (when error-message (raise-error error-message))
    (set! *codesnap-theme* theme)
    (set! *codesnap-background* background)
    (set! *codesnap-shadow-blur* shadow-blur)
    (set! *codesnap-window-controls* window-controls?)
    (set! *codesnap-show-title* show-title?)
    (set! *codesnap-line-numbers* line-numbers?)
    (set! *codesnap-pad-horiz* pad-horiz)
    (set! *codesnap-pad-vert* pad-vert)))

;; Normalizes editor language identifiers to Silicon-supported syntax names.
(define (normalize-language lang)
  (cond
    [(not lang) "markdown"]
    [(or (equal? lang "scheme") (equal? lang "scm") (equal? lang "steel")) "lisp"]
    [(or (equal? lang "txt") (equal? lang "text") (equal? lang "plaintext")) "markdown"]
    [else lang]))

;; Retrieves and normalizes the focused document language.
(define (current-language)
  (let* ([focus (editor-focus)]
         [doc-id (editor->doc-id focus)])
    (normalize-language (editor-document->language doc-id))))

;; Retrieves the focused document path when it has one.
(define (current-filename)
  (let* ([focus (editor-focus)]
         [doc-id (editor->doc-id focus)])
    (editor-document->path doc-id)))

;; Captures stdout, stderr, and exit status from a directly spawned process.
(define (run-program program args stdin-input)
  (with-handler
   (lambda (err) (hash 'stdout "" 'stderr (to-string err) 'exit #f))
   (let ([cmd (command program args)])
     (set-piped-stdout! cmd)
     (let ([spawned (spawn-process cmd)])
       (if (Err? spawned)
           (hash 'stdout "" 'stderr (to-string (Err->value spawned)) 'exit #f)
           (let* ([child (Ok->value spawned)]
                  [stdin (child-stdin child)]
                  [_ (when stdin
                       (when (string? stdin-input) (display stdin-input stdin))
                       (close-output-port stdin))]
                  [stdout-box (box "")]
                  [stderr-box (box "")]
                  [stdout-thread
                   (spawn-native-thread
                    (lambda ()
                      (let ([port (child-stdout child)])
                        (when port (set-box! stdout-box (read-port-to-string port))))))]
                  [stderr-thread
                   (spawn-native-thread
                    (lambda ()
                      (let ([port (child-stderr child)])
                        (when port (set-box! stderr-box (read-port-to-string port))))))]
                  [_ (thread-join! stdout-thread)]
                  [_ (thread-join! stderr-thread)]
                  [wait-result (wait child)])
             (hash 'stdout (unbox stdout-box)
                   'stderr (unbox stderr-box)
                   'exit (if (Ok? wait-result) (Ok->value wait-result) #f))))))))

;; Runs Silicon clipboard mode without capturing the pipe retained by its clipboard owner.
(define (run-clipboard-program args stdin-input)
  (with-handler
   (lambda (err) (hash 'stdout "" 'stderr (to-string err) 'exit #f))
   (let* ([stderr-port (open-output-file
                        (if (path-exists? "/dev/null") "/dev/null" "NUL")
                        #:exists 'truncate)]
          [cmd (command "silicon" args)]
          [_ (with-stdin-piped cmd)]
          [_ (with-stderr cmd stderr-port)]
          [spawned (spawn-process cmd)])
     (if (Err? spawned)
         (hash 'stdout "" 'stderr (to-string (Err->value spawned)) 'exit #f)
         (let* ([child (Ok->value spawned)]
                [stdin (child-stdin child)]
                [_ (when stdin
                     (display stdin-input stdin)
                     (close-output-port stdin))]
                [wait-result (wait child)])
           (hash 'stdout "" 'stderr ""
                 'exit (if (Ok? wait-result) (Ok->value wait-result) #f)))))))

;; Determines whether Silicon completed without process or application errors.
(define (render-success? result)
  (and (equal? (hash-ref result 'exit) 0)
       (string=? (trim (hash-ref result 'stderr)) "")))

;; Returns a concise user-facing message for a failed Silicon invocation.
(define (render-error-message result)
  (let ([stderr (trim (hash-ref result 'stderr))])
    (cond
      [(not (hash-ref result 'exit)) "Unable to start Silicon"]
      [(not (string=? stderr "")) (car (split-many stderr "\n"))]
      [else (string-append "Silicon exited with status "
                           (number->string (hash-ref result 'exit)))])))

;; Runs Silicon argv attempts until one succeeds or returns a non-syntax error.
(define (render-with-fallback selection attempts)
  (let loop ([remaining attempts] [last-result #f])
    (if (null? remaining)
        last-result
        (let* ([args (car remaining)]
               [result (if (member "--to-clipboard" args)
                           (run-clipboard-program args selection)
                           (run-program "silicon" args selection))])
          (if (and (not (render-success? result))
                   (unsupported-language-error? (hash-ref result 'stderr))
                   (not (null? (cdr remaining))))
              (loop (cdr remaining) result)
              result)))))

;; Creates the ordered language fallback list for the focused document.
(define (capture-languages lang filename)
  (let ([extension (path-extension filename)])
    (foldr (lambda (item acc)
             (if (or (not item) (member item acc)) acc (cons item acc)))
           '()
           (list lang extension "markdown"))))

;; Snapshots the current settings into one argv list per language attempt.
(define (capture-attempts languages filename out-path)
  (map (lambda (lang)
         (build-silicon-args
          lang filename *codesnap-theme* *codesnap-background*
          *codesnap-shadow-blur* *codesnap-window-controls*
          *codesnap-show-title* *codesnap-line-numbers*
          *codesnap-pad-horiz* *codesnap-pad-vert* out-path))
       languages))

;; Runs a capture asynchronously and reports its verified result.
(define (start-capture selection filename out-path)
  (let* ([languages (capture-languages (current-language) filename)]
         [attempts (capture-attempts languages filename out-path)]
         [theme *codesnap-theme*])
    (set-active-status! "CodeSnap: rendering...")
    (spawn-native-thread
     (lambda ()
       (let ([result (render-with-fallback selection attempts)])
         (hx.with-context
          (lambda ()
            (if (render-success? result)
                (if out-path
                    (set-temporary-status! (string-append "CodeSnap saved: " out-path))
                    (set-temporary-status! (string-append "CodeSnap copied. Theme: " theme)))
                (set-active-error!
                 (string-append "CodeSnap: " (render-error-message result)))))))))
    void))

;; Executes a clipboard capture or saves to the single supplied path.
(define (codesnap-execute . args)
  (cond
    [(> (length args) 1)
     (set-active-error! "CodeSnap accepts one output path; quote paths containing spaces")]
    [(not (which "silicon"))
     (set-active-error! "CodeSnap: Silicon is not installed or not on PATH")]
    [else
     (let* ([selection (selection-text (register->value #\.))]
            [filename (current-filename)]
            [out-path (if (null? args) #f (car args))])
       (cond
         [(string=? selection "")
          (set-active-error! "CodeSnap: select some code first")]
         [(and out-path (or (not (string? out-path)) (string=? (trim out-path) "")))
          (set-active-error! "CodeSnap: output path cannot be empty")]
         [else (start-capture selection filename out-path)]))]))

;; Captures the current selection using the active settings.
(define (codesnap . args)
  (apply codesnap-execute args))

;; Lists locally installed Silicon themes, falling back to bundled names.
(define (codesnap-themes)
  (if (not (which "silicon"))
      default-themes
      (let* ([result (run-program "silicon" '("--list-themes") #f)]
             [themes (if (render-success? result)
                         (filter (lambda (item) (not (string=? item "")))
                                 (map trim (split-many (hash-ref result 'stdout) "\n")))
                         '())])
        (if (null? themes) default-themes themes))))

;; Sets the active syntax highlighting theme.
(define (codesnap-theme theme)
  (codesnap-configure! #:theme theme)
  (set-temporary-status! (string-append "CodeSnap theme: " theme)))

;; Sets the active background color.
(define (codesnap-bg background)
  (codesnap-configure! #:background background)
  (set-temporary-status! (string-append "CodeSnap background: " background)))

;; Retrieves the active theme name.
(define (get-codesnap-theme) *codesnap-theme*)

;; Retrieves the active background color.
(define (get-codesnap-bg) *codesnap-background*)

;; Retrieves window control visibility.
(define (get-codesnap-window-controls) *codesnap-window-controls*)

;; Retrieves window title visibility.
(define (get-codesnap-show-title) *codesnap-show-title*)

;; Retrieves line number visibility.
(define (get-codesnap-line-numbers) *codesnap-line-numbers*)

;; Retrieves the shadow blur radius.
(define (get-codesnap-shadow-blur) *codesnap-shadow-blur*)

;; Retrieves horizontal padding.
(define (get-codesnap-pad-horiz) *codesnap-pad-horiz*)

;; Retrieves vertical padding.
(define (get-codesnap-pad-vert) *codesnap-pad-vert*)

;; Updates window control visibility after validation.
(define (codesnap-set-window-controls! value)
  (codesnap-configure! #:window-controls? value))

;; Updates window title visibility after validation.
(define (codesnap-set-show-title! value)
  (codesnap-configure! #:show-title? value))

;; Updates line number visibility after validation.
(define (codesnap-set-line-numbers! value)
  (codesnap-configure! #:line-numbers? value))

;; Updates shadow blur after validation.
(define (codesnap-set-shadow-blur! value)
  (codesnap-configure! #:shadow-blur value))

;; Updates horizontal padding after validation.
(define (codesnap-set-pad-horiz! value)
  (codesnap-configure! #:pad-horiz value))

;; Updates vertical padding after validation.
(define (codesnap-set-pad-vert! value)
  (codesnap-configure! #:pad-vert value))
