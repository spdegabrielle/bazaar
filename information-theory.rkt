#lang racket/base
;;; Copyright (C) Laurent Orseau, 2010-2013
;;; GNU Lesser General Public Licence (http://www.gnu.org/licenses/lgpl.html)

(require racket/contract
         racket/list)

(provide (all-defined-out))

(module+ test (require rackunit))

;;; Prefix-code for the integers:
;;; http://en.wikipedia.org/wiki/Universal_code_%28data_compression%29

; See also fllog2 from math/flonum
(define (log2 x)
  (/ (log x)
     (log 2)))

(define unary? (listof 0))
(define binary? (listof (or/c 0 1)))
(define N? exact-nonnegative-integer?)
(define N*? exact-positive-integer?)

;; Returns a list of (x-1) 0s.
;; (to be prefix-free, a 1 must be appended)
(define/contract (number->unary x)
  (N*? . -> . unary?)
  (make-list (sub1 x) 0))

(define/contract (number->binary x)
  (N? . -> . binary?)
  (let loop ([x x] [l '()])
    (if (< x 2)
        (cons x l)
        (loop (quotient x 2)
              (cons (modulo x 2) l)))))

;; for n=1, same as Elias-gamma coding (which does not encode 0).
;; for n=2, same as Elias-delta with 1 additional bit 
;; (but encodes 0, and easier to understand)
(define/contract (prefix-encode x [n 1])
  ((N?) (N*?) . ->* . binary?)
  (let loop ([x x] [n n] [l '()])
    (if (zero? n)
        (append (number->unary x) l)
        (let ([bx (number->binary x)])
          (loop (length bx)
                (sub1 n)
                (append bx l))))))

;; Same as Elias-gamma, but starts at 0 instead of 1.
(define (exp-golomb x)
  (prefix-encode (add1 x)))

;; http://en.wikipedia.org/wiki/Elias_delta_coding
(define/contract (elias-delta-length x)
  (N? . -> . number?)
  (inexact->exact
   (+ (floor (log2 x))
      (* 2 (floor (log2 (+ 1 (floor (log2 x))))))
      1)))

(module+ test
  (for ([i (in-range 1 18)]
        [len '(1 4 4 5 5 5 5 8 8 8 8 8 8 8 8 9 9)])
    (check-equal? (elias-delta-length i) len)
    (check-equal? (length (prefix-encode i 2)) (+ len 1)))
  
  )

(define code-length
  (case-lambda 
    [(x min max) ; encode x from an interval
     ; Since the probability of x in [min, max] is 1/(max-min+1),
     ; the code length is -log2(1/(max-min+1))
     (log2 (- (add1 max) min))]
    [(x) ; encode x with a variable length
     ; add1 to take 0 into account
     (elias-delta-length (add1 x))]))
