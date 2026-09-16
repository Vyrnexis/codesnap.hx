(require "helix/misc.scm")
(require (only-in "helix/editor.scm" editor-focused-buffer-area))
(require (only-in "helix/components.scm"
                  key-event-enter? key-event-right? key-event-left? key-event-escape?
                  prompt push-component! pop-last-component-by-name! event-result/consume
                  area-width area-height))
(require (only-in "codesnap-picker.scm" show-picker! picker-current-item))
(require (only-in "ui-utils.hx/picker-model.scm" make-picker))
(require (only-in "ui-utils.hx/keys.scm" char-is?))
(require (only-in "ui-utils.hx/strings.scm" truncate-left truncate-string/dots))
(require "codesnap-core.scm")
(require (only-in "codesnap-process.scm" absolute-path))
(require "codesnap.scm")

(provide codesnap-menu)

;; Calculates a content-aware overlay scale using the space available to the focused view.
(define (menu-scale rows)
  (let ([area (editor-focused-buffer-area)])
    (if area (picker-scale (area-width area) (area-height area) rows) 90)))

;; Measures the usable text width inside a picker, including its borders and row prefix.
(define (menu-text-width rows)
  (let ([area (editor-focused-buffer-area)])
    (if area (max 1 (- (quotient (* (area-width area) (menu-scale rows)) 100) 6)) 52)))

;; Keeps menu hints legible when the available width requires a shorter version.
(define (menu-hint text rows)
  (let ([width (menu-text-width rows)])
    (if (<= (string-length text) width) text
        (truncate-string/dots "Enter / Esc" width))))

;; Returns true for a back key without stealing letters from searchable pickers.
(define (back-key? event searchable?)
  (or (key-event-escape? event)
      (and (not searchable?)
           (or (key-event-left? event) (char-is? event #\h) (char-is? event #\q)))))

;; Shows validation errors without applying a partial setting change.
(define (apply-setting! setter value)
  (with-handler
   (lambda (err) (set-error! (trim (error-object-message err))) #f)
   (setter value)
   #t))

;; Prompts for a custom setting; blank input and Escape preserve the current value.
(define (prompt-setting title getter setter parse)
  (push-component!
   (prompt (string-append title " (current: " (to-string (getter)) "): ")
           (lambda (input)
             (when (not (string=? (trim input) ""))
               (apply-setting! setter (parse input)))))))

;; Shows current values, presets and a custom entry using the existing picker.
(define (show-setting-picker title getter setter options parse searchable?)
  (let* ([name "codesnap-value-picker"]
         [current (to-string (getter))]
         [items (append (current-first options current) '("Custom..."))]
         [spec (make-picker
                #:name name #:title (truncate-string/dots title (menu-text-width 12))
                #:instructions (menu-hint (if searchable? "Type to search; Enter" "Space:apply Enter:OK") 12)
                #:items items #:filter? searchable? #:close-mode 'pop
                #:selected-style 'theme
                #:overlay-scale (lambda () (menu-scale (min 12 (+ (length items) (if searchable? 2 0)))))
                #:item-label (lambda (item)
                               (string-append
                                (if (equal? item (to-string (getter))) "* " "  ") item))
                #:keys
                (lambda (state-box event)
                  (let ([choice (picker-current-item (unbox state-box))])
                    (cond
                      [(back-key? event searchable?)
                       (pop-last-component-by-name! name)
                       event-result/consume]
                      [(and choice (or (key-event-enter? event)
                                       (and (not searchable?) (char-is? event #\space))))
                       (if (equal? choice "Custom...")
                           (when (key-event-enter? event)
                             (pop-last-component-by-name! name)
                             (prompt-setting title getter setter parse))
                           (when (apply-setting! setter (parse choice))
                             (when (key-event-enter? event)
                               (pop-last-component-by-name! name))))
                       event-result/consume]
                      [else #f]))))])
    (show-picker! spec)
    void))

;; Extracts a hexadecimal color from a preset label.
(define (color-value label)
  (car (split-many (trim label) " ")))

;; Displays supported background presets and arbitrary hexadecimal color entry.
(define (show-background-picker)
  (show-setting-picker
   "Background" get-codesnap-bg codesnap-bg
   '("#aaaaff (Dracula)" "#2e3440 (Nord)" "#282c34 (One Dark)"
     "#282828 (Gruvbox)" "#002b36 (Solarized)" "#000000 (Black)"
     "#ffffff (White)" "#00000000 (Transparent)")
   color-value #f))

;; Presents a number picker with custom entry and validation in the setting setter.
(define (show-number-picker title getter setter options)
  (show-setting-picker title getter setter options string->number #f))

;; Converts a tab-width choice into an explicit width or automatic editor mode.
(define (parse-tab-width text)
  (if (equal? (trim text) "Editor") #f (or (string->number text) text)))

;; Formats automatic tab width for the menu.
(define (tab-width-label)
  (if (get-codesnap-tab-width) (number->string (get-codesnap-tab-width)) "Editor"))

;; Closes CodeSnap menus before opening an exported configuration buffer.
(define (export-from-menu)
  (pop-last-component-by-name! "codesnap-settings-menu")
  (pop-last-component-by-name! "codesnap-main-menu")
  (codesnap-export))

;; Describes each settings row with its current label and action.
(define (settings-items)
  (list
   (list "Theme" get-codesnap-theme
         (lambda () (show-setting-picker "Theme" get-codesnap-theme codesnap-theme
                                          (codesnap-themes) (lambda (x) x) #t)) #f)
   (list "Background" get-codesnap-bg show-background-picker #f)
   (list "Font" get-codesnap-font
         (lambda () (show-setting-picker "Font" get-codesnap-font codesnap-set-font!
                                          (codesnap-fonts) (lambda (x) x) #t)) #f)
   (list "Font Size" get-codesnap-font-size
         (lambda () (show-number-picker "Font Size" get-codesnap-font-size codesnap-set-font-size!
                                        '("16" "20" "24" "26" "32" "40"))) #f)
   (list "Tab Width" tab-width-label
         (lambda () (show-setting-picker "Tab Width" tab-width-label codesnap-set-tab-width!
                                          '("Editor" "2" "4" "8") parse-tab-width #f)) #f)
   (list "Shadow Blur" get-codesnap-shadow-blur
         (lambda () (show-number-picker "Shadow Blur" get-codesnap-shadow-blur codesnap-set-shadow-blur!
                                        '("0" "10" "15" "20" "30" "50"))) #f)
   (list "Horizontal Padding" get-codesnap-pad-horiz
         (lambda () (show-number-picker "Horizontal Padding" get-codesnap-pad-horiz codesnap-set-pad-horiz!
                                        '("0" "20" "40" "80" "100" "120"))) #f)
   (list "Vertical Padding" get-codesnap-pad-vert
         (lambda () (show-number-picker "Vertical Padding" get-codesnap-pad-vert codesnap-set-pad-vert!
                                        '("0" "20" "40" "80" "100" "150"))) #f)
   (list "Window Controls" get-codesnap-window-controls
         (lambda () (codesnap-set-window-controls! (not (get-codesnap-window-controls)))) #t)
   (list "Window Title" get-codesnap-show-title
         (lambda () (codesnap-set-show-title! (not (get-codesnap-show-title)))) #t)
   (list "Line Numbers" get-codesnap-line-numbers
         (lambda () (codesnap-set-line-numbers! (not (get-codesnap-line-numbers)))) #t)
   (list "Source Line Numbers" get-codesnap-original-lines
         (lambda () (codesnap-set-original-lines! (not (get-codesnap-original-lines)))) #t)
   (list "Remove Common Indent" get-codesnap-dedent
         (lambda () (codesnap-set-dedent! (not (get-codesnap-dedent)))) #t)
   (list "Reset Defaults" (lambda () #f) codesnap-reset #f)
   (list "Export Configuration" (lambda () #f) export-from-menu #f)))

;; Shows settings with immediately updated values and a keyboard-accessible action per row.
(define (show-settings-picker)
  (let ([items (settings-items)])
    (show-picker!
     (make-picker
      #:name "codesnap-settings-menu" #:title "Settings"
      #:instructions (menu-hint "Enter:open Space:toggle" 12) #:items items #:close-mode 'pop
      #:selected-style 'theme
      #:overlay-scale (lambda () (menu-scale (min 12 (length items))))
      #:item-label
      (lambda (item)
        (let ([value ((list-ref item 1))])
          (string-append (car item)
                         (if (list-ref item 3) (if value ": ON" ": OFF")
                             (if value (string-append ": " (to-string value) " >") "")))))
      #:keys
      (lambda (state-box event)
        (let ([choice (picker-current-item (unbox state-box))])
          (cond
            [(back-key? event #f)
             (pop-last-component-by-name! "codesnap-settings-menu")
             event-result/consume]
            [(and choice (or (key-event-enter? event) (key-event-right? event)
                             (char-is? event #\l)
                             (and (char-is? event #\space) (list-ref choice 3))))
             ((list-ref choice 2))
             event-result/consume]
            [else #f]))))))
  void)

;; Completes a typed path in one directory and always includes the proposed save destination.
(define (save-path-choices directory default-name input)
  (with-handler
   (lambda (_) (list (absolute-path (string-append directory "/" input))))
   (let* ([path (if (string=? input "")
                    (string-append directory "/" default-name)
                    (if (or (starts-with? input "/") (starts-with? input "~")
                            (starts-with? input "\\")
                            (and (> (string-length input) 1) (char=? (string-ref input 1) #\:)))
                        (absolute-path input) (string-append directory "/" input)))]
          [parent (if (or (ends-with? path "/") (ends-with? path "\\")) path (parent-name path))]
          [prefix (if (or (ends-with? path "/") (ends-with? path "\\")) "" (path-basename path))]
          [matches (if (is-dir? parent)
                       (filter (lambda (entry)
                                 (and (or (string=? input "") (starts-with? (path-basename entry) prefix))
                                      (or (is-dir? entry)
                                          (member (path-extension entry)
                                                  '("png" "jpg" "jpeg" "bmp" "gif" "ico" "tif" "tiff" "webp")))))
                               (read-dir parent))
                       '())]
          [destination (if (or (is-dir? path) (path-extension path)) path
                           (string-append path ".png"))])
     (cons destination
           (filter (lambda (entry) (not (equal? entry destination)))
                   (sort matches string<?))))))

;; Opens a searchable save picker; directory choices continue completion and files start captures.
(define (show-save-picker directory default-name)
  (show-picker!
   (make-picker
    #:name "codesnap-save-picker"
    #:title (truncate-left (string-append "Save in " directory) (menu-text-width 12))
    #:instructions (menu-hint "Type path; Enter:save" 12)
    #:items (save-path-choices directory default-name "")
    #:filter? #t #:close-mode 'pop #:selected-style 'theme
    #:overlay-scale (lambda () (menu-scale 12))
    #:filter-fn (lambda (_ input) (save-path-choices directory default-name input))
    #:item-label (lambda (path)
                   (string-append (if (is-dir? path) "Dir: " "Save: ")
                                  (truncate-left path (- (menu-text-width 12) 6))))
    #:on-accept (lambda (path)
                  (if (is-dir? path)
                      (show-save-picker (canonicalize-path path) default-name)
                      (codesnap-execute path)))))
  void)

;; Starts path completion with a unique source-derived default and the remembered directory.
(define (prompt-save-path)
  (let ([path (codesnap-default-path)])
    (show-save-picker (parent-name path) (path-basename path))))

;; Opens the root capture menu with access to saved output and rendering settings.
(define (codesnap-menu)
  (show-picker!
   (make-picker
    #:name "codesnap-main-menu" #:title "CodeSnap"
    #:instructions (menu-hint "Enter:select Esc:back" 4)
    #:items '("Snap to Clipboard" "Snap to File..." "Open Last Capture" "Settings >")
    #:close-mode 'pop #:selected-style 'theme
    #:overlay-scale (lambda () (menu-scale 4))
    #:keys
    (lambda (state-box event)
      (let ([choice (picker-current-item (unbox state-box))])
        (cond
          [(back-key? event #f)
           (pop-last-component-by-name! "codesnap-main-menu")
           event-result/consume]
          [(and (equal? choice "Settings >")
                (or (key-event-enter? event) (key-event-right? event) (char-is? event #\l)))
           (show-settings-picker)
           event-result/consume]
          [(key-event-enter? event)
           (pop-last-component-by-name! "codesnap-main-menu")
           (cond [(equal? choice "Snap to Clipboard") (codesnap-execute)]
                 [(equal? choice "Snap to File...") (prompt-save-path)]
                 [(equal? choice "Open Last Capture") (codesnap-open-last)])
           event-result/consume]
          [else #f])))))
  void)
