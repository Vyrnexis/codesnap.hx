(require (prefix-in helix. "helix/commands.scm"))
(require "helix/misc.scm")
(require (only-in "ui-utils.hx/picker.scm" show-picker! picker-current-item))
(require (only-in "ui-utils.hx/picker-model.scm" make-picker))
(require (only-in "helix/components.scm" key-event-enter? key-event-right? key-event-left? key-event-escape? pop-last-component-by-name! event-result/consume))
(require (only-in "codesnap.scm" 
                  codesnap-execute codesnap-theme codesnap-bg 
                  get-codesnap-theme get-codesnap-bg get-codesnap-window-controls get-codesnap-show-title get-codesnap-line-numbers
                  codesnap-set-window-controls! codesnap-set-show-title! codesnap-set-line-numbers!))

(provide codesnap-menu)

(define (starts-with? str prefix)
  (and (>= (string-length str) (string-length prefix))
       (equal? (substring str 0 (string-length prefix)) prefix)))

(define (show-theme-picker)
  (let* ([themes '("1337" "Coldark-Cold" "Coldark-Dark" "DarkNeon" "Dracula" "GitHub" "Monokai Extended" "Monokai Extended Bright" "Monokai Extended Light" "Monokai Extended Origin" "Nord" "OneHalfDark" "OneHalfLight" "Solarized (dark)" "Solarized (light)" "Sublime Snazzy" "TwoDark" "Visual Studio Dark+")]
         [spec (make-picker #:name "codesnap-theme-picker"
                            #:items themes
                            #:item-label (lambda (item)
                                           (if (equal? item (get-codesnap-theme))
                                               (string-append "✓ " item)
                                               (string-append "  " item)))
                            #:filter? #t
                            #:close-mode 'pop
                            #:keys (lambda (state-box event)
                                     (let* ([state (unbox state-box)]
                                            [choice (picker-current-item state)])
                                       (cond
                                         [(key-event-enter? event)
                                          (codesnap-theme choice)
                                          event-result/consume]
                                         [(or (key-event-left? event) (key-event-escape? event))
                                          (pop-last-component-by-name! "codesnap-theme-picker")
                                          event-result/consume]
                                         [else #f])))])
    (show-picker! spec)))

(define (show-background-picker)
  (let* ([colors '("#aaaaff (Dracula)" "#2e3440 (Nord)" "#282c34 (One Dark)" "#000000 (Black)" "#ffffff (White)")]
         [spec (make-picker #:name "codesnap-bg-picker"
                            #:items colors
                            #:item-label (lambda (item)
                                           (if (starts-with? item (get-codesnap-bg))
                                               (string-append "✓ " item)
                                               (string-append "  " item)))
                            #:filter? #t
                            #:close-mode 'pop
                            #:keys (lambda (state-box event)
                                     (let* ([state (unbox state-box)]
                                            [choice (picker-current-item state)])
                                       (cond
                                         [(key-event-enter? event)
                                          (codesnap-bg (substring choice 0 7))
                                          event-result/consume]
                                         [(or (key-event-left? event) (key-event-escape? event))
                                          (pop-last-component-by-name! "codesnap-bg-picker")
                                          event-result/consume]
                                         [else #f])))])
    (show-picker! spec)))

(define (codesnap-menu-impl yank?)
  (when yank?
    (helix.clipboard-yank))
  
  (let* ([items '("Snap to Clipboard" "Snap to File..." "Theme" "Background" "Window Controls" "Window Title" "Line Numbers")]
         [spec (make-picker #:name "codesnap-main-menu"
                            #:items items
                            #:item-label (lambda (item)
                                           (cond
                                             [(equal? item "Theme") (string-append "Theme: " (get-codesnap-theme) " >")]
                                             [(equal? item "Background") (string-append "Background: " (get-codesnap-bg) " >")]
                                             [(equal? item "Window Controls") (string-append "Window Controls: " (if (get-codesnap-window-controls) "ON" "OFF"))]
                                             [(equal? item "Window Title") (string-append "Window Title: " (if (get-codesnap-show-title) "ON" "OFF"))]
                                             [(equal? item "Line Numbers") (string-append "Line Numbers: " (if (get-codesnap-line-numbers) "ON" "OFF"))]
                                             [else item]))
                            #:filter? #f
                            #:close-mode 'pop
                            #:overlay-scale (lambda () 40)
                            #:keys (lambda (state-box event)
                                     (let* ([state (unbox state-box)]
                                            [choice (picker-current-item state)])
                                       (cond
                                         [(or (key-event-enter? event) (key-event-right? event))
                                          (cond
                                            [(equal? choice "Snap to Clipboard") 
                                             (codesnap-execute)
                                             (pop-last-component-by-name! "codesnap-main-menu")
                                             event-result/consume]
                                            [(equal? choice "Snap to File...") 
                                             (codesnap-execute "/tmp/codesnap.png")
                                             (pop-last-component-by-name! "codesnap-main-menu")
                                             event-result/consume]
                                            [(equal? choice "Theme") 
                                             (show-theme-picker)
                                             event-result/consume]
                                            [(equal? choice "Background") 
                                             (show-background-picker)
                                             event-result/consume]
                                            [(equal? choice "Window Controls") 
                                             (codesnap-set-window-controls! (not (get-codesnap-window-controls)))
                                             event-result/consume]
                                            [(equal? choice "Window Title") 
                                             (codesnap-set-show-title! (not (get-codesnap-show-title)))
                                             event-result/consume]
                                            [(equal? choice "Line Numbers") 
                                             (codesnap-set-line-numbers! (not (get-codesnap-line-numbers)))
                                             event-result/consume]
                                            [else #f])]
                                         [(key-event-escape? event)
                                          (pop-last-component-by-name! "codesnap-main-menu")
                                          event-result/consume]
                                         [else #f])))])
    (show-picker! spec)))

;;@doc
;; Open the interactive CodeSnap control panel
(define (codesnap-menu)
  (codesnap-menu-impl #t))
