(provide default-themes
         valid-color?
         valid-dimension?
         config-validation-error
         selection-text
         path-basename
         path-extension
         current-first
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
  (string-join fragments "\n"))

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

;; Builds Silicon argv without invoking a shell.
(define (build-silicon-args lang filename theme background shadow-blur
                            window-controls? show-title? line-numbers?
                            pad-horiz pad-vert out-path)
  (append
   (list "-l" lang
         "--theme" theme
         "--background" background
         "--shadow-blur-radius" (number->string shadow-blur)
         "--pad-horiz" (number->string pad-horiz)
         "--pad-vert" (number->string pad-vert))
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
