; -*- Scheme -*-
;
; Fifth pass of the Scheme 313 compiler:
;   assembly.
;
; $Id: assembler.scm,v 1.8 91/09/20 16:50:42 lth Exp Locker: lth $
;
; Parts of this code is Copyright 1991 Lightship Software, Incorporated.
;
; This is a the front end of a simple, table-driven assembler.
;
; The input to this pass is a list of symbolic
; MacScheme machine instructions and pseudo-instructions.
; Each symbolic MacScheme machine instruction or pseudo-instruction
; is a list whose car is a small non-negative fixnum that acts as
; the mnemonic for the instruction.  The rest of the list is
; interpreted as indicated by the mnemonic.
;
; The output is a pair consisting of machine code (a bytevector)
; and a constant vector.
;
; (Large chunks of the original code has been removed since it did not 
;  have a purpose in the current organization. The present program uses a 
;  three-pass scheme, in which the MacScheme instructions are first converted
;  to symbolic instructions for the target architecture, then assembled 
;  using an assembler for that architecture.)
;
; This assembler is table-driven, and may be customized to emit
; machine code for different target machines.  The table consists
; of a vector of procedures indexed by mnemonics.  Each procedure
; in the table should take two arguments: an assembly structure
; and a source instruction.
;
; The table can be changed by redefining the following procedure.

(define (assembly-table) $bytecode-assembly-table$)

; The main entry point.

(define (assemble source)
  (assemble1 (make-assembly-structure source)
             (lambda (as)
	       (assemble-finalize! as))))

; The following procedures are to be called by table routines.
;
; The assembly source for nested lambda expressions should be
; assembled by calling this procedure.  This allows an inner
; lambda to refer to labels defined by outer lambdas.
;
; The name is the name of the procedure; it may be any data object
; meaningful to the runtime system.

(define (assemble-nested-lambda as source name)
  (let ((nested-as (make-assembly-structure source)))
    (as-nested! as (cons nested-as (as-nested as)))
    (emit-constant nested-as name)
    (assemble1 nested-as (lambda (as) (cons (reverse! (as-code as))
					    (reverse! (as-constants as)))))))

(define operand0 car)      ; the mnemonic
(define operand1 cadr)
(define operand2 caddr)
(define operand3 cadddr)

; Emits the bits contained in the bytevector bv.
; (bv is really a symbolic instruction for the target architecture; it 
;  is a list.)

(define (emit! as bv)
  (as-code! as (cons bv (as-code as))))

; Given a Scheme object with its loader tag (data, codevector, or global),
; returns an index into the constant vector for that constant. Things may
; be shared.

(define (emit-constant as x)
  (emit-data as (list 'data x)))

(define (emit-global as x)
  (emit-data as (list 'global x)))

(define (emit-codevector as x)
  (emit-data as (list 'codevector x)))

(define (emit-constantvector as x)
  (emit-data as (list 'constantvector x)))

; do it.

(define (emit-data as x)
  (let* ((constants (as-constants as))
         (y (member x constants)))
    (if y
        (length y)
        (begin (as-constants! as (cons x constants))
               (+ (length constants) 1)))))

; A variation on the above, for constants (tag == data) only.
;
; Guarantees that the constants will not share structure
; with any others, and will occupy consecutive positions
; in the constant vector.  Returns the index of the first
; constant.
;
; Is this right? Should not all things be tagged?
; [Nodody uses this.]

(define (emit-constants as x . rest)
  (let* ((constants (as-constants as))
         (i (+ (length constants) 1)))
    (as-constants! as
                   (append (reverse rest)
                           (cons (list 'data x) constants)))
    i))



; For peephole optimization.

(define (next-instruction as)
  (let ((source (as-source as)))
    (if (null? source)
        '(-1)
        (car source))))

(define (consume-next-instruction! as)
  (as-source! as (cdr (as-source as))))

(define (push-instruction as instruction)
  (as-source! as (cons instruction (as-source as))))

; get the n'th previously emitted instruction (0-based)

(define (previous-emitted-instruction n as)
  (let loop ((n n) (code (as-code as)))
    (if (zero? n)
	(if (not (null? code))
	    (car code)
	    '(-1))
	(loop (- n 1) (if (null? code) '() (cdr code))))))

(define (discard-previous-instruction! as)
  (let ((code (as-code as)))
    (if (not (null? code))
	(as-code! as (cdr code)))))


; The remaining procedures in this file are local to the assembler.

; An assembly structure is a vector consisting of
;
;    table          (a table of assembly routines)
;    source         (a list of symbolic instructions)
;    lc             (location counter; an integer)
;    code           (a list of bytevectors)
;    constants      (a list)
;    labels         (an alist of labels and values)
;    fixups         (an alist of locations, sizes, and labels or fixnums)
;    nested         (a list of assembly structures for nested lambdas)
;
; In fixups, labels are of the form (<L>) to distinguish them from fixnums.
;
; In the generic version, lc, labels, fixups, and nested are not used.

(define label? pair?)
(define label.value car)

(define (make-assembly-structure source)
  (vector (assembly-table)
          source
          0
          '()
          '()
          '()
          '()
          '()))

(define (as-table as)     (vector-ref as 0))
(define (as-source as)    (vector-ref as 1))
(define (as-lc as)        (vector-ref as 2))
(define (as-code as)      (vector-ref as 3))
(define (as-constants as) (vector-ref as 4))
(define (as-labels as)    (vector-ref as 5))
(define (as-fixups as)    (vector-ref as 6))
(define (as-nested as)    (vector-ref as 7))

(define (as-source! as x)    (vector-set! as 1 x))
(define (as-lc! as x)        (vector-set! as 2 x))
(define (as-code! as x)      (vector-set! as 3 x))
(define (as-constants! as x) (vector-set! as 4 x))
(define (as-labels! as x)    (vector-set! as 5 x))
(define (as-fixups! as x)    (vector-set! as 6 x))
(define (as-nested! as x)    (vector-set! as 7 x))

; The guts of the assembler.

(define (assemble1 as finalize)
  (let ((assembly-table (as-table as)))
    (define (loop)
      (let ((source (as-source as)))
        (if (null? source)
            (finalize as)
            (begin (as-source! as (cdr source))
                   ((vector-ref assembly-table (caar source))
                    (car source)
                    as)
                   (loop)))))
    (loop)))

; At the end of the first pass, the finalizer is run. It calls the target
; assembler on all code vectors, and cleans up all constant vectors as well.

(define (assemble-finalize! as)

  ; Descend into a constant vector and assemble the nested code vectors.
  ; "constlist" is the constant vector in a tagged list form. "labels" is the
  ; collected symbol table (as an assoc list) of all outer procedures.
  ; The return value is an actual vector with each slot tagged.
  ;
  ; The traversal must be done breadth-first in order to know all labels for
  ; the nested procedures.

  (define (traverse-constvector constlist labels)

    ; Traverse constant list. Return pair of constant list and new symbol
    ; table.
    ; Due to the nature of labels, it is correct to keep passing in the 
    ; accumulated symbol table to procedures on the same level.

    (define (do-codevectors clist labels)
      (cons (map (lambda (x)
		   (case (car x)
		     ((codevector)
		      (let ((segment (assemble-codevector (cadr x) labels)))
			(set! labels (cdr segment))
			(list 'codevector (car segment))))
		     (else
		      x)))
		 clist)
	    labels))

    ; Descend into constant vectors. Return the constant list.

    (define (do-constvectors clist labels)
      (map (lambda (x)
	     (case (car x)
	       ((constantvector)
		(list 'constantvector (traverse-constvector (cadr x) labels)))
	       (else
		x)))
	   clist))

    ;
    
    (let ((s (do-codevectors constlist labels)))
      (list->vector (do-constvectors (car s) (cdr s)))))

  ; assemble-finalize!

  (let ((code  (reverse! (as-code as)))
	(const (reverse! (as-constants as))))
    (let ((segment (assemble-codevector code '())))
      (cons (car segment) (traverse-constvector const (cdr segment))))))

; Guts of bytecode-to-assembly-language translation.
;
; We generate lists of assembly instructions, which are later assembled to 
; code vectors. The assembly instruction generators are themselves hidden in
; some other file; the end result is that this file is (hopefully entirely)
; target-independent.

(define $bytecode-assembly-table$
  (make-vector
   64
   (lambda (instruction as)
     (error "Unrecognized mnemonic" instruction))))

(define (define-instruction i proc)
  (vector-set! $bytecode-assembly-table$ i proc)
  #t)

(define (list-instruction name instruction)
  (if listify?
      (begin (display list-indentation)
             (display "        ")
             (display name)
             (display (make-string (max (- 12 (string-length name)))
                                   #\space))
             (if (not (null? (cdr instruction)))
                 (begin (write (cadr instruction))
                        (do ((operands (cddr instruction)
                                       (cdr operands)))
                            ((null? operands))
                            (write-char #\,)
                            (write (car operands)))))
             (newline))))

(define (list-label instruction)
  (if listify?
      (begin (display list-indentation)
             (write-char #\L)
             (write (cadr instruction))
             (newline))))

(define (list-lambda-start instruction)
  (list-instruction "lambda" (list $lambda '* (operand2 instruction)))
  (set! list-indentation (string-append list-indentation "|   ")))

(define (list-lambda-end)
  (set! list-indentation
        (substring list-indentation
                   0
                   (- (string-length list-indentation) 4))))

(define list-indentation "")

(define listify? #f)
(define emit-undef-check? #f)

; Pseudo-instructions.

(define-instruction $.label
  (lambda (instruction as)
    (list-label instruction)
    (emit-label! as (make-asm-label (operand1 instruction)))))

; Given a numeric label, prepend a Q and make it a symbol (the assembler is
; a little picky...)

(define (make-asm-label q)
  (string->symbol (string-append
		   "Q"
		   (number->string q))))

(define new-label
  (let ((n 0))
    (lambda ()
      (set! n (+ n 1))
      (string->symbol (string-append "L" (number->string n))))))

(define-instruction $.asm
  (lambda (instruction as)
    (list-instruction ".asm" instruction)
    (emit! as (cadr instruction))))

(define-instruction $.proc
  (lambda (instruction as)
    (list-instruction ".proc" instruction)
    (emit-.proc! as)))

; no-op on Sparc

(define-instruction $.cont
  (lambda (instruction as)
    (list-instruction ".cont" instruction)
    '()))

; no-op on Sparc

(define-instruction $.align
  (lambda (instruction as)
    (list-instruction ".align" instruction)
    '()))

; Instructions.

; A hack to deal with the MacScheme macro expander's treatment of
; 1+ and 1-, and some peephole optimization.

(define-instruction $op1
  (lambda (instruction as)
    (cond ((eq? (operand1 instruction) (string->symbol "1+"))
	   (push-instruction as (list $op2imm '+ 1)))
	  ((eq? (operand1 instruction) (string->symbol "1-"))
	   (push-instruction as (list $op2imm '- 1)))
	  ((and (eq? (operand1 instruction) 'null?)
		(eq? (operand0 (next-instruction as)) $branchf))
	   (let ((i (next-instruction as)))
	     (consume-next-instruction! as)
	     (push-instruction as (list $optb2 'bfnull? (operand1 i)))))
	  ((and (eq? (operand1 instruction) 'zero?)
		(eq? (operand0 (next-instruction as)) $branchf))
	   (let ((i (next-instruction as)))
	     (consume-next-instruction! as)
	     (push-instruction as (list $optb2 'bfzero? (operand1 i)))))
	  ((and (eq? (operand1 instruction) 'pair?)
		(eq? (operand0 (next-instruction as)) $branchf))
	   (let ((i (next-instruction as)))
	     (consume-next-instruction! as)
	     (push-instruction as (list $optb2 'bfpair? (operand1 i)))))
	  (else
	   (list-instruction "op1" instruction)
	   (emit-primop0! as (operand1 instruction))))))

; ($op2 prim k)

(define-instruction $op2

  (let ((oplist '((= bf=) (< bf<) (> bf>) (<= bf<=) (>= bf>=))))

    (lambda (instruction as)
      (let ((op (assq (operand1 instruction) oplist)))
	(if (and op
		 (eq? (operand0 (next-instruction as)) $branchf))
	    (let ((i (next-instruction as)))
	      (consume-next-instruction! as)
	      (push-instruction as (list $optb3
					 (cadr op)
					 (operand2 instruction)
					 (operand1 i))))
	    (begin
	      (list-instruction "op2" instruction)
	      (emit-primop1! as
			     (operand1 instruction)
			     (regname (operand2 instruction)))))))))

; ($op3 prim k1 k2)

(define-instruction $op3
  (lambda (instruction as)
    (list-instruction "op3" instruction)
    (emit-primop2! as
		   (operand1 instruction)
		   (regname (operand2 instruction))
		   (regname (operand3 instruction)))))

; ($op2imm prim k x)
; Questionable use of argreg2?

(define-instruction $op2imm
  (lambda (instruction as)
    (list-instruction "opx" instruction)
    (emit-constant->register as (operand2 instruction) $r.argreg2)
    (emit-primop1! as
		   (operand1 instruction)
		   $r.argreg2)))

; Test-and-branch-on-false; introduced by peephole optimization of
; constructions of the form
;   ($op1 test)
;   ($bfalse label)
; The name of the test has been changed to make it easier for the backend.
;
; ($optb2 test label)

(define-instruction $optb2
  (lambda (instruction as)
    (list-instruction "optb2" instruction)
    (emit-primop1! as
		   (operand1 instruction)
		   (operand2 instruction))))

(define-instruction $optb3
  (lambda (instruction as)
    (list-instruction "optb3" instruction)
    (emit-primop2! as
		   (operand1 instruction)
		   (regname (operand2 instruction))
		   (operand3 instruction))))

; ($const foo)

(define-instruction $const
  (lambda (instruction as)
    (let ((next (next-instruction as)))
      (cond ((= (operand0 next) $setreg)
	     (consume-next-instruction! as)
	     (list-instruction "const2reg" (list '()
						 (operand1 instruction)
						 (operand1 next)))
	     (emit-constant->register as
				      (operand1 instruction)
				      (regname (operand1 next))))
	    (else
	     (list-instruction "const" instruction)
	     (emit-constant->register as (operand1 instruction) $r.result))))))

(define-instruction $global
  (lambda (instruction as)
    (list-instruction "global" instruction)
    (emit-global->register! as
			    (emit-global as (operand1 instruction))
			    $r.result)))

(define-instruction $setglbl
  (lambda (instruction as)
    (list-instruction "setglbl" instruction)
    (emit-result-register->global! as
			    (emit-global as (operand1 instruction)))))

(define-instruction $lambda
  (lambda (instruction as)
    (list-lambda-start instruction)
    (let ((segment (assemble-nested-lambda as 
					   (operand1 instruction)
					   (operand3 instruction))))
      (list-lambda-end)
      (let ((code-offset  (emit-codevector as (car segment)))
	    (const-offset (emit-constantvector as (cdr segment))))
	(emit-lambda! as
		      code-offset
		      const-offset
		      (operand2 instruction)
		      (operand3 instruction))))))

(define-instruction $lexes
  (lambda (instruction as)
    (list-instruction "lexes" instruction)
    (emit-lexes! as (operand1 instruction)
		    (operand2 instruction)))) 

(define-instruction $args=
  (lambda (instruction as)
    (list-instruction "args=" instruction)
    (emit-args=! as (operand1 instruction))))

(define-instruction $args>=
  (lambda (instruction as)
    (list-instruction "args>=" instruction)
    (emit-args>=! as (operand1 instruction))))

(define-instruction $invoke
  (lambda (instruction as)
    (list-instruction "invoke" instruction)
    (emit-invoke! as (operand1 instruction))))

(define-instruction $restore
  (lambda (instruction as)
    (list-instruction "restore" instruction)
    (emit-restore! as (operand1 instruction))))

(define-instruction $pop
  (lambda (instruction as)
    (list-instruction "pop" instruction)
    (emit-pop! as (operand1 instruction))))

(define-instruction $stack
  (lambda (instruction as)
    (list-instruction "stack" instruction)
    (emit-load! as (operand1 instruction) $r.result)))

(define-instruction $setstk
  (lambda (instruction as)
    (list-instruction "setstk" instruction)
    (emit-store! as $r.result (operand1 instruction))))

(define-instruction $load
  (lambda (instruction as)
    (list-instruction "load" instruction)
    (emit-load! as (operand1 instruction) (regname (operand2 instruction)))))

(define-instruction $store
  (lambda (instruction as)
    (list-instruction "store" instruction)
    (emit-store! as (regname (operand1 instruction)) (operand2 instruction))))

(define-instruction $lexical
  (lambda (instruction as)
    (list-instruction "lexical" instruction)
    (emit-lexical! as (operand1 instruction) (operand2 instruction))))

(define-instruction $setlex
  (lambda (instruction as)
    (list-instruction "setlex" instruction)
    (emit-lexical! as (operand1 instruction) (operand2 instruction))))

(define-instruction $reg
  (lambda (instruction as)
    (list-instruction "reg" instruction)
    (emit-register->register! as (regname (operand1 instruction)) $r.result)))

(define-instruction $setreg
  (lambda (instruction as)
    (list-instruction "setreg" instruction)
    (emit-register->register! as $r.result (regname (operand1 instruction)))))

(define-instruction $movereg
  (lambda (instruction as)
    (list-instruction "movereg" instruction)
    (emit-register->register! as 
			      (regname (operand1 instruction))
			      (regname (operand2 instruction)))))

(define-instruction $return
  (lambda (instruction as)
    (list-instruction "return" instruction)
    (emit-return! as)))

(define-instruction $nop
  (lambda (instruction as)
    (list-instruction "nop" instruction)
    (emit-nop! as)))

(define-instruction $save
  (lambda (instruction as)
    (list-instruction "save" instruction)
    (emit-save! as (operand1 instruction) (operand2 instruction))))

(define-instruction $setrtn
  (lambda (instruction as)
    (list-instruction "setrtn" instruction)
    (emit-setrtn! as (operand1 instruction))))

(define-instruction $apply
  (lambda (instruction as)
    (list-instruction "apply" instruction)
    (emit-apply! as)))

(define-instruction $jump
  (lambda (instruction as)
    (list-instruction "jump" instruction)
    (emit-jump! as (operand1 instruction) (operand2 instruction))))

(define-instruction $skip
  (lambda (instruction as)
    (list-instruction "skip" instruction)
    (emit-branch! as #f (operand1 instruction))))

(define-instruction $branch
  (lambda (instruction as)
    (list-instruction "branch" instruction)
    (emit-branch! as #t (operand1 instruction))))

(define-instruction $branchf
  (lambda (instruction as)
    (list-instruction "branchf" instruction)
    (emit-branchf! as (operand1 instruction))))

; Helpers

(define **eof** (lambda (x) x))

(define (emit-constant->register as opd r)

  (define (fixnum-range? x)
    (and (>= x (- (expt 2 29)))
	 (<= x (- (expt 2 29) 1))))

  (cond ((and (integer? opd) (exact? opd))
	 (if (fixnum-range? opd)	
	     (emit-fixnum->register! as opd r)
	     (emit-const->register! as (emit-constant as opd) r)))
	((boolean? opd)
	 (emit-immediate->register! as
				    (if (eq? opd #t)
					$imm.true
					$imm.false)
				    r))
	; is this correct?
	((eq? opd **eof**)
	 (emit-immediate->register! as $imm.eof r))
	((equal? opd hash-bang-unspecified)
	 (emit-immediate->register! as $imm.unspecified r))
	((null? opd)
	 (emit-immediate->register! as $imm.null r))
	((char? opd)
	 (emit-immediate->register! as (char->immediate opd) r))
	(else
	 (emit-const->register! as (emit-constant as opd) r))))
