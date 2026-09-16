(require "../codesnap-core.scm")

;; Raises a named failure when a core behavior regresses.
(define (check label value)
  (when (not value) (error label)))

(check "short color" (valid-color? "#abc"))
(check "alpha color" (valid-color? "#AABBCCDD"))
(check "invalid color" (not (valid-color? "blue")))
(check "zero dimension" (valid-dimension? 0))
(check "negative dimension" (not (valid-dimension? -1)))
(check "valid configuration"
       (not (config-validation-error
             "Dracula" "#aaaaff" 15 #t #t #t 80 100)))
(check "multiple selections"
       (equal? (selection-text '("first" "second")) "first\nsecond"))
(check "whole-line selections retain their existing separator"
       (equal? (selection-text '("first\n" "second\n")) "first\nsecond\n"))
(check "leading newlines and intentional blank lines survive"
       (equal? (selection-text '("first\n" "\nsecond")) "first\n\nsecond"))
(check "CRLF boundaries survive"
       (equal? (selection-text '("first\r\n" "second\r\n")) "first\r\nsecond\r\n"))
(check "no selection" (equal? (selection-text '()) ""))
(check "dedent preserves nesting and final newline"
       (equal? (dedent-text "  first\n    second\n  third\n") "first\n  second\nthird\n"))
(check "dedent handles tabs without changing relative whitespace"
       (equal? (dedent-text "\tfirst\n\t\tsecond\n") "first\n\tsecond\n"))
(check "different whitespace prefixes remain unchanged"
       (equal? (dedent-text "  first\n\tsecond") "  first\n\tsecond"))
(check "dedent preserves CRLF"
       (equal? (dedent-text "  first\r\n  second\r\n") "first\r\nsecond\r\n"))
(check "blank input survives dedent" (equal? (dedent-text "\n\n") "\n\n"))
(check "font fallback list" (not (font-validation-error "Hack; DejaVu Sans Mono" 26)))
(check "font parser injection rejected" (font-validation-error "Hack=broken" 26))
(check "empty font family rejected" (font-validation-error "Hack;" 26))
(check "zero font size rejected" (font-validation-error "Hack" 0))
(check "language order remains requested-first"
       (equal? (capture-languages "markdown" "file.rs") '("markdown" "rs")))
(check "language fallback removes duplicate extensions"
       (equal? (capture-languages "rs" "file.rs") '("rs" "markdown")))
(check "portable source filename"
       (equal? (capture-name "/src/my parser.scm" "20260916-120000")
               "my-parser-20260916-120000.png"))
(check "scratch filename"
       (equal? (capture-name #f "20260916-120000") "untitled-20260916-120000.png"))
(check "small terminal uses all available space" (= (picker-scale 40 12 12) 100))
(check "large terminal avoids fixed 40 percent" (< (picker-scale 200 60 4) 40))
(check "safe basename"
       (equal? (path-basename "/tmp/name \"$(safe).scm")
               "name \"$(safe).scm"))
(check "Windows basename"
       (equal? (path-basename "C:\\Users\\Vyrenxis\\example.scm")
               "example.scm"))
(check "path extension" (equal? (path-extension "/tmp/example.test.scm") "scm"))
(check "trailing dot" (not (path-extension "/tmp/example.")))
(check "current item first"
       (equal? (current-first '("one" "two" "three") "two")
               '("two" "one" "three")))

(let ([parse-color (lambda (label) (car (split-many label " ")))])
  (check "named background preset is marked by its color value"
         (equal? (setting-choice-label "#2e3440 (Nord)" "#2e3440" parse-color)
                 "* #2e3440 (Nord)"))
  (check "previous background preset loses its marker"
         (equal? (setting-choice-label "#aaaaff (Dracula)" "#2e3440" parse-color)
                 "  #aaaaff (Dracula)"))
  (check "current background row reads the active color"
         (equal? (setting-choice-label 'current "#2e3440" parse-color)
                 "  Current: #2e3440")))
(check "numeric preset markers still work"
       (equal? (setting-choice-label "26" 26 string->number) "* 26"))
(check "custom entry is never parsed as a preset"
       (equal? (setting-choice-label "Custom..." 26 string->number) "  Custom..."))

(let ([args (build-silicon-args
             "lisp" "/tmp/name \"$(safe).scm" "Dracula" "#aaaaff"
             15 #t #t #t 80 100 "/tmp/output name.png")])
  (check "filename argument" (member "name \"$(safe).scm" args))
  (check "output argument" (member "/tmp/output name.png" args))
  (check "output flag" (member "-o" args)))

(let ([args (build-silicon-args "rust" #f "Dracula" "#aaaaff" 15 #f #f #f
                                80.0 100.0 #f #:font "Hack; DejaVu Sans Mono"
                                #:font-size 32 #:tab-width 2.0 #:line-offset 42)])
  (check "font size applies to each fallback" (member "Hack=32;DejaVu Sans Mono=32" args))
  (check "JSON numeric settings become integer arguments" (member "2" args))
  (check "padding numeric settings become integer arguments" (member "80" args))
  (check "source line offset" (member "42" args))
  (check "clipboard mode" (member "--to-clipboard" args))
  (check "disabled line numbers" (member "--no-line-number" args)))

(check "unsupported language"
       (unsupported-language-error? "[error] Unsupported language: custom"))
(displayln "codesnap-core: all checks passed")
