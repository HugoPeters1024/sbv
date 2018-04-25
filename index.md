SBV: SMT Based Verification in Haskell
======================================

Express properties about Haskell programs and automatically prove them using SMT solvers.

```haskell
$ ghci
ghci> :m Data.SBV
ghci> prove $ \x -> x `shiftL` 2 .== 4 * (x::SWord8)
Q.E.D.
ghci> prove $ \x -> x `shiftL` 2 .== 2 * (x::SWord8)
Falsifiable. Counter-example:
  s0 = 32 :: Word8
```

The function `prove` establishes theorem-hood, while `sat` finds any satisfying model. All satisfying models can be computed using `allSat`. SBV can also perform static assertion checks, such as absence of division-by-0, and other user given properties. Furthermore, SBV can perform
optimization, minimizing/maximizing arithmetic goals for their optimal values.

SBV also allows for an incremental mode: Users are given a handle to the SMT solver as their programs execute, and they can issue SMTLib commands
programmatically, query values, and direct the interaction using a high-level typed API. The incremental mode also allows for creation of constraints
based on the current model, and access to internals of SMT solvers for advanced users. See the `runSMT` and `query` commands for details.

Overview
========

  - [![Hackage version](http://img.shields.io/hackage/v/sbv.svg?label=Hackage)](http://hackage.haskell.org/package/sbv) (Released: March 18th, 2018.)
  - [Release Notes](http://github.com/LeventErkok/sbv/tree/master/CHANGES.md). 

SBV library provides support for dealing with symbolic values in Haskell. It introduces the types:

  - `SBool`: Symbolic Booleans (bits).
  - `SWord8`, `SWord16`, `SWord32`, `SWord64`: Symbolic Words (unsigned).
  - `SInt8`,  `SInt16`,  `SInt32`,  `SInt64`: Symbolic Ints (signed).
  - `SInteger`: Symbolic unbounded integers (signed).
  - `SReal`: Symbolic infinite precision algebraic reals (signed).
  - `SFloat`: IEEE-754 single precision floating point number. (`Float`.)
  - `SDouble`: IEEE-754 double precision floating point number. (`Double.`)
  - Arrays of symbolic values.
  - Symbolic enumerations, for arbitrary user-defined enumerated types.
  - Symbolic polynomials over GF(2^n ), polynomial arithmetic, and CRCs.
  - Uninterpreted constants and functions over symbolic values, with user defined axioms.
  - Uninterpreted sorts, and proofs over such sorts, potentially with axioms.
  - Ability for users to define their own symbolic types, such as `SWord4`/`SInt4` as needed. (In a future version of SBV, we plan to support these automatically.)

The user can construct ordinary Haskell programs using these types, which behave like ordinary Haskell values when used concretely. However, when used with symbolic arguments, functions built out of these types can also be:

  - proven correct via an external SMT solver (the `prove` function),
  - checked for satisfiability (the `sat`, and `allSat` functions),
  - checked for assertion violations (the `safe` function with `sAssert` calls),
  - used in synthesis (the `sat` function with existentials),
  - optimized with respect to cost functions (the `optimize`, `maximize`, and `minimize` functions),
  - quick-checked,
  - used for generating Haskell and C test vectors (the `genTest` function),
  - compiled down to C, rendered as straight-line programs or libraries (`compileToC` and `compileToCLib` functions).


Picking the SMT solver to use
=============================
The SBV library uses third-party SMT solvers via the standard [SMT-Lib interface](http://smtlib.cs.uiowa.edu/). The following solvers
are supported:

  - [ABC](http://www.eecs.berkeley.edu/~alanmi/abc/) from University of Berkeley
  - [Boolector](http://fmv.jku.at/boolector/) from Johannes Kepler University
  - [CVC4](http://cvc4.cs.nyu.edu) from Stanford University and the University of Iowa
  - [MathSAT](http://mathsat.fbk.eu/) from FBK and DISI-University of Trento
  - [Yices](http://yices.csl.sri.com) from SRI
  - [Z3](http://github.com/Z3Prover/z3/wiki) from Microsoft
 
Most functions have two variants: For instance `prove`/`proveWith`. The former uses the default solver, which is currently Z3.
The latter expects you to pass it a configuration that picks the solver. The valid values are `abc`, `boolector`, `cvc4`, `mathSAT`, `yices`, and `z3`.

See [versions](http://github.com/LeventErkok/sbv/blob/master/SMTSolverVersions.md) for a listing of the versions of these tools SBV has been tested with. Please report if you see any discrepancies!

Other SMT solvers can be used with SBV as well, with a relatively easy hook-up mechanism. Please
do get in touch if you plan to use SBV with any other solver.

Using multiple solvers, simultaneously
======================================
SBV also allows for running multiple solvers at the same time, either picking the result of the first to complete, or getting results from all. See `proveWithAny`/`proveWithAll` and `satWithAny`/`satWithAll` functions. The function `sbvAvailableSolvers` can be used to query the available solvers at run-time.

### Copyright, License
The SBV library is distributed with the BSD3 license. See [COPYRIGHT](http://github.com/LeventErkok/sbv/tree/master/COPYRIGHT) for
details. The [LICENSE](http://github.com/LeventErkok/sbv/tree/master/LICENSE) file contains
the [BSD3](http://en.wikipedia.org/wiki/BSD_licenses) verbiage.

Thanks
======
The following people reported bugs, provided comments/feedback, or contributed to the development of SBV in various ways: Ara Adkins, Kanishka Azimi, Reid Barton, Ian Blumenfeld, Joel Burget, Ian Calvert, Christian Conkle, Matthew Danish, Iavor Diatchki, Robert Dockins, Thomas DuBuisson, Trevor Elliott, John Erickson, Adam Foltzer, Joshua Gancher, Remy Goldschmidt, Brad Hardy, Tom Hawkins, Greg Horn, Brian Huffman, Joe Leslie-Hurd, Georges-Axel Jaloyan, Anders Kaseorg, Tom Sydney Kerckhove, Piërre van de Laar, Brett Letner, Georgy Lukyanov, John Matthews, Philipp Meyer, Jan Path, Matthew Pickering, Lee Pike, Gleb Popov, Rohit Ramesh, Geoffrey Ramseyer, Stephan Renatus, Eric Seidel, Austin Seipp, Andrés Sicard-Ramírez, Don Stewart, Josef Svenningsson, Daniel Wagner, Sean Weaver, Nis Wegmann, and Jared Ziegler. Thanks!
