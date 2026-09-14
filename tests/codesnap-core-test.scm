(require "../codesnap-core.scm")

;; Raises a named failure when a core behavior regresses.
(define (check label value)
  (when (not value) (raise-error label)))

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

(let ([args (build-silicon-args
             "lisp" "/tmp/name \"$(safe).scm" "Dracula" "#aaaaff"
             15 #t #t #t 80 100 "/tmp/output name.png")])
  (check "filename argument" (member "name \"$(safe).scm" args))
  (check "output argument" (member "/tmp/output name.png" args))
  (check "output flag" (member "-o" args)))

(check "unsupported language"
       (unsupported-language-error? "[error] Unsupported language: custom"))
(displayln "codesnap-core: all checks passed")
