# -----------------------------------------------------------------------------
#
# (c) 2009 The University of Glasgow
#
# This file is part of the GHC build system.
#
# To understand how the build system works and how to modify it, see
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Architecture
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Modifying
#
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# For expressing extra dependencies on source files

define compiler-hs-dependency # args: $1 = module, $2 = dependency

$$(foreach stage,1 2 3,\
 $$(foreach way,$$(compiler_stage$$(stage)_WAYS),\
  compiler/stage$$(stage)/build/$1.$($(way)_osuf))) : $2

endef

# -----------------------------------------------------------------------------
# Create compiler configuration
#
# The 'echo' commands simply spit the values of various make variables
# into Config.hs, whence they can be compiled and used by GHC itself

compiler_CONFIG_HS = compiler/main/Config.hs

ifneq "$(BINDIST)" "YES"
compiler/stage1/package-data.mk : $(compiler_CONFIG_HS)
compiler/stage2/package-data.mk : $(compiler_CONFIG_HS)
compiler/stage3/package-data.mk : $(compiler_CONFIG_HS)
endif

$(compiler_CONFIG_HS) : mk/config.mk
	$(RM) -f $@
	@echo "Creating $@ ... "
	@echo "module Config where" >>$@
	@echo "cProjectName          :: String" >> $@
	@echo "cProjectName          = \"$(ProjectName)\"" >> $@
	@echo "cProjectVersion       :: String" >> $@
	@echo "cProjectVersion       = \"$(ProjectVersion)\"" >> $@
	@echo "cProjectVersionInt    :: String" >> $@
	@echo "cProjectVersionInt    = \"$(ProjectVersionInt)\"" >> $@
	@echo "cProjectPatchLevel    :: String" >> $@
	@echo "cProjectPatchLevel    = \"$(ProjectPatchLevel)\"" >> $@
	@echo "cBooterVersion        :: String" >> $@
	@echo "cBooterVersion        = \"$(GhcVersion)\"" >> $@
	@echo "cStage                :: String" >> $@
	@echo "cStage                = show (STAGE :: Int)" >> $@
	@echo "cHscIfaceFileVersion  :: String" >> $@
	@echo "cHscIfaceFileVersion  = \"$(HscIfaceFileVersion)\"" >> $@
	@echo "cSplitObjs            :: String" >> $@
	@echo "cSplitObjs            = \"$(SupportsSplitObjs)\"" >> $@
	@echo "cGhcWithInterpreter   :: String" >> $@
	@echo "cGhcWithInterpreter   = \"$(GhcWithInterpreter)\"" >> $@
	@echo "cGhcWithNativeCodeGen :: String" >> $@
	@echo "cGhcWithNativeCodeGen = \"$(GhcWithNativeCodeGen)\"" >> $@
	@echo "cGhcWithSMP           :: String" >> $@
	@echo "cGhcWithSMP           = \"$(GhcWithSMP)\"" >> $@
	@echo "cGhcRTSWays           :: String" >> $@
	@echo "cGhcRTSWays           = \"$(GhcRTSWays)\"" >> $@
	@echo "cGhcUnregisterised    :: String" >> $@
	@echo "cGhcUnregisterised    = \"$(GhcUnregisterised)\"" >> $@
	@echo "cGhcEnableTablesNextToCode :: String" >> $@
	@echo "cGhcEnableTablesNextToCode = \"$(GhcEnableTablesNextToCode)\"" >> $@
	@echo "cLeadingUnderscore    :: String" >> $@
	@echo "cLeadingUnderscore    = \"$(LeadingUnderscore)\"" >> $@
	@echo "cRAWCPP_FLAGS         :: String" >> $@
	@echo "cRAWCPP_FLAGS         = \"$(RAWCPP_FLAGS)\"" >> $@
	@echo "cGCC                  :: String" >> $@
	@echo "cGCC                  = \"$(WhatGccIsCalled)\"" >> $@
	@echo "cMKDLL                :: String" >> $@
	@echo "cMKDLL                = \"$(BLD_DLL)\"" >> $@
	@echo "cLdIsGNULd            :: String" >> $@
	@echo "cLdIsGNULd            = \"$(LdIsGNULd)\"" >> $@
	@echo "cLD_X		     :: String" >> $@
	@echo "cLD_X		     = \"$(LD_X)\"" >> $@
	@echo "cGHC_DRIVER_DIR   :: String" >> $@
	@echo "cGHC_DRIVER_DIR   = \"$(GHC_DRIVER_DIR)\"" >> $@
	@echo "cGHC_TOUCHY_PGM       :: String" >> $@
	@echo "cGHC_TOUCHY_PGM       = \"$(GHC_TOUCHY_PGM)\"" >> $@
	@echo "cGHC_TOUCHY_DIR   :: String" >> $@
	@echo "cGHC_TOUCHY_DIR   = \"$(GHC_TOUCHY_DIR)\"" >> $@
	@echo "cGHC_UNLIT_PGM        :: String" >> $@
	@echo "cGHC_UNLIT_PGM        = \"$(GHC_UNLIT_PGM)\"" >> $@
	@echo "cGHC_UNLIT_DIR    :: String" >> $@
	@echo "cGHC_UNLIT_DIR    = \"$(GHC_UNLIT_DIR)\"" >> $@
	@echo "cGHC_MANGLER_PGM      :: String" >> $@
	@echo "cGHC_MANGLER_PGM      = \"$(GHC_MANGLER_PGM)\"" >> $@
	@echo "cGHC_MANGLER_DIR  :: String" >> $@
	@echo "cGHC_MANGLER_DIR  = \"$(GHC_MANGLER_DIR)\"" >> $@
	@echo "cGHC_SPLIT_PGM        :: String" >> $@
	@echo "cGHC_SPLIT_PGM        = \"$(GHC_SPLIT_PGM)\"" >> $@
	@echo "cGHC_SPLIT_DIR    :: String" >> $@
	@echo "cGHC_SPLIT_DIR    = \"$(GHC_SPLIT_DIR)\"" >> $@
	@echo "cGHC_SYSMAN_PGM       :: String" >> $@
	@echo "cGHC_SYSMAN_PGM       = \"$(GHC_SYSMAN)\"" >> $@
	@echo "cGHC_SYSMAN_DIR   :: String" >> $@
	@echo "cGHC_SYSMAN_DIR   = \"$(GHC_SYSMAN_DIR)\"" >> $@
	@echo "cGHC_CP               :: String" >> $@
	@echo "cGHC_CP               = \"$(GHC_CP)\"" >> $@
	@echo "cGHC_PERL             :: String" >> $@
	@echo "cGHC_PERL             = \"$(GHC_PERL)\"" >> $@
	@echo "cEnableWin32DLLs      :: String" >> $@
	@echo "cEnableWin32DLLs      = \"$(EnableWin32DLLs)\"" >> $@
	@echo "cCONTEXT_DIFF         :: String" >> $@
	@echo "cCONTEXT_DIFF         = \"$(CONTEXT_DIFF)\"" >> $@
	@echo "cUSER_WAY_NAMES       :: String" >> $@
	@echo "cUSER_WAY_NAMES       = \"$(USER_WAY_NAMES)\"" >> $@
	@echo "cUSER_WAY_OPTS        :: String" >> $@
	@echo "cUSER_WAY_OPTS        = \"$(USER_WAY_OPTS)\"" >> $@
	@echo "cDEFAULT_TMPDIR       :: String" >> $@
	@echo "cDEFAULT_TMPDIR       = \"$(DEFAULT_TMPDIR)\"" >> $@
	@echo "cRelocatableBuild     :: Bool"                 >> $@
ifeq "$(RelocatableBuild)" "YES"
	@echo "cRelocatableBuild     = True"                  >> $@
else
	@echo "cRelocatableBuild     = False"                 >> $@
endif
	@echo "cLibFFI               :: Bool"                 >> $@
ifeq "$(UseLibFFIForAdjustors)" "YES"
	@echo "cLibFFI               = True"                  >> $@
else
	@echo "cLibFFI               = False"                 >> $@
endif
	@echo done.

$(eval $(call clean-target,compiler,config_hs,$(compiler_CONFIG_HS)))

# -----------------------------------------------------------------------------
# Create platform includes

# Here we generate a little header file containing CPP symbols that GHC
# uses to determine which platform it is building on/for.  The platforms
# can differ between stage1 and stage2 if we're cross-compiling, so we
# need one of these header files per stage.

PLATFORM_H = ghc_boot_platform.h

compiler/stage1/$(PLATFORM_H) : mk/config.mk
	$(MKDIRHIER) $(dir $@)
	$(RM) $@
	@echo "Creating $@..."
	@echo "#ifndef __PLATFORM_H__"  >$@
	@echo "#define __PLATFORM_H__" >>$@
	@echo >> $@
	@echo "#define BuildPlatform_NAME  \"$(BUILDPLATFORM)\"" >> $@
	@echo "#define HostPlatform_NAME   \"$(HOSTPLATFORM)\"" >> $@
	@echo "#define TargetPlatform_NAME \"$(TARGETPLATFORM)\"" >> $@
	@echo >> $@
	@echo "#define $(BuildPlatform_CPP)_BUILD  	1" >> $@
	@echo "#define $(HostPlatform_CPP)_HOST		1" >> $@
	@echo "#define $(TargetPlatform_CPP)_TARGET	1" >> $@
	@echo >> $@
	@echo "#define $(BuildArch_CPP)_BUILD_ARCH  	1" >> $@
	@echo "#define $(HostArch_CPP)_HOST_ARCH	1" >> $@
	@echo "#define $(TargetArch_CPP)_TARGET_ARCH	1" >> $@
	@echo "#define BUILD_ARCH \"$(BuildArch_CPP)\"" >> $@
	@echo "#define HOST_ARCH \"$(HostArch_CPP)\"" >> $@
	@echo "#define TARGET_ARCH \"$(TargetArch_CPP)\"" >> $@
	@echo >> $@
	@echo "#define $(BuildOS_CPP)_BUILD_OS 		1" >> $@
	@echo "#define $(HostOS_CPP)_HOST_OS		1" >> $@
	@echo "#define $(TargetOS_CPP)_TARGET_OS	1" >> $@  
	@echo "#define BUILD_OS \"$(BuildOS_CPP)\"" >> $@
	@echo "#define HOST_OS \"$(HostOS_CPP)\"" >> $@
	@echo "#define TARGET_OS \"$(TargetOS_CPP)\"" >> $@
ifeq "$(HostOS_CPP)" "irix"
	@echo "#ifndef $(IRIX_MAJOR)_TARGET_OS		 " >> $@  
	@echo "#define $(IRIX_MAJOR)_TARGET_OS		1" >> $@  
	@echo "#endif					 " >> $@  
endif
	@echo >> $@
	@echo "#define $(BuildVendor_CPP)_BUILD_VENDOR 	1" >> $@
	@echo "#define $(HostVendor_CPP)_HOST_VENDOR	1" >> $@
	@echo "#define $(TargetVendor_CPP)_TARGET_VENDOR  1" >> $@
	@echo "#define BUILD_VENDOR \"$(BuildVendor_CPP)\"" >> $@
	@echo "#define HOST_VENDOR \"$(HostVendor_CPP)\"" >> $@
	@echo "#define TARGET_VENDOR \"$(TargetVendor_CPP)\"" >> $@
	@echo >> $@
	@echo "#endif /* __PLATFORM_H__ */"          >> $@
	@echo "Done."

# For stage2 and above, the BUILD platform is the HOST of stage1, and
# the HOST platform is the TARGET of stage1.  The TARGET remains the same
# (stage1 is the cross-compiler, not stage2).
compiler/stage2/$(PLATFORM_H) : mk/config.mk
	$(MKDIRHIER) $(dir $@)
	$(RM) $@
	@echo "Creating $@..."
	@echo "#ifndef __PLATFORM_H__"  >$@
	@echo "#define __PLATFORM_H__" >>$@
	@echo >> $@
	@echo "#define BuildPlatform_NAME  \"$(HOSTPLATFORM)\"" >> $@
	@echo "#define HostPlatform_NAME   \"$(TARGETPLATFORM)\"" >> $@
	@echo "#define TargetPlatform_NAME \"$(TARGETPLATFORM)\"" >> $@
	@echo >> $@
	@echo "#define $(HostPlatform_CPP)_BUILD  	1" >> $@
	@echo "#define $(TargetPlatform_CPP)_HOST		1" >> $@
	@echo "#define $(TargetPlatform_CPP)_TARGET	1" >> $@
	@echo >> $@
	@echo "#define $(HostArch_CPP)_BUILD_ARCH  	1" >> $@
	@echo "#define $(TargetArch_CPP)_HOST_ARCH	1" >> $@
	@echo "#define $(TargetArch_CPP)_TARGET_ARCH	1" >> $@
	@echo "#define BUILD_ARCH \"$(HostArch_CPP)\"" >> $@
	@echo "#define HOST_ARCH \"$(TargetArch_CPP)\"" >> $@
	@echo "#define TARGET_ARCH \"$(TargetArch_CPP)\"" >> $@
	@echo >> $@
	@echo "#define $(HostOS_CPP)_BUILD_OS 		1" >> $@
	@echo "#define $(TargetOS_CPP)_HOST_OS		1" >> $@
	@echo "#define $(TargetOS_CPP)_TARGET_OS	1" >> $@  
	@echo "#define BUILD_OS \"$(HostOS_CPP)\"" >> $@
	@echo "#define HOST_OS \"$(TargetOS_CPP)\"" >> $@
	@echo "#define TARGET_OS \"$(TargetOS_CPP)\"" >> $@
ifeq "$(HostOS_CPP)" "irix"
	@echo "#ifndef $(IRIX_MAJOR)_TARGET_OS		 " >> $@  
	@echo "#define $(IRIX_MAJOR)_TARGET_OS		1" >> $@  
	@echo "#endif					 " >> $@  
endif
	@echo >> $@
	@echo "#define $(HostVendor_CPP)_BUILD_VENDOR 	1" >> $@
	@echo "#define $(TargetVendor_CPP)_HOST_VENDOR	1" >> $@
	@echo "#define $(TargetVendor_CPP)_TARGET_VENDOR  1" >> $@
	@echo "#define BUILD_VENDOR \"$(HostVendor_CPP)\"" >> $@
	@echo "#define HOST_VENDOR \"$(TargetVendor_CPP)\"" >> $@
	@echo "#define TARGET_VENDOR \"$(TargetVendor_CPP)\"" >> $@
	@echo >> $@
	@echo "#endif /* __PLATFORM_H__ */"          >> $@
	@echo "Done."

compiler/stage3/$(PLATFORM_H) : compiler/stage2/$(PLATFORM_H)
	$(CP) $< $@

# Every Constants.o object file depends on includes/GHCConstants.h:
$(eval $(call compiler-hs-dependency,Constants,$(includes_GHCCONSTANTS)))

# ----------------------------------------------------------------------------
#		Generate supporting stuff for prelude/PrimOp.lhs 
#		from prelude/primops.txt

# XXX: these should go in stage1/stage2/stage3
PRIMOP_BITS = compiler/primop-data-decl.hs-incl        \
              compiler/primop-tag.hs-incl              \
              compiler/primop-list.hs-incl             \
              compiler/primop-has-side-effects.hs-incl \
              compiler/primop-out-of-line.hs-incl      \
              compiler/primop-commutable.hs-incl       \
              compiler/primop-needs-wrapper.hs-incl    \
              compiler/primop-can-fail.hs-incl         \
              compiler/primop-strictness.hs-incl       \
              compiler/primop-primop-info.hs-incl

compiler_CPP_OPTS += -I$(GHC_INCLUDE_DIR)
compiler_CPP_OPTS += ${GhcCppOpts}

$(PRIMOPS_TXT) compiler/parser/Parser.y: %: %.pp compiler/stage1/$(PLATFORM_H)
	$(CPP) $(RAWCPP_FLAGS) -P $(compiler_CPP_OPTS) -x c $< | grep -v '^#pragma GCC' > $@

$(eval $(call clean-target,compiler,primop, $(PRIMOPS_TXT) compiler/parser/Parser.y $(PRIMOP_BITS)))

compiler/primop-data-decl.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --data-decl          < $< > $@
compiler/primop-tag.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --primop-tag         < $< > $@
compiler/primop-list.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --primop-list        < $< > $@
compiler/primop-has-side-effects.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --has-side-effects   < $< > $@
compiler/primop-out-of-line.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --out-of-line        < $< > $@
compiler/primop-commutable.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --commutable         < $< > $@
compiler/primop-needs-wrapper.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --needs-wrapper      < $< > $@
compiler/primop-can-fail.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --can-fail           < $< > $@
compiler/primop-strictness.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --strictness         < $< > $@
compiler/primop-primop-info.hs-incl: $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE)
	$(GENPRIMOP_INPLACE) --primop-primop-info < $< > $@

# Every PrimOp.o object file depends on $(PRIMOP_BITS):
$(eval $(call compiler-hs-dependency,PrimOp,$(PRIMOP_BITS)))

# Usages aren't used any more; but the generator 
# can still generate them if we want them back
compiler/primop-usage.hs-incl: $(PRIMOPS_TXT)
	$(GENPRIMOP_INPLACE) --usage              < $< > $@

# -----------------------------------------------------------------------------
# Configuration

compiler_stage1_CONFIGURE_OPTS += --flags=stage1
compiler_stage2_CONFIGURE_OPTS += --flags=stage2
compiler_stage3_CONFIGURE_OPTS += --flags=stage3

ifeq "$(GhcWithNativeCodeGen)" "YES"
compiler_stage1_CONFIGURE_OPTS += --flags=ncg
compiler_stage2_CONFIGURE_OPTS += --flags=ncg
endif

ifeq "$(GhcWithInterpreter)" "YES"
compiler_stage2_CONFIGURE_OPTS += --flags=ghci

ifeq "$(BuildSharedLibs)" "YES"
compiler_stage2_CONFIGURE_OPTS += --enable-shared
# If we are going to use dynamic libraries instead of .o files for ghci,
# we will need to always retain CAFs in the compiler.
# ghci/keepCAFsForGHCi contains a GNU C __attribute__((constructor))
# function which sets the keepCAFs flag for the RTS before any Haskell
# code is run.
compiler_stage2_CONFIGURE_OPTS += --flags=dynlibs
endif

ifeq "$(GhcEnableTablesNextToCode) $(GhcUnregisterised)" "YES NO"
# Should GHCI be building info tables in the TABLES_NEXT_TO_CODE style
# or not?
# XXX This should logically be a CPP option, but there doesn't seem to
# be a flag for that
compiler_stage2_CONFIGURE_OPTS += --ghc-option=-DGHCI_TABLES_NEXT_TO_CODE
endif

# Should the debugger commands be enabled?
ifeq "$(GhciWithDebugger)" "YES"
compiler_stage2_CONFIGURE_OPTS += --ghc-option=-DDEBUGGER
endif

endif

ifeq "$(GhcWithNativeCodeGen)" "NO"
# XXX This should logically be a CPP option, but there doesn't seem to
# be a flag for that
compiler_CONFIGURE_OPTS += --ghc-option=-DOMIT_NATIVE_CODEGEN
endif

ifeq "$(TargetOS_CPP)" "openbsd"
compiler_CONFIGURE_OPTS += --ld-options=-E
endif

ifeq "$(GhcUnregisterised)" "NO"
ifeq "$(HOSTPLATFORM)" "ia64-unknown-linux"
# needed for generating proper relocation in large binaries: trac #856
compiler_CONFIGURE_OPTS += --ld-option=-Wl,--relax
endif
endif

# We need to turn on profiling either if we have been asked to
# (GhcLibProfiled = YES) or if we want GHC itself to be compiled with
# profiling enabled (GhcProfiled = YES).
ifneq "$(GhcLibProfiled) $(GhcProfiled)" "NO NO"
compiler_stage2_CONFIGURE_OPTS += --enable-library-profiling
# And if we're profiling GHC then we want lots of SCCs.
# We also don't want to waste time building the non-profiling library,
# either normally or for ghci. Unfortunately this means that we have to
# tell ghc-pkg --force as it gets upset when libHSghc-6.9.a doesn't
# exist.
ifeq "$(GhcProfiled)" "YES"
compiler_stage2_CONFIGURE_OPTS += --ghc-option=-auto-all
compiler_stage2_CONFIGURE_OPTS += --disable-library-vanilla
compiler_stage2_CONFIGURE_OPTS += --disable-library-for-ghci
compiler_stage2_CONFIGURE_OPTS += --ghc-pkg-option=--force
endif
endif

ifeq "$(HOSTPLATFORM)" "i386-unknown-mingw32"
# The #include is vital for the via-C route with older compilers, else the C
# compiler doesn't realise that the stcall foreign imports are indeed
# stdcall, and doesn't generate the Foo@8 name for them
# As it's only important for older compilers we don't need to do anything
# for stage2+.
compiler_stage1_CONFIGURE_OPTS += --ghc-option='-\#include'    \
                          --ghc-option='"<windows.h>"' \
                          --ghc-option='-\#include'    \
                          --ghc-option='"<process.h>"'
endif

# ghc_strlen percolates through so many modules that it is easier to get its
# prototype via a global option instead of a myriad of per-file OPTIONS.
# Again, this is only important for older compilers, so we don't do it in
# stage 2+.
compiler_stage1_CONFIGURE_OPTS += --ghc-options='-\#include "cutils.h"'

compiler_stage3_CONFIGURE_OPTS := $(compiler_stage2_CONFIGURE_OPTS)

compiler_stage1_CONFIGURE_OPTS += --ghc-option=-DSTAGE=1
compiler_stage2_CONFIGURE_OPTS += --ghc-option=-DSTAGE=2
compiler_stage3_CONFIGURE_OPTS += --ghc-option=-DSTAGE=3
compiler_stage2_HADDOCK_OPTS += --haddock-option=--optghc=-DSTAGE=2

compiler_stage1_CONFIGURE_OPTS += --ghc-options='$(GhcStage1HcOpts)'
compiler_stage2_CONFIGURE_OPTS += --ghc-options='$(GhcStage2HcOpts)'
compiler_stage3_CONFIGURE_OPTS += --ghc-options='$(GhcStage3HcOpts)'

compiler/stage1/package-data.mk : compiler/ghc.mk
compiler/stage2/package-data.mk : compiler/ghc.mk
compiler/stage3/package-data.mk : compiler/ghc.mk

# -----------------------------------------------------------------------------
# And build the package

compiler_PACKAGE = ghc

# Note [fiddle-stage1-version]
# The version of the GHC package changes every day, since the
# patchlevel is the current date.  We don't want to force
# recompilation of the entire compiler when this happens, so for stage
# 1 we omit the patchlevel from the version number.  For stage 2 we
# have to include the patchlevel since this is the package we install,
# however.
#
# Note: we also have to tweak the version number of the package itself
# when it gets registered; see Note [munge-stage1-package-config]
# below.
ifneq "$(ProjectPatchLevel)" "0"
define compiler_PACKAGE_MAGIC
compiler_stage1_VERSION = $(subst .$(ProjectPatchLevel),,$(ProjectVersion))
endef
endif

# haddocking only happens for stage2
compiler_stage1_DO_HADDOCK = NO
compiler_stage3_DO_HADDOCK = NO

# Don't do splitting for the GHC package, it takes too long and
# there's not much benefit.
compiler_stage1_SplitObjs = NO
compiler_stage2_SplitObjs = NO
compiler_stage3_SplitObjs = NO

# For now, bindists always use stage 2
ifneq "$(BINDIST)" "YES"
# stage 1 is enabled unless $(stage) is set to something other than 1
ifeq "$(filter-out 1,$(stage))" ""
$(eval $(call build-package,compiler,stage1,0))
endif
endif

# stage 2 is enabled unless $(stage) is set to something other than 2
ifeq "$(filter-out 2,$(stage))" ""
$(eval $(call build-package,compiler,stage2,1))
endif

ifneq "$(BINDIST)" "YES"
# stage 3 has to be requested explicitly with stage=3
ifeq "$(stage)" "3"
$(eval $(call build-package,compiler,stage3,2))
endif

$(compiler_stage1_depfile) : compiler/stage1/$(PLATFORM_H)
$(compiler_stage2_depfile) : compiler/stage2/$(PLATFORM_H)
$(compiler_stage3_depfile) : compiler/stage3/$(PLATFORM_H)

$(compiler_stage1_depfile) : $(includes_H_CONFIG) $(includes_H_PLATFORM) $(includes_GHCCONSTANTS) $(includes_DERIVEDCONSTANTS) $(PRIMOP_BITS)
$(compiler_stage2_depfile) : $(includes_H_CONFIG) $(includes_H_PLATFORM) $(includes_GHCCONSTANTS) $(includes_DERIVEDCONSTANTS) $(PRIMOP_BITS)
$(compiler_stage3_depfile) : $(includes_H_CONFIG) $(includes_H_PLATFORM) $(includes_GHCCONSTANTS) $(includes_DERIVEDCONSTANTS) $(PRIMOP_BITS)

# Note [munge-stage1-package-config]
# Strip the date/patchlevel from the version of stage1.  See Note
# [fiddle-stage1-version] above.
ifneq "$(ProjectPatchLevel)" "0"
compiler/stage1/inplace-pkg-config-munged: compiler/stage1/inplace-pkg-config
	sed "s#.$(ProjectPatchLevel)##" <$< >$@
	$(compiler_stage1_GHC_PKG) update --force $(compiler_stage1_GHC_PKG_OPTS) $@

$(compiler_stage1_v_LIB) : compiler/stage1/inplace-pkg-config-munged
endif

endif
