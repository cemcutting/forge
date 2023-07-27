#lang racket/base

; The #lang forge reader produces a module referencing this one as its module-path:
; https://docs.racket-lang.org/reference/module.html

(require syntax/parse/define racket/stxparam
         (for-syntax racket/base syntax/parse racket/syntax syntax/parse/define racket/function
                     syntax/srcloc racket/match racket/list                     
                     (only-in racket/path file-name-from-path))
         ; Needed because the abstract-tok definition below requires phase 2
         (for-syntax (for-syntax racket/base)))
                 
(require (only-in racket empty? first))
(require forge/sigs)
(require forge/choose-lang-specific)

(provide isSeqOf seqFirst seqLast indsOf idxOf lastIdxOf elems inds isEmpty hasDups reachable)
(provide #%module-begin)
(provide #%top #%app #%datum #%top-interaction)

(provide require provide all-defined-out except-out prefix-in only-in
         module+ submod)
(provide forge:nsa define-namespace-anchor)
(provide (all-from-out forge/sigs))
(provide (all-defined-out))
(begin-for-syntax (provide (all-defined-out)))

(define-syntax-parameter current-forge-context #f)

(begin-for-syntax
  (define (forge-context=? x)
    (define ctx (syntax-parameter-value #'current-forge-context))
    (if (pair? x)
      (memq ctx x)
      (eq? ctx x)))

  (define-syntax-parser make-token
    [(make-token token-class:id token-string:str token-symbol)
     #'(define-syntax-class token-class
         (pattern token-string
           #:attr symbol #'token-symbol))])

  (make-token abstract-tok "abstract" #:abstract))

(define-for-syntax (my-expand stx)
  (define core-funcs-and-macros
    (map (curry datum->syntax stx)
         '(^ * ~ + - & join
           -> => implies ! not and or && || ifte iff <=>
           = in ni != !in !ni is
           no some one lone all set two
           < > int= >= <=
           add subtract multiply divide sign abs remainder
           card sum sing succ max min sum-quant
           node/int/constant
           let)))

  (define result (local-expand stx 'expression core-funcs-and-macros))
  result)

(begin-for-syntax
  ; AlloyModule : ModuleDecl? Import* Paragraph*
  ;             | EvalDecl*
  ; (define-syntax-class AlloyModuleClass
  ;   (pattern ((~datum AlloyModule)
  ;             (~optional module-decl:ModuleDeclClass)
  ;             (~seq import:ImportClass ...)
  ;             (~seq paragraph:ParagraphClass ...)))
  ;   (pattern ((~datum AlloyModule)
  ;             (~seq eval-decl:EvalDeclClass ...))))


  ; Header stuff

  ; ModuleDecl : /MODULE-TOK QualName (LEFT-SQUARE-TOK NameList RIGHT-SQUARE-TOK)?
  (define-syntax-class ModuleDeclClass
    (pattern ((~datum ModuleDecl)
              module-name:QualNameClass
              (~optional (~seq "[" other-names:NameListClass "]")))))

  ; Import : OPEN-TOK QualName (LEFT-SQUARE-TOK QualNameList RIGHT-SQUARE-TOK)? (AS-TOK Name)?
  (define-syntax-class ImportClass
    (pattern ((~datum Import)
              import-name:QualNameClass
              (~optional (~seq "[" other-names:QualNameListClass "]"))
              (~optional (~seq "as" as-name:NameClass))))
    (pattern ((~datum Import)
              file-path:str
              (~optional (~seq "as" as-name:NameClass)))))


  ; Main Decls

  ; EvalDecl : EVAL-TOK Expr
  (define-syntax-class EvalDeclClass
    (pattern ((~datum EvalDecl)
              "eval"
              exp:ExprClass)))

  ; @Paragraph : SigDecl | FactDecl | PredDecl | FunDecl | AssertDecl 
  ;                      | CmdDecl | TestExpectDecl | SexprDecl | BreakDecl 
  ;                      | InstanceDecl | QueryDecl | StateDecl | TransitionDecl 
  ;                      | RelDecl | OptionDecl | InstDecl | TraceDecl
  (define-syntax-class ParagraphClass
    (pattern decl:SigDeclClass)
    (pattern decl:FactDeclClass)
    (pattern decl:PredDeclClass)
    (pattern decl:FunDeclClass)
    (pattern decl:AssertDeclClass)
    (pattern decl:CmdDeclClass)
    (pattern decl:TestExpectDeclClass)
    (pattern decl:PropertyDeclClass)
    (pattern decl:TestSuiteDeclClass)
    (pattern decl:SexprDeclClass)
    ; (pattern decl:BreakDeclClass)
    ; (pattern decl:InstanceDeclClass)
    ; (pattern decl:QueryDeclClass)
    ; (pattern decl:StateDeclClass)
    ; (pattern decl:TransitionDeclClass)
    (pattern decl:RelDeclClass)
    (pattern decl:OptionDeclClass)
    (pattern decl:InstDeclClass)
    (pattern decl:ExampleDeclClass))
    ; (pattern decl:TraceDeclClass))

  ;Used for Electrum stuff
  ;Used to declare var Sigs and Relations (so they can change over time)
  (define-syntax-class VarKeywordClass (pattern "var")) 

  ; SigDecl : VAR-TOK? ABSTRACT-TOK? Mult? /SIG-TOK NameList SigExt? /LEFT-CURLY-TOK ArrowDeclList? /RIGHT-CURLY-TOK Block?
  (define-syntax-class SigDeclClass
    (pattern ((~datum SigDecl)
              (~optional isv:VarKeywordClass #:defaults ([isv #'#f]))
              (~optional abstract:abstract-tok)
              (~optional mult:MultClass)
              sig-names:NameListClass
              ;when extending with in is implemented,
              ;if "sig A in B extends C" is allowed,
              ;check if this allows multiple SigExtClasses / how to do that if not
              ;note the parser currently does not allow that
              (~optional extends:SigExtClass)
              (~optional relation-decls:ArrowDeclListClass)
              (~optional block:BlockClass))))

  ; SigExt : EXTENDS-TOK QualName 
  ;        | IN-TOK QualName (PLUS-TOK QualName)*
  (define-syntax-class SigExtClass
    (pattern ((~datum SigExt)
              "extends"
              name:QualNameClass)
      #:attr symbol #'#:extends
      #:attr value #'name.name)
    (pattern ((~datum SigExt)
              "in" 
              name:QualNameClass
              (~seq (~seq "+" names:QualNameClass) ...))
      #:attr symbol #'#:in
      #:attr value #'(raise "Extending with in not yet implemented.")))

  ; Mult : LONE-TOK | SOME-TOK | ONE-TOK | TWO-TOK
  (define-syntax-class MultClass
    (pattern ((~datum Mult) "lone") #:attr symbol #'#:lone)
    (pattern ((~datum Mult) "some") #:attr symbol #'#:some)
    (pattern ((~datum Mult) "one") #:attr symbol #'#:one)
    (pattern ((~datum Mult) "two") #:attr symbol #'#:two))

  ; ArrowMult : LONE-TOK | SET-TOK | ONE-TOK | TWO-TOK
  (define-syntax-class ArrowMultClass
    (pattern ((~datum ArrowMult) "lone") #:attr symbol #'pfunc)
    (pattern ((~datum ArrowMult) "set") #:attr symbol #'default)
    (pattern ((~datum ArrowMult) "one") #:attr symbol #'func)
    (pattern ((~datum ArrowMult) "func") #:attr symbol #'func)
    (pattern ((~datum ArrowMult) "pfunc") #:attr symbol #'pfunc)
    (pattern ((~datum ArrowMult) "two") #:attr symbol #'(raise "relation arity two not implemented")))

  ; Decl : DISJ-TOK? NameList /COLON-TOK DISJ-TOK? SET-TOK? Expr
  (define-syntax-class DeclClass
    (pattern ((~datum Decl)
              ;(~optional "disj")
              names:NameListClass
              ;(~optional "disj")
              (~optional "set")
              expr:ExprClass)
      #:attr translate (with-syntax ([expr #'expr])
                         #'((names.names expr) ...))))

  ; DeclList : Decl
  ;          | Decl /COMMA-TOK @DeclList
  (define-syntax-class DeclListClass
    (pattern ((~datum DeclList)
              decls:DeclClass ...)
      #:attr translate (datum->syntax #'(decls ...) 
                                      (apply append 
                                             (map syntax->list 
                                                  (syntax->list #'(decls.translate ...)))))))

  ; ArrowDecl : DISJ-TOK? NameList /COLON-TOK DISJ-TOK? ArrowMult ArrowExpr
  (define-syntax-class ArrowDeclClass
    (pattern ((~datum ArrowDecl)
              ;(~optional "disj")
              (~optional isv:VarKeywordClass #:defaults ([isv #'#f])) ; electrum
              name-list:NameListClass
              ;(~optional "disj") 
              mult-class:ArrowMultClass
              type-list:ArrowExprClass)
      #:attr names #'(name-list.names ...)
      #:attr types #'type-list.names
      #:attr mult #'mult-class.symbol
      #:attr is-var #'isv))

  ; ArrowDeclList : ArrowDecl
  ;               | ArrowDecl /COMMA-TOK @ArrowDeclList
  (define-syntax-class ArrowDeclListClass
    (pattern ((~datum ArrowDeclList)
              arrow-decl:ArrowDeclClass ...)))

  ; ArrowExpr : QualName
  ;           | QualName /ARROW-TOK @ArrowExpr
  (define-syntax-class ArrowExprClass
    (pattern ((~datum ArrowExpr)
              name-list:QualNameClass ...)
      #:attr names #'(name-list.name ...)))

  ; FactDecl : FACT-TOK Name? Block
  (define-syntax-class FactDeclClass
    (pattern ((~datum FactDecl)
              "fact" 
              (~optional name:NameClass)
              block:BlockClass)))

  (define-syntax-class PredTypeClass
    #:datum-literals (PredType)
    #:attributes (kw)
    (pattern (PredType "wheat")
      #:attr kw #'#:wheat))

  ; PredDecl : /PRED-TOK (QualName DOT-TOK)? Name ParaDecls? Block
  (define-syntax-class PredDeclClass
    (pattern ((~datum PredDecl)
              (~optional _:PredTypeClass)
              (~optional (~seq prefix:QualNameClass "."))
              name:NameClass
              (~optional decls:ParaDeclsClass)
              block:BlockClass)))

  ; FunDecl : /FUN-TOK (QualName DOT-TOK)? Name ParaDecls? /COLON-TOK Expr Block
  (define-syntax-class FunDeclClass
    (pattern ((~datum FunDecl)
              (~optional (~seq prefix:QualNameClass "."))
              name:NameClass
              (~optional decls:ParaDeclsClass)
              output:ExprClass
              body:ExprClass)))

  ; ParaDecls : /LEFT-PAREN-TOK @DeclList? /RIGHT-PAREN-TOK 
  ;           | /LEFT-SQUARE-TOK @DeclList? /RIGHT-SQUARE-TOK
  ; DeclList : Decl
  ;          | Decl /COMMA-TOK @DeclList
  (define-syntax-class ParaDeclsClass
    (pattern ((~datum ParaDecls)
              (~seq decls:DeclClass ...))
      #:attr translate (datum->syntax #'(decls ...)
                                      (apply append (map (compose (curry map car )
                                                                  (curry map syntax->list )
                                                                  syntax->list) 
                                                         (syntax->list #'(decls.translate ...)))))))

  ; AssertDecl : /ASSERT-TOK Name? Block
  (define-syntax-class AssertDeclClass
    (pattern ((~datum AssertDecl)
              (~optional name:NameClass)
              block:BlockClass)))

  ; CmdDecl :  (Name /COLON-TOK)? (RUN-TOK | CHECK-TOK) Parameters? (QualName | Block)? Scope? (/FOR-TOK Bounds)?
  (define-syntax-class CmdDeclClass
    (pattern ((~datum CmdDecl)
              (~optional name:NameClass)
              (~or "run" "check")
              (~optional parameters:ParametersClass)
              (~optional (~or pred-name:QualNameClass
                              pred-block:BlockClass))
              (~optional scope:ScopeClass)
              (~optional bounds:BoundsClass))))

  ; TestDecl : (Name /COLON-TOK)? Parameters? (QualName | Block)? Scope? (/FOR-TOK Bounds)? /IS-TOK (SAT-TOK | UNSAT-TOK)
  (define-syntax-class TestDeclClass
    (pattern ((~datum TestDecl)
              (~optional name:NameClass)
              (~optional parameters:ParametersClass)
              (~optional (~or pred-name:QualNameClass
                              pred-block:BlockClass))
              (~optional scope:ScopeClass)
              (~optional bounds:BoundsClass)
              (~or "sat" "unsat" "theorem"))))

  ; TestBlock : /LEFT-CURLY-TOK TestDecl* /RIGHT-CURLY-TOK
  (define-syntax-class TestBlockClass
    (pattern ((~datum TestBlock)
              test-decls:TestDeclClass ...)))

  ; TestExpectDecl : TEST-TOK? EXPECT-TOK Name? TestBlock
  (define-syntax-class TestExpectDeclClass
    (pattern ((~datum TestExpectDecl)
              (~optional "test")
              "expect"
              (~optional name:NameClass)
              test-block:TestBlockClass)))

  (define-syntax-class TestConstructClass
    (pattern decl:ExampleDeclClass)
    (pattern decl:TestExpectDeclClass)
    (pattern decl:PropertyDeclClass))

  (define-syntax-class PropertyDeclClass
    #:attributes (prop-name pred-name constraint-type scope bounds)
    (pattern ((~datum PropertyDecl)      
              -prop-name:NameClass
              (~and (~or "sufficient" "necessary") ct)
              -pred-name:NameClass
              (~optional -scope:ScopeClass)
              (~optional -bounds:BoundsClass))
      #:with prop-name #'-prop-name.name
      #:with pred-name #'-pred-name.name
      #:with constraint-type (string->symbol (syntax-e #'ct))
      #:with scope (if (attribute -scope) #'-scope.translate #'())
      #:with bounds (if (attribute -bounds) #'-bounds.translate #'())))


  (define-syntax-class TestSuiteDeclClass
    #:attributes (pred-name (test-constructs 1))
    (pattern ((~datum TestSuiteDecl)
              -pred-name:NameClass
              test-constructs:TestConstructClass ...)
      #:with pred-name #'-pred-name.name))

  (define-syntax-class ExampleDeclClass
    (pattern ((~datum ExampleDecl)
              (~optional name:NameClass)
              pred:ExprClass
              bounds:BoundsClass)))

  ; Scope : /FOR-TOK Number (/BUT-TOK @TypescopeList)? 
  ;       | /FOR-TOK @TypescopeList
  ; TypescopeList : Typescope
  ;               | Typescope /COMMA-TOK @TypescopeList
  (define-syntax-class ScopeClass
    (pattern ((~datum Scope)
              (~optional default:NumberClass)
              (~seq typescope:TypescopeClass ...))
      #:attr translate #'(typescope.translate ...)))

  ; Typescope : EXACTLY-TOK? Number QualName
  (define-syntax-class TypescopeClass
    (pattern ((~datum Typescope)
              (~optional (~and "exactly" exactly))
              num:NumberClass
              name:QualNameClass)
      #:attr translate (if (attribute exactly)
                           #'(name.name num.value num.value)
                           #'(name.name 0 num.value))))

  ; OptionDecl : /OPTION-TOK QualName (QualName | FILE-PATH-TOK | Number)
  (define-syntax-class OptionDeclClass
    #:attributes (n v)
    (pattern ((~datum OptionDecl) name:QualNameClass value:QualNameClass)
             #:attr n #'name.name
             #:attr v #'value.name)
    (pattern ((~datum OptionDecl) name:QualNameClass value:str)
             #:attr n #'name.name
             #:attr v #'value)
    (pattern ((~datum OptionDecl) name:QualNameClass value:NumberClass)
             #:attr n #'name.name
             #:attr v #'value.value)
    (pattern ((~datum OptionDecl) name:QualNameClass "-" value:NumberClass)
             #:attr n #'name.name
             #:attr v (quasisyntax #,(* -1 (syntax->datum #'value.value)))))

 
  ; Block : /LEFT-CURLY-TOK Expr* /RIGHT-CURLY-TOK
  (define-syntax-class BlockClass
    (pattern ((~datum Block)
              exprs:ExprClass ...)))

  ; Name : IDENTIFIER-TOK
  (define-syntax-class NameClass
    (pattern ((~datum Name)
              name:id)))

  ; NameList : @Name
  ;          | @Name /COMMA-TOK @NameList
  (define-syntax-class NameListClass
    (pattern ((~datum NameList)
              names:id ...)))

  ; QualName : (THIS-TOK /SLASH-TOK)? (@Name /SLASH-TOK)* @Name | INT-TOK | SUM-TOK
  (define-syntax-class QualNameClass
    #:attributes (name)
    (pattern ((~datum QualName)
              (~optional "this") ; TODO, allow more complex qualnames
              (~seq prefixes:id ...)
              raw-name:id)
      #:attr name #'raw-name)
    (pattern ((~datum QualName) "Int")
      #:attr name #'(raise "Int as qualname?"))
    (pattern ((~datum QualName) "sum")
      #:attr name #'(raise "sum as qualname?")))

  ; QualNameList : @QualName
  ;              | @QualName /COMMA-TOK @QualNameList
  (define-syntax-class QualNameListClass
    (pattern ((~datum QualNameList)
              (~or (~seq (~optional "this")
                         (~seq prefixes:id ...)
                         name:id)
                   "Int"
                   "sum") ...)))

  ; Number : NUM-CONST-TOK
  (define-syntax-class NumberClass
    (pattern ((~datum Number) n)
      #:attr value #'n))

  ; SexprDecl : Sexpr
  (define-syntax-class SexprDeclClass
    (pattern ((~datum SexprDecl) exp:SexprClass)))

  ; Sexpr : SEXPR-TOK
  (define-syntax-class SexprClass
    (pattern ((~datum Sexpr) exp)))

  ; InstDecl : /INST-TOK Name Bounds Scope?
  (define-syntax-class InstDeclClass
    (pattern ((~datum InstDecl)
              name:NameClass
              bounds:BoundsClass
              (~optional scope:ScopeClass))))

  ; RelDecl : ArrowDecl
  (define-syntax-class RelDeclClass
    (pattern ((~datum RelDecl) decl:ArrowDeclClass)))

  ; Parameters : /LeftAngle @QualNameList /RightAngle 
  (define-syntax-class ParametersClass
    (pattern ((~datum Parameters)
              name:QualNameClass ...)))

  ; Bounds : EXACTLY-TOK? @ExprList
  ;        | EXACTLY-TOK? @Block
  (define-syntax-class BoundsClass
    (pattern ((~datum Bounds)
              (~optional "exactly")
              exprs:ExprClass ...)
      #:attr translate (datum->syntax #'(exprs ...)
                                      (syntax->list #'(exprs ...)))))

  ; EXPRESSIONS

  ; Const : NONE-TOK | UNIV-TOK | IDEN-TOK
  ;       | MINUS-TOK? Number 
  (define-syntax-class ConstClass
    #:attributes (translate)
    (pattern ((~datum Const) "none")
      #:attr translate (syntax/loc this-syntax none))
    (pattern ((~datum Const) "univ")
      #:attr translate (syntax/loc this-syntax univ))
    (pattern ((~datum Const) "iden")
      #:attr translate (syntax/loc this-syntax iden))
    (pattern ((~datum Const) n:NumberClass)
      #:attr translate (syntax/loc this-syntax (int n.value)))
    (pattern ((~datum Const) "-" n:NumberClass)
      #:attr translate (quasisyntax/loc this-syntax (int #,(* -1 (syntax->datum #'n.value))))))

  ; ArrowOp : (@Mult | SET-TOK)? ARROW-TOK (@Mult | SET-TOK)?
  ;         | STAR-TOK
  (define-syntax-class ArrowOpClass
    (pattern ((~datum ArrowOp)
              (~optional (~or "lone" "some" "one" "two" "set"))
              "->"
              (~optional (~or "lone" "some" "one" "two" "set"))))
    (pattern ((~datum ArrowOp) "*")))

  ; CompareOp : IN-TOK | EQ-TOK | LT-TOK | GT-TOK | LEQ-TOK | GEQ-TOK | EQUIV-TOK | IS-TOK | NI-TOK
  (define-syntax-class CompareOpClass
    (pattern ((~datum CompareOp)
              (~and op
                    (~or "in" "=" "<" ">" "<=" ">="
                         "is" "ni")))
      #:attr symbol (datum->syntax #'op (string->symbol (syntax->datum #'op)))))

  ; LetDecl : @Name /EQ-TOK Expr
  (define-syntax-class LetDeclClass
    (pattern ((~datum LetDecl)
              name:id
              exp:ExprClass)
      #:attr translate (with-syntax ([exp #'exp]) 
                         #'(name exp))))

  ; LetDeclList : LetDecl
  ;             | LetDecl /COMMA-TOK @LetDeclList
  (define-syntax-class LetDeclListClass
    (pattern ((~datum LetDeclList)
              decls:LetDeclClass ...)
      #:attr translate #'(decls.translate ...)))

  ; BlockOrBar : Block | BAR-TOK Expr
  (define-syntax-class BlockOrBarClass
      #:attributes (exprs)
    (pattern ((~datum BlockOrBar) block:BlockClass)
      #:attr exprs #'block)
    (pattern ((~datum BlockOrBar) "|" exp:ExprClass)
      #:attr exprs #'exp))

  ; Quant : ALL-TOK | NO-TOK | SUM-TOK | @Mult
  (define-syntax-class QuantClass
    (pattern ((~datum Quant) (~and q (~or "all" "no" "lone"
                                            "some" "one" "two")))
      #:attr symbol (datum->syntax #'q
                                   (string->symbol (syntax->datum #'q))))
    (pattern ((~datum Quant) (~literal sum))
      #:attr symbol (syntax/loc #'q sum-quant)))

  (define-syntax-class ExprClass
    (pattern ((~or (~datum Expr) (~datum Expr1) (~datum Expr2) (~datum Expr3)
                   (~datum Expr4) (~datum Expr4.5) (~datum Expr5) (~datum Expr6) (~datum Expr7) (~datum Expr7.5)
                   (~datum Expr8) (~datum Expr9) (~datum Expr10) (~datum Expr11)
                   (~datum Expr12) (~datum Expr13) (~datum Expr14) (~datum Expr15)
                   (~datum Expr16) (~datum Expr17))
             _ ...)))

  ; ExprList : Expr
  ;          | Expr /COMMA-TOK @ExprList
  (define-syntax-class ExprListClass
    (pattern ((~datum ExprList)
              exprs:ExprClass ...))))



; AlloyModule : ModuleDecl? Import* Paragraph*
;             | EvalDecl*
(define-syntax (AlloyModule stx)    
  (syntax-parse stx
    [((~datum AlloyModule) (~optional module-decl:ModuleDeclClass)
                             (~seq import:ImportClass ...)
                             (~seq paragraph:ParagraphClass ...))
     (syntax/loc stx
       (begin
         (~? module-decl)
         import ...
         paragraph ...))]
    [((~datum AlloyModule) ((~datum EvalDecl) "eval" expr:ExprClass))
     (syntax/loc stx expr)]
    [((~datum AlloyModule) ((~datum EvalDecl) "eval" expr:ExprClass) ...+)
     (syntax/loc stx (raise "Can't eval multiple expressions."))]))

; ModuleDecl : /MODULE-TOK QualName (LEFT-SQUARE-TOK NameList RIGHT-SQUARE-TOK)?
(define-syntax (ModuleDecl stx)
  (syntax-parse stx 
    [((~datum ModuleDecl) module-name:QualNameClass
                            (~optional (~seq "[" other-names:NameListClass "]")))
     (syntax/loc stx (raise "ModuleDecl not yet implemented."))]))


; Import : OPEN-TOK QualName (LEFT-SQUARE-TOK QualNameList RIGHT-SQUARE-TOK)? (AS-TOK Name)?
(define-syntax (Import stx)
  (syntax-parse stx
      [((~datum Import) file-path:str
                          (~optional (~seq "as" as-name:NameClass)))
       (syntax/loc stx (begin
           (~? (require (prefix-in as-name.name file-path))
               (require file-path))))]
    [((~datum Import) import-name:QualNameClass
                        (~optional (~seq "[" other-names:QualNameListClass "]"))
                        (~optional (~seq "as" as-name:NameClass)))
     (syntax/loc stx (begin
         (raise (format "Importing packages not yet implemented: ~a." 'import-name))
         (~? (raise (format "Bracketed import not yet implemented. ~a" 'other-names)))
         (~? (raise (format "Importing as not yet implemented. ~a" 'as-name)))))]))
  
; SigDecl : VAR-TOK? ABSTRACT-TOK? Mult? /SIG-TOK NameList SigExt? /LEFT-CURLY-TOK ArrowDeclList? /RIGHT-CURLY-TOK Block?
(define-syntax (SigDecl stx)
  (syntax-parse stx
    [((~datum SigDecl) (~optional isv:VarKeywordClass #:defaults ([isv #'#f]))
                         (~optional abstract:abstract-tok)
                         (~optional mult:MultClass)
                         sig-names:NameListClass
                         ;when extending with in is implemented,
                         ;if "sig A in B extends C" is allowed,
                         ;check if this allows multiple SigExtClasses / how to do that if not
                         ;note the parser currently does not allow that
                         (~optional extends:SigExtClass)
                         (~optional block:BlockClass))
     (syntax/loc stx (begin
       (~? (raise (format "Sig block not yet implemented: ~a" 'block)))
       ;when extending with in is implemented,
       ;if "sig A in B extends C" is allowed,
       ;check if this allows that and update if needed
       ;note the parser currently does not allow that
       (sig (#:lang (get-check-lang)) sig-names.names (~? mult.symbol)
                            (~? abstract.symbol)
                            (~? (~@ #:is-var isv))
                            (~? (~@ extends.symbol extends.value))) ...))]

    [((~datum SigDecl) (~optional isv:VarKeywordClass #:defaults ([isv #'#f]))
                         (~optional abstract:abstract-tok)
                         (~optional mult:MultClass)
                         sig-names:NameListClass
                         ;when extending with in is implemented,
                         ;if "sig A in B extends C" is allowed,
                         ;check if this allows multiple SigExtClasses / how to do that if not
                         ;note the parser currently does not allow that
                         (~optional extends:SigExtClass)
                         ((~datum ArrowDeclList) arrow-decl:ArrowDeclClass ...)
                         (~optional block:BlockClass))
     (quasisyntax/loc stx (begin
       (~? (raise (format "Sig block not yet implemented: ~a" 'block)))
       ;when extending with in is implemented,
       ;if "sig A in B extends C" is allowed,
       ;check if this allows that and update if needed
       ;note the parser currently does not allow that
       #,@(for/list ([sig-name (syntax-e #'(sig-names.names ...))])
            (with-syntax ([sig-name-p0 sig-name])
              (syntax/loc sig-name
                (sig (#:lang (get-check-lang)) sig-name-p0 (~? mult.symbol)
                     (~? abstract.symbol)
                     (~? (~@ #:is-var isv))
                     (~? (~@ extends.symbol extends.value))))))
       #,@(apply append
            ; for each sig in this declaration (e.g., "sig A, B, C { ...")
            (for/list ([sig-name (syntax->list #'(sig-names.names ...))]
                       #:when #t
                       [relation-names (syntax->list #'(arrow-decl.names ...))]
                       [relation-types (syntax->list #'(arrow-decl.types ...))]
                       [relation-is-var (syntax->list #'(arrow-decl.is-var ...))]
                       [relation-mult (syntax->list #'((~? arrow-decl.mult default) ...))])
              ; for each field declared
              (for/list ([relation-name-p1 (syntax->list relation-names)])
                (with-syntax ([relation-name relation-name-p1]
                              [relation-types (datum->syntax relation-types 
                                                             (cons sig-name ;(syntax->datum sig-name)
                                                                   (syntax->list relation-types)))]                          
                              [relation-mult relation-mult]
                              [is-var relation-is-var])
                      (syntax/loc relation-name-p1 (relation (#:lang (get-check-lang)) relation-name relation-types #:is relation-mult #:is-var is-var))))))))]))
   
; RelDecl : ArrowDecl
(define-syntax (RelDecl stx)
  (syntax-parse stx
  [((~datum RelDecl) arrow-decl:ArrowDeclClass)
   (quasisyntax/loc stx (begin
   #,@(for/list ([name (syntax->list #'arrow-decl.names)])
        (with-syntax ([name name])
          (syntax/loc stx (relation (#:lang (get-check-lang)) name arrow-decl.types))))))]))

; FactDecl : FACT-TOK Name? Block
(define-syntax (FactDecl stx)
  (syntax-parse stx
  [((~datum FactDecl) _ ...)
   (syntax/loc stx (raise "Facts are not allowed in #lang forge."))]))

; PredDecl : /PRED-TOK (QualName DOT-TOK)? Name ParaDecls? Block
(define-syntax (PredDecl stx)
  (syntax-parse stx
  [((~datum PredDecl) (~optional pt:PredTypeClass)
                        (~optional (~seq prefix:QualNameClass "."))
                        name:NameClass
                        block:BlockClass)
   (with-syntax ([block #'block])
     (quasisyntax/loc stx (begin
       (~? (raise (format "Prefixes not allowed: ~a" 'prefix)))
       ; preserve stx location in Racket *sub*expression
       #,(syntax/loc stx (pred (~? pt.kw) (#:lang (get-check-lang)) name.name block)))))]

  [((~datum PredDecl) (~optional pt:PredTypeClass)
                        (~optional (~seq prefix:QualNameClass "."))
                        name:NameClass
                        decls:ParaDeclsClass
                        block:BlockClass)
   (with-syntax ([decl (datum->syntax #'name (cons (syntax->datum #'name.name)
                                                   (syntax->list #'decls.translate)))]
                 [block #'block])
     (quasisyntax/loc stx (begin
       (~? (raise (format "Prefixes not allowed: ~a" 'prefix)))
       ; preserve stx location in Racket *sub*expression
       #,(syntax/loc stx (pred (~? pt.kw) (#:lang (get-check-lang)) decl block)))))]))

; FunDecl : /FUN-TOK (QualName DOT-TOK)? Name ParaDecls? /COLON-TOK Expr Block
(define-syntax (FunDecl stx)
  (syntax-parse stx
  [((~datum FunDecl) (~optional (~seq prefix:QualNameClass "."))
                       name:NameClass
                       output:ExprClass
                       body:ExprClass)
   (with-syntax ([body #'body])
     (syntax/loc stx (begin
       (~? (raise (format "Prefixes not allowed: ~a" 'prefix)))
       (const name.name body))))]

  [((~datum FunDecl) (~optional (~seq prefix:QualNameClass "."))
                       name:NameClass
                       decls:ParaDeclsClass
                       output:ExprClass
                       body:ExprClass)
   (with-syntax ([decl (datum->syntax #'name (cons (syntax->datum #'name.name)
                                                   (syntax->list #'decls.translate)))]
                 [body #'body])
     (syntax/loc stx (begin
       (~? (raise (format "Prefixes not allowed: ~a" 'prefix)))
       (fun decl body))))]))

; AssertDecl : /ASSERT-TOK Name? Block
(define-syntax (AssertDecl stx)
  (syntax-parse stx
  [((~datum AssertDecl) _ ...)
   (syntax/loc stx (raise "Assertions not yet implemented."))]))

(define-for-syntax make-temporary-name
  (let ((name-counter (box 1)))
    (lambda (stx)
      (define curr-num (unbox name-counter))
      (set-box! name-counter (+ 1 curr-num))
      (define source_disambiguator
        (if (and (source-location-source stx)
                 (file-name-from-path (source-location-source stx)))
            (path-replace-extension (file-name-from-path (source-location-source stx)) #"")
            "unknown"))      
      (string->symbol (format "temporary-name_~a_~a" source_disambiguator curr-num)))))

; CmdDecl :  (Name /COLON-TOK)? (RUN-TOK | CHECK-TOK) Parameters? (QualName | Block)? Scope? (/FOR-TOK Bounds)?
(define-syntax (CmdDecl stx)
  (syntax-parse stx
  [((~datum CmdDecl) (~optional name:NameClass)
                       (~and cmd-type (~or "run" "check"))
                       (~optional parameters:ParametersClass)
                       (~optional (~or pred:QualNameClass
                                       preds:BlockClass))
                       (~optional scope:ScopeClass)
                       (~optional bounds:BoundsClass))
   (with-syntax ([cmd-type (datum->syntax #'cmd-type
                                         (string->symbol (syntax->datum #'cmd-type)))]
                 [name #`(~? name.name #,(make-temporary-name stx))]
                 [preds #'(~? pred.name preds)])
    #`(begin
       #,(syntax/loc stx (cmd-type name (~? (~@ #:preds [preds]))
                      (~? (~@ #:scope scope.translate))
                      (~? (~@ #:bounds bounds.translate))))
       #,(syntax/loc stx (display name))))]))

; TestDecl : (Name /COLON-TOK)? Parameters? (QualName | Block)? Scope? (/FOR-TOK Bounds)? /IS-TOK (SAT-TOK | UNSAT-TOK)
(define-syntax (TestDecl stx)
  (syntax-parse stx
  [((~datum TestDecl) (~optional name:NameClass)
                        (~optional parameters:ParametersClass)
                        (~optional (~or pred:QualNameClass
                                        preds:BlockClass))
                        (~optional scope:ScopeClass)
                        (~optional bounds:BoundsClass)
                        (~and expected (~or "sat" "unsat" "theorem")))
   (with-syntax ([name #`(~? name.name #,(make-temporary-name stx))]
                 [preds #'(~? pred.name preds)]
                 [expected (datum->syntax #'expected
                                          (string->symbol (syntax->datum #'expected)))])
     (syntax/loc stx
       (test name (~? (~@ #:preds [preds]))
                  (~? (~@ #:scope scope.translate))
                  (~? (~@ #:bounds bounds.translate))
                  #:expect expected)))]))

; TestExpectDecl : TEST-TOK? EXPECT-TOK Name? TestBlock
(define-syntax (TestExpectDecl stx)
  (syntax-parse stx
  [((~datum TestExpectDecl) (~optional (~and "test" test-tok))
                              "expect" 
                              (~optional name:NameClass)
                              block:TestBlockClass)
   (if (attribute test-tok)
       (syntax/loc stx (begin block.test-decls ...))
       (syntax/loc stx (begin)))]))


(define-syntax (PropertyDecl stx)
  (syntax-parse stx
  [pwd:PropertyDeclClass 
   #:with imp_total (if (eq? (syntax-e #'pwd.constraint-type) 'sufficient)
                        (syntax/loc stx (implies pwd.prop-name pwd.pred-name))  ;; p => q : p is a sufficient condition for q 
                        (syntax/loc stx (implies pwd.pred-name pwd.prop-name))) ;; q => p : p is a necessary condition for q
   #:with test_name (format-id stx "Assertion_~a_is_~a_for_~a" #'pwd.prop-name #'pwd.constraint-type #'pwd.pred-name)
   (syntax/loc stx
      (test
        test_name
        #:preds [imp_total]
        #:scope pwd.scope
        #:bounds pwd.bounds
        #:expect theorem ))]))


;; Quick and dirty static check to ensure a test
;; references a predicate.

;; A potential improvement is to break apart test-expect
;; blocks and examine each test.

(define-for-syntax (ensure-target-ref target-pred ex)
  (define tp (syntax-e target-pred))
  (let ([ex-as-datum (syntax->datum ex)])
    (unless 
      (memq tp (flatten ex-as-datum))
      (eprintf  "Warning: ~a ~a:~a Test does not reference ~a.\n" 
        (syntax-source ex) (syntax-line ex) (syntax-column ex)  tp))))


(define-syntax (TestSuiteDecl stx)
  (syntax-parse stx
  [tsd:TestSuiteDeclClass 
   
    ;; Static checks on test blocks go here.
   (for ([tc (syntax->list #'(tsd.test-constructs ...))])
        (ensure-target-ref #'tsd.pred-name tc))

   (syntax/loc stx
    (begin tsd.test-constructs ...))]))


(define-syntax (ExampleDecl stx)
  (syntax-parse stx
  [((~datum ExampleDecl) (~optional name:NameClass)
                           pred:ExprClass
                           bounds:BoundsClass)
   (quasisyntax/loc stx
     (example (~? name.name unnamed-example)
       pred
       (syntax-parameterize ([current-forge-context 'example])
         (list #,@(syntax/loc stx bounds.translate)))))]))

; OptionDecl : /OPTION-TOK QualName (QualName | FILE-PATH-TOK | Number)
(define-syntax (OptionDecl stx)
  (syntax-parse stx
  [dec:OptionDeclClass
   ; Some options contain file paths. By saving the path of the .frg file at a point
   ; we still have it, we can let (e.g.) option solver work even if racket is invoked
   ; from outside the folder containing the .frg file.
   (quasisyntax/loc stx (set-option! 'dec.n 'dec.v #:original-path #,(current-load-relative-directory)))
   ]))

; InstDecl : /INST-TOK Name Bounds Scope?
(define-syntax (InstDecl stx)
  (syntax-parse stx
  [((~datum InstDecl)
              name:NameClass
              bounds:BoundsClass
              (~optional scope:ScopeClass))
   (quasisyntax/loc stx
     (begin
       (~? (raise (format "Scope not implemented for InstDecl ~a" 'scope)))
       (inst name.name
             (syntax-parameterize ([current-forge-context 'inst])
               (list #,@(syntax/loc stx bounds.translate))))))]))

(define (disambiguate-block xs)
  (cond [(empty? xs) 
         ; {} always means the formula true
         true]
         ; Body of a helper function
        [(and (equal? 1 (length xs)) (node/expr? (first xs)))
         (first xs)]
        [(node/formula? (first xs))
         (&& xs)]         
        [(and (equal? 1 (length xs)) (node/int? (first xs)))
         (first xs)]         
        [else 
         (raise-user-error (format "~a" (first xs)) (format "Ill-formed block"))]))

; Block : /LEFT-CURLY-TOK Expr* /RIGHT-CURLY-TOK
(define-syntax (Block stx)
  (syntax-parse stx
    [((~datum Block) exprs:ExprClass ...)
     (with-syntax ([(exprs ...) (syntax->list #'(exprs ...))])
       (syntax/loc stx (disambiguate-block (list exprs ...))))]))

(define-syntax (Expr stx)
  (syntax-parse stx
  [((~datum Expr) "let" decls:LetDeclListClass bob:BlockOrBarClass)
   (syntax/loc stx (let decls.translate bob.exprs))]

  [((~datum Expr) "bind" decls:LetDeclListClass bob:BlockOrBarClass)
   (syntax/loc stx (raise "bind not implemented."))]

  [((~datum Expr) q:QuantClass decls:DeclListClass bob:BlockOrBarClass)
   (syntax/loc stx (q.symbol decls.translate bob.exprs))] ; stx, not #'q

  [((~datum Expr) q:QuantClass "disj" decls:DeclListClass bob:BlockOrBarClass)
   (syntax/loc stx (q.symbol #:disj decls.translate bob.exprs))] ; stx, not #'q

  [((~datum Expr) expr1:ExprClass (~or "or" "||") expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (|| expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass (~or "iff" "<=>") expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (iff (#:lang (get-check-lang)) expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass (~or "implies" "=>") expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])     
     (syntax/loc stx (implies (#:lang (get-check-lang)) expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass (~or "implies" "=>") expr2:ExprClass
                                    "else" expr3:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)]
                 [expr3 (my-expand #'expr3)])
     (syntax/loc stx (ifte expr1 expr2 expr3)))]

  [((~datum Expr) expr1:ExprClass (~or "and" "&&") expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (&& expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass (~or "releases") expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (releases expr1 expr2)))]
  [((~datum Expr) expr1:ExprClass (~or "until") expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (until expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass (~or "since") expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (since expr1 expr2)))]
  [((~datum Expr) expr1:ExprClass (~or "triggered") expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (triggered expr1 expr2)))]

    
  [((~datum Expr) (~or "!" "not") expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (! (#:lang (get-check-lang)) expr1)))]

  [((~datum Expr) (~or "always") expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (always expr1)))]
  [((~datum Expr) (~or "eventually") expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (eventually expr1)))]
  [((~datum Expr) (~or "next_state") expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
       (syntax/loc stx (next_state expr1)))]

  [((~datum Expr) (~or "historically") expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (historically expr1)))]
  [((~datum Expr) (~or "once") expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (once expr1)))]
  [((~datum Expr) (~or "prev_state") expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
       (syntax/loc stx (prev_state expr1)))]       
    
  [((~datum Expr) expr1:ExprClass op:CompareOpClass expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)]
                 [op #'op.symbol])
     (syntax/loc stx (op (#:lang (get-check-lang)) expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass 
                    (~or "!" "not") op:CompareOpClass 
                    expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)]
                 [op #'op.symbol])
     ; Need to preserve srcloc in both the "not" and the "op" nodes
     (quasisyntax/loc stx (! #,(syntax/loc stx (op (#:lang (get-check-lang)) expr1 expr2)))))]

  [((~datum Expr) (~and (~or "no" "some" "lone" "one" "two" "set")
                          op)
                    expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [op (datum->syntax #'op (string->symbol (syntax->datum #'op)))])
     (syntax/loc stx (op (#:lang (get-check-lang)) expr1)))]

  [((~datum Expr) "#" expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (card (#:lang (get-check-lang)) expr1)))]

  ; Semantic priming as in Electrum
  [((~datum Expr) expr1:ExprClass "'")
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (prime (#:lang (get-check-lang)) expr1)))]

  [((~datum Expr) expr1:ExprClass "+" expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)]
                 [check-lang (if (forge-context=? '(inst example))
                               #''forge
                               #'(get-check-lang))])
     (syntax/loc stx (+ (#:lang check-lang) expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass "-" expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (- (#:lang (get-check-lang)) expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass "++" expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (++ (#:lang (get-check-lang)) expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass "&" expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (& (#:lang (get-check-lang)) expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass op:ArrowOpClass expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)]
                 [check-lang (if (forge-context=? '(inst example))
                               #''forge
                               #'(get-check-lang))])
     (syntax/loc stx (-> (#:lang check-lang) expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass ":>" expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (:> (#:lang (get-check-lang)) expr1 expr2)))]

  [((~datum Expr) expr1:ExprClass "<:" expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (<: (#:lang (get-check-lang)) expr1 expr2)))]

  [((~datum Expr) "[" exprs:ExprListClass "]")
   (syntax/loc stx (raise (format "Unimplemented ~a" exprs)))]

  [((~datum Expr) expr1:ExprClass "." expr2:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [expr2 (my-expand #'expr2)])
     (syntax/loc stx (join (#:lang (get-check-lang)) expr1 expr2)))]

  [((~datum Expr) name:NameClass "[" exprs:ExprListClass "]")
   (with-syntax ([name #'name.name]
                 [(exprs ...) (datum->syntax #f (map my-expand (syntax->list #'(exprs.exprs ...))))])
     (syntax/loc stx (name exprs ...)))]

  [((~datum Expr) expr1:ExprClass "[" exprs:ExprListClass "]")
   (with-syntax ([expr1 (my-expand #'expr1)]
                 [(exprs ...) (datum->syntax #f (map my-expand (syntax->list #'(exprs.exprs ...))))])
     (syntax/loc stx (expr1 exprs ...)))]

  [((~datum Expr) "~" expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (~ (#:lang (get-check-lang)) expr1)))]

  [((~datum Expr) "^" expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (^ (#:lang (get-check-lang)) expr1)))]

  [((~datum Expr) "*" expr1:ExprClass)
   (with-syntax ([expr1 (my-expand #'expr1)])
     (syntax/loc stx (* (#:lang (get-check-lang)) expr1)))]

  [((~datum Expr) const:ConstClass)   
   (syntax/loc stx const.translate)]

  [((~datum Expr) name:QualNameClass)
   (syntax/loc stx name.name)]

  [((~datum Expr) "this")
   (syntax/loc stx this)]

  [((~datum Expr) "`" name:NameClass)
   (syntax/loc stx (atom 'name.name))]
  
  [((~datum Expr) "{" decls:DeclListClass bob:BlockOrBarClass "}")
   (syntax/loc stx (set (#:lang (get-check-lang))  decls.translate bob.exprs))]

  [((~datum Expr) block:BlockClass)
   (my-expand (syntax/loc stx block))]

  [((~datum Expr) sexpr:SexprClass)
   (syntax/loc stx (read sexpr))]))

; --------------------------
; these used to be define-simple-macro, but define-simple-macro doesn't
; preserve syntax location, so we copy the definition from the docs except use syntax/loc.

(define-syntax (dsm-keep stx-outer)
  (syntax-case stx-outer ()
    [(_ (macro-id . pattern) pattern-directive ... template)
     (with-syntax ([ellip '...])
       (syntax/loc stx-outer
         (define-syntax (macro-id stx)
           (syntax-parse stx
             #:track-literals
             [((~var macro-id id) . pattern) pattern-directive ... (syntax/loc stx template)]))))]))


(dsm-keep (Expr1 stx ...) (Expr stx ...))
(dsm-keep (Expr2 stx ...) (Expr stx ...))
(dsm-keep (Expr3 stx ...) (Expr stx ...))
(dsm-keep (Expr4 stx ...) (Expr stx ...))
(dsm-keep (Expr4.5 stx ...) (Expr stx ...))
(dsm-keep (Expr5 stx ...) (Expr stx ...))
(dsm-keep (Expr6 stx ...) (Expr stx ...))
(dsm-keep (Expr7 stx ...) (Expr stx ...))
(dsm-keep (Expr7.5 stx ...) (Expr stx ...))
(dsm-keep (Expr8 stx ...) (Expr stx ...))
(dsm-keep (Expr9 stx ...) (Expr stx ...))
(dsm-keep (Expr10 stx ...) (Expr stx ...))
(dsm-keep (Expr11 stx ...) (Expr stx ...))
(dsm-keep (Expr12 stx ...) (Expr stx ...))
(dsm-keep (Expr13 stx ...) (Expr stx ...))
(dsm-keep (Expr14 stx ...) (Expr stx ...))
(dsm-keep (Expr15 stx ...) (Expr stx ...))
(dsm-keep (Expr16 stx ...) (Expr stx ...))
(dsm-keep (Expr17 stx ...) (Expr stx ...))





; Transition System Stuff to be implemented
; StateDecl : STATE-TOK /LEFT-SQUARE-TOK QualName /RIGHT-SQUARE-TOK 
;     (QualName DOT-TOK)? Name ParaDecls? Block
; TransitionDecl : TRANSITION-TOK /LEFT-SQUARE-TOK QualName /RIGHT-SQUARE-TOK 
;     (QualName DOT-TOK)? Name ParaDecls? Block
; TraceDecl : TRACE-TOK Parameters
;     (QualName DOT-TOK)? Name ParaDecls? (/COLON-TOK Expr)? Block
; LeftAngle : LT-TOK | LEFT-TRIANGLE-TOK
; RightAngle: GT-TOK | RIGHT-TRIANGLE-TOK


; Other things (to be implemented?)
; NumberList : Number
;            | Number /COMMA-TOK @NumberList

; BreakDecl : /FACT-TOK /BREAK-TOK? Expr /COLON-TOK @NameList
;           | /BREAK-TOK Expr /COLON-TOK @NameList
; InstanceDecl : INSTANCE-TOK
; QueryDecl : @Name /COLON-TOK ArrowExpr /EQ-TOK Expr
