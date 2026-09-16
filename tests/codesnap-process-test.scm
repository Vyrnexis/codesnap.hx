(require "../codesnap-process.scm")
(require-builtin steel/time)

;; Raises a named error when subprocess or publication behavior regresses.
(define (check label value)
  (when (not value) (error label)))

(let ([result (run-program "silicon" '("-l" "unsupported" "--to-clipboard") "code")])
  (check "zero exit is not sufficient" (not (render-success? result)))
  (check "clipboard diagnostics are preserved"
         (string-contains? (render-error-message result) "Unsupported language")))

(check "clipboard language fallback"
       (render-success?
        (render-with-fallback "code" '(("-l" "unsupported" "--to-clipboard")
                                       ("-l" "rust" "--to-clipboard")))))
(check "non-syntax errors are not retried"
       (not (render-success?
             (render-with-fallback "code" '(("--theme" "Broken" "--to-clipboard")
                                            ("-l" "rust" "--to-clipboard"))))))
(check "nonzero exit is a failure"
       (not (render-success? (run-program "silicon" '("-l" "crashed") "code"))))
(check "missing executable"
       (not (render-success? (run-program "codesnap-nonexistent-executable" '() "code"))))
(check "early exit preserves diagnostics for large selections"
       (string-contains?
        (render-error-message
         (run-program "silicon" '("--theme" "Broken") (make-string 200000 #\x)))
        "Cannot load theme"))

(let ([started (current-milliseconds)])
  (check "inherited stderr completes"
         (render-success? (run-program "silicon" '("-l" "inherited") "code")))
  (check "does not wait for clipboard owner" (< (- (current-milliseconds) started) 1500)))

(with-temporary-file
 (lambda (destination port)
   (display "keep me" port)
   (close-output-port port)
   (check "failed replacement is reported"
          (not (render-success?
                (render-file "code" (lambda (path) (list (list "--theme" "Broken" "-o" path)))
                             destination #t))))
   (check "failed replacement preserves original"
          (equal? (call-with-input-file destination read-port-to-string) "keep me"))
   (check "unconfirmed replacement fails"
          (not (render-success?
                (render-file "code" (lambda (path) (list (list "-o" path))) destination #f))))
   (check "unconfirmed replacement preserves original"
          (equal? (call-with-input-file destination read-port-to-string) "keep me"))
   (check "confirmed replacement succeeds"
          (render-success?
           (render-file "code" (lambda (path) (list (list "-o" path))) destination #t)))
   (check "complete image published"
          (equal? (call-with-input-file destination read-port-to-string) "rendered\n")))
 #:suffix ".png")

(displayln "codesnap-process: all checks passed")
