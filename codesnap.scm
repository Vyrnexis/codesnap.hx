(require (prefix-in helix. "helix/commands.scm"))
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/ext.scm")

(provide codesnap)

(define (current-language)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)]
         [lang (editor-document->language focus-doc-id)])
    ;; If the language is #false or nil, default to "txt"
    (if lang lang "txt")))

;;@doc
;; Captures the current selection as a beautiful image and saves it to clipboard
(define (codesnap)
  ;; 1. Yank the selection to clipboard
  (helix.clipboard-yank)
  
  ;; 2. Give it a tiny delay to ensure the clipboard is populated, then run silicon
  (enqueue-thread-local-callback-with-delay
   100
   (lambda ()
     (let ([lang (current-language)])
       ;; We run silicon, taking text from clipboard, saving to a tmp file, then copying to clipboard
       ;; Note: Make sure `silicon` and `xclip` are in your PATH!
       (helix.run-shell-command (string-append "silicon --from-clipboard -l " lang " -o /tmp/codesnap.png && xclip -selection clipboard -t image/png -i /tmp/codesnap.png"))
       (set-status! (string-append "📸 Snap saved! Language: " lang))))))
