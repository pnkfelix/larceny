;; :Basic:make-trap.sch is Mac specific
;; :Basic:mac-type is Mac specific 
;; :Basic:general is FFI stuff that we can do ourselves
;; :Basic:blt is also very lowlevel FFI stuff 
;; :Basic:event event handling protocols; want to do this ourselves
;; :Basic:tasks interrupt & event based multi-tasker
;; :Standard:data&traps seems mostly mac specific, but it might be
;;    good to know what state it defines...
;;    - *also*, at least some of the functions in here are directly
;;      used by user agents (at least in WillsEditor;
;;      e.g. invertrect), and therefore it might represent (a superset
;;      of?) basic graphics functionality that all need to support.
;;    - *also*, watch out for case [in]sensitivity issues; code may
;;      reference TEInsert which is defined as teinsert.
;; :Standard:events standard event handlers -- worth looking over.
;; :Standard:objects routines used for Toolsmith's OOP; 
;;    I should take inspiration; but the code itself is useless
;; :Standard:menus routines to manipulate menus; 
;;    read over this carefully
;; :Standard:windows routines to manipulate windows and their agents
;; :Standard:editors (suprising little code!)
;; :Standard:scrollers maintains scrollbars and text in editor window

;; Toolsmith documentation describes the following operations and procedures:
;; [[ operations are denoted by two parens, procedures by one ]]
;; ((object 'operations))
;; (make-menu title)
;; ((menu 'close))
;; ((menu 'append) item action)            ; item : String, action : () -> ()
;; ((menu 'append) item action enableproc) ; enableproc () -> Bool
;;   Special chars in item: #\- #\/ #\< #\! #\^
;; ((menu 'addresources) rtype raction)
;; ((menu 'update))
;;   enables and disables all its menuitems according to the enableproc's
;; ((menu 'selectitem) itemnumber)
;; (pushmenubar)
;; (popmenubar)
;; ((menu 'id))
;; ((menu 'menuhandle))
;; (make-window) (make-window 'make-agent make-window-agent 'text 'bounds (left top right bottom) 'title string 'nogoaway 'nosizebox)
;;    (make-window 'text) is equivalent to (make-window 'make-agent make-editor)
;; ((window 'close))
;; ((window 'closed?))
;; ((window 'agent))
;; ((window 'windowptr))
;; ((window 'width))
;; ((window 'height))
;; ((window 'update))
;; ((window 'activate))
;; ((window 'deactivate))
;; ((window 'keydown) char)
;; ((window 'autokey) char)
;; ((window 'mousedown) part where event)
;; ((window 'select))
;; (lookup-window-object windowptr)
;; ((agent 'close))
;; ((agent 'update) window-object)
;; ((agent 'activate) window-object)
;; ((agent 'deactivate) window-object)
;; ((agent 'mousedown) window-object where modifiers)
;; ((agent 'keydown) char)
;; ((agent 'autokey) char)
;; ((agent 'grow) rectangle)
;; (make-editor windowptr width height)
;; ((editor 'scroller))
;; ((editor 'texthandle))
;; ((editor 'cut))
;; ((editor 'copy))
;; ((editor 'paste))
;; ((editor 'insert) string)
;; ((editor 'textsize))
;; ((editor 'textstring))
;; ((editor 'set-textstring) string)
;; ((editor 'selectionstring))
;; ((editor 'selstart))
;; ((editor 'selend))
;; ((editor 'set-selection) start end)
;;   to set the insertion point, use equiv start and end.
;;   (really?  why overload this way?)
;; ((editor 'line) n)
;; ((editor 'column) n)
;; ((scroller 'close))
;; ((scroller 'vertical))
;; ((scroller 'horizontal))
;; ((scroller 'update) window)
;; ((scroller 'activate))
;; ((scroller 'deactivate))
;; ((scroller 'line) window editor control direction)
;; ((scroller 'page) window editor control direction)
;; ((scroller 'show) editor n)
;;   scrolls text vertically so that a particular position in text is
;;   visible
;; ((scroller 'set) editor)
;;   sets scroll bar indicators so that they indicate correct position
;;   of currently displayed text

(define-syntax msg-handler
  (syntax-rules ()
    ((msg-handler ((OP-NAME . ARGS) BODY ...) ...)
     (lambda (op)
       ;; (display `(handling msg ,op)) (newline)
       (case op
         ((OP-NAME) (lambda ARGS BODY ...))
         ...
         ((operations) (lambda () '(OP-NAME ... operations)))
         (else (error 'msg-handler 
                      ": unhandled object message " op)))))))

;; An agent can choose whether or not it handles the paint event (by
;; including paint in its operations list).
;; If it does handle paint, then the window will dynamically dispatch
;; to the agent every time it needs to be painted.
;; If it does not handle paint, then the window will keep image state
;; to be rendered and the agent will imperatively modify that.

;; Note that all agent operations are optional, except (of course) the
;; 'operations operation.
;; 
;; AGENT: (make-noisy-agent) ; client def's ctors, perhaps via msg-handler form
;;  (on-close wnd) 
;;  (on-keypress wnd char) (on-keydown wnd sym mods) (on-keyup wnd sym mods)
;;  (on-mousedown wnd x y) (on-mouseup wnd x y) (on-mousemove wnd x y) 
;;  (on-mouseclick wnd x y) (on-mousedoubleclick wnd x y)
;;  (on-mouseenter wnd) (on-mouseleave wnd)
;;  (on-paint gfx x y w h) (dispose)
;;  (vertical-scrollbar) (horizontal-scrollbar) ; scrollbar exposure+properties
;;  (on-vscroll wnd new-val event-type)
;;  (on-hscroll wnd new-val event-type)
;;  (on-resize wnd)

;; Agents are client written entities; the objects below are provided
;; by the runtime system.

;; FNT: (make-fnt name em-size) (available-fontnames) (monospace-fontname) (sans-serif-fontname) (serif-fontname)
;;  (clone ['italic] ['bold] ['underline] ['em-size r])
;;  (name) (em-size) (italic?) (bold?) (underline?) (fntptr)
;; GFX: ;; no public constructors (received via agent's on-paint op)
;;  (measure-text txt-string font-obj) 
;;  (draw-text txt-string font-obj x y col) 
;;  (draw-line col x1 y1 x2 y2) (draw-image img-obj x y) 
;;  (draw-rect col x1 y1 x2 y2) (gfxptr)
;; COL: (make-col alpha red green blue) (name->col name) (available-colornames)
;;  (name) (alpha) (red) (green) (blue) (colptr)
;; WND: (make-wnd ['make-agent agent-ctor] 
;;                ['bounds (x y w h)] 
;;                ['double-buffered] 
;;                ['title string])
;;  (show) (hide) (show-dialog) (title) (close) (dispose) (update)
;;  (width) (height)
;;  (measure-text txt-string font-obj) 
;;  (push-menus mnu ...) (pop-menus)
;; MNU: (make-mnu name)
;;  (append item action) ;; item is string or mnu; action is nullary procedure
;;  (append item action enabled?) ;; enabled? is nullary predicate
;;  (items) (mnuptr) (name)

(define (make-noisy-agent width height)
  (define (displayln x) (display x) (newline))
  (msg-handler
   ((on-close wnd)                (displayln `(on-close)))
   ((on-keydown wnd int mods)     (displayln `(on-keydown ,int ,mods)))
   ((on-keyup wnd int mods)       (displayln `(on-keyup ,int ,mods)))
   ((on-keypress wnd char)        (displayln `(on-keypress ,char)))
   ((on-mousedown wnd x y)        (displayln `(on-mousedown ,x ,y)))
   ((on-mouseup   wnd x y)        (displayln `(on-mouseup ,x ,y)))
   ((on-mousemove wnd x y)        (displayln `(on-mousemove ,x ,y)))
   ((on-mouseclick wnd x y)       (displayln `(on-mouseclick ,x ,y)))
   ((on-mousedoubleclick wnd x y) (displayln `(on-mousedoubleclick ,x ,y)))
   ((on-mouseenter wnd)           (displayln `(on-mouseenter)))
   ((on-mouseleave wnd)           (displayln `(on-mouseleave)))
   ((on-paint wnd g x y w h)      (displayln `(on-paint ,g ,x ,y ,w ,h)))
   ((on-dispose wnd)              (displayln `(on-dispose)))
   ))

(define (make-rectangle-drawing-agent width height)
  (let* ((last-x #f)
         (last-y #f)
         (temp-rect #f)
         (save! (lambda (x y) (set! last-x x) (set! last-y y)))
         (temp! (lambda (x y) 
                  (cond ((and last-x last-y)
                         (set! temp-rect (list last-x last-y x y))))))
         (forget! (lambda () 
                    (set! last-x #f) (set! last-y #f) (set! temp-rect #f)))
         (rect-list '()))
    (msg-handler 
     ((on-mousedown wnd x y) (save! x y))
     ((on-mousemove wnd x y) 
      (cond ((and last-x last-y)
             (temp! x y) ((wnd 'update)))))
     ((on-mouseup wnd x y) 
      (cond ((and last-x last-y)
             (set! rect-list 
                   (cons (list last-x last-y x y) rect-list))
             (forget!)
             ((wnd 'update))
             )))
     ((on-mouseleave wnd) (forget!) ((wnd 'update)))
     ((on-paint wnd g x y w h)
      (for-each
       (lambda (rect) (apply (g 'draw-rect) (name->col "Black") rect))
       rect-list)
      ;;(begin (display `(on-paint temp-rect: ,temp-rect)) (newline))
      (cond (temp-rect (apply (g 'draw-rect) (name->col "Red") temp-rect)))
      ))))

(define (make-code-editor-agent width height)
  ;; XXX don't spend too much time writing code oriented around this
  ;; representation of the text contents; we would be better off
  ;; adopting something like Will's buffer abstraction (see text.sch
  ;; in his editor code)
  (let* ((rlines-before-view '("line B" "line A"))
         (lines '("line C" "line D" "" "line Y" "line Z"))
         (cursor-line 2)
         (cursor-pos  0)
         (em-size 10)
         (fnt (make-fnt (monospace-fontname) em-size))
         (col (name->col (string->symbol "Black"))))

    (define (check-invariants)
      (assert (number? cursor-line))
      ;; cursor-line is less than 0 when cursor's line is out of view
      (assert (< cursor-line (length lines)))
      (assert (number? cursor-pos))
      (assert (>= cursor-pos 0))
      (assert (<= cursor-pos (string-length (list-ref lines cursor-line)))))
    
    (define (all-text-lines)
      (append (reverse rlines-before-view) lines))

    (define (all-text-string)
      (apply string-append
             (map (lambda (x) (string-append x "\n")) (all-text-lines))))

    (define (take lst n)
      (cond ((zero? n) '())
            ((null? lst) '())
            (else (cons (car lst) 
                        (take (cdr lst) (- n 1))))))
    (define (drop lst n)
      (cond ((zero? n) lst)
            ((null? lst) '())
            (else (drop (cdr lst) (- n 1)))))

    (define (max-visible-lines)
      ;; XXX this is broken; the em-size is not directly related to
      ;; the height of a line.  (This manner of exposing the em-size
      ;; might be a mistake anyway for this application; might be
      ;; better to have a available-emsizes function.)
      (quotient height em-size))

    (define (count-visible-lines)
      (min (length lines)
           (max-visible-lines)))

    (define (count-lines)
      (+ (length rlines-before-view)
         (length lines)))

    (msg-handler
     ((text) 
      (all-text-string))
     ((on-keydown wnd sym mods)
      '(begin (write `(keydown ,((wnd 'title)) ,sym ,mods)) (newline))
      )
     ((on-keyup   wnd sym mods)
      (define num-tries 0)
      '(begin (write `(keyup ,((wnd 'title)) ,sym ,mods)) (newline))
      (let retry ()
        (set! num-tries (+ num-tries 1))
        (assert (< num-tries 3))
        (let ((l_k (list-ref lines cursor-line)))
          (case sym
            ((back delete) 
             (cond 
              ((> cursor-pos 0)
               (list-set! lines cursor-line
                          (string-append (substring l_k 0 (- cursor-pos 1))
                                         (substring l_k cursor-pos
                                                    (string-length l_k))))
               (set! cursor-pos (- cursor-pos 1)))
              ((> cursor-line 0)
               (let* ((l_0..k-2 (take lines (- cursor-line 1))) 
                      (l_k-1    (list-ref lines (- cursor-line 1))) 
                      (l_k+1..n (drop lines (+ cursor-line 1)))
                      (l_new (string-append l_k-1 l_k)))
                 (set! lines (append l_0..k-2
                                     (list l_new)
                                     l_k+1..n))
                 (set! cursor-line (- cursor-line 1))
                 (set! cursor-pos (string-length l_k-1))
                 ))
              ((null? rlines-before-view)
               'do-nothing)
              (else
               ((wnd 'scroll) 'vertical -1)
               (assert (not (null? lines)))
               (set! cursor-line (+ cursor-line 1))
               (retry))))
            ((enter) 
             (cond
              ((= cursor-line (count-visible-lines))
               ((wnd 'scroll) 'vertical 1)
               (retry))
              (else
               (let ((l_0..k-1 (take lines cursor-line))
                     (l_k+1..n (drop lines (+ cursor-line 1))))
                 (set! lines 
                       (append l_0..k-1
                               (list (substring l_k 0 cursor-pos)
                                     (substring l_k cursor-pos (string-length l_k)))
                               l_k+1..n))
                 (set! cursor-line (+ cursor-line 1))
                 (set! cursor-pos 0)))))
            ((up)
             (cond ((> cursor-line 0)
                    (set! cursor-line (- cursor-line 1))
                    (set! cursor-pos
                          (min (string-length (list-ref lines cursor-line))
                               cursor-pos)))
                   ((null? rlines-before-view)         
                    'do-nothing)
                   (else
                    ((wnd 'scroll) 'vertical -1)
                    (retry))))
            ((down)
             (cond ((>= (+ cursor-line 1) (length lines)) 'do-nothing)
                   ((< cursor-line (count-visible-lines))
                    (set! cursor-line (+ cursor-line 1))
                    (set! cursor-pos
                          (min (string-length (list-ref lines cursor-line))
                               cursor-pos)))
                   ((= cursor-line (count-visible-lines))
                    ((wnd 'scroll) 'vertical 1)
                    (retry))))
            ((left)
             (cond ((> cursor-pos 0)
                    (set! cursor-pos (- cursor-pos 1)))
                   ((> cursor-line 0)
                    (set! cursor-line (- cursor-line 1))
                    (set! cursor-pos (string-length 
                                      (list-ref lines cursor-line))))
                   (else
                    ((wnd 'scroll) 'vertical -1)
                    (retry))))
            ((right)
             (cond ((< cursor-pos (string-length l_k))
                    (set! cursor-pos (+ cursor-pos 1)))
                   ((< cursor-line (count-visible-lines))
                    (set! cursor-line (+ cursor-line 1))
                    (set! cursor-pos 0))
                   ((= cursor-line (count-visible-lines))
                    ((wnd 'scroll) 'vertical 1)
                    (retry))
                   ))
            )))
      ((wnd 'update)))
     ((on-resize wnd)
      (set! width  ((wnd 'width)))
      (set! height ((wnd 'height))))
     ((on-keypress wnd char) 
      (case char
        ((#\backspace #\return #\esc #\tab) 'do-nothing)
        (else
         (let ((l_k (list-ref lines cursor-line)))
           (let* ((prefix (substring l_k 0 cursor-pos))
                  (suffix (substring l_k cursor-pos (string-length l_k)))
                  (l_k* (string-append prefix (string char) suffix)))
             (list-set! lines cursor-line l_k*)))
         (set! cursor-pos (+ cursor-pos 1))))
      ((wnd 'update)))
     ((horizontal-scrollbar) #f)
     ((vertical-scrollbar)
      ;; These do not have to be in pixels to be meaningful; we as the
      ;; client select our own unit of measurement, and are then
      ;; responsible for using it consistently.  In this case, we are
      ;; using a line as the measurement grain.  (But when image
      ;; support is added, the line might not remain apporpriate.)
      `((min ,0) 
        (max ,(count-lines))
        (value ,(length rlines-before-view))
        (dsmall ,1)
        (dlarge ,(quotient (max-visible-lines) 2))))
     ((on-hscroll wnd new-int event-type)
      (begin (write `(on-hscroll wnd ,new-int ,event-type))
             (newline)))
     ((on-vscroll wnd new-int event-type)
      (let* ((all-lines (all-text-lines))
             (len-rlines (length rlines-before-view))
             (abs-cursor-line (+ len-rlines cursor-line)))
        (set! lines (drop all-lines new-int))
        (set! rlines-before-view (reverse (take all-lines new-int)))
        (set! cursor-line (- abs-cursor-line (length rlines-before-view))))
      ((wnd 'update)))
     ((on-paint wnd g rx ry rw rh)
      '(begin (write `(on-paint wnd g ,rx ,ry ,rw ,rh))
              (newline))
      (check-invariants)
      (let ((measure-height
             (lambda (s) 
               (call-with-values (lambda () ((g 'measure-text) s fnt))
                 (lambda (w h) h))))
            (cursor-height #f))
        (let loop ((h 0) (lines lines) (line-num 0))
          (cond ((= line-num cursor-line)
                 (set! cursor-height h)))
          (cond ((not (null? lines))
                 ((g 'draw-text) (car lines) fnt 0 h col)
                 (loop (+ h (measure-height (car lines))) 
                       (cdr lines) 
                       (+ line-num 1)))))
        (cond 
         ((>= cursor-line 0)
          (let ((l_k (list-ref lines cursor-line)))
            (call-with-values (lambda () 
                                ((g 'measure-text) 
                                 (substring l_k 0 cursor-pos)
                                 fnt))
              (lambda (w h)
                ((g 'draw-line) col w cursor-height w (+ cursor-height h)))))
          ))))
     )))

    