-----------------------------------------------------------------------------
-- |
-- Module    : Data.SBV.Lambda
-- Copyright : (c) Levent Erkok
-- License   : BSD3
-- Maintainer: erkokl@gmail.com
-- Stability : experimental
--
-- Generating lambda-expressions, constraints, and named functions, for (limited)
-- higher-order function support in SBV.
-----------------------------------------------------------------------------

{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns        #-}
{-# LANGUAGE ScopedTypeVariables   #-}

{-# OPTIONS_GHC -Wall -Werror #-}

module Data.SBV.Lambda (
            lambda,      lambdaStr
          , namedLambda, namedLambdaStr
          , constraint,  constraintStr
        ) where

import Control.Monad.Trans

import Data.SBV.Core.Data
import Data.SBV.Core.Kind
import Data.SBV.SMT.SMTLib2
import Data.SBV.Utils.PrettyNum

import           Data.SBV.Core.Symbolic hiding   (mkNewState, fresh)
import qualified Data.SBV.Core.Symbolic as     S (mkNewState)

import Data.IORef (readIORef)
import Data.List
import Data.Maybe (fromMaybe)

import qualified Data.Foldable      as F
import qualified Data.Map.Strict    as M
import qualified Data.IntMap.Strict as IM

import qualified Data.Generics.Uniplate.Data as G

data Defn = Defn [String]        -- The uninterpreted names referred to in the body
                 (Maybe String)  -- Param declaration, if any
                 (Int -> String) -- Body, given the tab amount.

-- | Maka a new substate from the incoming state, sharing parts as necessary
inSubState :: MonadIO m => State -> (State -> m b) -> m b
inSubState inState comp = do
        ll <- liftIO $ readIORef (rLambdaLevel inState)
        stEmpty <- S.mkNewState (stCfg inState) (LambdaGen (ll + 1))

        let share fld = fld inState   -- reuse the field from the parent-context
            fresh fld = fld stEmpty   -- create a new field here

        -- freshen certain fields, sharing some from the parent, and run the comp
        comp State { pathCond     = share pathCond
                   , stCfg        = fresh stCfg
                   , startTime    = share startTime
                   , runMode      = fresh runMode
                   , rIncState    = share rIncState
                   , rCInfo       = share rCInfo
                   , rObservables = share rObservables
                   , rctr         = fresh rctr
                   , rLambdaLevel = fresh rLambdaLevel
                   , rUsedKinds   = share rUsedKinds
                   , rUsedLbls    = share rUsedLbls
                   , rinps        = fresh rinps
                   , rConstraints = fresh rConstraints
                   , routs        = fresh routs
                   , rtblMap      = share rtblMap
                   , spgm         = fresh spgm
                   , rconstMap    = fresh rconstMap
                   , rexprMap     = fresh rexprMap
                   , rArrayMap    = share rArrayMap
                   , rFArrayMap   = share rFArrayMap
                   , rUIMap       = share rUIMap
                   , rUserFuncs   = share rUserFuncs
                   , rCgMap       = share rCgMap
                   , rDefns       = share rDefns
                   , rSMTOptions  = share rSMTOptions
                   , rOptGoals    = share rOptGoals
                   , rAsserts     = share rAsserts
                   , rSVCache     = fresh rSVCache
                   , rAICache     = fresh rAICache
                   , rQueryState  = fresh rQueryState
                   }

-- | Generic creator for anonymous lamdas.
lambdaGen :: (MonadIO m, Lambda (SymbolicT m) a) => (Defn -> b) -> State -> Kind -> a -> m b
lambdaGen trans inState fk f = inSubState inState $ \st -> trans <$> convert st fk (mkLambda st f)

-- | Create an SMTLib lambda, in the given state.
lambda :: (MonadIO m, Lambda (SymbolicT m) a) => State -> Kind -> a -> m SMTDef
lambda inState fk = lambdaGen mkLam inState fk
   where mkLam (Defn frees params body) = SMTLam fk frees params body

-- | Create an anonymous lambda, rendered as n SMTLib string
lambdaStr :: (MonadIO m, Lambda (SymbolicT m) a) => State -> Kind -> a -> m String
lambdaStr = lambdaGen mkLam
   where mkLam (Defn _frees mbParams body) = "(lambda " ++ fromMaybe "()" mbParams ++ "\n" ++ body 2 ++ ")"

-- | Generaic creator for named functions,
namedLambdaGen :: (MonadIO m, Lambda (SymbolicT m) a) => (Defn -> b) -> State -> Kind -> a -> m b
namedLambdaGen trans inState fk f = inSubState inState $ \st -> trans <$> convert st fk (mkLambda st f)

-- | Create a named SMTLib function, in the given state.
namedLambda :: (MonadIO m, Lambda (SymbolicT m) a) => State -> String -> Kind -> a -> m SMTDef
namedLambda inState nm fk = namedLambdaGen mkDef inState fk
   where mkDef (Defn frees params body) = SMTDef nm fk frees params body

-- | Create a named SMTLib function, in the given state, string version
namedLambdaStr :: (MonadIO m, Lambda (SymbolicT m) a) => State -> String -> Kind -> a -> m String
namedLambdaStr inState nm fk = namedLambdaGen mkDef inState fk
   where mkDef (Defn frees params body) = concat $ declUserFuns [SMTDef nm fk frees params body]

-- | Generic constraint generator.
constraintGen :: (MonadIO m, Constraint (SymbolicT m) a) => (Defn -> b) -> State -> a -> m b
constraintGen trans inState@State{rLambdaLevel} f = do
   -- make sure we're at the top
   ll <- liftIO $ readIORef rLambdaLevel
   () <- case ll of
           0 -> pure ()
           _ -> error "Data.SBV.constraintGen: Not supported: constraint calls that are not at the top-level."

   inSubState inState $ \st -> trans <$> convert st KBool (mkConstraint st f >>= output >> pure ())

-- | Generate a constraint.
constraint :: (MonadIO m, Constraint (SymbolicT m) a) => State -> a -> m SBool
constraint inState = (mkBool <$>) . constraintStr inState
   where mkBool :: String -> SBool
         mkBool str = SBV $ SVal KBool $ Right $ cache f
           where f st = newExpr st KBool (SBVApp (Uninterpreted str) [])

-- | Generate a constraint, string version
constraintStr :: (MonadIO m, Constraint (SymbolicT m) a) => State -> a -> m String
constraintStr = constraintGen toStr
   where toStr (Defn _frees Nothing       body) = body 0
         toStr (Defn _frees (Just params) body) = "(forall " ++ params ++ "\n" ++ body 4 ++ ")"

-- | Convert to an appropriate SMTLib representation.
convert :: MonadIO m => State -> Kind -> SymbolicT m () -> m Defn
convert st expectedKind comp = do
   ((), res) <- runSymbolicInState st comp
   pure $ toLambda (stCfg st) expectedKind res

-- | Convert the result of a symbolic run to a more abstract representation
toLambda :: SMTConfig -> Kind -> Result -> Defn
toLambda cfg expectedKind result@Result{resAsgns = SBVPgm asgnsSeq} = sh result
 where tbd xs = error $ unlines $ "*** Data.SBV.lambda: Unsupported construct." : map ("*** " ++) ("" : xs ++ ["", report])
       bad xs = error $ unlines $ "*** Data.SBV.lambda: Impossible happened."   : map ("*** " ++) ("" : xs ++ ["", bugReport])
       report    = "Please request this as a feature at https://github.com/LeventErkok/sbv/issues"
       bugReport = "Please report this at https://github.com/LeventErkok/sbv/issues"

       sh (Result _ki           -- Kind info, we're assuming that all the kinds used are already available in the surrounding context.
                                -- There's no way to create a new kind in a lambda. If a new kind is used, it should be registered.

                  _qcInfo       -- Quickcheck info, does not apply, ignored

                  _observables  -- Observables: Nothing to do

                  _codeSegs     -- UI code segments: Again, shouldn't happen; if present, error out

                  is            -- Inputs

                  ( _allConsts  -- This contains the CV->SV map, which isn't needed for lambdas since we don't support tables
                  , consts      -- constants used
                  )

                  _tbls         -- Tables                : nothing to do with them
                  _arrs         -- Arrays                : nothing to do with them
                  _uis          -- Uninterpeted constants: nothing to do with them
                  _axs          -- Axioms definitions    : nothing to do with them

                  pgm           -- Assignments

                  cstrs         -- Additional constraints: Not currently supported inside lambda's
                  assertions    -- Assertions: Not currently supported inside lambda's

                  outputs       -- Outputs of the lambda (should be singular)
         )
         | not (null cstrs)
         = tbd [ "Constraints."
               , "  Saw: " ++ show (length cstrs) ++ " additional constraint(s)."
               ]
         | not (null assertions)
         = tbd [ "Assertions."
               , "  Saw: " ++ intercalate ", " [n | (n, _, _) <- assertions]
               ]
         | kindOf out /= expectedKind
         = bad [ "Expected kind and final kind do not match"
               , "   Saw     : " ++ show (kindOf out)
               , "   Expected: " ++ show expectedKind
               ]
         | True
         = res
         where res = Defn (nub [nm | Uninterpreted nm <- G.universeBi asgnsSeq])
                          mbParam
                          (intercalate "\n" . body)

               params = case is of
                          (inps, trackers) | any ((== EX) . fst) inps
                                           -> bad [ "Unexpected existentially quantified variables as inputs"
                                                  , "   Saw: " ++ intercalate ", " [getUserName' n | (EX, n) <- inps]
                                                  ]
                                           | not (null trackers)
                                           -> tbd [ "Tracker variables"
                                                  , "   Saw: " ++ intercalate ", " (map getUserName' trackers)
                                                  ]
                                           | True
                                           -> map (getSV . snd) inps

               mbParam
                 | null params = Nothing
                 | True        = Just $ '(' : unwords (map (\p -> '(' : show p ++ " " ++ smtType (kindOf p) ++ ")")  params) ++ ")"

               body tabAmnt
                 | Just e <- simpleBody bindings out
                 = [replicate tabAmnt ' ' ++ e]
                 | True
                 = let tab = replicate tabAmnt ' '
                   in    [tab ++ "(let ((" ++ show s ++ " " ++ v ++ "))" | (s, v) <- bindings]
                      ++ [tab ++ show out ++ replicate (length bindings) ')']

               -- if we have just one definition returning it, simplify
               simpleBody :: [(SV, String)] -> SV -> Maybe String
               simpleBody [(v, e)] o | v == o = Just e
               simpleBody _        _          = Nothing

               assignments = F.toList (pgmAssignments pgm)

               constants = filter ((`notElem` [falseSV, trueSV]) . fst) consts

               bindings :: [(SV, String)]
               bindings = map mkConst constants ++ map mkAsgn assignments

               mkConst :: (SV, CV) -> (SV, String)
               mkConst (sv, cv) = (sv, cvToSMTLib (roundingMode cfg) cv)

               out :: SV
               out = case outputs of
                       [o] -> o
                       _   -> bad [ "Unexpected non-singular output"
                                  , "   Saw: " ++ show outputs
                                  ]

               mkAsgn (sv, e) = (sv, converter e)
               converter = cvtExp solverCaps rm skolemMap tableMap funcMap
                 where solverCaps = capabilities (solver cfg)
                       rm         = roundingMode cfg
                       skolemMap  = M.empty
                       tableMap   = IM.empty
                       funcMap    = M.empty
