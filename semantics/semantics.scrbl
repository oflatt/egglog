#lang scribble/manual

@(require racket/match)
@(require scribble-math/dollar redex)
@(require "semantics.rkt")
@(require (except-in pict table))
@(require scribble/core
          scribble/html-properties
          racket/runtime-path
          (only-in xml cdata))

@(define head-google
  (head-extra (cdata #f #f "<link rel=\"stylesheet\"
          href=\"https://fonts.googleapis.com/css?family=Nunito+Sa
          ns\">")))

@(define-runtime-path css-path "style.css")
@(define css-object (css-addition css-path))

@(define html5-style
   (with-html5 manual-doc-style))
@(define title-style
   (struct-copy style html5-style
                [properties
                 (append
                  (style-properties html5-style)
                  (list css-object head-google))]))

@(reduction-relation-rule-separation 10)
@(metafunction-rule-gap-space 10)
@(non-terminal-gap-space 10) 

@(define (set-notation lws)
  (match lws
    [`(,paren ,tset ,elements ... ,paren2)
      (append  `("" "{")
                (if (equal? (length elements) 0)
                    (list
                    (struct-copy lw tset
                      [e (blank)]))
                    (list))
                elements
                `("}" ""))]
    [else (error "bad tset")]))

@(define (add-between lst element)
   (apply append
    (for/list ([ele lst]
               [i (in-range (length lst))])
      (if (zero? i)
          (list ele)
          (list element ele)))))

@(define (set-union-notation lws)
  (match lws
    [`(,paren ,func-call ,elements ... ,paren2)
      (append `("") (add-between elements "∪") `(""))]))

@(define (set-element-notation lws)
  (match lws
    [`(,paren ,func-call ,element1 ,element2 ,paren2)
      `("" ,element1 " ∈ " ,element2 "")]))

@(define (set-subset-notation lws)
  (match lws
    [`(,paren ,func-call ,element1 ,element2 ,paren2)
      `("" ,element1 " ⊆ " ,element2 "")]))

@(define (my-render-reduction-relation reduction-relation)
  (render
   (lambda ()
    (render-reduction-relation reduction-relation))))

@(define (my-render-language language)
  (render
   (lambda ()
    (render-language language))))

@(define-syntax-rule (my-render-judgement judgement)
  (render
   (lambda ()
    (render-judgment-form judgement))))

@(define (all-valid-query-subst-notation lws)
  (match lws
    [`(,paren ,func-call ,elements ... ,paren2)
      (append 
        `("" "{Env s.t. (valid-query-subst ")
         elements
         `(" Env)}" ""))]))

@(define-syntax-rule (my-render-metafunction metafunction)
  (render
   (lambda ()
    (render-metafunction metafunction))))

@(define (render func)
  (parameterize ([rule-pict-style 'compact-vertical]
                 [metafunction-pict-style 'left-right/vertical-side-conditions]
                 [metafunction-fill-acceptable-width 10])
    (with-compound-rewriters
     (['tset set-notation]
      ['congr set-notation]
      ['vars-union set-union-notation]
      ['tset-union set-union-notation]
      ['tset-element set-element-notation]
      ['tset-is-subset set-subset-notation]
      ['congr-subset set-subset-notation]
      ['all-valid-query-subst all-valid-query-subst-notation])
     (func))))


@title[#:style  title-style]{ Egglog Semantics }

@section{Egglog Grammar}

@(parameterize ([render-language-nts (remove 'ReservedSymbol (language-nts Egglog))])
  (my-render-language Egglog))

An egglog @code{Program} is a sequence of top-level @code{Cmd}s.
Egglog keeps track of a global @code{Database}
as it runs.
An @code{Action} adds directly to the database.
A @code{Rule} is added to the list of rules,
and a @code{(run)} statement runs the rules.

Rules have two parts: a @code{Query} and @code{Actions}.
The @code{Query} is a set of patterns that must
match terms in the database for the rule to fire.
The @code{Actions} add to the database for every valid match.

@;; don't include stuff about typechecking
@;; since we don't do it yet
@(parameterize ([render-language-nts
                (remove* `(Type TypeEnv TypeBinding) (language-nts Egglog+Database))])
  (my-render-language Egglog+Database))

Egglog's global state is a @code{Database}, containing:
@itemlist[
 @item{A set of @code{Terms}}
 @item{A set of equalities @code{Congr}, which forms a congruence closure}
 @item{A set of global bindings @code{Env}}
 @item{A set of rules @code{Rules}, which are run when @code{(run)} is called}
]

Running an @code{Action} may add terms and equalities to the database.
In-between each command, the congruence closure over these terms is completed.

@section{Running Commands}

Egglog's top-level reduction relation @-->_Program runs a sequence of commands.
Notice that between running commands, egglog restores the congruence relation (see section on restoring congruence).

@(define stepped
  (hc-append 10
   (render-term Egglog
    (Cmd_1 Database_1))
   -->_Command
   (render-term Egglog
    (Cmd_stepped Database_2))))
    
@(with-unquote-rewriter
  (lambda (old)
    (struct-copy lw old
      [e stepped]))
  (my-render-reduction-relation Egglog-Reduction))

The @-->_Command reduction relation defines
how each of these commands is run.

@(my-render-reduction-relation Command-Reduction)

The next two sections will cover evaluating actions (@code{Eval-Actions}) and evaluating
queries (@code{Rule-Envs}).

@section{Evaluating Actions}

Given an evironment @code{Env}, egglog's
expressions construct a single term.
The @code{Lookup} function looks up a term
in the environment, given the variable.

@(my-render-metafunction Eval-Expr)

Egglog's actions add new terms and equalities to
the global database.
An action is either a let binding,
an expression,
or a union between two expressions.
At the top level, let bindings add new global
variables to the environment.
In the actions of a rule, let bindings add
new local variables.

The resulting database after evaluating expressions may not contain all intermediate terms.
These are added when the congruence closure
is restored.

@(my-render-metafunction Eval-Action)


Evaluating a sequence of actions is done
by evaluating each action in turn.
Since actions only add terms to the set of terms
and equalities to the congruence relation,
the order of evaluation of these actions
does not matter (besides needing variables to be bound first).

@(my-render-metafunction Eval-Global-Actions)

In order to evaluate local actions for
a rule, we evaluate the actions in the global
scope, then forget the resulting environment.

@(my-render-metafunction Eval-Local-Actions)

Given a set of substitutions from running a rule's query, we can evaluate
a rule's actions by applying the actions 
multiple times, once for each substitution.

@(my-render-metafunction Eval-Actions)

The @(rterm U_d) function is a database-union function. It takes two databases and unions the terms, equalities, environments, and rules.

@(my-render-metafunction U_d)

The @(rterm Dedup) metafunction removes duplicates from sets.

@section{Evaluating Queries}

To evaluate a rule, egglog first finds
all valid substitutions for the rule's @code{Query}.

@(my-render-metafunction Rule-Envs)

The @code{valid-query-subst} judgement defines
which environments (also called substitutions) are valid for a query.
An environment @(rterm Env_r) is valid for a query if it is valid for each pattern in the query.
The @(rterm Env-Union) metafunction ensures that the environments for each
pattern are compatible: if they share variable
bindings, they must be bound to the same term.


@(my-render-judgement valid-query-subst)


The @code{valid-subst} judgement defines
when a substitution is valid for a pattern.
It states these conditions:

@itemlist[
  @item{@(rterm Env_subst) is a valid environment mapping free variables in the pattern to grounded terms in the database}
  @item{There exists a witness term @(rterm Term_witness) in the database}
  @item{Evaluating the pattern with the substitution results in another term @(rterm Term_res)}
  @item{@(rterm Term_res) is equal to @(rterm Term_witness) using the congruence closure.}
]

We say that the pattern and substitution `e-matches` the witness term.

@(my-render-judgement valid-subst)

@(rterm free-vars) returns the set of free variables of a pattern.
Valid-env defines the set of valid environments
mapping free variables to grounded terms.

@(my-render-judgement valid-env)



@section{Restoring Congruence}

In-between every command, egglog restores
the congruence closure using
the axioms of congruence closure.
It also uses a a "presence of children" axiom to ensure
all terms, including their children, are present
in the congruence closure.


@(my-render-reduction-relation Congruence-Reduction)

The restore-congruence metafunction applies
the Congruence-Reduction until a fixed point.

@(my-render-metafunction restore-congruence)


@section{To Do}

This semantics is not yet complete, and does not
cover everything egglog can do.


@itemlist[
 @item{Type checking: egglog enforces well-typed terms and rules, and supports
 primitives}
 @item{Seminaive evaluation: Egglog doesn't actually return all valid substitutions. Actully, it only returns new ones.}
 @item{Merge functions: egglog supports merge
 functions, which are a functional depedency from inputs to a single output.}
 @item{Schedules: egglog supports running
 different rulesets in a schedule}
 @item{Extraction: egglog supports extracting
 programs from the database}
 @item{Containers: Egglog supports custom containers, such as vectors}
]