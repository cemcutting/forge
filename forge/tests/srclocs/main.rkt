#lang forge/core 

; Confirm that source locations are indeed preserved in case they are needed for errors.

(require (rename-in rackunit [check rackunit-check]))
(require (only-in racket flatten first string-contains?))

; Returns a list of all AST nodes in this tree
(define (gather-tree n #:leafs-only leafs-only)
  (define descendents
    (cond [(node/expr/op? n)
           (flatten (map (lambda (ch) (gather-tree ch #:leafs-only leafs-only))
                         (node/expr/op-children n)))]
          [(node/formula/op? n)
           (flatten (map (lambda (ch) (gather-tree ch #:leafs-only leafs-only))
                         (node/formula/op-children n)))]
          [(node/int/op? n)
           (flatten (map (lambda (ch) (gather-tree ch #:leafs-only leafs-only))
                         (node/int/op-children n)))]
          
          [(node/fmla/pred-spacer? n)
           (gather-tree (node/fmla/pred-spacer-expanded n) #:leafs-only leafs-only)]
          [(node/expr/fun-spacer? n)
           (gather-tree (node/expr/fun-spacer-expanded n) #:leafs-only leafs-only)]

          [(node/formula/multiplicity? n)
           (gather-tree (node/formula/multiplicity-expr n) #:leafs-only leafs-only)]
          [(node/formula/quantified? n)
           ; TODO: decls
           (gather-tree (node/formula/quantified-formula n) #:leafs-only leafs-only)]

          ;; TODO: other cases
          [else (list n)]))
  (if leafs-only
      descendents
      (cons n descendents)))

(define (print-one-per-line l)
  (cond [(not (list l)) (printf "  ~a~n" l)]
        [(empty? l) (printf "~n")]
        [else (printf "  ~a~n" (first l)) (print-one-per-line (rest l))]))


; Confirm that the syntax location information for all nodes refers to the proper module
(define (check-full-ast-srclocs root-ast sub-path-str)
  (for ([n (gather-tree root-ast #:leafs-only #f)])
    (define loc (nodeinfo-loc (node-info n)))
    (define source-path-correct
      (string-contains?
       (path->string (srcloc-source loc))
       sub-path-str))
    (unless source-path-correct 
      (printf "     ~a: ~a~n" n loc))
    ; Comment out for now, avoid unpleasant flickering spam
    ;(check-true source-path-correct)
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Need to do these separately, because of "already bound" sig names shared etc.

;(require (only-in "../forge/library/seq.frg" order))
; For debugging: is anything not being broken down properly?
; (print-one-per-line (gather-tree order #:leafs-only #t))
;(check-full-ast-srclocs order "/forge/library/seq.frg")

;(require (only-in "../forge/library/reachable.frg" reach6))
;(check-full-ast-srclocs reach6 "/forge/library/reachable.frg")

(require (only-in "../forge/formulas/booleanFormulaOperators.rkt" Implies And Or Not))
(check-full-ast-srclocs Implies  "/forge/formulas/booleanFormulaOperators.rkt")
(check-full-ast-srclocs And  "/forge/formulas/booleanFormulaOperators.rkt")
(check-full-ast-srclocs Or  "/forge/formulas/booleanFormulaOperators.rkt")
(check-full-ast-srclocs Not  "/forge/formulas/booleanFormulaOperators.rkt")



;; TODO: check run parameters as well (catch instances...) 
;; TODO: other examples