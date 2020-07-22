SBV has been tested with the following versions of the SMT solvers. While we strive to make sure
it works with latest releases of each of these tools, newer versions can exhibit issues. Please
report any issues you might see with newer releases.

  * ABC:
      * http://github.com/berkeley-abc/abc
      * Version as downloaded from the above site on Jul 6, 2019
  * Boolector:
      * http://github.com/Boolector/boolector
      * Version 3.2.0
  * CVC4:
      * https://github.com/CVC4/CVC4
      * Version as downloaded from the above site on May 19, 2020
  * dReal:
      * https://dreal.github.io/
      * Version installed via "brew rm dreal; brew install dreal --HEAD"
        on Jul 22, 2020.
  * MathSAT:
      * http://mathsat.fbk.eu/
      * Version 5.6.3
  * Yices:
      * https://github.com/SRI-CSL/yices2
      * Version 2.6.2 as downloaded from the above site on Apr 7, 2020
  * Z3:
      * http://github.com/Z3Prover/z3
      * Version as downloaded from the above site on Jul 22nd, 2020
      * SBV typically relies on latest features of z3, so compiling directly
        from the sources is recommended. If that's not possible, you should
	always use their latest release.
