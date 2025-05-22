/=  compute-table  /common/table/prover/compute
/=  memory-table   /common/table/prover/memory
/=  *  /common/zeke
/=  nock-common  /common/nock-common
::
::TODO shouldn't need all of this but its useful to keep here for now
::while we're figuring out how to turn all tables off or on in general
=>  :*  stark-engine
        nock-common=nock-common
        compute-table=compute-table
        memory-table=memory-table
    ==
~%  %stark-prover  ..stark-engine-jet-hook  ~
|%
+$  prove-result  (each =proof err=prove-err)
+$  prove-err     $%([%too-big heights=(list @)])
+$  prover-output    [=proof deep-codeword=fpoly]
::  +prove: prove the Nock computation [s f]
::
::
::    .override: an optional list of which tables should be computed and constraints
::    checked. this is for debugging use only, it should always be ~ in production.
::    to use it for debugging, pass in the same list of tables to both +prove
::    and +verify. these are the tables that will be computed - all others will
::    be ignored. you do not need to worry about sorting it in the correct order, that
::    happens automatically.
++  prove
  ~/  %prove
  |=  $:  header=noun-digest:tip5
          nonce=noun-digest:tip5
          pow-len=@
          override=(unit (list term))
      ==
  ^-  prove-result
  =/  [s=* f=*]  (puzzle-nock header nonce pow-len)
  =/  [prod=* return=fock-return]  (fink:fock [s f])
  (generate-proof header nonce pow-len s f prod return override)
::
:: generate-proof is the main body of the prover.
++  generate-proof
  :: Disabled jet hint for now, under development.
  :: ~/  %generate-proof
  |=  $:  header=noun-digest:tip5
          nonce=noun-digest:tip5
          pow-len=@
          s=*
          f=*
          prod=*
          return=fock-return
          override=(unit (list term))
      ==
  ^-  prove-result
  =|  =proof  ::  the proof stream
  =.  proof  (~(push proof-stream proof) [%puzzle header nonce pow-len prod])
  ::
  ::  build tables
  ::~&  %building-tables
  =/  tables=(list table-dat)
    (build-table-dats return override)
  ::
  ::  check that the tables have correct base width. Comment this out for production.
  ::?:  %+  levy  tables
  ::    |=  t=table-dat
  ::    !=(step.p.p.t base-width.p.t)
  ::  ~&  %widths-mismatch
  ::  ~|("prove: mismatch between table full widths and actual widths" !!)
  ::
  =/  num-tables  (lent tables)
  =.  table-names  (turn tables |=(t=table-dat name.p.t))
  =/  heights=(list @)
    %+  turn  tables
    |=  t=table-dat
    =/  len  len.array.p.p.t
    ?:(=(len 0) 0 (bex (xeb (dec len))))
  ::~&  heights+heights
  ::
  =.  proof  (~(push proof-stream proof) [%heights heights])
  =/  pre=preprocess-0  prep.stark-config
  ::
  =/  clc  ~(. calc heights cd.pre)
  =*  num-colinearity-tests=@  num-colinearity-tests:fri:clc
  =*  fri-domain-len=@  init-domain-len:fri:clc
  ::
  ::  convert the base columns to marys, this is a temporary preprocessing step until
  ::  we change the table struct to contain a mary rather than a (list fpoly)
  ::
  ::  think of each mary as a list of the table's rows
  =/  [base-marys=(list mary) width=@]
    %^  spin  tables
      0
    |=([t=table-dat width=@] [p.p.t (add width base-width.p.t)])
  =/  base=codeword-commitments
    (compute-codeword-commitments base-marys fri-domain-len width)
  =.  proof  (~(push proof-stream proof) [%m-root h.q.merk-heap.base])
  ::
  ::  generate first round of randomness
  =/  rng  ~(prover-fiat-shamir proof-stream proof)
  ::
  ::  get coefficients for table extensions, extend tables
  ::  round one challenges: a, b, c, ..., α
  =^  chals-rd1=(list belt)  rng  (belts:rng num-chals-rd1:chal)
  ::
  ::  extension columns: list or mary? probably should be a list
  ::
  ::  build extension columns
  =/  table-exts=(list table-mary)
    %+  turn  tables
    |=  t=table-dat
    ^-  table-mary
    (extend:q.t p.t chals-rd1 return)
  =.  tables
    %+  turn
    (zip-up tables table-exts)
    |=  [t=table-dat ext=table-mary]
    ^-  table-dat
    :_  [q.t r.t]
    (weld-exts:tlib p.t ext)
  ::
  ::  check that the tables have correct num of ext cols. Comment this out for production.
  ::
  ::?:  %+  levy  (zip-up tables table-exts)
      ::|=  [table=table-dat ext=table-mary]
      ::!=(step.p.ext ext-width.p.table)
    ::~&  %widths-mismatch
    ::~|("prove: mismatch between table ext widths and actual ext widths" !!)
  ::~&  %ext-cols
  ::
  ::  convert the ext columns to marys
  ::
  ::  think of each mary as a list of the table's rows
  =/  [ext-marys=(list mary) width=@]
    %^  spin  table-exts
      0
    |=([t=table-mary width=@] [p.t (add width ext-width.t)])
  ::
  =/  ext=codeword-commitments
    (compute-codeword-commitments ext-marys fri-domain-len width)
  =.  proof  (~(push proof-stream proof) [%m-root h.q.merk-heap.ext])
  ::
  ::  reseed the rng
  =.  rng  ~(prover-fiat-shamir proof-stream proof)
  ::
  ::  get coefficients for table extensions, extend tables
  ::  round two challenges: β, z
  =^  chals-rd2=(list belt)  rng  (belts:rng num-chals-rd2:chal)
  =/  challenges  (weld chals-rd1 chals-rd2)
  =/  chal-map=(map @ belt)
    (make-challenge-map:chal challenges s f)
  ::
  ::  build mega-extension columns
  =/  table-mega-exts=(list table-mary) 
    (build-mega-extend tables challenges return)
  ::~&  %tables-built
  =.  tables
    %+  turn  (zip-up tables table-mega-exts)
    |=  [t=table-dat mega-ext=table-mary]
    ^-  table-dat
    :_  [q.t r.t]
    (weld-exts:tlib p.t mega-ext)
  ::
  ::  check that the tables have correct num of ext cols. Comment this out for production.
  ::~&  >>  %check-mega-ext-cols
  ::?:  %+  levy  (zip-up tables table-mega-exts)
      ::|=  [table=table-dat mext=table-mary]
      ::!=(step.p.mext mega-ext-width.p.table)
    ::~&  %widths-mismatch
    ::~|("prove: mismatch between table ext widths and actual ext widths" !!)
  ::
  ::  convert the mega-ext columns to marys
  ::
  ::  think of each mary as a list of the table's rows
  =/  [mega-ext-marys=(list mary) width=@]
    %^  spin  table-mega-exts
      0
    |=  [t=table-mary width=@]
    [p.t (add width mega-ext-width.t)]
  =/  mega-ext=codeword-commitments
    (compute-codeword-commitments mega-ext-marys fri-domain-len width)
  ::
  ::  get terminal values for use in permutation/evaluation arguments
  =/  dyn-map=(map @ bpoly)
    %-  ~(gas by *(map @ bpoly))
    %+  iturn  tables
    |=  [i=@ t=table-dat]
    [i (terminal:q.t p.t)]
  ::
  ::  weld terminals from each table together
  =/  terminals=bpoly
    %+  roll  (range (lent tables))
    |=  [i=@ acc=bpoly]
    (~(weld bop acc) (~(got by dyn-map) i))
  ::  send terminals to verifier
  =.  proof  (~(push proof-stream proof) terms+terminals)
  ::  reseed the rng
  =.  rng  ~(prover-fiat-shamir proof-stream proof)
  ::
  ::
  ::
  ::  This chunk of code plugs all the rows into the constraints to check if they really do
  ::  evaluate to 0. Verifying the proof also checks this and is much faster, but this code
  ::  is useful if you are debugging constraints. Keep it commented out unless you need it.
  ::  It should never be run in production.
  ::
  ::?>  %+  levy  (zip-up (range (lent tables)) tables)
  ::    |=  [i=@ t=table-dat]
  ::    %-  (test:zkvm-debug p.t s f)
  ::    [challenges (~(got by dyn-map) i) r.t]
  ::~&  %passed-tests
  ::
  =/  num-extra-constraints=@
    %+  roll  (range num-tables)
    |=  [i=@ acc=@]
    =/  cs  (~(got by count-map.pre) i)
    ;:  add
      acc
      boundary.cs
      row.cs
      transition.cs
      terminal.cs
      extra.cs
    ==
  ::
  =/  total-cols=@
    %+  roll  tables
    |=  [[p=table-mary *] sum=@]
    (add sum step:p.p)
  ::
  ::  The constraints take variables for a full row plus the following row. So to evaluate them
  ::  the trace polys are not enough. We need to compose each trace poly with f(X)=g*X to create
  ::  polys that will give the value of the following row. Then we weld these second-row polys
  ::  to the original polys to get the double trace polys. These can then be used to compose with
  ::  the constraints and evaluate at the DEEP challenge later on.
  ::~&  %transposing-table
  ::  TODO: we already transposed the tables when we interpolated the polynomials and we should
  ::  just reuse that. But that requires changing the interface to the interpolation functions.
  =/  marys=(list table-mary)
    %+  turn  tables
    |=(t=table-dat p.t)
  =/  transposed-tables=(list mary)
    %+  turn  marys
    |=  =table-mary
    (transpose-bpolys p.table-mary)
  ::
  ::~&  %composing-trace-polys
  ::  each mary is a list of a table's columns, interpolated to polys
  =/  trace-polys
    %+  turn  (zip-up polys.base (zip-up polys.ext polys.mega-ext))
    |=  [bm=mary em=mary mem=mary]
    ^-  mary
    (~(weld ave bm) (~(weld ave em) mem))
  ::
  =/  second-row-trace-polys=(list mary)
    %+  turn  transposed-tables
    |=  polys=mary
    %-  zing-bpolys
    %+  turn  (range len.array.polys)
    |=  i=@
    =/  bp=bpoly  (~(snag-as-bpoly ave polys) i)
    (bp-ifft (bp-shift-by-unity bp 1))
  ::
  ::~&  %appending-first-and-second-row-trace-polys
  ::
  =/  tworow-trace-polys=(list mary)
    %^    zip
        trace-polys
      second-row-trace-polys
    |=  [t-poly=mary s-poly=mary]
    (~(weld ave t-poly) s-poly)
  ::
  ::
  ::  Compute trace and tworow-trace polynomials in eval form over a 4*d root of unity
  ::  (where d is the lowest power of 2 greater than the max degree of the constraints)
  ::~&  %extending-trace-polys
  ::
  ::  TODO: Save these variables in the preprocess step
  =/  max-constraint-degree  (get-max-constraint-degree cd.pre)
  =/  ntt-len
    %-  bex  %-  xeb  %-  dec
    (get-max-constraint-degree cd.pre)
  =/  max-height=@
    %-  bex  %-  xeb  %-  dec
    (roll heights max)
  =/  tworow-trace-polys-eval=(list bpoly)
    %+  iturn  tworow-trace-polys
    |=  [i=@ polys=mary]
    (precompute-ntts polys max-height ntt-len)
  ::
  ::
  ::  compute extra composition poly
  =/  omicrons-belt
    %+  turn  tables
    |=  [t=table-mary *]
    ~(omicron quot t)
  =/  omicrons-bpoly=bpoly  (init-bpoly omicrons-belt)
  =/  omicrons-fpoly=fpoly
    (init-fpoly (turn omicrons-belt lift))
  =^  extra-comp-weights=bpoly  rng
    =^  belt-list  rng  (belts:rng (mul 2 num-extra-constraints))
    [(init-bpoly belt-list) rng]
  =/  extra-composition-chals=(map @ bpoly)
    %-  ~(gas by *(map @ bpoly))
    =-  -<
    %+  roll  (range num-tables)
    |=  [i=@ acc=(list [@ bpoly]) num=@]
    =/  cs  (~(got by count-map.pre) i)
    =/  num-extra-constraints=@
      ;:  add
          boundary.cs
          row.cs
          transition.cs
          terminal.cs
          extra.cs
      ==
    :_  (add num (mul 2 num-extra-constraints))
    [[i (~(swag bop extra-comp-weights) num (mul 2 num-extra-constraints))] acc]
  ::~&  %computing-extra-composition-poly
  =/  extra-composition-poly=bpoly
    %-  compute-composition-poly
    :*  omicrons-bpoly
        heights
        tworow-trace-polys-eval
        constraint-map.pre
        count-map.pre
        extra-composition-chals
        chal-map
        dyn-map
        %.y
    ==
  =.  proof
    (~(push proof-stream proof) [%poly extra-composition-poly])
  =.  rng  ~(prover-fiat-shamir proof-stream proof)
  =^  extra-comp-eval-point  rng  $:felt:rng
  ::
  ::  compute extra trace evals
  ::~&  %evaluating-trace-at-new-comp-eval-point
  =/  extra-trace-evaluations=fpoly
    %-  init-fpoly
    %-  zing
    %+  turn  tworow-trace-polys
    |=  polys=mary
    %+  turn  (range len.array.polys)
    |=  i=@
    =/  b=bpoly  (~(snag-as-bpoly ave polys) i)
    (bpeval-lift b extra-comp-eval-point)
  ::
  =.  proof
    (~(push proof-stream proof) [%evals extra-trace-evaluations])
  ::
  ::  send mega extension columns to verifier
  =.  proof  (~(push proof-stream proof) [%m-root h.q.merk-heap.mega-ext])
  ::  reseed the rng
  =/  rng  ~(prover-fiat-shamir proof-stream proof)
  ::
  ::  compute the Composition Polynomial
  ::  This polynomial composes the trace polynomials with the constraints, takes quotients
  ::  over the rows where the constraint should be zero, adjusts the degree so they all
  ::  have the same maximal degree, and combines them into one big random linear combination.
  ::
  ::  compute weights used in linear combination of composition polynomial
  =/  num-constraints=@
    %+  roll  (range num-tables)
    |=  [i=@ acc=@]
    =/  cs  (~(got by count-map.pre) i)
    ;:  add
      acc
      boundary.cs
      row.cs
      transition.cs
      terminal.cs
    ==
  =^  comp-weights=bpoly  rng
    =^  belt-list  rng  (belts:rng (mul 2 num-constraints))
    [(init-bpoly belt-list) rng]
  ::
  =/  composition-chals=(map @ bpoly)
    %-  ~(gas by *(map @ bpoly))
    =-  -<
    %+  roll  (range num-tables)
    |=  [i=@ acc=(list [@ bpoly]) num=@]
    =/  cs  (~(got by count-map.pre) i)
    =/  num-constraints=@
      ;:  add
          boundary.cs
          row.cs
          transition.cs
          terminal.cs
      ==
    :_  (add num (mul 2 num-constraints))
    [[i (~(swag bop comp-weights) num (mul 2 num-constraints))] acc]
  ::
  ::~&  %computing-composition-poly
  =/  composition-poly=bpoly
    %-  compute-composition-poly
    :*  omicrons-bpoly
        heights
        tworow-trace-polys-eval
        constraint-map.pre
        count-map.pre
        composition-chals
        chal-map
        dyn-map
        %.n
    ==
  ::
  ::  decompose composition polynomial into one polynomial for each degree of the
  ::  constraints. If the max degree of the constraints is D, then this will produce
  ::  D polynomials each of degree table-height.
  ::~&  %decomposing-composition-poly
  =/  num-composition-pieces  (get-max-constraint-degree cd.pre)
  ::
  =/  composition-pieces=(list bpoly)
    (bp-decompose composition-poly num-composition-pieces)
  ::
  ::  turn composition pieces into codewords
  ::~&  %computing-composition-codewords
  =/  composition-codewords=mary
    %-  zing-bpolys
    %+  turn  composition-pieces
    |=  poly=bpoly
    (bp-coseword poly g fri-domain-len)
  =/  composition-codeword-array=mary
    (transpose-bpolys composition-codewords)
  =/  composition-merk=(pair @ merk-heap:merkle)
    (bp-build-merk-heap:merkle composition-codeword-array)
  =.  proof
    (~(push proof-stream proof) [%comp-m h.q.composition-merk num-composition-pieces])
  ::
  ::
  ::
  ::
  ::  reseed the rng
  =.  rng  ~(prover-fiat-shamir proof-stream proof)
  ::
  ::  compute DEEP challenge point from extension field
  =^  deep-challenge=felt  rng
    =^  deep-candidate  rng  $:felt:rng
    =/  n  fri-domain-len:clc
    =/  exp-offset  (lift (bpow generator:stark-engine n))
    |-
    =/  exp-deep-can  (fpow deep-candidate n)
    ?.  ?|(=(exp-deep-can f1) =(exp-deep-can exp-offset))
      [deep-candidate rng]
    =^  felt  rng  $:felt:rng
    $(deep-candidate felt)
  ::~&  %evaluating-trace-at-deep-challenge
  ::
  ::  trace-evaluations: list of evaluations of interpolated column polys and
  ::  shifted column polys at deep point, grouped in order by tables
  =/  trace-evaluations=fpoly
    %-  init-fpoly
    %-  zing
    %+  turn  tworow-trace-polys
    |=  polys=mary
    %+  turn  (range len.array.polys)
    |=  i=@
    =/  b=bpoly  (~(snag-as-bpoly ave polys) i)
    (bpeval-lift b deep-challenge)
  ::
  ::~&  %evaluating-pieces-at-deep-challenge
  =/  composition-pieces-fpoly  (turn composition-pieces bpoly-to-fpoly)
  =/  composition-piece-evaluations=fpoly
    =/  c  (fpow deep-challenge num-composition-pieces)
    %-  init-fpoly
    %+  turn  composition-pieces-fpoly
    |=(poly=fpoly (fpeval poly c))
  ::
  =.  proof
    (~(push proof-stream proof) [%evals trace-evaluations])
  =.  proof
    (~(push proof-stream proof) [%evals composition-piece-evaluations])
  ::
  ::  reseed the rng
  =.  rng  ~(prover-fiat-shamir proof-stream proof)
  ::
  ::  compute weights used in linear combination of deep polynomial. These
  ::  are from the extension field.
  =^  deep-weights=fpoly  rng
    =^  felt-list  rng
      %-  felts:rng
      (add (mul 4 total-cols) max-constraint-degree)
    [(init-fpoly felt-list) rng]
  =/  all-evals  (~(weld fop trace-evaluations) extra-trace-evaluations)
  ::~&  %computing-deep-poly
  =/  deep-poly=fpoly
    %-  compute-deep
    :*  trace-polys
        all-evals
        composition-pieces-fpoly
        composition-piece-evaluations
        deep-weights
        omicrons-fpoly
        deep-challenge
        extra-comp-eval-point
    ==
  ::
  ::  create DEEP codeword and push to proof
  ::~&  %computing-deep-codeword
  =/  deep-codeword=fpoly
    (coseword deep-poly (lift g) fri-domain-len)
  ::
  =^  fri-indices=(list @)  proof
    (prove:fri:clc deep-codeword proof)
  ::
  ::
  ::~&  %opening-codewords
  =.  proof
    %^  zip-roll  (range num-spot-checks)  fri-indices
    |=  [[i=@ idx=@] proof=_proof]
    ::
    ::  base trace codewords
    =/  elem=mary
      (~(change-step ave (~(snag-as-mary ave codewords.base) idx)) 1)
    =/  axis  (index-to-axis:merkle p.merk-heap.base idx)
    =/  opening=merk-proof:merkle
      (build-merk-proof:merkle q.merk-heap.base axis)
    =.  proof
      %-  ~(push proof-stream proof)
      m-pathbf+[(tail elem) path.opening]
    ::
    ::  ext trace codewords
    =.  elem
      (~(change-step ave (~(snag-as-mary ave codewords.ext) idx)) 1)
    =.  axis  (index-to-axis:merkle p.merk-heap.ext idx)
    =.  opening
      (build-merk-proof:merkle q.merk-heap.ext axis)
    =.  proof
      %-  ~(push proof-stream proof)
      m-pathbf+[(tail elem) path.opening]
    ::
    ::  mega-ext trace codewords
    =.  elem
      (~(change-step ave (~(snag-as-mary ave codewords.mega-ext) idx)) 1)
    =.  axis  (index-to-axis:merkle p.merk-heap.mega-ext idx)
    =.  opening
      (build-merk-proof:merkle q.merk-heap.mega-ext axis)
    =.  proof
      %-  ~(push proof-stream proof)
      m-pathbf+[(tail elem) path.opening]
    ::
    ::  piece codewords
    =.  elem
      (~(change-step ave (~(snag-as-mary ave composition-codeword-array) idx)) 1)
    =.  axis  (index-to-axis:merkle p.composition-merk idx)
    =.  opening  (build-merk-proof:merkle q.composition-merk axis)
    %-  ~(push proof-stream proof)
    m-pathbf+[(tail elem) path.opening]
  ::
  ::~&  %finished-proof
  [%& %0 objects.proof ~ 0]
::
::
++  build-table-dats
  ::~/  %build-table-dats
  |=  [return=fock-return override=(unit (list term))]
  ^-  (list table-dat)
  %-  sort
  :_  td-order
  %+  turn  ?~  override    :: check to see if we only want to use certain tables
              gen-table-names:nock-common
            u.override
  |=  name=term
  =/  t-funcs
    ~|  "table-funcs do not exist for {<name>}"
    (~(got by table-funcs-map) name)
  =/  v-funcs
    ~|  "verifier-funcs do not exist for {<name>}"
    (~(got by all-verifier-funcs-map:nock-common) name)
  =/  tm=table-mary  (build:t-funcs return)
  [(pad:t-funcs tm) t-funcs v-funcs]
::
++  table-funcs-map
  ~+
  ^-  (map term table-funcs)
  %-  ~(gas by *(map term table-funcs))
  :~  :-  name:static:common:compute-table
      funcs:compute-table
      :-  name:static:common:memory-table
      funcs:memory-table
  ==
++  build-mega-extend
  ~/  %build-mega-extend
  |=  [tables=(list table-dat) chals=(list belt) return=fock-return]
  ^-  (list table-mary)
  %+  turn  tables
  |=  t=table-dat
  ^-  table-mary
  (mega-extend:q.t p.t chals return)
--
