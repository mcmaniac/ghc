%
% (c) The University of Glasgow, 2000
%
\section[Linker]{The In-Memory Object File Linker}

\begin{code}
{-# OPTIONS -#include "Linker.h" #-}
module Linker ( 
   initLinker,	 -- :: IO ()
   loadObj,      -- :: String -> IO ()
   unloadObj,    -- :: String -> IO ()
   lookupSymbol, -- :: String -> IO (Maybe (Ptr a))
   resolveObjs,  -- :: IO ()
   addDLL	 -- :: String -> IO Bool
  )  where

import Foreign		( Ptr, nullPtr )
import PrelByteArr
import PrelPack 	(packString)
import Panic		( panic )

-- ---------------------------------------------------------------------------
-- RTS Linker Interface
-- ---------------------------------------------------------------------------

lookupSymbol str = do
   addr <- c_lookupSymbol (packString str)
   if addr == nullPtr
	then return Nothing
	else return (Just addr)

loadObj str = do
   r <- c_loadObj (packString str)
   if (r == 0)
	then panic "loadObj: failed"
	else return ()

unloadObj str = do
   r <- c_unloadObj (packString str)
   if (r == 0)
	then panic "unloadObj: failed"
	else return ()

resolveObjs = do
   r <- c_resolveObjs
   if (r == 0)
	then panic "resolveObjs: failed"
	else return ()

addDLL str = do
   r <- c_addDLL (packString str)
   return (r == 0)

type PackedString = ByteArray Int

foreign import "lookupSymbol" unsafe
   c_lookupSymbol :: PackedString -> IO (Ptr a)

foreign import "loadObj" unsafe
   c_loadObj :: PackedString -> IO Int

foreign import "unloadObj" unsafe
   c_unloadObj :: PackedString -> IO Int

foreign import "resolveObjs" unsafe
   c_resolveObjs :: IO Int

foreign import "initLinker" unsafe
   initLinker :: IO ()

foreign import "addDLL" unsafe 
   c_addDLL :: PackedString -> IO Int

\end{code}
