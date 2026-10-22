(require "helix/misc.scm")
(require "helix/ext.scm")
(require (only-in "helix/components.scm" prompt push-component!))
(require-builtin steel/process)
(require-builtin steel/time)
(require "codesnap-core.scm")
(require "codesnap-process.scm")
(require "codesnap-compat.scm")
(require "codesnap-config.scm")

(provide codesnap codesnap-copy codesnap-save codesnap-doctor codesnap-save-config
         codesnap-take-warnings codesnap-execute codesnap-theme codesnap-bg codesnap-configure!
         codesnap-themes codesnap-fonts codesnap-reset codesnap-export codesnap-open-last
         codesnap-default-path get-codesnap-busy get-codesnap-last-path
         get-codesnap-theme get-codesnap-bg get-codesnap-shadow-blur
         get-codesnap-window-controls get-codesnap-show-title get-codesnap-line-numbers
         get-codesnap-pad-horiz get-codesnap-pad-vert get-codesnap-font
         get-codesnap-font-size get-codesnap-tab-width get-codesnap-original-lines
         get-codesnap-dedent
         codesnap-set-shadow-blur! codesnap-set-window-controls! codesnap-set-show-title!
         codesnap-set-line-numbers! codesnap-set-pad-horiz! codesnap-set-pad-vert!
         codesnap-set-font! codesnap-set-font-size! codesnap-set-tab-width!
         codesnap-set-original-lines! codesnap-set-dedent!)

(define *codesnap-theme* "Dracula")
(define *codesnap-background* "#aaaaff")
(define *codesnap-shadow-blur* 15)
(define *codesnap-window-controls* #t)
(define *codesnap-show-title* #t)
(define *codesnap-line-numbers* #t)
(define *codesnap-pad-horiz* 80)
(define *codesnap-pad-vert* 100)
(define *codesnap-font* "Hack")
(define *codesnap-font-size* 26)
(define *codesnap-tab-width* #f)
(define *codesnap-original-lines* #f)
(define *codesnap-dedent* #f)
(define *codesnap-busy* #f)
(define *codesnap-last-path* #f)
(define *codesnap-save-directory* #f)

;; Validates the entire configuration before changing any active settings.
(define (codesnap-configure! #:theme [theme *codesnap-theme*]
                             #:background [background *codesnap-background*]
                             #:shadow-blur [shadow-blur *codesnap-shadow-blur*]
                             #:window-controls? [window-controls? *codesnap-window-controls*]
                             #:show-title? [show-title? *codesnap-show-title*]
                             #:line-numbers? [line-numbers? *codesnap-line-numbers*]
                             #:pad-horiz [pad-horiz *codesnap-pad-horiz*]
                             #:pad-vert [pad-vert *codesnap-pad-vert*]
                             #:font [font *codesnap-font*]
                             #:font-size [font-size *codesnap-font-size*]
                             #:tab-width [tab-width *codesnap-tab-width*]
                             #:original-line-numbers? [original-lines? *codesnap-original-lines*]
                             #:dedent? [dedent? *codesnap-dedent*]
                             #:clipboard-command [_clipboard-command #f])
  (let ([error-message
         (or (config-validation-error theme background shadow-blur
                                      window-controls? show-title? line-numbers?
                                      pad-horiz pad-vert)
             (font-validation-error font font-size)
             (and tab-width
                  (not (and (integer? tab-width) (<= 1 tab-width) (<= tab-width 255)))
                  "CodeSnap tab width must be #f (editor) or an integer from 1 to 255")
             (and (not (boolean? original-lines?)) "CodeSnap original-line-numbers? must be boolean")
             (and (not (boolean? dedent?)) "CodeSnap dedent? must be boolean"))])
    (when error-message (error error-message))
    (set! *codesnap-theme* theme)
    (set! *codesnap-background* background)
    (set! *codesnap-shadow-blur* shadow-blur)
    (set! *codesnap-window-controls* window-controls?)
    (set! *codesnap-show-title* show-title?)
    (set! *codesnap-line-numbers* line-numbers?)
    (set! *codesnap-pad-horiz* pad-horiz)
    (set! *codesnap-pad-vert* pad-vert)
    (set! *codesnap-font* font)
    (set! *codesnap-font-size* font-size)
    (set! *codesnap-tab-width* tab-width)
    (set! *codesnap-original-lines* original-lines?)
    (set! *codesnap-dedent* dedent?)
    void))

;; Maps editor syntax names to the available Silicon language tokens.
(define (normalize-language lang)
  (cond
    [(not lang) "markdown"]
    [(member lang '("scheme" "scm" "steel")) "lisp"]
    [(member lang '("txt" "text" "plaintext")) "markdown"]
    [else lang]))

;; Resolves tab width from an explicit override, editor settings, or language configuration.
(define (capture-tab-width language)
  (or *codesnap-tab-width*
      (compat-editor-tab-width)
      (compat-language-tab-width language)
      4))

;; Snapshots source, metadata and arguments without touching the editor selection.
(define (capture-snapshot out-path)
  (let* ([doc (compat-document)]
         [filename (compat-document-path doc)]
         [language (compat-document-language doc)]
         [selection (selection-text (compat-selection-fragments))]
         [offset (if *codesnap-original-lines* (compat-selection-start-line doc) 1)]
         [args (map (lambda (lang)
                      (build-silicon-args
                       lang filename *codesnap-theme* *codesnap-background*
                       *codesnap-shadow-blur* *codesnap-window-controls*
                       *codesnap-show-title* *codesnap-line-numbers*
                       *codesnap-pad-horiz* *codesnap-pad-vert* out-path
                       #:font *codesnap-font* #:font-size *codesnap-font-size*
                       #:tab-width (capture-tab-width language) #:line-offset offset))
                    (capture-languages (normalize-language language) filename))])
    (when (string=? selection "") (error "Select some code first"))
    (hash 'selection (if *codesnap-dedent* (dedent-text selection) selection)
          'args args 'theme *codesnap-theme*)))

;; Starts one worker, keeping its settings stable through confirmation and completion.
(define (start-capture snapshot out-path replace?)
  (if *codesnap-busy*
      (set-status! "CodeSnap: a capture is already running")
      (begin
        (set! *codesnap-busy* #t)
        (set-status! "CodeSnap: rendering...")
        (with-handler
         (lambda (err)
           (set! *codesnap-busy* #f)
           (set-error! (string-append "CodeSnap: " (error-object-message err))))
         (spawn-native-thread
          (lambda ()
            (let ([result
                   (with-handler
                    (lambda (err) (hash 'stdout "" 'stderr (to-string err) 'exit #f))
                    (if out-path
                        (render-file
                         (hash-ref snapshot 'selection)
                         (lambda (staging)
                           (map (lambda (args)
                                  (append (take args (- (length args) 1)) (list staging)))
                                (hash-ref snapshot 'args)))
                         out-path replace?)
                        (render-with-fallback (hash-ref snapshot 'selection)
                                              (hash-ref snapshot 'args))))])
              (hx.with-context
               (lambda ()
                 (set! *codesnap-busy* #f)
                 (if (render-success? result)
                     (if out-path
                         (begin
                           (set! *codesnap-last-path* out-path)
                           (set! *codesnap-save-directory* (parent-name out-path))
                           (set-status! (string-append "CodeSnap saved: " out-path)))
                         (set-status! (string-append "CodeSnap copied. Theme: "
                                                    (hash-ref snapshot 'theme))))
                     (set-error! (string-append "CodeSnap: " (render-error-message result))))
                 void))))))))
  void)

;; Validates paths and asks before replacing an existing file, for both entry points.
(define (codesnap-execute . args)
  (with-handler
   (lambda (err) (set-error! (string-append "CodeSnap: " (error-object-message err))))
   (cond
     [*codesnap-busy* (set-status! "CodeSnap: a capture is already running")]
     [(> (length args) 1)
      (set-error! "CodeSnap accepts one output path; quote paths containing spaces")]
     [(not (which "silicon"))
      (set-error! "CodeSnap: Silicon is not installed or not on PATH (run :codesnap-doctor)")]
     [else
      (let* ([input (if (null? args) #f (car args))]
             [_ (when (and (pair? args)
                           (or (not (string? input)) (string=? (trim input) "")))
                  (error "Output path cannot be empty"))]
             [out-path (and input (absolute-path input))]
             [_ (when (and out-path (is-dir? out-path))
                  (error "Choose an image filename, not a directory"))]
             [snapshot (capture-snapshot out-path)])
        (if (and out-path (path-exists? out-path))
            (push-component!
             (prompt (string-append "Replace "
                                    (let ([name (path-basename out-path)])
                                      (if (> (string-length name) 24)
                                          (string-append (substring name 0 21) "...") name))
                                    "? Type yes: ")
                     (lambda (answer)
                       (when (string=? (trim answer) "yes")
                         (start-capture snapshot out-path #t)))))
            (start-capture snapshot out-path #f)))]))
  void)

;; Captures the current selection using the active settings.
(define (codesnap . args)
  (apply codesnap-execute args))

;; Copies the current selection's image to the clipboard.
(define (codesnap-copy)
  (codesnap-execute))

;; Saves the image to a path, or to a unique default filename when no path is given.
(define (codesnap-save . args)
  (if (null? args)
      (codesnap-execute (codesnap-default-path))
      (apply codesnap-execute args)))

;; Chooses a unique PNG name in the last save directory, Pictures, or the current directory.
(define (codesnap-default-path)
  (let* ([pictures (absolute-path "~/Pictures")]
         [directory (or (and *codesnap-save-directory*
                             (is-dir? *codesnap-save-directory*)
                             *codesnap-save-directory*)
                        (if (is-dir? pictures) pictures (current-directory)))]
         [name (capture-name (compat-document-path (compat-document))
                             (local-time/now! "%Y%m%d-%H%M%S"))]
         [base (string-append directory "/" (substring name 0 (- (string-length name) 4)))])
    (let loop ([index 0])
      (let ([path (string-append base (if (= index 0) "" (string-append "-" (number->string index))) ".png")])
        (if (path-exists? path) (loop (+ index 1)) path)))))

;; Returns Silicon's installed values, with a usable fallback if discovery fails.
(define (silicon-values flag fallback)
  (if (not (which "silicon"))
      fallback
      (let* ([result (run-program "silicon" (list flag) #f)]
             [values (if (render-success? result)
                         (filter (lambda (item) (not (string=? item "")))
                                 (map trim (split-many (hash-ref result 'stdout) "\n")))
                         '())])
        (if (null? values) fallback values))))

;; Lists installed syntax themes.
(define (codesnap-themes)
  (silicon-values "--list-themes" default-themes))

;; Lists installed font families, including Silicon's bundled Hack font.
(define (codesnap-fonts)
  (current-first (silicon-values "--list-fonts" '()) "Hack"))

;; Restores rendering defaults without discarding the last saved capture.
(define (codesnap-reset)
  (codesnap-configure! #:theme "Dracula" #:background "#aaaaff" #:shadow-blur 15
                      #:window-controls? #t #:show-title? #t #:line-numbers? #t
                      #:pad-horiz 80 #:pad-vert 100 #:font "Hack" #:font-size 26
                      #:tab-width #f #:original-line-numbers? #f #:dedent? #f)
  (set-status! "CodeSnap: defaults restored")
  void)

;; Opens a Scheme configuration snippet in a new scratch buffer for saving or copying.
(define (codesnap-export)
  (let ([port (open-output-string)])
    (display "(codesnap-configure!" port)
    (for-each
     (lambda (entry)
       (display "\n  " port)
       (display (car entry) port)
       (display " " port)
       (write (cdr entry) port))
     (list (cons "#:theme" *codesnap-theme*) (cons "#:background" *codesnap-background*)
           (cons "#:shadow-blur" *codesnap-shadow-blur*)
           (cons "#:window-controls?" *codesnap-window-controls*)
           (cons "#:show-title?" *codesnap-show-title*) (cons "#:line-numbers?" *codesnap-line-numbers*)
           (cons "#:pad-horiz" *codesnap-pad-horiz*) (cons "#:pad-vert" *codesnap-pad-vert*)
           (cons "#:font" *codesnap-font*) (cons "#:font-size" *codesnap-font-size*)
           (cons "#:tab-width" *codesnap-tab-width*)
           (cons "#:original-line-numbers?" *codesnap-original-lines*)
           (cons "#:dedent?" *codesnap-dedent*)))
    (display ")\n" port)
    (compat-open-scratch! (get-output-string port))
    (set-status! "CodeSnap: copy this configuration into helix.scm"))
  void)

;; Opens the last saved image with the operating system's image viewer.
(define (codesnap-open-last)
  (cond
    [(or (not *codesnap-last-path*) (not (is-file? *codesnap-last-path*)))
     (set-error! "CodeSnap: no saved capture is available")]
    [else
     (let* ([path *codesnap-last-path*]
            [opener (cond [(which "xdg-open") "xdg-open"]
                          [(which "open") "open"]
                          [(which "rundll32.exe") "rundll32.exe"]
                          [else #f])])
       (if (not opener)
           (set-error! "CodeSnap: no system image opener was found")
           (begin
             (set-status! (string-append "CodeSnap opening: " path))
             (spawn-native-thread
              (lambda ()
                (let ([result (run-program opener
                                           (if (equal? opener "rundll32.exe")
                                               (list "url.dll,FileProtocolHandler" path) (list path))
                                           #f)])
                  (when (not (equal? (hash-ref result 'exit) 0))
                    (hx.with-context
                     (lambda () (set-error! (string-append "CodeSnap: " (render-error-message result))))))))))))])
  void)

;; Sets the active syntax theme.
(define (codesnap-theme theme)
  (codesnap-configure! #:theme theme)
  (set-status! (string-append "CodeSnap theme: " theme))
  void)

;; Sets the active background.
(define (codesnap-bg background)
  (codesnap-configure! #:background background)
  (set-status! (string-append "CodeSnap background: " background))
  void)

;; Returns whether a capture is running.
(define (get-codesnap-busy) *codesnap-busy*)
;; Returns the last successfully saved image path.
(define (get-codesnap-last-path) *codesnap-last-path*)
;; Returns the active syntax theme.
(define (get-codesnap-theme) *codesnap-theme*)
;; Returns the active background color.
(define (get-codesnap-bg) *codesnap-background*)
;; Returns the shadow blur radius.
(define (get-codesnap-shadow-blur) *codesnap-shadow-blur*)
;; Returns window control visibility.
(define (get-codesnap-window-controls) *codesnap-window-controls*)
;; Returns window title visibility.
(define (get-codesnap-show-title) *codesnap-show-title*)
;; Returns line number visibility.
(define (get-codesnap-line-numbers) *codesnap-line-numbers*)
;; Returns horizontal padding.
(define (get-codesnap-pad-horiz) *codesnap-pad-horiz*)
;; Returns vertical padding.
(define (get-codesnap-pad-vert) *codesnap-pad-vert*)
;; Returns the font family list.
(define (get-codesnap-font) *codesnap-font*)
;; Returns the font size.
(define (get-codesnap-font-size) *codesnap-font-size*)
;; Returns the tab override, or false to follow the editor.
(define (get-codesnap-tab-width) *codesnap-tab-width*)
;; Returns whether source line numbering is enabled.
(define (get-codesnap-original-lines) *codesnap-original-lines*)
;; Returns whether common indentation is removed.
(define (get-codesnap-dedent) *codesnap-dedent*)

;; Updates the shadow blur radius.
(define (codesnap-set-shadow-blur! value) (codesnap-configure! #:shadow-blur value))
;; Updates window control visibility.
(define (codesnap-set-window-controls! value) (codesnap-configure! #:window-controls? value))
;; Updates window title visibility.
(define (codesnap-set-show-title! value) (codesnap-configure! #:show-title? value))
;; Updates line number visibility.
(define (codesnap-set-line-numbers! value) (codesnap-configure! #:line-numbers? value))
;; Updates horizontal padding.
(define (codesnap-set-pad-horiz! value) (codesnap-configure! #:pad-horiz value))
;; Updates vertical padding.
(define (codesnap-set-pad-vert! value) (codesnap-configure! #:pad-vert value))
;; Updates the font family list.
(define (codesnap-set-font! value) (codesnap-configure! #:font value))
;; Updates font size.
(define (codesnap-set-font-size! value) (codesnap-configure! #:font-size value))
;; Updates the tab override.
(define (codesnap-set-tab-width! value) (codesnap-configure! #:tab-width value))
;; Updates source line numbering.
(define (codesnap-set-original-lines! value) (codesnap-configure! #:original-line-numbers? value))
;; Updates common indentation removal.
(define (codesnap-set-dedent! value) (codesnap-configure! #:dedent? value))

;; Saved-file keys paired with the function that validates and applies each value.
(define (config-appliers)
  (list
   (cons "theme" (lambda (v) (codesnap-configure! #:theme v)))
   (cons "background" (lambda (v) (codesnap-configure! #:background v)))
   (cons "shadow-blur" (lambda (v) (codesnap-configure! #:shadow-blur v)))
   (cons "window-controls" (lambda (v) (codesnap-configure! #:window-controls? v)))
   (cons "show-title" (lambda (v) (codesnap-configure! #:show-title? v)))
   (cons "line-numbers" (lambda (v) (codesnap-configure! #:line-numbers? v)))
   (cons "pad-horiz" (lambda (v) (codesnap-configure! #:pad-horiz v)))
   (cons "pad-vert" (lambda (v) (codesnap-configure! #:pad-vert v)))
   (cons "font" (lambda (v) (codesnap-configure! #:font v)))
   (cons "font-size" (lambda (v) (codesnap-configure! #:font-size v)))
   (cons "tab-width" (lambda (v) (codesnap-configure! #:tab-width v)))
   (cons "original-line-numbers" (lambda (v) (codesnap-configure! #:original-line-numbers? v)))
   (cons "dedent" (lambda (v) (codesnap-configure! #:dedent? v)))))

;; Problems found while loading the settings file, shown once on first use.
(define *codesnap-warnings* '())

;; Applies saved settings one at a time so a single bad value cannot discard the rest.
(define (load-saved-config!)
  (let ([parsed (read-config-file)])
    (when parsed
      (set! *codesnap-warnings* (hash-ref parsed 'warnings))
      (for-each
       (lambda (entry)
         (let ([applier (assoc (car entry) (config-appliers))])
           (with-handler
            (lambda (err)
              (set! *codesnap-warnings*
                    (append *codesnap-warnings*
                            (list (string-append (car entry) ": " (trim (error-object-message err)))))))
            (if applier ((cdr applier) (cdr entry))
                (error "unknown setting")))))
       (hash-ref parsed 'entries)))))

;; Shows and clears any saved-settings problems; returns whether there were any.
(define (codesnap-take-warnings)
  (let ([warnings *codesnap-warnings*])
    (set! *codesnap-warnings* '())
    (when (pair? warnings)
      (set-error! (string-append "CodeSnap settings file: " (car warnings)
                                 (if (pair? (cdr warnings))
                                     (string-append " (+" (number->string (length (cdr warnings))) " more)")
                                     ""))))
    (pair? warnings)))

;; Current settings as ordered key/value pairs; shared by the file and the export snippet.
(define (settings-entries)
  (list (cons "theme" *codesnap-theme*) (cons "background" *codesnap-background*)
        (cons "shadow-blur" *codesnap-shadow-blur*)
        (cons "window-controls" *codesnap-window-controls*)
        (cons "show-title" *codesnap-show-title*)
        (cons "line-numbers" *codesnap-line-numbers*)
        (cons "pad-horiz" *codesnap-pad-horiz*) (cons "pad-vert" *codesnap-pad-vert*)
        (cons "font" *codesnap-font*) (cons "font-size" *codesnap-font-size*)
        (cons "tab-width" *codesnap-tab-width*)
        (cons "original-line-numbers" *codesnap-original-lines*)
        (cons "dedent" *codesnap-dedent*)))

;; Saves the current settings so they apply in every future editor session.
(define (codesnap-save-config)
  (with-handler
   (lambda (err) (set-error! (string-append "CodeSnap: could not save settings: "
                                            (trim (error-object-message err)))))
   (let ([path (write-config-file (settings-entries))])
     (set-status! (string-append "CodeSnap settings saved: " path))))
  void)

;; Reports Silicon's version, or false when it cannot be determined.
(define (silicon-version)
  (let ([result (run-program "silicon" (list "--version") #f)])
    (and (render-success? result) (parse-silicon-version (hash-ref result 'stdout)))))

;; Opens a scratch buffer describing what CodeSnap found on this machine.
(define (codesnap-doctor)
  (let* ([silicon (which "silicon")]
         [version (and silicon (silicon-version))]
         [clipboards (filter which '("wl-copy" "xclip" "xsel"))]
         [path (config-file-path)]
         [lines
          (list
           "CodeSnap setup check"
           ""
           (cond
             [(not silicon) "silicon:   NOT FOUND. Install it with: cargo install silicon"]
             [(not version) (string-append "silicon:   " silicon " (version unknown)")]
             [(version-at-least? version minimum-silicon-version)
              (string-append "silicon:   " silicon " " (string-join (map number->string version) ".") " OK")]
             [else (string-append "silicon:   " silicon " is older than "
                                  (string-join (map number->string minimum-silicon-version) ".")
                                  "; upgrade with: cargo install silicon --force")])
           (string-append "clipboard: "
                          (if (null? clipboards)
                              "no wl-copy/xclip/xsel found (needed on Linux for :codesnap-copy)"
                              (string-join clipboards ", ")))
           (string-append "settings:  " (or path "unknown")
                          (if (and path (is-file? path)) "" " (not saved yet)"))
           (if (null? *codesnap-warnings*) ""
               (string-append "problems:  " (string-join *codesnap-warnings* "\n           ")))
           (string-append "save to:   " (or *codesnap-save-directory* "~/Pictures or current directory")))])
    (compat-open-scratch! (string-append (string-join lines "\n") "\n"))
    (set-status! (if (and silicon version (version-at-least? version minimum-silicon-version)
                          (null? *codesnap-warnings*))
                     "CodeSnap: setup looks good"
                     "CodeSnap: setup needs attention, see the report")))
  void)

(load-saved-config!)
