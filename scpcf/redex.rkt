#lang racket
(provide SCPCF sc inj-scv -->scv typeof/contract/symbolic typable/contract/symbolic?)
(require redex/reduction-semantics cpcf/redex pcf/redex)

(define-extended-language SCPCF CPCF
  ;; Values
  (V .... (• T C ...))

  (C .... any? prime?)
  (B (λ ([X : T] ...) (C L L ⚖ ((λ ([X : T] ...) M) (C L L ⚖ X) ...))))
  (NB (side-condition V (not (redex-match SCPCF B (term NB))))))


(define sc
  (reduction-relation
   SCPCF #:domain M
   (--> ((• (T_0 ... -> T)
	    (C_0 ... -> C) ...)
	 V ...)
	(• T C ...) β•)

   (--> ((• (T -> T_o)  ;; FIXME bug in _1 in Redex
	    (C -> C_o) ...)
	 V)
	(havoc T C ... V)
	havoc)

   (--> (O V ...) M
	(judgment-holds (δ^ O (V ...) M))
	δ^)
   (--> (if0 (• nat C ...) M_0 M_1) M_0 if•-t)
   (--> (if0 (• nat C ...) M_0 M_1) M_1 if•-f)

   (--> (any? L_+ L_- ⚖ V) V any?)

   (--> (C L_+ L_- ⚖ (• T C_0 ... C C_1 ...))
	(• T C_0 ... C C_1 ...)
	(side-condition (not (eq? (term M) 'any?)))
	known)

   (--> (M L_+ L_- ⚖ (• T C ...))
	(if0 (M (• T C ...))
	     (• T C ... M)
	     (blame L_+))
	(side-condition (not (eq? (term M) 'any?)))
	(side-condition (not (member (term M) (term (C ...)))))
	check-rem)

   (--> (M L_+ L_- ⚖ V)
        (if0 (M V) V (blame L_+))
	(side-condition (not (eq? (term M) 'any?)))
	(side-condition (not (redex-match SCPCF (• T C ...) (term V))))
	?)
   (--> ((C_1 ... -> C) L_+ L_- ⚖ (λ ([X : T] ...) M))
	(λ ([X : T] ...)
	  (C L_+ L_- ⚖ ((λ ([X : T] ...) M) (C_1 L_- L_+ ⚖ X) ...)))
	(side-condition (not (eq? (term C) 'any?)))
	η)
   (--> ((C_1 ... -> any?) L_+ L_- ⚖ (λ ([X : T] ...) M))
	(λ ([X : T] ...)
	  ((λ ([X : T] ...) M) (C_1 L_- L_+ ⚖ X) ...))
	ηt)))

;; --
;; DUPLICATION OF INJ-CV
;; doesn't seem possible to abstract with metafunction extensions.
(define-metafunction SCPCF
  inj-scv : M -> M
  [(inj-scv M) (lab/context M †)])

(define-metafunction SCPCF
  lab/context : M L -> M
  [(lab/context (C ⚖ M) L)
   ((lab-c/context C L) L L_0 ⚖ (lab/context M L_0))
   (where L_0 (quote ,(gensym)))]
  [(lab/context (M ...) L)
   ((lab/context M L) ...)]
  [(lab/context (if0 M ...) L)
   (if0 (lab/context M L) ...)]
  [(lab/context (λ ([X : T] ...) M) L)
   (λ ([X : T] ...) (lab/context M L))]
  [(lab/context M L) M])

(define-metafunction SCPCF
  lab-c/context : C L -> C
  [(lab-c/context (C_0 ... -> C) L)
   ((lab-c/context C_0 L) ... -> (lab-c/context C L))]
  [(lab-c/context V L)
   (lab/context V L)])
;; --

(define-metafunction SCPCF
  not-zero? : any -> #t or #f
  [(not-zero? 0) #f]
  [(not-zero? any) #t])

(define-metafunction SCPCF
  not-div? : any -> #t or #f
  [(not-div? div) #f]
  [(not-div? any) #t])

(define-metafunction SCPCF
  no-pos? : C ... -> #t or #f
  [(no-pos? C_1 ... pos? C_2 ...) #f]
  [(no-pos? C ...) #t])

(define-metafunction SCPCF
  not-pos? : C -> #t or #f
  [(not-pos? pos?) #f]
  [(not-pos? any) #t])

(define-judgment-form SCPCF
  #:mode (δ^ I I O)
  #:contract (δ^ O (V ...) M)
  [(δ^ quotient (any (• nat C ...)) (• nat))]
  [(δ^ quotient (any (• nat C_0 ... pos? C_1 ...)) (• nat))]
  [(δ^ quotient (any (• nat C ...)) (err nat "Divide by zero"))
   (side-condition (no-pos? C ...))]
  [(δ^ quotient ((• nat C ...) 0)   (err nat "Divide by zero"))]
  [(δ^ quotient ((• nat C ...) N)   (• nat))
   (side-condition (not-zero? N))]
  [(δ^ pos? ((• nat C_1 ... pos? C_2 ...)) 0)]
  [(δ^ pos? ((• nat C ...)) (• nat))
   (side-condition (no-pos? C ...))]

  [(δ^ O (any_0 ... (• nat C ...) any_1 ...) (• nat))
   (side-condition (not-div? O))
   (side-condition (not-pos? O))])

(define-metafunction SCPCF
  havoc : T C ... M -> M
  [(havoc nat C ... M) M]
  [(havoc (T_0 -> T_1) (C_0 -> C_1) ...
	  (λ ((X : T)) ((λ ((X : T)) M) (C_3 ⚖ X))))
   (havoc T_1 C_1 ...
	  ((λ ((X : T)) M) (• T_0 C_3 C_0 ...)))]
  [(havoc (T_0 -> T_1) (C_0 -> C_1) ...
	  (λ ((X : T)) (C_2 ⚖ ((λ ((X : T)) M) (C_3 ⚖ X)))))
   (havoc T_1 C_1 ...
	  (C_2 ⚖ ((λ ((X : T)) M) (• T_0 C_3 C_0 ...))))]
  [(havoc (T_0 -> T_1) (C_0 -> C_1) ... M)
   (havoc T_1 (M (• T_0 C_0 ...)))])

(define scv
  (union-reduction-relations sc (extend-reduction-relation v SCPCF)))

(define -->scv (context-closure scv SCPCF E))


(define (typable/contract/symbolic? M)
  (cons? (judgment-holds (typeof/contract/symbolic () ,M T) T)))

(define-extended-judgment-form SCPCF typeof/contract
  #:mode (typeof/contract/symbolic I I O)
  [(typeof/contract/symbolic Γ M nat)]) ;; FIXME