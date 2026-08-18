(require (prefix-in helix. "helix/commands.scm"))
(require "helix/misc.scm")
(require (only-in "ui-utils.hx/picker.scm" show-picker!))
(require (only-in "ui-utils.hx/picker-model.scm" make-picker))
(require (only-in "codesnap.scm" codesnap-execute *codesnap-theme* codesnap-theme *codesnap-background* codesnap-bg *codesnap-window-controls* *codesnap-line-numbers* *codesnap-show-title*))

(provide codesnap-menu)

(define (show-theme-picker)
  (let* ([themes '("1337" "Coldark-Cold" "Coldark-Dark" "DarkNeon" "Dracula" "GitHub" "Monokai Extended" "Monokai Extended Bright" "Monokai Extended Light" "Monokai Extended Origin" "Nord" "OneHalfDark" "OneHalfLight" "Solarized (dark)" "Solarized (light)" "Sublime Snazzy" "TwoDark" "Visual Studio Dark+")]
         [spec (make-picker #:name "codesnap-theme-picker"
                            #:items themes
                            #:filter? #t
                            #:close-mode 'pop
                            #:on-accept (lambda (theme) 
                                          (codesnap-theme theme)
                                          (codesnap-menu-impl #f)))])
    (show-picker! spec)))

(define (show-background-picker)
  (let* ([colors '("#aaaaff (Dracula)" "#2e3440 (Nord)" "#282c34 (One Dark)" "#000000 (Black)" "#ffffff (White)")]
         [spec (make-picker #:name "codesnap-bg-picker"
                            #:items colors
                            #:filter? #t
                            #:close-mode 'pop
                            #:on-accept (lambda (choice) 
                                          (codesnap-bg (car (string-split choice " ")))
                                          (codesnap-menu-impl #f)))])
    (show-picker! spec)))

;;@doc
;; Open the interactive CodeSnap control panel
(define (codesnap-menu)
  (codesnap-menu-impl #t))

(define (codesnap-menu-impl yank?)
  (when yank?
    (helix.clipboard-yank))
  
  (let* ([items (list "Snap to Clipboard"
                      "Snap to File..."
                      (string-append "Theme: " *codesnap-theme* " >")
                      (string-append "Background: " *codesnap-background* " >")
                      (string-append "Window Controls: " (if *codesnap-window-controls* "ON" "OFF"))
                      (string-append "Window Title: " (if *codesnap-show-title* "ON" "OFF"))
                      (string-append "Line Numbers: " (if *codesnap-line-numbers* "ON" "OFF")))]
         [spec (make-picker #:name "codesnap-main-menu"
                            #:items items
                            #:filter? #f
                            #:close-mode 'pop
                            #:overlay-scale (lambda () 40)
                            #:on-accept (lambda (choice)
                                          (cond
                                            [(starts-with? choice "Snap to Clipboard") 
                                             (codesnap-execute)]
                                            [(starts-with? choice "Snap to File") 
                                             (codesnap-execute "/tmp/codesnap.png")]
                                            [(starts-with? choice "Theme") 
                                             (show-theme-picker)]
                                            [(starts-with? choice "Background") 
                                             (show-background-picker)]
                                            [(starts-with? choice "Window Controls") 
                                             (set! *codesnap-window-controls* (not *codesnap-window-controls*))
                                             (codesnap-menu-impl #f)]
                                            [(starts-with? choice "Window Title") 
                                             (set! *codesnap-show-title* (not *codesnap-show-title*))
                                             (codesnap-menu-impl #f)]
                                            [(starts-with? choice "Line Numbers") 
                                             (set! *codesnap-line-numbers* (not *codesnap-line-numbers*))
                                             (codesnap-menu-impl #f)])))])
    (show-picker! spec)))
