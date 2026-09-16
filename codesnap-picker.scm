;; Single-list picker adapted from ui-utils.hx, Copyright (C) 2026 Tom Waddington.
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
;; THE SOFTWARE.

(require-builtin helix/components)
(require "helix/misc.scm")
(require "ui-utils.hx/picker-model.scm")
(require "ui-utils.hx/line-edit.scm")
(require "ui-utils.hx/keys.scm")
(require (only-in "ui-utils.hx/geometry.scm" overlay-area))
(require (only-in "ui-utils.hx/scroll.scm" clamp-top))
(require (only-in "ui-utils.hx/strings.scm" truncate-string/dots))
(require (only-in "ui-utils.hx/draw.scm" bordered-block draw-filter-bar))
(require (only-in "ui-utils.hx/component.scm" component-handlers))

(provide show-picker! picker-current-item)

(struct menu-state (spec filtered cursor top text caret) #:mutable #:transparent)

;; Returns the selected item, or false when filtering leaves no matches.
(define (picker-current-item state)
  (let ([items (menu-state-filtered state)])
    (and (pair? items) (list-ref items (menu-state-cursor state)))))

;; Draws the list with a stable viewport, scrolling only to reveal an offscreen selection.
(define (render-menu state-box rect buffer)
  (let* ([state (unbox state-box)]
         [spec (menu-state-spec state)]
         [overlay (overlay-area rect ((picker-spec-overlay-scale spec)))]
         [x (+ (area-x overlay) 2)]
         [y (+ (area-y overlay) 1)]
         [width (max 0 (- (area-width overlay) 4))]
         [bottom (+ (area-y overlay) (area-height overlay) -1)]
         [items (menu-state-filtered state)]
         [cursor (menu-state-cursor state)])
    (buffer/clear buffer overlay)
    (block/render buffer overlay (bordered-block 'quiet))
    (for-each
     (lambda (entry)
       (when (< y bottom)
         (frame-set-string! buffer x y (truncate-string/dots (car entry) width) (cdr entry)))
       (set! y (+ y 1)))
     (list (cons (picker-spec-title spec) (style))
           (cons (picker-spec-instructions spec) (style-fg (style) Color/Gray))))
    (set! y (+ y 1))
    (when (picker-spec-filter? spec)
      (when (< y bottom)
        (draw-filter-bar buffer x y width (menu-state-text state) (length items)
                         (max (length items) (length (picker-spec-items spec)))
                         (menu-state-caret state)))
      (when (< (+ y 1) bottom)
        (frame-set-string! buffer x (+ y 1) (make-string width #\─) (style)))
      (set! y (+ y 2)))
    (let* ([height (max 0 (- bottom y))]
           [top (clamp-top (menu-state-top state) cursor (max 1 height) (length items))])
      (set-menu-state-top! state top)
      (if (null? items)
          (when (> height 0)
            (frame-set-string! buffer x y
                               (truncate-string/dots (picker-spec-no-match-message spec) width)
                               (style)))
          (let loop ([index top])
            (when (< index (min (length items) (+ top height)))
              (frame-set-string!
               buffer x (+ y (- index top))
               (truncate-string/dots
                (string-append (if (= index cursor) "> " "  ")
                               ((picker-spec-item-label spec) (list-ref items index))) width)
               (if (= index cursor) (theme-scope *helix.cx* "ui.menu.selected") (style)))
              (loop (+ index 1))))))))

;; Applies a text edit and returns the highlight and viewport to the first match.
(define (edit-filter! state edit)
  (let* ([spec (menu-state-spec state)]
         [filter-fn (or (picker-spec-filter-fn spec)
                        (make-item-filter fuzzy-match (picker-spec-item-label spec)))])
    (set-menu-state-text! state (car edit))
    (set-menu-state-caret! state (cdr edit))
    (set-menu-state-filtered! state (filter-fn (picker-spec-items spec) (car edit)))
    (set-menu-state-cursor! state 0)
    (set-menu-state-top! state 0)))

;; Preserves the searchable picker's caret movement and editing shortcuts.
(define (handle-filter-edit! state event)
  (let ([text (menu-state-text state)] [caret (menu-state-caret state)])
    (cond
      [(or (alt-char? event #\b) (and (key-event-left? event) (ctrl-modifier? event)))
       (set-menu-state-caret! state (line-move-word text caret 'back))]
      [(or (alt-char? event #\f) (and (key-event-right? event) (ctrl-modifier? event)))
       (set-menu-state-caret! state (line-move-word text caret 'forward))]
      [(or (ctrl-char? event #\w)
           (and (key-event-backspace? event) (or (alt-modifier? event) (ctrl-modifier? event))))
       (edit-filter! state (line-delete-word-back text caret))]
      [(or (alt-char? event #\d) (and (key-event-delete? event) (alt-modifier? event)))
       (edit-filter! state (line-delete-word-forward text caret))]
      [(or (key-event-left? event) (ctrl-char? event #\b))
       (set-menu-state-caret! state (line-move-char text caret -1))]
      [(or (key-event-right? event) (ctrl-char? event #\f))
       (set-menu-state-caret! state (line-move-char text caret 1))]
      [(ctrl-char? event #\a) (set-menu-state-caret! state 0)]
      [(ctrl-char? event #\e) (set-menu-state-caret! state (string-length text))]
      [(ctrl-char? event #\k) (edit-filter! state (line-kill-to-end text caret))]
      [(key-event-backspace? event) (edit-filter! state (line-delete-back text caret))]
      [(key-event-delete? event) (edit-filter! state (line-delete-forward text caret))]
      [else
       (let ([ch (key-event-char event)])
         (when (and ch (or (no-modifier? event) (shift-modifier? event)))
           (edit-filter! state (line-insert text caret ch))))])))

;; Handles custom actions first, followed by wrapping navigation and optional text filtering.
(define (handle-menu state-box event)
  (let* ([state (unbox state-box)]
         [spec (menu-state-spec state)]
         [search? (picker-spec-filter? spec)]
         [count (length (menu-state-filtered state))]
         [cursor (menu-state-cursor state)]
         [custom ((picker-spec-keys spec) state-box event)])
    (or custom
        (begin
          (cond
            [(or (key-event-escape? event) (and search? (ctrl-char? event #\c)))
             (pop-last-component-by-name! (picker-spec-name spec))]
            [(key-event-enter? event)
             (let ([item (picker-current-item state)])
               (when item
                 (pop-last-component-by-name! (picker-spec-name spec))
                 ((picker-spec-on-accept spec) item)))]
            [(or (key-event-up? event)
                 (and (not search?) (char-is? event #\k))
                 (and search? (or (ctrl-char? event #\p)
                                  (and (key-event-tab? event) (shift-modifier? event)))))
             (set-menu-state-cursor! state (picker-move cursor -1 count))]
            [(or (key-event-down? event)
                 (and (not search?) (char-is? event #\j))
                 (and search? (or (ctrl-char? event #\n)
                                  (and (key-event-tab? event) (no-modifier? event)))))
             (set-menu-state-cursor! state (picker-move cursor 1 count))]
            [(and search? (or (ctrl-char? event #\u) (ctrl-char? event #\d)))
             (set-menu-state-cursor!
              state (picker-page cursor (if (ctrl-char? event #\u) -1 1) count
                                 (picker-spec-page-size spec)))]
            [(key-event-home? event) (set-menu-state-cursor! state 0)]
            [(key-event-end? event)
             (set-menu-state-cursor! state (picker-boundary 'last count))]
            [search? (handle-filter-edit! state event)])
          event-result/consume))))

;; Opens CodeSnap's single-list picker with the existing ui-utils specification and styling.
(define (show-picker! spec)
  (let ([state-box (box (menu-state spec (picker-spec-items spec) 0 0 "" 0))])
    (push-component!
     (new-component! (picker-spec-name spec) state-box render-menu
                     (component-handlers handle-menu)))
    state-box))
