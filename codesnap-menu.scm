(require (prefix-in helix. "helix/commands.scm"))
(require "helix/misc.scm")
(require (only-in "ui-utils.hx/menu.scm" show-menu))
(require (only-in "ui-utils.hx/menu-model.scm" menu-action menu-switch menu-info))
(require (only-in "ui-utils.hx/picker.scm" show-picker!))
(require (only-in "ui-utils.hx/picker-model.scm" make-picker))
(require (only-in "codesnap.scm" codesnap-execute *codesnap-theme* codesnap-theme))

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

;;@doc
;; Open the interactive CodeSnap control panel
(define (codesnap-menu)
  (codesnap-menu-impl #t))

(define (codesnap-menu-impl yank?)
  ;; Yank immediately to preserve visual selection before popup opens
  (when yank?
    (helix.clipboard-yank))
  (show-menu "CodeSnap Options"
    (list
      (menu-action #\s "Snap to Clipboard" (lambda (switches) (codesnap-execute)))
      (menu-action #\f "Snap to File..." (lambda (switches) (codesnap-execute "/tmp/codesnap.png")))
      (menu-action #\t (string-append "Theme: " *codesnap-theme*) (lambda (switches) (show-theme-picker)))
      (menu-action #\q "Cancel" (lambda (switches) #f)))
    #:overlay-scale (lambda () 40)))
