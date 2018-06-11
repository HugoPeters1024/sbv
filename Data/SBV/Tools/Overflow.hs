-----------------------------------------------------------------------------
-- |
-- Module      :  Data.SBV.Tools.Overflow
-- Copyright   :  (c) Levent Erkok
-- License     :  BSD3
-- Maintainer  :  erkokl@gmail.com
-- Stability   :  experimental
--
-- Implementation of overflow detection functions.
-- Based on: <http://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/z3prefix.pdf>
-----------------------------------------------------------------------------

{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Data.SBV.Tools.Overflow (

         -- * Overflow detection
         BVOverflow(..)

    ) where

import Data.SBV.Core.Data
import Data.SBV.Core.Symbolic
import Data.SBV.Core.Operations

-- | Detecting underflow/overflow conditions. For each function,
-- the first result is the condition under which the computation
-- underflows, and the second is the condition under which it
-- overflows.
class BVOverflow a where
  -- | Bit-vector addition. Unsigned addition can only overflow. Signed addition can underflow and overflow.
  bvAddO :: a -> a -> (SBool, SBool)

  -- | Bit-vector subtraction. Unsigned subtraction can only underflow. Signed subtraction can underflow and overflow.
  bvSubO :: a -> a -> (SBool, SBool)

  -- | Bit-vector multiplication. Unsigned multiplication can only overflow. Signed multiplication can underflow and overflow.
  bvMulO     :: a -> a -> (SBool, SBool)

  -- | Same as 'bvMulO', except instead of doing the computation internally, it simply sends it off to z3 as a primitive.
  -- Obviously, only use if you have the z3 backend! Note that z3 provides this operation only when no logic is set,
  -- so make sure to call @setLogic Logic_NONE@ in your program!
  bvMulOFast :: a -> a -> (SBool, SBool)

  -- | Bit-vector division. Unsigned division neither underflows nor overflows. Signed division can only overflow.
  bvDivO :: a -> a -> (SBool, SBool)

  -- | Bit-vector negation. Unsigned negation neither underflows nor overflows. Signed negation can only overflow.
  bvNegO :: a -> (SBool, SBool)

instance BVOverflow SWord8  where {bvAddO = l2 bvAddO; bvSubO = l2 bvSubO; bvMulO = l2 bvMulO; bvMulOFast = l2 bvMulOFast; bvDivO = l2 bvDivO; bvNegO = l1 bvNegO}
instance BVOverflow SWord16 where {bvAddO = l2 bvAddO; bvSubO = l2 bvSubO; bvMulO = l2 bvMulO; bvMulOFast = l2 bvMulOFast; bvDivO = l2 bvDivO; bvNegO = l1 bvNegO}
instance BVOverflow SWord32 where {bvAddO = l2 bvAddO; bvSubO = l2 bvSubO; bvMulO = l2 bvMulO; bvMulOFast = l2 bvMulOFast; bvDivO = l2 bvDivO; bvNegO = l1 bvNegO}
instance BVOverflow SWord64 where {bvAddO = l2 bvAddO; bvSubO = l2 bvSubO; bvMulO = l2 bvMulO; bvMulOFast = l2 bvMulOFast; bvDivO = l2 bvDivO; bvNegO = l1 bvNegO}
instance BVOverflow SInt8   where {bvAddO = l2 bvAddO; bvSubO = l2 bvSubO; bvMulO = l2 bvMulO; bvMulOFast = l2 bvMulOFast; bvDivO = l2 bvDivO; bvNegO = l1 bvNegO}
instance BVOverflow SInt16  where {bvAddO = l2 bvAddO; bvSubO = l2 bvSubO; bvMulO = l2 bvMulO; bvMulOFast = l2 bvMulOFast; bvDivO = l2 bvDivO; bvNegO = l1 bvNegO}
instance BVOverflow SInt32  where {bvAddO = l2 bvAddO; bvSubO = l2 bvSubO; bvMulO = l2 bvMulO; bvMulOFast = l2 bvMulOFast; bvDivO = l2 bvDivO; bvNegO = l1 bvNegO}
instance BVOverflow SInt64  where {bvAddO = l2 bvAddO; bvSubO = l2 bvSubO; bvMulO = l2 bvMulO; bvMulOFast = l2 bvMulOFast; bvDivO = l2 bvDivO; bvNegO = l1 bvNegO}

instance BVOverflow SVal where
  bvAddO     = signPick2 bvuaddo     bvsaddo
  bvSubO     = signPick2 bvusubo     bvssubo
  bvMulO     = signPick2 bvumulo     bvsmulo
  bvMulOFast = signPick2 bvumuloFast bvsmuloFast
  bvDivO     = signPick2 bvudivo     bvsdivo
  bvNegO     = signPick1 bvunego     bvsnego

-- | Zero-extend to given bits
zx :: Int -> SVal -> SVal
zx n a
 | n < sa = error $ "Data.SBV: Unexpected zero extension: from: " ++ show (intSizeOf a) ++ " to: " ++ show n
 | True   = p `svJoin` a
 where sa = intSizeOf a
       s  = hasSign a
       p  = svInteger (KBounded s (n - sa)) 0

-- | Sign-extend to given bits. Note that we keep the signedness of the argument.
sx :: Int -> SVal -> SVal
sx n a
 | n < sa = error $ "Data.SBV: Unexpected sign extension: from: " ++ show (intSizeOf a) ++ " to: " ++ show n
 | True   = p `svJoin` a
 where sa = intSizeOf a
       mk = svInteger $ KBounded (hasSign a) (n - sa)
       p  = svIte (pos a) (mk 0) (mk (-1))

-- | Get the sign-bit
signBit :: SVal -> SVal
signBit x = x `svTestBit` (intSizeOf x - 1)

-- | Is the sign-bit high?
neg :: SVal -> SVal
neg x = signBit x `svEqual` svTrue

-- | Is the sign-bit low?
pos :: SVal -> SVal
pos x = signBit x `svEqual` svFalse

-- | Do these have the same sign?
sameSign :: SVal -> SVal -> SVal
sameSign x y = (pos x `svAnd` pos y) `svOr` (neg x `svAnd` neg y)

-- | Do these have opposing signs?
diffSign :: SVal -> SVal -> SVal
diffSign x y = svNot (sameSign x y)

-- | Check all true
svAll :: [SVal] -> SVal
svAll = foldr svAnd svTrue

-- | Unsigned addition. Can only overflow.
bvuaddo :: Int -> SVal -> SVal -> (SVal, SVal)
bvuaddo n x y = (underflow, overflow)
  where underflow = svFalse

        n'       = n+1
        overflow = neg $ zx n' x `svPlus` zx n' y

-- | Signed addition.
bvsaddo :: Int -> SVal -> SVal -> (SVal, SVal)
bvsaddo _n x y = (underflow, overflow)
  where underflow = svAll [neg x, neg y, pos (x `svPlus` y)]
        overflow  = svAll [pos x, pos y, neg (x `svPlus` y)]

-- | Unsigned subtraction. Can only underflow.
bvusubo :: Int -> SVal -> SVal -> (SVal, SVal)
bvusubo _n x y = (underflow, overflow)
  where underflow = y `svGreaterThan` x
        overflow  = svFalse

-- | Signed subtraction.
bvssubo :: Int -> SVal -> SVal -> (SVal, SVal)
bvssubo _n x y = (underflow, overflow)
  where underflow = svAll [neg x, pos y, pos (x `svMinus` y)]
        overflow  = svAll [pos x, neg y, neg (x `svMinus` y)]

-- | Unsigned multiplication. Can only overflow.
bvumulo :: Int -> SVal -> SVal -> (SVal, SVal)
bvumulo 0 _ _ = (svFalse,   svFalse)
bvumulo n x y = (underflow, overflow)
  where underflow = svFalse

        n1        = n+1
        overflow1 = signBit $ zx n1 x `svTimes` zx n1 y

        -- From Z3 sources:
        --
        -- expr_ref ovf(m()), v(m()), tmp(m());
        -- ovf = m().mk_false();
        -- v = m().mk_false();
        -- for (unsigned i = 1; i < sz; ++i) {
        --    mk_or(ovf, a_bits[sz-i], ovf);
        --    mk_and(ovf, b_bits[i], tmp);
        --    mk_or(tmp, v, v);
        -- }
        -- overflow2 = v;
        --
        overflow2 = go 1 svFalse svFalse
          where go i ovf v
                 | i >= n = v
                 | True   = go (i+1) ovf' v'
                 where ovf' = ovf  `svOr`  (x `svTestBit` (n-i))
                       tmp  = ovf' `svAnd` (y `svTestBit` i)
                       v'   = tmp `svOr` v

        overflow = overflow1 `svOr` overflow2

-- | Signed multiplication.
bvsmulo :: Int -> SVal -> SVal -> (SVal, SVal)
bvsmulo 0 _ _ = (svFalse,   svFalse)
bvsmulo n x y = (underflow, overflow)
  where underflow = diffSign x y `svAnd` overflowPossible
        overflow  = sameSign x y `svAnd` overflowPossible

        n1        = n+1
        overflow1 = (xy1 `svTestBit` n) `svXOr` (xy1 `svTestBit` (n-1))
           where xy1 = sx n1 x `svTimes` sx n1 y

        -- From Z3 sources:
        -- expr_ref v(m()), tmp(m()), a(m()), b(m()), a_acc(m()), sign(m());
        -- a_acc = m().mk_false();
        -- v = m().mk_false();
        -- for (unsigned i = 1; i + 1 < sz; ++i) {
        --    mk_xor(b_bits[sz-1], b_bits[i], b);
        --    mk_xor(a_bits[sz-1], a_bits[sz-1-i], a);
        --    mk_or(a, a_acc, a_acc);
        --    mk_and(a_acc, b, tmp);
        --    mk_or(tmp, v, v);
        -- }
        -- overflow2 = v;
        overflow2 = go 1 svFalse svFalse
           where sY = signBit y
                 sX = signBit x
                 go i v a_acc
                  | i + 1 >= n = v
                  | True       = go (i+1) v' a_acc'
                  where b      = sY `svXOr` (y `svTestBit` i)
                        a      = sX `svXOr` (x `svTestBit` (n-1-i))
                        a_acc' = a `svOr` a_acc
                        tmp    = a_acc' `svAnd` b
                        v'     = tmp `svOr` v

        overflowPossible = overflow1 `svOr` overflow2

-- | Is this a concrete value?
known :: SVal -> Bool
known (SVal _ (Left _)) = True
known _                 = False

-- | Unsigned multiplication, fast version using z3 primitives.
bvumuloFast :: Int -> SVal -> SVal -> (SVal, SVal)
bvumuloFast n x y
   | known x && known y                         -- Not particularly fast, but avoids shipping of to the solver
   = bvumulo n x y
   | True
   = (underflow, overflow)
  where underflow = fst $ bvumulo n x y         -- No internal version for underflow exists (because it can't underflow)
        overflow  = svMkOverflow Overflow_UMul_OVFL x y

-- | Signed multiplication, fast version using z3 primitives.
bvsmuloFast :: Int -> SVal -> SVal -> (SVal, SVal)
bvsmuloFast n x y
  | known x && known y                -- Not particularly fast, but avoids shipping of to the solver
  = bvsmulo n x y
  | True
  = (underflow, overflow)
  where underflow = svMkOverflow Overflow_SMul_UDFL x y
        overflow  = svMkOverflow Overflow_SMul_OVFL x y

-- | Unsigned division. Neither underflows, nor overflows.
bvudivo :: Int -> SVal -> SVal -> (SVal, SVal)
bvudivo _ _ _ = (underflow, overflow)
  where underflow = svFalse
        overflow  = svFalse

-- | Signed division. Can only overflow.
bvsdivo :: Int -> SVal -> SVal -> (SVal, SVal)
bvsdivo n x y = (underflow, overflow)
  where underflow = svFalse

        ones      = svInteger (KBounded True n) (-1)
        topSet    = svInteger (KBounded True n) (2^(n-1))

        overflow = svAll [x `svEqual` topSet, y `svEqual` ones]

-- | Unsigned negation. Neither underflows, nor overflows.
bvunego :: Int -> SVal -> (SVal, SVal)
bvunego _ _ = (underflow, overflow)
  where underflow = svFalse
        overflow  = svFalse

-- | Signed negation. Can only overflow.
bvsnego :: Int -> SVal -> (SVal, SVal)
bvsnego n x = (underflow, overflow)
  where underflow = svFalse

        topSet    = svInteger (KBounded True n) (2^(n-1))
        overflow  = x `svEqual` topSet

-- Helpers
l2 :: (SVal -> SVal -> (SBool, SBool)) -> SBV a -> SBV a -> (SBool, SBool)
l2 f (SBV a) (SBV b) = f a b

l1 :: (SVal -> (SBool, SBool)) -> SBV a -> (SBool, SBool)
l1 f (SBV a) = f a

signPick2 :: (Int -> SVal -> SVal -> (SVal, SVal)) -> (Int -> SVal -> SVal -> (SVal, SVal)) -> (SVal -> SVal -> (SBool, SBool))
signPick2 fu fs a b
 | hasSign a = let (u, o) = fs n a b in (SBV u, SBV o)
 | True      = let (u, o) = fu n a b in (SBV u, SBV o)
 where n = intSizeOf a

signPick1 :: (Int -> SVal -> (SVal, SVal)) -> (Int -> SVal -> (SVal, SVal)) -> (SVal -> (SBool, SBool))
signPick1 fu fs a
 | hasSign a = let (u, o) = fs n a in (SBV u, SBV o)
 | True      = let (u, o) = fu n a in (SBV u, SBV o)
 where n = intSizeOf a
