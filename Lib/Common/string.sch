; Copyright Lightship Software, Incorporated.
;
; $Id$
;
; Larceny library --  characters, strings, and bytevectors.
;
; Should there be a bytevector-like-subfill! primop to use here?

($$trace "string")

; The character set, collating order, and so on can be redefined by
; changing this table.
;
; The table has a byte for each character, with the following value
; assignments:
; - Uppercase alphabetic: value 1
; - Lowercase alphabetic: value 2
; - Numeric:              value 4
; - Whitespace:           value 8

(define *char-table* '#())


; ISO Latin 1 character set.

(define (make-iso-latin-1-table)

  (define tbl (make-bytevector 256))

  (bytevector-fill! tbl 0)

  (do ((i (char->integer #\A) (+ i 1)))
      ((> i (char->integer #\Z)))
    (bytevector-set! tbl i 1))

  (do ((i (char->integer #\a) (+ i 1)))
      ((> i (char->integer #\z)))
    (bytevector-set! tbl i 2))

  (do ((i (char->integer #\�) (+ i 1)))
      ((> i (char->integer #\�)))
    (bytevector-set! tbl i 1))

  (do ((i (char->integer #\�) (+ i 1)))
      ((> i (char->integer #\�)))
    (bytevector-set! tbl i 1))

  (do ((i (char->integer #\�) (+ i 1)))
      ((> i (char->integer #\�)))
    (bytevector-set! tbl i 2))

  (do ((i (char->integer #\�) (+ i 1)))
      ((> i (char->integer #\�)))
    (bytevector-set! tbl i 2))

  (do ((i (char->integer #\0) (+ i 1)))
      ((> i (char->integer #\9)))
    (bytevector-set! tbl i 4))

  (let ((f (lambda (x)
	     (let ((i (char->integer x)))
	       (bytevector-set! tbl i 8)))))
    (f #\space)				;
    (f #\newline)			; Unix: LF  (code 10)
    (f (integer->char 13))		; CR
    (f (integer->char 9))		; TAB
    (f (integer->char 12))		; Form feed
    )

  tbl)

(set! *char-table* (make-iso-latin-1-table))


; Upper- and lower-case predicates and conversions
; for both characters and strings.

(define char-ci=?
  (lambda (x y)
    (char=? (char-downcase x) (char-downcase y))))

(define char-ci<?
  (lambda (x y)
    (char<? (char-downcase x) (char-downcase y))))

(define char-ci>?
  (lambda (x y)
    (char>? (char-downcase x) (char-downcase y))))

(define char-ci<=?
  (lambda (x y)
    (char<=? (char-downcase x) (char-downcase y))))

(define char-ci>=?
  (lambda (x y)
    (char>=? (char-downcase x) (char-downcase y))))

(define char-alphabetic?
  (lambda (x)
    (not (eq? 0 (logand 3 (bytevector-ref *char-table* (char->integer x)))))))

(define char-upper-case?
  (lambda (x)
    (eq? 1 (bytevector-ref *char-table* (char->integer x)))))

(define char-lower-case?
  (lambda (x)
    (eq? 2 (bytevector-ref *char-table* (char->integer x)))))

(define char-numeric?
  (lambda (x)
    (eq? 4 (bytevector-ref *char-table* (char->integer x)))))

(define char-whitespace?
  (lambda (x)
    (eq? 8 (bytevector-ref *char-table* (char->integer x)))))

(define char-upcase
  (lambda (x)
    (if (char-lower-case? x)
        (integer->char (- (char->integer x) 32))
	x)))

(define char-downcase
  (lambda (x)
    (if (char-upper-case? x)
        (integer->char (+ (char->integer x) 32))
        x)))

(define (string-ci=? s1 s2)

  (define (loop i)
    (cond ((< i 0))
	  ((char-ci=? (string-ref s1 i) (string-ref s2 i))
	   (loop (- i 1)))
	  (else #f)))

  (if (= (string-length s1) (string-length s2))
      (loop (- (string-length s1) 1))
      #f))

(define (string-ci<? s1 s2)

  (define (loop i limit)
    (cond ((= i limit)
	   (< (string-length s1) (string-length s2)))
	  ((char-ci<? (string-ref s1 i) (string-ref s2 i))
	   #t)
	  ((char-ci>? (string-ref s1 i) (string-ref s2 i))
	   #f)
	  (else
	   (loop (+ i 1) limit))))

  (loop 0 (min (string-length s1) (string-length s2))))

(define string-ci>?
  (lambda (x y)
    (string-ci<? y x)))

(define string-ci<=?
  (lambda (x y)
    (not (string-ci>? x y))))

(define string-ci>=?
  (lambda (x y)
    (not (string-ci<? x y))))

(define string-copy
  (lambda (x)
    (string-append x "")))

(define string
  (lambda chars
    (list->string chars)))

(define (string-append . args)

  (define (lengths args n)
    (if (null? args)
	n
	(lengths (cdr args) (+ n (string-length (car args))))))

  (let* ((n (lengths args 0))
	 (s (make-bytevector n)))
    (typetag-set! s sys$tag.string-typetag)
    (do ((l args (cdr l))
	 (i 0    (+ i (string-length (car l)))))
	((null? l) s)
      (bytevector-like-copy-into! (car l) 0 (string-length (car l))
				  s i))))

(define (substring s m n)
  (let ((y (make-bytevector (- n m))))
    (typetag-set! y sys$tag.string-typetag)
    (bytevector-like-copy-into! s m n y 0)
    y))


(define string-fill!
  (lambda (s c)
    (if (and (string? s) (char? c))
	(bytevector-fill! s (char->integer c))
	(begin (error "string-fill!: bad operands: " s " " c)
	       #t))))

(define substring-fill!
  (lambda (s start end c)
    (do ((i start (+ i 1)))
        ((>= i end) s)
        (string-set! s i c))))

; Make-string is now a primitive; see primops.sch.

;(define (make-string n . rest)
;  (let ((init (char->integer (if (null? rest) #\space (car rest))))
;	(s    (make-bytevector n)))
;    (bytevector-fill! s init)
;    (typetag-set! s sys$tag.string-typetag)
;    s))

(define list->string
  (letrec ((loop
             (lambda (s i l)
               (if (pair? l)
                   (begin (string-set! s i (car l))
                          (loop s (+ i 1) (cdr l)))
                   s))))
    (lambda (l)
      (loop (make-string (length l)) 0 l))))

(define string->list
  (letrec ((loop
             (lambda (bv i l)
               (if (< i 0)
                   l
                   (loop bv (- i 1) (cons (string-ref bv i) l))))))
    (lambda (bv)
      (loop bv (- (string-length bv) 1) '()))))

;;; String hash based on
;;;
;;; @inproceedings{ ramakrishna97performance,
;;;     author = "M. V. Ramakrishna and Justin Zobel",
;;;     title = "Performance in Practice of String Hashing Functions",
;;;     booktitle = "Database Systems for Advanced Applications",
;;;     pages = "215-224",
;;;     year = "1997",
;;;     url = "citeseer.ist.psu.edu/article/ramakrishna97performance.html" }

;;; Note, the stepping function is this:
;;;   hash_n+1 <- (logxor hash_n (+ (shift-left hash_n 5)
;;;                                 (shift-right hash_n 2)
;;;                                 (string-ref string index)))
;;;
;;; But the speed limiting factor (under dotnet) is not memory access,
;;; but number of primitive operations per step.  Thus we precompute
;;;  (+ (shift-left hash 5) (shift-right hash 2)) for the possible
;;; hash codes and just fetch them from a table.
;;;
;;; Additionally, we want the hash code to be in the range [0 2^16).
;;; To avoid a masking step, we limit the table entries to
;;; [0 (2^16 - 256)) so that adding in a byte from the string always
;;; leaves us with at most 16 bits.

;;; The end result is a > 25% speedup in hashing, and a better
;;; distribution of hash values.  (Hashing a set of words from a
;;; dictionary showed fewer empty buckets, more buckets with exactly
;;; one entry and fewer buckets with three or more entries.)

; Returns a value in the range 0 .. 2^16-1 (a fixnum in Larceny).

(define string-hash
  (let ((shift-table (make-vector 65536 0)))

    (define (string-hash-loop string limit i code)
      (if (= i limit)
          code
          (string-hash-loop
           string limit (+ i 1)
           (logxor code
                   (+ (vector-ref shift-table code)
                      (bytevector-like-ref string i))))))

    (define (string-hash-internal string)
      (let ((n (string-length string)))
        (string-hash-loop string n 0 (logxor n #x5aa5))))

    (do ((sti 0 (+ sti 1)))
        ((>= sti 65536))
      (vector-set! shift-table sti
                   (remainder (+ (lsh sti 5) (rsha sti 2))
                              (- 65536 256))))

    string-hash-internal))

;(define (string-hash string)
;  (define (loop s i h)
;    (if (< i 0)
;	h
;	(loop s
;	      (- i 1)
;	      (logand 65535 (+ (char->integer (string-ref s i)) h h h)))))
;  (let ((n (string-length string)))
;    (loop string (- n 1) n)))

(define (%string-downcase! src dest)
  (do ((i (- (string-length src) 1) (- i 1)))
      ((< i 0) dest)
    (let ((x (bytevector-like-ref src i)))
      (bytevector-like-set! dest i
                            (if (= 1 (bytevector-ref *char-table* x))
                                (+ x 32)
                                x)))))

(define (string-downcase! string)
  (%string-downcase! string string))

(define (string-downcase string)
  (%string-downcase! string (make-string (string-length string))))

(define (%string-upcase! src dest)
  (do ((i (- (string-length src) 1) (- i 1)))
      ((< i 0) dest)
    (let ((x (bytevector-like-ref src i)))
      (bytevector-like-set! dest i
                            (if (= 2 (bytevector-ref *char-table* x))
                                (- x 32)
                                x)))))

(define (string-upcase! string)
  (%string-upcase! string string))

(define (string-upcase string)
  (%string-upcase! string (make-string (string-length string))))

(define list->bytevector
  (letrec ((loop
             (lambda (bv i l)
               (if (pair? l)
                   (begin (bytevector-set! bv i (car l))
                          (loop bv (+ i 1) (cdr l)))
                   bv))))
    (lambda (l)
      (loop (make-bytevector (length l)) 0 l))))

(define bytevector->list
  (letrec ((loop
             (lambda (bv i l)
               (if (< i 0)
                   l
                   (loop bv (- i 1) (cons (bytevector-ref bv i) l))))))
    (lambda (bv)
      (loop bv (- (bytevector-length bv) 1) '()))))

(define (string=? a b)
  (= (string-compare 'string=? a b) 0))

(define string-equal? string=?)       ; for backward compatibility

(define (string<? a b)
  (< (string-compare 'string<? a b) 0))

(define (string<=? a b)
  (<= (string-compare 'string<=? a b) 0))

(define (string>? a b)
  (> (string-compare 'string>? a b) 0))

(define (string>=? a b)
  (>= (string-compare 'string>=? a b) 0))

(define (string-compare name a b)
  (if (not (and (string? a) (string? b)))
      (begin (error name ": Operands must be strings: " a " " b)
	     #t)
      (bytevector-like-compare a b)))


(define (bytevector-equal? a b)
  (if (not (bytevector? a))
      (error "bytevector-equal?: not a bytevector: " a))
  (if (not (bytevector? b))
      (error "bytevector-equal?: not a bytevector: " b))
  (zero? (bytevector-like-compare a b)))


(define (bytevector-copy b)
  (if (not (bytevector? b))
      (error "bytevector-copy: not a bytevector: " b))
  (bytevector-like-copy b))


(define (bytevector-like-equal? b1 b2)
  (zero? (bytevector-like-compare b1 b2)))


(define (bytevector-like-copy b)
  (let ((v (make-bytevector (bytevector-like-length b))))
    (typetag-set! v (typetag b))
    (bytevector-like-copy-into! b 0 (bytevector-like-length b) v 0)))


(define (bytevector-like-copy-into! src from lim dest to)
  (do ((i from (+ i 1))
       (j to   (+ j 1)))
      ((= i lim) dest)
    (bytevector-like-set! dest j (bytevector-like-ref src i))))

; eof
