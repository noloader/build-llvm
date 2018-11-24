#!/usr/bin/env bash

# build-llvm.sh - LLVM and component build script.
#
# Written and placed in public domain by Jeffrey Walton and Uri Blumenthal.
# This scripts builds the latest LLVM release from sources. The script is
# pieced together from the following web pages:
#
#  - https://llvm.org/docs/GettingStarted.html
#  - https://llvm.org/docs/CMake.html
#  - https://releases.llvm.org/download.html

# The libcxx and libcxxabi recipes are currently broken. There's a
# problem with a missing symbol called __thread_local_data(). We don't
# know how to work around it, and our LLVM mailing list questions have
# not been answered. Also see https://stackoverflow.com/q/53356172/608639.

# If you find a LLVM provided script you should use it instead. We could not
# find one so we are suffering the build process like hundreds of other
# developers before us.

# TODO
#
#  - fix libcxx and libcxxabi recipes
#  - port to Solaris (tar and --strip-component)
#  - investiagte RPATHs using ${ORIGIN}. Also see https://bit.ly/2RW4CGL
#  - investiagte install_names on OS X
#  - set LLVM_BUILD_TESTS="ON" eventually

################################################################
# Variables
################################################################

# CMake and Make location. Defaults to program on-path
CMAKE="${CMAKE:-cmake}"
MAKE="${MAKE:-make}"
TAR="${TAR:-tar}"

# AIX and Solaris override
if [[ "$MAKE" = "make" ]] && [[ -f "/usr/bin/gmake" ]]; then
	MAKE=/usr/bin/gmake
fi

# AIX and Solaris override
if [[ "$TAR" = "tar" ]] && [[ -f "/usr/linux/bin/tar" ]]; then
	TAR=/usr/linux/bin/tar
fi

# libcxx and libcxxabi recipes are broken. Also see
# https://stackoverflow.com/q/53356172/608639 and
# https://stackoverflow.com/q/53459921/608639
if [[ ! -z "$BUILD_SCRIPT_LIBCXX" ]]; then
	BUILD_SCRIPT_LIBCXX="false"
fi

# Download and install the additional self tests. LLVM
# has a minimal set of tests without the additional ones.
if [[ ! -z "$BUILD_SCRIPT_TESTS" ]]; then
	BUILD_SCRIPT_TESTS="false"
fi

# Concurrent make jobs
if [[ ! -z "$BUILD_SCRIPT_COMPILE_JOBS" ]]; then
	BUILD_SCRIPT_COMPILE_JOBS="4"
fi

# Where to install the artifacts
if [[ ! -z "$BUILD_SCRIPT_INSTALL_PREFIX" ]]; then
	BUILD_SCRIPT_INSTALL_PREFIX="/opt/llvm"
fi

# Easier override
if [[ ! -z "$PREFIX" ]]; then
	BUILD_SCRIPT_INSTALL_PREFIX="$PREFIX"
fi

# There must be an llvm/ in $BUILD_SCRIPT_SOURCE_DIR
BUILD_SCRIPT_SOURCE_DIR="$HOME/llvm_source/llvm"
BUILD_SCRIPT_BUILD_DIR="$HOME/llvm_build"

# LLVM_VERSION="7.0.0"
BUILD_SCRIPT_TARGET_ARCH="Unknown"

# https://llvm.org/docs/GettingStarted.html#local-llvm-configuration
BUILD_SCRIPT_HOST=$(uname -m)
if [[ $(uname -s) = "AIX" ]]; then
	BUILD_SCRIPT_HOST="aix";
fi

# These should be OK. "power" captures "Power Macintosh"
LOWER_HOST=$(echo "$BUILD_SCRIPT_HOST" | tr '[:upper:]' '[:lower:]')
case "$LOWER_HOST" in
	i86pc)
		BUILD_SCRIPT_TARGET_ARCH="X86" ;;
	i.86)
		BUILD_SCRIPT_TARGET_ARCH="X86" ;;
	x86_64)
		BUILD_SCRIPT_LIBCXX="true"
		BUILD_SCRIPT_TARGET_ARCH="X86" ;;
	amd64)
		BUILD_SCRIPT_LIBCXX="true"
		BUILD_SCRIPT_TARGET_ARCH="X86" ;;
	aix)
		BUILD_SCRIPT_TARGET_ARCH="PowerPC" ;;
	ppc*)
		BUILD_SCRIPT_TARGET_ARCH="PowerPC" ;;
	power*)
		BUILD_SCRIPT_TARGET_ARCH="PowerPC" ;;
	arm*)
		BUILD_SCRIPT_TARGET_ARCH="ARM" ;;
	eabihf)
		BUILD_SCRIPT_TARGET_ARCH="ARM" ;;
	aarch*)
		BUILD_SCRIPT_TARGET_ARCH="AArch64" ;;
	mips*)
		BUILD_SCRIPT_TARGET_ARCH="Mips" ;;
	sun)
		BUILD_SCRIPT_TARGET_ARCH="Sparc" ;;
	sparc*)
		BUILD_SCRIPT_TARGET_ARCH="Sparc" ;;
	*)
		echo "Unknown host platform $BUILD_SCRIPT_HOST"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
esac

################################################################
# Exit
################################################################

CURRENT_DIR=$(pwd)

function finish {
  cd "$CURRENT_DIR"
}
trap finish EXIT

################################################################
# Setup and clean old caches
################################################################

if [[ -d "$BUILD_SCRIPT_BUILD_DIR" ]]; then
	rm -rf "$BUILD_SCRIPT_BUILD_DIR"
fi

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR"
mkdir -p "$BUILD_SCRIPT_BUILD_DIR"

################################################################
# LLVM base
################################################################

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR"
cd "$BUILD_SCRIPT_SOURCE_DIR"

if [[ ! -f llvm-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/llvm-7.0.0.src.tar.xz;
	then
		echo "Attempting download LLVM using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/llvm-7.0.0.src.tar.xz;
		then
			echo "Failed to download LLVM sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f llvm-7.0.0.src.unpacked ]];
then
	if ! xz -cd llvm-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack LLVM sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch llvm-7.0.0.src.unpacked
fi

################################################################
# Clang front end
################################################################

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR/tools/clang"
cd "$BUILD_SCRIPT_SOURCE_DIR/tools/clang"

if [[ ! -f cfe-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/cfe-7.0.0.src.tar.xz;
	then
		echo "Attempting download Clang front end using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/cfe-7.0.0.src.tar.xz;
		then
			echo "Failed to download Clang front end sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f cfe-7.0.0.src.unpacked ]];
then
	if ! xz -cd cfe-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Clang front end sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch cfe-7.0.0.src.unpacked
fi

################################################################
# Clang Tools
################################################################

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR/tools/clang/tools/extra"
cd "$BUILD_SCRIPT_SOURCE_DIR/tools/clang/tools/extra"

if [[ ! -f clang-tools-extra-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/clang-tools-extra-7.0.0.src.tar.xz;
	then
		echo "Attempting download Clang Tools using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/clang-tools-extra-7.0.0.src.tar.xz;
		then
			echo "Failed to download Clang Tools sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f clang-tools-extra-7.0.0.src.unpacked ]];
then
	if ! xz -cd clang-tools-extra-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Clang Tools sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch clang-tools-extra-7.0.0.src.unpacked
fi

################################################################
# LLD Linker
################################################################

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR/tools/lld"
cd "$BUILD_SCRIPT_SOURCE_DIR/tools/lld"

if [[ ! -f lld-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/lld-7.0.0.src.tar.xz;
	then
		echo "Attempting download LLD Linker using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/lld-7.0.0.src.tar.xz;
		then
			echo "Failed to download LLD Linker sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f lld-7.0.0.src.unpacked ]];
then
	if ! xz -cd lld-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack LLD Linker sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch lld-7.0.0.src.unpacked
fi

################################################################
# Polly optimizer
################################################################

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR/tools/polly"
cd "$BUILD_SCRIPT_SOURCE_DIR/tools/polly"

if [[ ! -f polly-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/polly-7.0.0.src.tar.xz;
	then
		echo "Attempting download Polly Optimizer using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/polly-7.0.0.src.tar.xz;
		then
			echo "Failed to download Polly Optimizer sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f polly-7.0.0.src.unpacked ]];
then
	if ! xz -cd polly-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Polly Optimizer sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch polly-7.0.0.src.unpacked
fi

################################################################
# Compiler-RT
################################################################

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR/projects/compiler-rt"
cd "$BUILD_SCRIPT_SOURCE_DIR/projects/compiler-rt"

if [[ ! -f compiler-rt-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/compiler-rt-7.0.0.src.tar.xz;
	then
		echo "Attempting download Compiler-RT using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/compiler-rt-7.0.0.src.tar.xz;
		then
			echo "Failed to download Compiler-RT sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f compiler-rt-7.0.0.src.unpacked ]];
then
	if ! xz -cd compiler-rt-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Compiler-RT sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch compiler-rt-7.0.0.src.unpacked
fi

################################################################
# libc++
################################################################

if [[ "$BUILD_SCRIPT_LIBCXX" = "true" ]]; then

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR/projects/libcxx"
cd "$BUILD_SCRIPT_SOURCE_DIR/projects/libcxx"

if [[ ! -f libcxx-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/libcxx-7.0.0.src.tar.xz;
	then
		echo "Attempting download libc++ using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/libcxx-7.0.0.src.tar.xz;
		then
			echo "Failed to download libc++ sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f libcxx-7.0.0.src.unpacked ]];
then
	if ! xz -cd libcxx-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libc++ sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch libcxx-7.0.0.src.unpacked
fi

if [[ "$BUILD_SCRIPT_TARGET_ARCH" = "PowerPC" ]];
then
	# https://bugzilla.redhat.com/show_bug.cgi?id=1538817
	if [[ ! -f thread.patched ]];
	then
		echo "Patching libcxx/include/thread"
		THIS_FILE=include/thread
		sed -i "s/_LIBCPP_CONSTEXPR duration<long double> _Max/const duration<long double> _Max/g" "$THIS_FILE" > "$THIS_FILE.patched"
		mv "$THIS_FILE.patched" "$THIS_FILE"
		touch thread.patched
	fi
fi

fi

################################################################
# libc++abi
################################################################

if [[ "$BUILD_SCRIPT_LIBCXX" = "true" ]]; then

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR/projects/libcxxabi"
cd "$BUILD_SCRIPT_SOURCE_DIR/projects/libcxxabi"

if [[ ! -f libcxxabi-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/libcxxabi-7.0.0.src.tar.xz;
	then
		echo "Attempting download libc++abi using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/libcxxabi-7.0.0.src.tar.xz;
		then
			echo "Failed to download libc++abi sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f libcxxabi-7.0.0.src.unpacked ]];
then
	if ! xz -cd libcxxabi-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libc++abi sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch libcxxabi-7.0.0.src.unpacked
fi

fi

################################################################
# libunwind
################################################################

# TODO: Figure out how and when to use this.
# https://bcain-llvm.readthedocs.io/projects/libunwind/

if false; then

mkdir -p "$BUILD_SCRIPT_SOURCE_DIR/projects/libunwind"
cd "$BUILD_SCRIPT_SOURCE_DIR/projects/libunwind"

if [[ ! -f libunwind-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/libunwind-7.0.0.src.tar.xz;
	then
		echo "Attempting download libunwind using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/libunwind-7.0.0.src.tar.xz;
		then
			echo "Failed to download libunwind sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f libunwind-7.0.0.src.unpacked ]];
then
	if ! xz -cd libunwind-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libunwind sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch libunwind-7.0.0.src.unpacked
fi

# Don't build
fi

################################################################
# Test suite
################################################################

# TODO: Use the newly built compiler to build the test suite
# TODO: Turn LLVM_BUILD_TESTS to ON
#
# - https://llvm.org/docs/TestingGuide.html
# - https://llvm.org/docs/TestSuiteGuide.html

if [[ "$BUILD_SCRIPT_TESTS" = "true" ]]; then

# https://llvm.org/docs/GettingStarted.html#checkout-llvm-from-subversion
mkdir -p "$BUILD_SCRIPT_SOURCE_DIR/projects/test-suite"
cd "$BUILD_SCRIPT_SOURCE_DIR/projects/test-suite"

if [[ ! -f test-suite-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/test-suite-7.0.0.src.tar.xz;
	then
		echo "Attempting download Test Suite using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/test-suite-7.0.0.src.tar.xz;
		then
			echo "Failed to download Test Suite sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f test-suite-7.0.0.src.unpacked ]];
then
	if ! xz -cd test-suite-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Test Suite sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch test-suite-7.0.0.src.unpacked
fi

# BUILD_SCRIPT_TESTS
fi

################################################################
# Patches from https://reviews.llvm.org/D54787
################################################################

# Needed for PowerPC. Also see https://bugs.llvm.org/show_bug.cgi?id=39704
if [[ ! -f "$BUILD_SCRIPT_SOURCE_DIR/tools/clang/lib/Headers/altivec.h.patched" ]];
then
	echo "Patching altivec.h"
	cd "$BUILD_SCRIPT_SOURCE_DIR/tools/clang/lib/Headers/"
	
	if wget "https://reviews.llvm.org/file/data/pqvafnefzlkhyubairgc/PHID-FILE-t22yd7z53iacq5375jrt/lib_Headers_altivec.h" -O altivec.h;
	then	
		touch "$BUILD_SCRIPT_SOURCE_DIR/tools/clang/lib/Headers/altivec.h.patched"
	fi
fi

# Only fetch these if BUILD_SCRIPT_TESTS is ON
if [[ "$BUILD_SCRIPT_TESTS" = "true" ]]; then

if [[ ! -f "$BUILD_SCRIPT_SOURCE_DIR/test/CodeGen/test_CodeGen_builtins-ppc-altivec.c" ]];
then
	echo "Patching test_CodeGen_builtins-ppc-altivec.c"
	cd "$BUILD_SCRIPT_SOURCE_DIR/test/CodeGen/"
	
	if wget "https://reviews.llvm.org/file/data/vzh7jxxovv6dkijjtx65/PHID-FILE-vclvlhuqaauv753flmvi/test_CodeGen_builtins-ppc-altivec.c" -O test_CodeGen_builtins-ppc-altivec.c;
	then	
		touch "$BUILD_SCRIPT_SOURCE_DIR/test/CodeGen/test_CodeGen_builtins-ppc-altivec.c"
	fi
fi

if [[ ! -f "$BUILD_SCRIPT_SOURCE_DIR/test/CodeGen/test_CodeGen_builtins-ppc-vsx.c.patched" ]];
then
	echo "Patching test_CodeGen_builtins-ppc-vsx.c"
	cd "$BUILD_SCRIPT_SOURCE_DIR/test/CodeGen/"
	
	if wget "https://reviews.llvm.org/file/data/xdlnjqv4y6zc76r6kouh/PHID-FILE-5njcjgb57h6gncc6y5he/test_CodeGen_builtins-ppc-vsx.c" -O test_CodeGen_builtins-ppc-vsx.c;
	then	
		touch "$BUILD_SCRIPT_SOURCE_DIR/test/CodeGen/test_CodeGen_builtins-ppc-vsx.c.patched"
	fi
fi

# BUILD_SCRIPT_TESTS
fi

################################################################
# Build
################################################################

cd "$BUILD_SCRIPT_BUILD_DIR"

CMAKE_ARGS=()
CMAKE_ARGS+=(-DCMAKE_INSTALL_PREFIX="$BUILD_SCRIPT_INSTALL_PREFIX")
CMAKE_ARGS+=(-DLLVM_TARGETS_TO_BUILD="$BUILD_SCRIPT_TARGET_ARCH")
CMAKE_ARGS+=(-DLLVM_PARALLEL_COMPILE_JOBS="$BUILD_SCRIPT_COMPILE_JOBS")
CMAKE_ARGS+=(-DCMAKE_BUILD_TYPE="Release")
CMAKE_ARGS+=(-DLLVM_INCLUDE_TOOLS="ON")

if [[ "$BUILD_SCRIPT_LIBCXX" = "true" ]]; then
	CMAKE_ARGS+=(-DLIBCXX_LIBCPPABI_VERSION="")
fi

if [[ "$BUILD_SCRIPT_TESTS" = "true" ]]; then
	CMAKE_ARGS+=(-DLLVM_BUILD_TESTS="ON")
else
	CMAKE_ARGS+=(-DLLVM_BUILD_TESTS="OFF")
fi

# Add CC and CXX to CMake if provided in the environment.
if [[ ! -z "$CC" ]]; then
	CMAKE_ARGS+=(-DCMAKE_C_COMPILER="$CC")
fi
if [[ ! -z "$CXX" ]]; then
	CMAKE_ARGS+=(-DCMAKE_CXX_COMPILER="$CXX")
fi

if true; then
	echo
	echo "*****************************************************************************"
	echo "CMake arguments: ${CMAKE_ARGS[@]}"
	echo "*****************************************************************************"
	echo
fi

if ! "$CMAKE" "${CMAKE_ARGS[@]}" "$BUILD_SCRIPT_SOURCE_DIR";
then
	echo "Failed to cmake LLVM sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if ! "$MAKE" -j "$BUILD_SCRIPT_COMPILE_JOBS" VERBOSE=1;
then
	echo "Failed to make LLVM sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if ! "$MAKE" -j "$BUILD_SCRIPT_COMPILE_JOBS" check;
then
	echo "Failed to test LLVM sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "*****************************************************************************"
echo "It looks like the build and test succeeded. You next step are:"
echo "  cd $BUILD_SCRIPT_BUILD_DIR"
echo "  sudo make install"
echo "Then, optionally:"
echo "  cd ~"
echo "  rm -rf \"$BUILD_SCRIPT_SOURCE_DIR\" \"$BUILD_SCRIPT_BUILD_DIR\""
echo "*****************************************************************************"

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
