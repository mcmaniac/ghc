\begin{code}
-- Type definitions for the constraint solver
module TcSMonad ( 

       -- Canonical constraints
    CanonicalCts, emptyCCan, andCCan, andCCans, 
    singleCCan, extendCCans, isEmptyCCan,
    CanonicalCt(..), Xi, tyVarsOfCanonical, tyVarsOfCanonicals,
    mkWantedConstraints, deCanonicaliseWanted, 
    makeGivens, makeSolved,

    CtFlavor (..), isWanted, isGiven, isDerived, canRewrite, 
    joinFlavors, mkGivenFlavor,

    TcS, runTcS, failTcS, panicTcS, traceTcS, traceTcS0,  -- Basic functionality 
    tryTcS, nestImplicTcS, wrapErrTcS, wrapWarnTcS,
    SimplContext(..), isInteractive, simplEqsOnly, performDefaulting,
       
       -- Creation of evidence variables

    newWantedCoVar, newGivOrDerCoVar, newGivOrDerEvVar, 
    newIPVar, newDictVar, newKindConstraint,

       -- Setting evidence variables 
    setWantedCoBind, setDerivedCoBind, 
    setIPBind, setDictBind, setEvBind,

    setWantedTyBind,

    newTcEvBindsTcS,
 
    getInstEnvs, getFamInstEnvs,                -- Getting the environments 
    getTopEnv, getGblEnv, getTcEvBinds, getUntouchablesTcS,
    getTcEvBindsBag, getTcSContext, getTcSTyBinds,


    newFlattenSkolemTy,                         -- Flatten skolems 

    instDFunTypes,                              -- Instantiation
    instDFunConstraints,                        

    isGoodRecEv,

    isTouchableMetaTyVar,

    getDefaultInfo, getDynFlags,

    matchClass, matchFam, MatchInstResult (..), 
    checkWellStagedDFun, 
    warnTcS,
    pprEq,                                   -- Smaller utils, re-exported from TcM 
                                             -- TODO (DV): these are only really used in the 
                                             -- instance matcher in TcSimplify. I am wondering
                                             -- if the whole instance matcher simply belongs
                                             -- here 


    mkWantedFunDepEqns                       -- Instantiation of 'Equations' from FunDeps

) where 

#include "HsVersions.h"

import HscTypes
import BasicTypes 
import Type

import Inst
import InstEnv 
import FamInst 
import FamInstEnv

import NameSet ( addOneToNameSet ) 

import qualified TcRnMonad as TcM
import qualified TcMType as TcM
import qualified TcEnv as TcM 
       ( checkWellStaged, topIdLvl, tcLookupFamInst, tcGetDefaultTys )
import TcType
import Module 
import DynFlags

import Coercion
import Class
import TyCon
import Name
import Var
import Outputable
import Bag
import MonadUtils
import VarSet
import FastString

import HsBinds               -- for TcEvBinds stuff 
import Id 
import FunDeps

import TcRnTypes

import Control.Monad
import Data.IORef
\end{code}


%************************************************************************
%*									*
%*                       Canonical constraints                          *
%*                                                                      *
%*   These are the constraints the low-level simplifier works with      *
%*									*
%************************************************************************

\begin{code}
-- Types without any type functions inside.  However, note that xi
-- types CAN contain unexpanded type synonyms; however, the
-- (transitive) expansions of those type synonyms will not contain any
-- type functions.
type Xi = Type       -- In many comments, "xi" ranges over Xi

type CanonicalCts = Bag CanonicalCt
 
data CanonicalCt
  -- Atomic canonical constraints 
  = CDictCan {  -- e.g.  Num xi
      cc_id     :: EvVar,
      cc_flavor :: CtFlavor, 
      cc_class  :: Class, 
      cc_tyargs :: [Xi]
    }

  | CIPCan {	-- ?x::tau
      -- See note [Canonical implicit parameter constraints].
      cc_id     :: EvVar,
      cc_flavor :: CtFlavor, 
      cc_ip_nm  :: IPName Name,
      cc_ip_ty  :: TcTauType
    }

  | CTyEqCan {  -- tv ~ xi	(recall xi means function free)
       -- Invariant: 
       --   * tv not in tvs(xi)   (occurs check)
       --   * If tv is a MetaTyVar, then typeKind xi <: typeKind tv 
       --              a skolem,    then typeKind xi =  typeKind tv 
      cc_id     :: EvVar, 
      cc_flavor :: CtFlavor, 
      cc_tyvar :: TcTyVar, 
      cc_rhs   :: Xi
    }

  | CFunEqCan {  -- F xis ~ xi  
                 -- Invariant: * isSynFamilyTyCon cc_fun 
                 --            * cc_rhs is not a touchable unification variable 
                 --                   See Note [No touchables as FunEq RHS]
                 --            * typeKind (TyConApp cc_fun cc_tyargs) == typeKind cc_rhs
      cc_id     :: EvVar,
      cc_flavor :: CtFlavor, 
      cc_fun    :: TyCon,	-- A type function
      cc_tyargs :: [Xi],	-- Either under-saturated or exactly saturated
      cc_rhs    :: Xi      	--    *never* over-saturated (because if so
      		      		--    we should have decomposed)
                   
    }

makeGivens :: CanonicalCts -> CanonicalCts
makeGivens = mapBag (\ct -> ct { cc_flavor = mkGivenFlavor (cc_flavor ct) UnkSkol })
	   -- The UnkSkol doesn't matter because these givens are
	   -- not contradictory (else we'd have rejected them already)

makeSolved :: CanonicalCt -> CanonicalCt
-- Record that a constraint is now solved
-- 	  Wanted         -> Derived
--	  Given, Derived -> no-op
makeSolved ct 
  | Wanted loc <- cc_flavor ct = ct { cc_flavor = Derived loc }
  | otherwise                  = ct

mkWantedConstraints :: CanonicalCts -> Bag Implication -> WantedConstraints
mkWantedConstraints flats implics 
  = mapBag (WcEvVar . deCanonicaliseWanted) flats `unionBags` mapBag WcImplic implics

deCanonicaliseWanted :: CanonicalCt -> WantedEvVar
deCanonicaliseWanted ct 
  = WARN( not (isWanted $ cc_flavor ct), ppr ct ) 
    let Wanted loc = cc_flavor ct 
    in WantedEvVar (cc_id ct) loc

tyVarsOfCanonical :: CanonicalCt -> TcTyVarSet
tyVarsOfCanonical (CTyEqCan { cc_tyvar = tv, cc_rhs = xi })    = extendVarSet (tyVarsOfType xi) tv
tyVarsOfCanonical (CFunEqCan { cc_tyargs = tys, cc_rhs = xi }) = tyVarsOfTypes (xi:tys)
tyVarsOfCanonical (CDictCan { cc_tyargs = tys }) 	       = tyVarsOfTypes tys
tyVarsOfCanonical (CIPCan { cc_ip_ty = ty })     	       = tyVarsOfType ty

tyVarsOfCanonicals :: CanonicalCts -> TcTyVarSet
tyVarsOfCanonicals = foldrBag (unionVarSet . tyVarsOfCanonical) emptyVarSet

instance Outputable CanonicalCt where
  ppr (CDictCan d fl cls tys)     
      = ppr fl <+> ppr d  <+> dcolon <+> pprClassPred cls tys
  ppr (CIPCan ip fl ip_nm ty)     
      = ppr fl <+> ppr ip <+> dcolon <+> parens (ppr ip_nm <> dcolon <> ppr ty)
  ppr (CTyEqCan co fl tv ty)      
      = ppr fl <+> ppr co <+> dcolon <+> pprEqPred (mkTyVarTy tv, ty)
  ppr (CFunEqCan co fl tc tys ty) 
      = ppr fl <+> ppr co <+> dcolon <+> pprEqPred (mkTyConApp tc tys, ty)
\end{code}


Note [No touchables as FunEq RHS]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Notice that (F xis ~ beta), where beta is an touchable unification
variable, is not canonical.  Why?  
  * If (F xis ~ beta) was the only wanted constraint, we'd 
    definitely want to spontaneously-unify it

  * But suppose we had an earlier wanted (beta ~ Int), and 
    have already spontaneously unified it.  Then we have an
    identity given (id : beta ~ Int) in the inert set.  

  * But (F xis ~ beta) does not react with that given (because we
    don't subsitute on the RHS of a function equality).  So there's a
    serious danger that we'd spontaneously unify it a second time.

Hence the invariant.

Note [Canonical implicit parameter constraints]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The type in a canonical implicit parameter constraint doesn't need to
be a xi (type-function-free type) since we can defer the flattening
until checking this type for equality with another type.  If we
encounter two IP constraints with the same name, they MUST have the
same type, and at that point we can generate a flattened equality
constraint between the types.  (On the other hand, the types in two
class constraints for the same class MAY be equal, so they need to be
flattened in the first place to facilitate comparing them.)

\begin{code}
singleCCan :: CanonicalCt -> CanonicalCts 
singleCCan = unitBag 

andCCan :: CanonicalCts -> CanonicalCts -> CanonicalCts 
andCCan = unionBags

extendCCans :: CanonicalCts -> CanonicalCt -> CanonicalCts 
extendCCans = snocBag 

andCCans :: [CanonicalCts] -> CanonicalCts 
andCCans = unionManyBags

emptyCCan :: CanonicalCts 
emptyCCan = emptyBag

isEmptyCCan :: CanonicalCts -> Bool
isEmptyCCan = isEmptyBag
\end{code}

%************************************************************************
%*									*
                    CtFlavor
         The "flavor" of a canonical constraint
%*									*
%************************************************************************

\begin{code}
data CtFlavor 
  = Given   GivenLoc  -- We have evidence for this constraint in TcEvBinds
  | Derived WantedLoc -- We have evidence for this constraint in TcEvBinds;
                      --   *however* this evidence can contain wanteds, so 
                      --   it's valid only provisionally to the solution of
                      --   these wanteds 
  | Wanted WantedLoc  -- We have no evidence bindings for this constraint. 

instance Outputable CtFlavor where 
  ppr (Given _)   = ptext (sLit "[Given]")
  ppr (Wanted _)  = ptext (sLit "[Wanted]")
  ppr (Derived _) = ptext (sLit "[Derived]") 

isWanted :: CtFlavor -> Bool 
isWanted (Wanted {}) = True
isWanted _           = False

isGiven :: CtFlavor -> Bool 
isGiven (Given {}) = True 
isGiven _          = False 

isDerived :: CtFlavor -> Bool 
isDerived ctid =  not $ isGiven ctid || isWanted ctid 

canRewrite :: CtFlavor -> CtFlavor -> Bool 
-- canRewrite ctid1 ctid2 
-- The constraint ctid1 can be used to rewrite ctid2 
canRewrite (Given {})   _            = True 
canRewrite (Derived {}) (Wanted {})  = True 
canRewrite (Derived {}) (Derived {}) = True 
canRewrite (Wanted {})  (Wanted {})  = True
canRewrite _ _ = False

joinFlavors :: CtFlavor -> CtFlavor -> CtFlavor 
joinFlavors (Wanted loc) _  = Wanted loc 
joinFlavors _ (Wanted loc)  = Wanted loc 
joinFlavors (Derived loc) _ = Derived loc 
joinFlavors _ (Derived loc) = Derived loc 
joinFlavors (Given loc) _   = Given loc

mkGivenFlavor :: CtFlavor -> SkolemInfo -> CtFlavor
mkGivenFlavor (Wanted  loc) sk = Given (setCtLocOrigin loc sk)
mkGivenFlavor (Derived loc) sk = Given (setCtLocOrigin loc sk)
mkGivenFlavor (Given   loc) sk = Given (setCtLocOrigin loc sk)
\end{code}


%************************************************************************
%*									*
%*		The TcS solver monad                                    *
%*									*
%************************************************************************

Note [The TcS monad]
~~~~~~~~~~~~~~~~~~~~
The TcS monad is a weak form of the main Tc monad

All you can do is
    * fail
    * allocate new variables
    * fill in evidence variables

Filling in a dictionary evidence variable means to create a binding
for it, so TcS carries a mutable location where the binding can be
added.  This is initialised from the innermost implication constraint.

\begin{code}
data TcSEnv
  = TcSEnv { 
      tcs_ev_binds :: EvBindsVar,
          -- Evidence bindings

      tcs_ty_binds :: IORef (Bag (TcTyVar, TcType)),
          -- Global type bindings

      tcs_context :: SimplContext
    }

data SimplContext
  = SimplInfer		-- Inferring type of a let-bound thing
  | SimplRuleLhs	-- Inferring type of a RULE lhs
  | SimplInteractive	-- Inferring type at GHCi prompt
  | SimplCheck		-- Checking a type signature or RULE rhs

instance Outputable SimplContext where
  ppr SimplInfer       = ptext (sLit "SimplInfer")
  ppr SimplRuleLhs     = ptext (sLit "SimplRuleLhs")
  ppr SimplInteractive = ptext (sLit "SimplInteractive")
  ppr SimplCheck       = ptext (sLit "SimplCheck")

isInteractive :: SimplContext -> Bool
isInteractive SimplInteractive = True
isInteractive _                = False

simplEqsOnly :: SimplContext -> Bool
-- Simplify equalities only, not dictionaries
-- This is used for the LHS of rules; ee
-- Note [Simplifying RULE lhs constraints] in TcSimplify
simplEqsOnly SimplRuleLhs = True
simplEqsOnly _            = False

performDefaulting :: SimplContext -> Bool
performDefaulting SimplInfer   	   = False
performDefaulting SimplRuleLhs 	   = False
performDefaulting SimplInteractive = True
performDefaulting SimplCheck       = True

---------------
newtype TcS a = TcS { unTcS :: TcSEnv -> TcM a } 

instance Functor TcS where
  fmap f m = TcS $ fmap f . unTcS m

instance Monad TcS where 
  return x  = TcS (\_ -> return x) 
  fail err  = TcS (\_ -> fail err) 
  m >>= k   = TcS (\ebs -> unTcS m ebs >>= \r -> unTcS (k r) ebs)

-- Basic functionality 
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
wrapTcS :: TcM a -> TcS a 
-- Do not export wrapTcS, because it promotes an arbitrary TcM to TcS,
-- and TcS is supposed to have limited functionality
wrapTcS = TcS . const -- a TcM action will not use the TcEvBinds

wrapErrTcS :: TcM a -> TcS a 
-- The thing wrapped should just fail
-- There's no static check; it's up to the user
-- Having a variant for each error message is too painful
wrapErrTcS = wrapTcS

wrapWarnTcS :: TcM a -> TcS a 
-- The thing wrapped should just add a warning, or no-op
-- There's no static check; it's up to the user
wrapWarnTcS = wrapTcS

failTcS, panicTcS :: SDoc -> TcS a
failTcS      = wrapTcS . TcM.failWith
panicTcS doc = pprPanic "TcCanonical" doc

traceTcS :: String -> SDoc -> TcS ()
traceTcS herald doc = TcS $ \_env -> TcM.traceTc herald doc

traceTcS0 :: String -> SDoc -> TcS ()
traceTcS0 herald doc = TcS $ \_env -> TcM.traceTcN 0 herald doc

runTcS :: SimplContext
       -> TcTyVarSet 	       -- Untouchables
       -> TcS a		       -- What to run
       -> TcM (a, Bag EvBind)
runTcS context untouch tcs 
  = do { ty_binds_var <- TcM.newTcRef emptyBag
       ; ev_binds_var@(EvBindsVar evb_ref _) <- TcM.newTcEvBinds
       ; let env = TcSEnv { tcs_ev_binds = ev_binds_var
                          , tcs_ty_binds = ty_binds_var
                          , tcs_context = context }

	     -- Run the computation
       ; res <- TcM.setUntouchables untouch (unTcS tcs env)

	     -- Perform the type unifications required
       ; ty_binds <- TcM.readTcRef ty_binds_var
       ; mapBagM_ do_unification ty_binds

             -- And return
       ; ev_binds <- TcM.readTcRef evb_ref
       ; return (res, evBindMapBinds ev_binds) }
  where
    do_unification (tv,ty) = TcM.writeMetaTyVar tv ty
       
nestImplicTcS :: EvBindsVar -> TcTyVarSet -> TcS a -> TcS a 
nestImplicTcS ref untouch tcs 
  = TcS $ \ TcSEnv { tcs_ty_binds = ty_binds, tcs_context = ctxt } -> 
    let 
       nest_env = TcSEnv { tcs_ev_binds = ref
                         , tcs_ty_binds = ty_binds
                         , tcs_context = ctxtUnderImplic ctxt }
    in 
    TcM.setUntouchables untouch (unTcS tcs nest_env) 

ctxtUnderImplic :: SimplContext -> SimplContext
-- See Note [Simplifying RULE lhs constraints] in TcSimplify
ctxtUnderImplic SimplRuleLhs = SimplCheck
ctxtUnderImplic ctxt         = ctxt

tryTcS :: TcTyVarSet -> TcS a -> TcS a 
-- Like runTcS, but from within the TcS monad 
-- Ignore all the evidence generated, and do not affect caller's evidence!
tryTcS untch tcs 
  = TcS (\env -> do { ty_binds_var <- TcM.newTcRef emptyBag
                    ; ev_binds_var <- TcM.newTcEvBinds
                    ; let env1 = env { tcs_ev_binds = ev_binds_var
                                     , tcs_ty_binds = ty_binds_var }
                    ; TcM.setUntouchables untch (unTcS tcs env1) })

-- Update TcEvBinds 
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

getDynFlags :: TcS DynFlags
getDynFlags = wrapTcS TcM.getDOpts

getTcSContext :: TcS SimplContext
getTcSContext = TcS (return . tcs_context)

getTcEvBinds :: TcS EvBindsVar
getTcEvBinds = TcS (return . tcs_ev_binds) 

getTcSTyBinds :: TcS (IORef (Bag (TcTyVar, TcType)))
getTcSTyBinds = TcS (return . tcs_ty_binds)

getTcEvBindsBag :: TcS EvBindMap
getTcEvBindsBag
  = do { EvBindsVar ev_ref _ <- getTcEvBinds 
       ; wrapTcS $ TcM.readTcRef ev_ref }

setWantedCoBind :: CoVar -> Coercion -> TcS () 
setWantedCoBind cv co 
  = setEvBind cv (EvCoercion co)
     -- Was: wrapTcS $ TcM.writeWantedCoVar cv co 

setDerivedCoBind :: CoVar -> Coercion -> TcS () 
setDerivedCoBind cv co 
  = setEvBind cv (EvCoercion co)

setWantedTyBind :: TcTyVar -> TcType -> TcS () 
-- Add a type binding
setWantedTyBind tv ty 
  = do { ref <- getTcSTyBinds
       ; wrapTcS $ 
         do { ty_binds <- TcM.readTcRef ref
            ; TcM.writeTcRef ref (ty_binds `snocBag` (tv,ty)) } }

setIPBind :: EvVar -> EvTerm -> TcS () 
setIPBind = setEvBind 

setDictBind :: EvVar -> EvTerm -> TcS () 
setDictBind = setEvBind 

setEvBind :: EvVar -> EvTerm -> TcS () 
-- Internal
setEvBind ev rhs 
  = do { tc_evbinds <- getTcEvBinds 
       ; wrapTcS (TcM.addTcEvBind tc_evbinds ev rhs) }

newTcEvBindsTcS :: TcS EvBindsVar
newTcEvBindsTcS = wrapTcS (TcM.newTcEvBinds)

warnTcS :: CtLoc orig -> Bool -> SDoc -> TcS ()
warnTcS loc warn_if doc 
  | warn_if   = wrapTcS $ TcM.setCtLoc loc $ TcM.addWarnTc doc
  | otherwise = return ()

getDefaultInfo ::  TcS (SimplContext, [Type], (Bool, Bool))
getDefaultInfo 
  = do { ctxt <- getTcSContext
       ; (tys, flags) <- wrapTcS (TcM.tcGetDefaultTys (isInteractive ctxt))
       ; return (ctxt, tys, flags) }

-- Just get some environments needed for instance looking up and matching
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

getInstEnvs :: TcS (InstEnv, InstEnv) 
getInstEnvs = wrapTcS $ Inst.tcGetInstEnvs 

getFamInstEnvs :: TcS (FamInstEnv, FamInstEnv) 
getFamInstEnvs = wrapTcS $ FamInst.tcGetFamInstEnvs

getTopEnv :: TcS HscEnv 
getTopEnv = wrapTcS $ TcM.getTopEnv 

getGblEnv :: TcS TcGblEnv 
getGblEnv = wrapTcS $ TcM.getGblEnv 

getUntouchablesTcS :: TcS TcTyVarSet 
getUntouchablesTcS = wrapTcS $ TcM.getUntouchables

-- Various smaller utilities [TODO, maybe will be absorbed in the instance matcher]
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

checkWellStagedDFun :: PredType -> DFunId -> WantedLoc -> TcS () 
checkWellStagedDFun pred dfun_id loc 
  = wrapTcS $ TcM.setCtLoc loc $ 
    do { use_stage <- TcM.getStage
       ; TcM.checkWellStaged pp_thing bind_lvl (thLevel use_stage) }
  where
    pp_thing = ptext (sLit "instance for") <+> quotes (ppr pred)
    bind_lvl = TcM.topIdLvl dfun_id

pprEq :: TcType -> TcType -> SDoc
pprEq ty1 ty2 = pprPred $ mkEqPred (ty1,ty2)

isTouchableMetaTyVar :: TcTyVar -> TcS Bool
-- is touchable variable!
isTouchableMetaTyVar v 
  | isMetaTyVar v = wrapTcS $ do { untch <- TcM.isUntouchable v; 
                                 ; return (not untch) }
  | otherwise     = return False


-- Flatten skolems
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

newFlattenSkolemTy :: TcType -> TcS TcType
newFlattenSkolemTy ty = mkTyVarTy <$> newFlattenSkolemTyVar ty
  where newFlattenSkolemTyVar :: TcType -> TcS TcTyVar
        newFlattenSkolemTyVar ty
            = wrapTcS $ do { uniq <- TcM.newUnique
                           ; let name = mkSysTvName uniq (fsLit "f")
                           ; return $ mkTcTyVar name (typeKind ty) (FlatSkol ty)
                           }

-- Instantiations 
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

instDFunTypes :: [Either TyVar TcType] -> TcS [TcType] 
instDFunTypes mb_inst_tys = 
  let inst_tv :: Either TyVar TcType -> TcS Type
      inst_tv (Left tv)  = wrapTcS $ TcM.tcInstTyVar tv >>= return . mkTyVarTy
      inst_tv (Right ty) = return ty 
  in mapM inst_tv mb_inst_tys


instDFunConstraints :: TcThetaType -> TcS [EvVar] 
instDFunConstraints preds = wrapTcS $ TcM.newWantedEvVars preds 


-- Superclasses and recursive dictionaries 
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

newGivOrDerEvVar :: TcPredType -> EvTerm -> TcS EvVar 
newGivOrDerEvVar pty evtrm 
  = do { ev <- wrapTcS $ TcM.newEvVar pty 
       ; setEvBind ev evtrm 
       ; return ev }

newGivOrDerCoVar :: TcType -> TcType -> Coercion -> TcS EvVar 
-- Note we create immutable variables for given or derived, since we
-- must bind them to TcEvBinds (because their evidence may involve 
-- superclasses). However we should be able to override existing
-- 'derived' evidence, even in TcEvBinds 
newGivOrDerCoVar ty1 ty2 co 
  = do { cv <- newCoVar ty1 ty2
       ; setEvBind cv (EvCoercion co) 
       ; return cv } 

newWantedCoVar :: TcType -> TcType -> TcS EvVar 
newWantedCoVar ty1 ty2 =  wrapTcS $ TcM.newWantedCoVar ty1 ty2 

newKindConstraint :: TcType -> Kind -> TcS (CoVar, TcType)
newKindConstraint ty kind =  wrapTcS $ TcM.newKindConstraint ty kind

newCoVar :: TcType -> TcType -> TcS EvVar 
newCoVar ty1 ty2 = wrapTcS $ TcM.newCoVar ty1 ty2 

newIPVar :: IPName Name -> TcType -> TcS EvVar 
newIPVar nm ty = wrapTcS $ TcM.newIP nm ty 

newDictVar :: Class -> [TcType] -> TcS EvVar 
newDictVar cl tys = wrapTcS $ TcM.newDict cl tys 
\end{code} 


\begin{code} 
isGoodRecEv :: EvVar -> WantedEvVar -> TcS Bool 
-- In a call (isGoodRecEv ev wv), we are considering solving wv 
-- using some term that involves ev, such as:
-- by setting		wv = ev
-- or                   wv = EvCast x |> ev
-- etc. 
-- But that would be Very Bad if the evidence for 'ev' mentions 'wv',
-- in an "unguarded" way. So isGoodRecEv looks at the evidence ev 
-- recursively through the evidence binds, to see if uses of 'wv' are guarded.
--
-- Guarded means: more instance calls than superclass selections. We
-- compute this by chasing the evidence, adding +1 for every instance
-- call (constructor) and -1 for every superclass selection (destructor).
--
-- See Note [Superclasses and recursive dictionaries] in TcInteract
isGoodRecEv ev_var (WantedEvVar wv _)
  = do { tc_evbinds <- getTcEvBindsBag 
       ; mb <- chase_ev_var tc_evbinds wv 0 [] ev_var 
       ; return $ case mb of 
                    Nothing -> True 
                    Just min_guardedness -> min_guardedness > 0
       }

  where chase_ev_var :: EvBindMap   -- Evidence binds 
                 -> EvVar           -- Target variable whose gravity we want to return
                 -> Int             -- Current gravity 
                 -> [EvVar]         -- Visited nodes
                 -> EvVar           -- Current node 
                 -> TcS (Maybe Int)
        chase_ev_var assocs trg curr_grav visited orig
            | trg == orig         = return $ Just curr_grav
            | orig `elem` visited = return $ Nothing 
            | Just (EvBind _ ev_trm) <- lookupEvBind assocs orig
            = chase_ev assocs trg curr_grav (orig:visited) ev_trm

{-  No longer needed: evidence is in the EvBinds
            | isTcTyVar orig && isMetaTyVar orig 
            = do { meta_details <- wrapTcS $ TcM.readWantedCoVar orig
                 ; case meta_details of 
                     Flexi -> return Nothing 
                     Indirect tyco -> chase_ev assocs trg curr_grav 
                                             (orig:visited) (EvCoercion tyco)
                           }
-}
            | otherwise = return Nothing 

        chase_ev assocs trg curr_grav visited (EvId v) 
            = chase_ev_var assocs trg curr_grav visited v
        chase_ev assocs trg curr_grav visited (EvSuperClass d_id _) 
            = chase_ev_var assocs trg (curr_grav-1) visited d_id
        chase_ev assocs trg curr_grav visited (EvCast v co)
            = do { m1 <- chase_ev_var assocs trg curr_grav visited v
                 ; m2 <- chase_co assocs trg curr_grav visited co
                 ; return (comb_chase_res Nothing [m1,m2]) } 

        chase_ev assocs trg curr_grav visited (EvCoercion co)
            = chase_co assocs trg curr_grav visited co
        chase_ev assocs trg curr_grav visited (EvDFunApp _ _ ev_vars) 
            = do { chase_results <- mapM (chase_ev_var assocs trg (curr_grav+1) visited) ev_vars
                 ; return (comb_chase_res Nothing chase_results) } 

        chase_co assocs trg curr_grav visited co 
            = -- Look for all the coercion variables in the coercion 
              -- chase them, and combine the results. This is OK since the
              -- coercion will not contain any superclass terms -- anything 
              -- that involves dictionaries will be bound in assocs. 
              let co_vars       = foldVarSet (\v vrs -> if isCoVar v then (v:vrs) else vrs) []
                                             (tyVarsOfType co)
              in do { chase_results <- mapM (chase_ev_var assocs trg curr_grav visited) co_vars
                    ; return (comb_chase_res Nothing chase_results) } 

        comb_chase_res f []                   = f 
        comb_chase_res f (Nothing:rest)       = comb_chase_res f rest 
        comb_chase_res Nothing (Just n:rest)  = comb_chase_res (Just n) rest
        comb_chase_res (Just m) (Just n:rest) = comb_chase_res (Just (min n m)) rest 


-- Matching and looking up classes and family instances
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

data MatchInstResult mi
  = MatchInstNo         -- No matching instance 
  | MatchInstSingle mi  -- Single matching instance
  | MatchInstMany       -- Multiple matching instances


matchClass :: Class -> [Type] -> TcS (MatchInstResult (DFunId, [Either TyVar TcType])) 
-- Look up a class constraint in the instance environment
matchClass clas tys
  = do	{ let pred = mkClassPred clas tys 
        ; instEnvs <- getInstEnvs
	; case lookupInstEnv instEnvs clas tys of {
            ([], unifs)               -- Nothing matches  
                -> do { traceTcS "matchClass not matching"
                                 (vcat [ text "dict" <+> ppr pred, 
                                         text "unifs" <+> ppr unifs ]) 
                      ; return MatchInstNo  
                      } ;  
	    ([(ispec, inst_tys)], []) -- A single match 
		-> do	{ let dfun_id = is_dfun ispec
			; traceTcS "matchClass success"
				   (vcat [text "dict" <+> ppr pred, 
				          text "witness" <+> ppr dfun_id
					   <+> ppr (idType dfun_id) ])
				  -- Record that this dfun is needed
			; record_dfun_usage dfun_id
			; return $ MatchInstSingle (dfun_id, inst_tys) 
                        } ;
     	    (matches, unifs)          -- More than one matches 
		-> do	{ traceTcS "matchClass multiple matches, deferring choice"
			           (vcat [text "dict" <+> ppr pred,
				   	  text "matches" <+> ppr matches,
				   	  text "unifs" <+> ppr unifs])
                        ; return MatchInstMany 
		        }
	}
        }
  where record_dfun_usage :: Id -> TcS () 
        record_dfun_usage dfun_id 
          = do { hsc_env <- getTopEnv 
               ; let  dfun_name = idName dfun_id
        	      dfun_mod  = ASSERT( isExternalName dfun_name ) 
        	         	  nameModule dfun_name
               ; if isInternalName dfun_name ||    -- Internal name => defined in this module
        	    modulePackageId dfun_mod /= thisPackage (hsc_dflags hsc_env)
        	 then return () -- internal, or in another package
        	 else do updInstUses dfun_id 
               }

        updInstUses :: Id -> TcS () 
        updInstUses dfun_id 
            = do { tcg_env <- getGblEnv 
                 ; wrapTcS $ TcM.updMutVar (tcg_inst_uses tcg_env) 
                                            (`addOneToNameSet` idName dfun_id) 
                 }

matchFam :: TyCon 
         -> [Type] 
         -> TcS (MatchInstResult (TyCon, [Type]))
matchFam tycon args
  = do { mb <- wrapTcS $ TcM.tcLookupFamInst tycon args
       ; case mb of 
           Nothing  -> return MatchInstNo 
           Just res -> return $ MatchInstSingle res
       -- DV: We never return MatchInstMany, since tcLookupFamInst never returns 
       -- multiple matches. Check. 
       }


-- Functional dependencies, instantiation of equations
-------------------------------------------------------

mkWantedFunDepEqns :: WantedLoc -> [(Equation, (PredType, SDoc), (PredType, SDoc))]
                   -> TcS [WantedEvVar] 
mkWantedFunDepEqns _   [] = return []
mkWantedFunDepEqns loc eqns
  = do { traceTcS "Improve:" (vcat (map pprEquationDoc eqns))
       ; wevvars <- mapM to_work_item eqns
       ; return $ concat wevvars }
  where
    to_work_item :: (Equation, (PredType,SDoc), (PredType,SDoc)) -> TcS [WantedEvVar]
    to_work_item ((qtvs, pairs), _, _)
      = do { (_, _, tenv) <- wrapTcS $ TcM.tcInstTyVars (varSetElems qtvs)
           ; mapM (do_one tenv) pairs }

    do_one tenv (ty1, ty2) = do { let sty1 = substTy tenv ty1 
                                      sty2 = substTy tenv ty2 
                                ; ev <- newWantedCoVar sty1 sty2
                                ; return (WantedEvVar ev loc) }

pprEquationDoc :: (Equation, (PredType, SDoc), (PredType, SDoc)) -> SDoc
pprEquationDoc (eqn, (p1, _), (p2, _)) 
  = vcat [pprEquation eqn, nest 2 (ppr p1), nest 2 (ppr p2)]
\end{code}