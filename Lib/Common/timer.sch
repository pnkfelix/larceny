; Copyright 1998 Lars T Hansen.
;
; $Id$
;
; Larceny library -- timer interrupts (and other cruft, right now).

($$trace "timer")

; This is well-behaved but somewhat expensive w.r.t. allocation.

(define (call-without-interrupts thunk)
  (let ((old #f))
    (dynamic-wind 
     (lambda () (set! old (disable-interrupts)))
     thunk
     (lambda () (if old (enable-interrupts old))))))

; The timer interrupt handler is called with timer interrupts off.

(define timer-interrupt-handler
  (system-parameter "timer-interrupt-handler"
                    (lambda ()
                      ($$debugmsg "Unhandled timer interrupt."))
                    procedure?))

; The keyboard interrupt handler is called with timer interrupts in
; the state they were when the interrupt was delivered.

(define keyboard-interrupt-handler
  (system-parameter "keyboard-interrupt-handler"
                    (lambda ()
                      ($$debugmsg "Unhandled keyboad interrupt.")
                      (exit))
                    procedure?))

; A timeslice of 50,000 is a compromise between overhead and response time.
; On atlas.ccs.neu.edu (a SPARC 10 (?)), 50,000 is really too much for
; longer sections of straight-line code yet too little for very branch-
; or call-intensive programs.  See Util/timeslice.sch for details.
;
; The _right_ solution is probably the following:
;  * the scheduler uses priorities
;  * higher-priority jobs get longer time slices
;  * interactive input tasks (mouse, keyboard) get to interrupt
;    whatever task is running.
;  * run-benchmark gets to ask for a very long time slice.
;
; Since the scheduler will run at a different level from this low-level
; RTS code, the 50,000 is an OK compromise for this level.
;
; (Alternatively, the timer has some arbitrary value but that value is
; chunked into pieces of 10,000, say, maintained by millicode.  Each 10K
; decrements a quick trip is made into millicode to check for interrupts
; and get the next timer chunk.)

(define *max-ticks* 536870911)            ; (- (expt 2 29) 1)

(define *standard-timeslice* 50000)       ; Empirical.

(define standard-timeslice
  (system-parameter "standard-timeslice"
		    *standard-timeslice* 
		    (lambda (x)
		      (and (fixnum? x) (> x 0)))))

; eof
