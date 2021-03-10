# (c) Copyright Levent Erkok. All rights reserved.
#
# The sbv library is distributed with the BSD3 license. See the LICENSE file
# in the distribution for details.

OS := $(shell uname)
SHELL := /usr/bin/env bash

CONFIGOPTS = "-Wall -fhide-source-paths"

export SBV_TEST_ENVIRONMENT := local

DOCTESTSOURCES := $(shell find Data/SBV -name "*.hs") $(shell find Documentation/SBV -name "*.hs")

ifeq ($(OS), Darwin)
# OSX tends to sleep for long jobs; so run through caffeinate
TIME        = /usr/bin/time caffeinate -dimsu
NO_OF_CORES = `sysctl hw.ncpu | awk '{print $$2}'`
else
TIME        = /usr/bin/time
NO_OF_CORES = `grep -c "^processor" /proc/cpuinfo`
endif

.PHONY: install docs testsuite release tags clean veryclean timeRelease

all: quick

quick: tags
	@$(TIME) cabal new-install --lib
	
install: tags
	@$(TIME) cabal new-configure --enable-tests --ghc-options=$(CONFIGOPTS)
	@$(TIME) cabal new-install --lib

docs:
	cabal new-haddock --haddock-option=--hyperlinked-source --haddock-option=--no-warnings

ghci:
	cabal new-repl --repl-options=-Wno-unused-packages

ghci_SBVTest:
	cabal new-repl --repl-options=-Wno-unused-packages SBVTest

ghcid:
	ghcid --command="cabal new-repl --repl-options=-Wno-unused-packages"

bench:
	cabal new-bench

testsuite: lintTest docTest test

lintTest:
	@$(TIME) cabal new-test SBVHLint

testInterfaces:
	@$(TIME) cabal new-test SBVConnections

# Doctests are broken with GHC 9.0.1
docTest:
	# @$(TIME) cabal new-run SBVDocTest -- --fast --no-magic

vdocTest:
	@$(TIME) doctest --verbose --fast --no-magic $(DOCTESTSOURCES)

test:
ifndef TGT
	@$(TIME) cabal new-run SBVTest -- --hide-successes -j $(NO_OF_CORES)
else
	@$(TIME) cabal new-run SBVTest -- 	           -j $(NO_OF_CORES) -p ${TGT}
endif

testAccept:
ifndef TGT
	@$(TIME) cabal new-run SBVTest -- -j $(NO_OF_CORES) --accept
else
	@$(TIME) cabal new-run SBVTest -- -j $(NO_OF_CORES) -p ${TGT} --accept
endif

checkLinks:
	@brok --no-cache --only-failures $(DOCTESTSOURCES) COPYRIGHT INSTALL LICENSE $(wildcard *.md)

mkDistro:
	$(TIME) cabal new-sdist

# Useful if we update z3 (or some other solver) but don't make any changes to SBV
releaseNoBuild: testsuite testInterfaces mkDistro checkLinks
	@echo "*** SBV is ready for release! -- no SBV build was done."

fullRelease: veryclean install docs testsuite testInterfaces mkDistro checkLinks
	@echo "*** SBV is ready for release!"

release:
	$(TIME) make fullRelease

# use this as follows:
#         make docTestPattern TGT=./Documentation/SBV/Examples/Puzzles/HexPuzzle.hs
docTestPattern:
	$(TIME) doctest --fast --no-magic --verbose ${TGT}

tags:
	@fast-tags -R --nomerge .

hlint: 
	@echo "Running HLint.."
	@hlint Data SBVTestSuite -i "Use otherwise" -i "Parse error"

clean:
	@rm -rf dist dist-newstyle cabal.project.local*

veryclean: clean
	@make -C buildUtils clean
