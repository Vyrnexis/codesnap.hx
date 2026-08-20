(require (prefix-in helix. "helix/commands.scm"))
(require "helix/misc.scm")
(require (only-in "ui-utils.hx/picker.scm" show-picker! picker-current-item))
(require (only-in "ui-utils.hx/picker-model.scm" make-picker))
(require (only-in "ui-utils.hx/keys.scm" char-is?))
(require (only-in "helix/components.scm" 
                  key-event-enter? 
                  key-event-right? 
                  key-event-left? 
                  key-event-escape? 
                  pop-last-component-by-name! 
                  event-result/consume))
(require (only-in "codesnap.scm" 
                  codesnap-execute 
                  codesnap-theme 
                  codesnap-bg 
                  get-codesnap-theme 
                  get-codesnap-bg 
                  get-codesnap-window-controls 
                  get-codesnap-show-title 
                  get-codesnap-line-numbers
                  codesnap-set-window-controls! 
                  codesnap-set-show-title! 
                  codesnap-set-line-numbers!
                  get-codesnap-shadow-blur 
                  get-codesnap-pad-horiz 
                  get-codesnap-pad-vert
                  codesnap-set-shadow-blur! 
                  codesnap-set-pad-horiz! 
                  codesnap-set-pad-vert!))

(provide codesnap-menu)

;; Determines if target string begins with the given prefix.
(define (starts-with? str prefix)
  (and (>= (string-length str) (string-length prefix))
       (equal? (substring str 0 (string-length prefix)) prefix)))

;; Extracts hexadecimal color value from menu label string.
(define (extract-color str)
  (cond
    [(starts-with? str "#00000000") "#00000000"]
    [else (substring str 0 7)]))

;; Displays the interactive syntax theme selection picker.
(define (show-theme-picker)
  (let* ([themes '("1337" "Coldark-Cold" "Coldark-Dark" "DarkNeon" "Dracula" "GitHub" 
                   "Monokai Extended" "Monokai Extended Bright" "Monokai Extended Light" 
                   "Monokai Extended Origin" "Nord" "OneHalfDark" "OneHalfLight" 
                   "Solarized (dark)" "Solarized (light)" "Sublime Snazzy" "TwoDark" 
                   "Visual Studio Dark+" "gruvbox-dark" "gruvbox-light" "zenburn")]
         [spec (make-picker #:name "codesnap-theme-picker"
                            #:title "Syntax Theme"
                            #:instructions "Space: select | Enter: apply | Esc: back"
                            #:items themes
                            #:item-label (lambda (item)
                                           (if (equal? item (get-codesnap-theme))
                                               (string-append "✓ " item)
                                               (string-append "  " item)))
                            #:filter? #f
                            #:close-mode 'pop
                            #:overlay-scale (lambda () 40)
                            #:keys (lambda (state-box event)
                                     (let* ([state (unbox state-box)]
                                            [choice (picker-current-item state)])
                                       (cond
                                         [(char-is? event #\space)
                                          (codesnap-theme choice)
                                          event-result/consume]
                                         [(key-event-enter? event)
                                          (codesnap-theme choice)
                                          (pop-last-component-by-name! "codesnap-theme-picker")
                                          event-result/consume]
                                         [(or (key-event-left? event) (key-event-escape? event) (char-is? event #\h))
                                          (pop-last-component-by-name! "codesnap-theme-picker")
                                          event-result/consume]
                                         [else #f]))))])
    (show-picker! spec)))

;; Displays the interactive background color selection picker.
(define (show-background-picker)
  (let* ([colors '("#aaaaff (Dracula)" 
                   "#2e3440 (Nord)" 
                   "#282c34 (One Dark)" 
                   "#282828 (Gruvbox)"
                   "#002b36 (Solarized)"
                   "#000000 (Black)" 
                   "#ffffff (White)" 
                   "#00000000 (Transparent)")]
         [spec (make-picker #:name "codesnap-bg-picker"
                            #:title "Background Color"
                            #:instructions "Space: select | Enter: apply | Esc: back"
                            #:items colors
                            #:item-label (lambda (item)
                                           (if (equal? (extract-color item) (get-codesnap-bg))
                                               (string-append "✓ " item)
                                               (string-append "  " item)))
                            #:filter? #f
                            #:close-mode 'pop
                            #:overlay-scale (lambda () 40)
                            #:keys (lambda (state-box event)
                                     (let* ([state (unbox state-box)]
                                            [choice (picker-current-item state)])
                                       (cond
                                         [(char-is? event #\space)
                                          (codesnap-bg (extract-color choice))
                                          event-result/consume]
                                         [(key-event-enter? event)
                                          (codesnap-bg (extract-color choice))
                                          (pop-last-component-by-name! "codesnap-bg-picker")
                                          event-result/consume]
                                         [(or (key-event-left? event) (key-event-escape? event) (char-is? event #\h))
                                          (pop-last-component-by-name! "codesnap-bg-picker")
                                          event-result/consume]
                                         [else #f]))))])
    (show-picker! spec)))

;; Displays a numeric value picker for dimension and blur configuration.
(define (show-number-picker name title getter setter! options)
  (let* ([spec (make-picker #:name name
                            #:title title
                            #:instructions "Space: select | Enter: apply | Esc: back"
                            #:items options
                            #:item-label (lambda (item)
                                           (if (equal? item (number->string (getter)))
                                               (string-append "✓ " item)
                                               (string-append "  " item)))
                            #:filter? #f
                            #:close-mode 'pop
                            #:overlay-scale (lambda () 40)
                            #:keys (lambda (state-box event)
                                     (let* ([state (unbox state-box)]
                                            [choice (picker-current-item state)])
                                       (cond
                                         [(char-is? event #\space)
                                          (setter! (string->number choice))
                                          event-result/consume]
                                         [(key-event-enter? event)
                                          (setter! (string->number choice))
                                          (pop-last-component-by-name! name)
                                          event-result/consume]
                                         [(or (key-event-left? event) (key-event-escape? event) (char-is? event #\h))
                                          (pop-last-component-by-name! name)
                                          event-result/consume]
                                         [else #f]))))])
    (show-picker! spec)))

;; Displays the settings configuration submenu.
(define (show-settings-picker)
  (let* ([items '("Theme" "Background" "Shadow Blur" "Horizontal Padding" "Vertical Padding" "Window Controls" "Window Title" "Line Numbers")]
         [spec (make-picker #:name "codesnap-settings-menu"
                            #:title "CodeSnap Settings"
                            #:instructions "Enter/Right: open | Space: toggle | Esc: back"
                            #:items items
                            #:item-label (lambda (item)
                                           (cond
                                             [(equal? item "Theme") (string-append "Theme: " (get-codesnap-theme) " >")]
                                             [(equal? item "Background") (string-append "Background: " (get-codesnap-bg) " >")]
                                             [(equal? item "Shadow Blur") (string-append "Shadow Blur: " (number->string (get-codesnap-shadow-blur)) " >")]
                                             [(equal? item "Horizontal Padding") (string-append "Horizontal Padding: " (number->string (get-codesnap-pad-horiz)) " >")]
                                             [(equal? item "Vertical Padding") (string-append "Vertical Padding: " (number->string (get-codesnap-pad-vert)) " >")]
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
                                         [(or (key-event-enter? event) (key-event-right? event) (char-is? event #\l) (char-is? event #\space))
                                          (cond
                                            [(equal? choice "Theme") 
                                             (if (not (char-is? event #\space))
                                                 (begin (show-theme-picker) event-result/consume) #f)]
                                            [(equal? choice "Background") 
                                             (if (not (char-is? event #\space))
                                                 (begin (show-background-picker) event-result/consume) #f)]
                                            [(equal? choice "Shadow Blur") 
                                             (if (not (char-is? event #\space))
                                                 (begin (show-number-picker "codesnap-shadow-blur-picker" "Shadow Blur" get-codesnap-shadow-blur codesnap-set-shadow-blur! '("0" "10" "15" "20" "30" "50")) event-result/consume) #f)]
                                            [(equal? choice "Horizontal Padding") 
                                             (if (not (char-is? event #\space))
                                                 (begin (show-number-picker "codesnap-pad-horiz-picker" "Horizontal Padding" get-codesnap-pad-horiz codesnap-set-pad-horiz! '("0" "20" "40" "80" "100" "120")) event-result/consume) #f)]
                                            [(equal? choice "Vertical Padding") 
                                             (if (not (char-is? event #\space))
                                                 (begin (show-number-picker "codesnap-pad-vert-picker" "Vertical Padding" get-codesnap-pad-vert codesnap-set-pad-vert! '("0" "20" "40" "80" "100" "150")) event-result/consume) #f)]
                                            [(equal? choice "Window Controls") 
                                             (begin
                                               (codesnap-set-window-controls! (not (get-codesnap-window-controls)))
                                               event-result/consume)]
                                            [(equal? choice "Window Title") 
                                             (begin
                                               (codesnap-set-show-title! (not (get-codesnap-show-title)))
                                               event-result/consume)]
                                            [(equal? choice "Line Numbers") 
                                             (begin
                                               (codesnap-set-line-numbers! (not (get-codesnap-line-numbers)))
                                               event-result/consume)]
                                            [else #f])]
                                         [(or (key-event-escape? event) (key-event-left? event) (char-is? event #\h))
                                          (pop-last-component-by-name! "codesnap-settings-menu")
                                          event-result/consume]
                                         [else #f]))))])
    (show-picker! spec)))

;; Core implementation of the root CodeSnap interactive menu.
(define (codesnap-menu-impl yank?)
  (when yank?
    (helix.clipboard-yank))
  
  (let* ([items '("Snap to Clipboard" "Snap to File..." "Settings >")]
         [spec (make-picker #:name "codesnap-main-menu"
                            #:title "CodeSnap"
                            #:instructions "Enter: execute | Right: open | Esc: close"
                            #:items items
                            #:filter? #f
                            #:close-mode 'pop
                            #:overlay-scale (lambda () 40)
                            #:keys (lambda (state-box event)
                                     (let* ([state (unbox state-box)]
                                            [choice (picker-current-item state)])
                                       (cond
                                         [(or (key-event-enter? event) (key-event-right? event) (char-is? event #\l))
                                          (cond
                                            [(equal? choice "Snap to Clipboard") 
                                             (if (key-event-enter? event)
                                                 (begin
                                                   (codesnap-execute)
                                                   (pop-last-component-by-name! "codesnap-main-menu")
                                                   event-result/consume)
                                                 #f)]
                                            [(equal? choice "Snap to File...") 
                                             (if (key-event-enter? event)
                                                 (begin
                                                   (codesnap-execute "~/Pictures/codesnap-capture.png")
                                                   (pop-last-component-by-name! "codesnap-main-menu")
                                                   event-result/consume)
                                                 #f)]
                                            [(equal? choice "Settings >") 
                                             (show-settings-picker)
                                             event-result/consume]
                                            [else #f])]
                                         [(or (key-event-escape? event) (key-event-left? event) (char-is? event #\h) (char-is? event #\q))
                                          (pop-last-component-by-name! "codesnap-main-menu")
                                          event-result/consume]
                                         [else #f]))))])
    (show-picker! spec)))

;; Opens the root interactive CodeSnap control panel.
(define (codesnap-menu)
  (codesnap-menu-impl #t))
