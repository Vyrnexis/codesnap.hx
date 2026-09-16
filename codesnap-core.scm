(provide default-themes
         valid-color?
         valid-dimension?
         config-validation-error
         selection-text
         dedent-text
         font-validation-error
         capture-languages
         capture-name
         picker-scale
         path-basename
         path-extension
         current-first
         setting-choice-label
         build-silicon-args
         unsupported-language-error?)

(define default-themes
  '("1337" "Coldark-Cold" "Coldark-Dark" "DarkNeon" "Dracula" "GitHub"
    "Monokai Extended" "Monokai Extended Bright" "Monokai Extended Light"
    "Monokai Extended Origin" "Nord" "OneHalfDark" "OneHalfLight"
    "Solarized (dark)" "Solarized (light)" "Sublime Snazzy" "TwoDark"
    "Visual Studio Dark+" "ansi" "base16" "base16-256" "gruvbox-dark"
    "gruvbox-light" "zenburn"))

;; Determines whether every character from idx onward is hexadecimal.
(define (hex-tail? value idx)
  (if (= idx (string-length value))
      #t
      (and (member (char-downcase (string-ref value idx))
                   '(#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9
                     #\a #\b #\c #\d #\e #\f))
           (hex-tail? value (+ idx 1)))))

;; Validates a Silicon color in #RGB[A] or #RRGGBB[AA] form.
(define (valid-color? value)
  (and (string? value)
       (member (string-length value) '(4 5 7 9))
       (char=? (string-ref value 0) #\#)
       (hex-tail? value 1)))

;; Validates a non-negative integer dimension accepted by Silicon.
(define (valid-dimension? value)
  (and (integer? value) (>= value 0)))

;; Returns the first invalid configuration message, or false when valid.
(define (config-validation-error theme background shadow-blur
                                 window-controls? show-title? line-numbers?
                                 pad-horiz pad-vert)
  (cond
    [(or (not (string? theme)) (= (string-length theme) 0))
     "CodeSnap theme must be a non-empty string"]
    [(not (valid-color? background))
     "CodeSnap background must be #RGB[A] or #RRGGBB[AA]"]
    [(not (valid-dimension? shadow-blur))
     "CodeSnap shadow blur must be a non-negative integer"]
    [(not (boolean? window-controls?))
     "CodeSnap window-controls? must be boolean"]
    [(not (boolean? show-title?))
     "CodeSnap show-title? must be boolean"]
    [(not (boolean? line-numbers?))
     "CodeSnap line-numbers? must be boolean"]
    [(not (valid-dimension? pad-horiz))
     "CodeSnap horizontal padding must be a non-negative integer"]
    [(not (valid-dimension? pad-vert))
     "CodeSnap vertical padding must be a non-negative integer"]
    [else #f]))

;; Joins multiple Helix selections as separate source lines.
(define (selection-text fragments)
  (let loop ([remaining fragments] [previous ""] [parts '()])
    (if (null? remaining)
        (string-join (reverse parts) "")
        (let* ([fragment (car remaining)]
               [separator (if (or (null? parts) (string=? previous "")
                                  (ends-with? previous "\n")
                                  (ends-with? previous "\r")
                                  (starts-with? fragment "\n")
                                  (starts-with? fragment "\r"))
                              "" "\n")])
          (loop (cdr remaining) fragment (cons fragment (cons separator parts)))))))

;; Counts leading spaces and tabs without touching code or line endings.
(define (indent-length line)
  (let loop ([idx 0])
    (if (and (< idx (string-length line))
             (member (string-ref line idx) '(#\space #\tab)))
        (loop (+ idx 1))
        idx)))

;; Removes the common whitespace prefix of nonblank lines, preserving relative indentation.
(define (dedent-text text)
  (let* ([lines (split-many text "\n")]
         [nonblank (filter (lambda (line) (not (string=? (trim line) ""))) lines)]
         [prefix (if (null? nonblank) ""
                     (foldl
                      (lambda (line prefix)
                        (let loop ([idx 0])
                          (if (and (< idx (string-length prefix))
                                   (< idx (indent-length line))
                                   (char=? (string-ref prefix idx) (string-ref line idx)))
                              (loop (+ idx 1))
                              (substring prefix 0 idx))))
                      (substring (car nonblank) 0 (indent-length (car nonblank)))
                      (cdr nonblank)))])
    (string-join
     (map (lambda (line)
            (if (starts-with? line prefix)
                (substring line (string-length prefix) (string-length line))
                line))
          lines)
     "\n")))

;; Validates a font family list; sizes are supplied separately to avoid Silicon parser panics.
(define (font-validation-error font size)
  (cond
    [(or (not (string? font)) (string=? (trim font) "")
         (string-contains? font "=")
         (string-contains? font "\n") (string-contains? font "\r")
         (member "" (map trim (split-many font ";"))))
     "CodeSnap font must contain font families separated by semicolons, without sizes"]
    [(not (and (integer? size) (<= 1 size) (<= size 256)))
     "CodeSnap font size must be an integer from 1 to 256"]
    [else #f]))

;; Keeps the requested syntax first, followed by a distinct extension and fallback.
(define (capture-languages lang filename)
  (reverse
   (foldl (lambda (item acc)
            (if (or (not item) (member item acc)) acc (cons item acc)))
          '() (list lang (path-extension filename) "markdown"))))

;; Builds a portable source-derived PNG filename using the supplied timestamp.
(define (capture-name filename timestamp)
  (let* ([name (or (path-basename filename) "untitled")]
         [extension (path-extension name)]
         [stem (if extension
                   (substring name 0 (- (string-length name) (string-length extension) 1))
                   name)]
         [safe (list->string
                (map (lambda (ch)
                       (let ([code (char->integer ch)])
                         (if (or (and (<= 65 code) (<= code 90))
                                 (and (<= 97 code) (<= code 122))
                                 (and (<= 48 code) (<= code 57))
                                 (member ch '(#\- #\_))) ch #\-)))
                     (string->list stem)))])
    (string-append (if (string=? safe "") "untitled" safe) "-" timestamp ".png")))

;; Fits picker content into the available area using the library's percentage geometry.
(define (picker-scale width height rows)
  (let ([w (max 1 width)] [h (max 1 (- height 2))])
    (min 100 (max 10
                  (quotient (+ 5800 w -1) w)
                  (quotient (+ (* 100 (+ rows 7)) h -1) h)))))

;; Extracts the filename component from a platform path.
(define (path-basename path)
  (if (not path)
      #f
      (let loop ([idx (- (string-length path) 1)])
        (cond
          [(< idx 0) path]
          [(or (char=? (string-ref path idx) #\/)
               (char=? (string-ref path idx) #\\))
           (substring path (+ idx 1) (string-length path))]
          [else (loop (- idx 1))]))))

;; Extracts a filename extension without its leading dot.
(define (path-extension path)
  (let ([name (path-basename path)])
    (if name
        (let loop ([idx (- (string-length name) 1)])
          (cond
            [(<= idx 0) #f]
            [(char=? (string-ref name idx) #\.)
             (if (= idx (- (string-length name) 1))
                 #f
                 (substring name (+ idx 1) (string-length name)))]
            [else (loop (- idx 1))]))
        #f)))

;; Moves the current value to the front, adding it when absent.
(define (current-first items current)
  (cons current (filter (lambda (item) (not (equal? item current))) items)))

;; Formats a live current-value row or marks the preset whose parsed value is active.
(define (setting-choice-label item current parse)
  (if (eq? item 'current)
      (string-append "  Current: " (to-string current))
      (string-append
       (if (and (not (equal? item "Custom..."))
                (equal? (parse item) (parse (to-string current)))) "* " "  ")
       item)))

;; Builds Silicon argv without invoking a shell.
(define (build-silicon-args lang filename theme background shadow-blur
                            window-controls? show-title? line-numbers?
                            pad-horiz pad-vert out-path
                            #:font [font "Hack"] #:font-size [font-size 26]
                            #:tab-width [tab-width 4] #:line-offset [line-offset 1])
  (append
   (list "-l" lang
         "--theme" theme
         "--background" background
         "--shadow-blur-radius" (number->string (exact shadow-blur))
         "--pad-horiz" (number->string (exact pad-horiz))
         "--pad-vert" (number->string (exact pad-vert))
         "--font" (string-join
                   (map (lambda (family)
                          (string-append (trim family) "=" (number->string font-size)))
                        (split-many font ";")) ";")
         "--tab-width" (number->string (exact tab-width))
         "--line-offset" (number->string (exact line-offset)))
   (if (and show-title? filename)
       (list "--window-title" (path-basename filename))
       '())
   (if window-controls? '() '("--no-window-controls"))
   (if line-numbers? '() '("--no-line-number"))
   (if out-path (list "-o" out-path) '("--to-clipboard"))))

;; Detects the Silicon error that permits a syntax fallback retry.
(define (unsupported-language-error? stderr)
  (or (string-contains? stderr "Unsupported language")
      (string-contains? stderr "Failed to detect the language")))
