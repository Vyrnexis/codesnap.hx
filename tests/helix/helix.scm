(require "../../codesnap.scm")
(require "../../codesnap-menu.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require-builtin steel/time)
(provide codesnap codesnap-menu codesnap-reset codesnap-export codesnap-open-last
         codesnap-check-start codesnap-check-finish)

(define check-path #f)
(define check-selection #f)

;; Starts an isolated capture and verifies atomic settings validation and the busy guard.
(define (codesnap-check-start)
  (codesnap-reset)
  (let ([message (with-handler error-object-message
                     (codesnap-configure! #:theme "Nord" #:font-size 0)
                     #f)])
    (assert! (equal? (trim message) "CodeSnap font size must be an integer from 1 to 256"))
    (assert! (equal? (get-codesnap-theme) "Dracula")))
  (codesnap-configure! #:original-line-numbers? #t #:dedent? #t)
  (set! check-path (string-append (current-directory) "/.test-work/integration-"
                                 (local-time/now! "%Y%m%d-%H%M%S") ".png"))
  (assert! (not (path-exists? check-path)))
  (set! check-selection (register->value #\.))
  (codesnap-execute check-path)
  (assert! (get-codesnap-busy))
  (codesnap-execute (string-append check-path "-blocked.png"))
  void)

;; Checks completed publication, unchanged selection, and default restoration.
(define (codesnap-check-finish)
  (assert! (string? check-path))
  (assert! (not (get-codesnap-busy)))
  (assert! (is-file? check-path))
  (assert! (not (path-exists? (string-append check-path "-blocked.png"))))
  (assert! (equal? check-path (get-codesnap-last-path)))
  (assert! (equal? check-selection (register->value #\.)))
  (codesnap-reset)
  (assert! (not (get-codesnap-original-lines)))
  (assert! (not (get-codesnap-dedent)))
  (assert! (equal? check-path (get-codesnap-last-path)))
  (set-status! "CodeSnap integration: all checks passed")
  void)

(set-status! "CodeSnap integration loaded")
