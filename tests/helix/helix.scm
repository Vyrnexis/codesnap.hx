(require "../../codesnap.scm")
(require "../../codesnap-menu.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (only-in "helix/components.scm" key-event-enter? pop-last-component-by-name!
                  event-result/consume))
(require (only-in "../../codesnap-picker.scm" show-picker! picker-current-item))
(require (only-in "ui-utils.hx/picker-model.scm" make-picker))
(require-builtin steel/time)
(provide codesnap codesnap-menu codesnap-reset codesnap-export codesnap-open-last
         codesnap-check-start codesnap-check-finish codesnap-check-menu)

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

;; Checks that moving to the second row retains every item in a short menu.
(define (codesnap-check-menu)
  (let ([visible '()] [items '("first" "second" "third" "fourth")])
    (show-picker!
     (make-picker
      #:name "codesnap-scroll-check" #:title "Menu scrolling check"
      #:instructions "Press j, then Enter" #:items items
      #:overlay-scale (lambda () (set! visible '()) 90)
      #:item-label (lambda (item) (set! visible (append visible (list item))) item)
      #:keys (lambda (state-box event)
               (if (key-event-enter? event)
                   (begin
                     (when (not (equal? (picker-current-item (unbox state-box)) "second"))
                       (error "Select the second row before checking"))
                     (when (not (equal? visible items))
                       (error "Menu rows scrolled before reaching the visible edge"))
                     (pop-last-component-by-name! "codesnap-scroll-check")
                     (set-status! "CodeSnap menu scrolling: check passed")
                     event-result/consume)
                   #f))))
    void))

(set-status! "CodeSnap integration loaded")
