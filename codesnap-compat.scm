;; Every Helix editor API that CodeSnap calls lives here, so a change in the
;; unreleased Steel branch needs fixing in one place. Names are checked against
;; the upstream branch by scripts/check-helix-api.sh.
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/ext.scm")
(require (only-in "helix/configuration.scm" get-config-option-value get-language-config))
(require (only-in "helix/commands.scm" new))
(require (only-in "helix/static.scm" current-selection-object selection->ranges
                  range->from insert_string))
(require-builtin helix/core/text as text.)

(provide compat-document compat-document-path compat-document-language
         compat-selection-fragments compat-selection-start-line
         compat-editor-tab-width compat-language-tab-width compat-open-scratch!)

;; Returns the focused document ID.
(define (compat-document)
  (editor->doc-id (editor-focus)))

;; Returns the document's file path, or false for a scratch buffer.
(define (compat-document-path doc)
  (editor-document->path doc))

;; Returns the document's Helix language identifier, or false.
(define (compat-document-language doc)
  (editor-document->language doc))

;; Returns the text of every selection, in order, from the yank-style `.` register.
(define (compat-selection-fragments)
  (register->value #\.))

;; Returns the 1-based line where the primary selection begins, or 1 for multiple selections.
(define (compat-selection-start-line doc)
  (let ([ranges (selection->ranges (current-selection-object))])
    (if (= (length ranges) 1)
        (+ 1 (text.rope-char->line (editor->text doc) (range->from (car ranges))))
        1)))

;; Returns the editor-wide tab width, or false when unset.
(define (compat-editor-tab-width)
  (with-handler
   (lambda (_) #f)
   (let ([width (get-config-option-value "tab-width")])
     (and (integer? width) (> width 0) width))))

;; Returns the language's configured tab width, or false when unavailable.
(define (compat-language-tab-width language)
  (with-handler
   (lambda (_) #f)
   (let ([width (hash-ref (hash-ref (get-language-config language) 'indent) 'tab-width)])
     (and (integer? width) (> width 0) width))))

;; Opens a new scratch buffer containing the text.
(define (compat-open-scratch! text)
  (new)
  (insert_string text))
