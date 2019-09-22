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

# The script applies two patches:
#  - https://bugs.llvm.org/show_bug.cgi?id=39704
#  - https://bugzilla.redhat.com/show_bug.cgi?id=1538817

# The libcxx and libcxxabi recipes are mostly broken. They only work on X86.
# There's a problem with a missing symbol called __thread_local_data(). We
# don't know how to work around, and our LLVM mailing list questions have
# not been answered. Also see https://stackoverflow.com/q/53356172/608639.

# TODO
#
#  - Figure out libcxx and libcxxabi build procedure on some other
#    useful platforms like PowerPC.

################################################################
# Variables
################################################################

# CMake and Make location. Defaults to program on-path
CMAKE="${CMAKE:-cmake}"
MAKE="${MAKE:-make}"
TAR="${TAR:-tar}"

# Wget falls back to insecure check if the secure fetch fails. This is
# needed for Wget builds that use OpenSSL instead of GnuTLS. Also see
# https://lists.gnu.org/archive/html/bug-wget/2017-10/msg00004.html
INSECURE=--no-check-certificate

# AIX and Solaris override
if [[ "$MAKE" = "make" ]] && [[ ! -z $(command -v gmake) ]]; then
	MAKE=$(command -v gmake)
fi

# AIX and Solaris override
if [[ "$TAR" = "tar" ]] && [[ -f "/usr/linux/bin/tar" ]]; then
	TAR=/usr/linux/bin/tar
elif [[ "$TAR" = "tar" ]] && [[ -f "/usr/gnu/bin/tar" ]]; then
	TAR=/usr/gnu/bin/tar
fi

# Compiler-RT is a no-go on Solaris
if [[ -z "$BS_TOOLS" ]]; then
	BS_TOOLS="ON"
fi

# libcxx and libcxxabi recipes are mostly broken. Also see
# https://stackoverflow.com/q/53356172/608639 and
# https://stackoverflow.com/q/53459921/608639
if [[ -z "$BS_LIBCXX" ]]; then
	BS_LIBCXX="OFF"
fi

# Download and install the additional self tests. LLVM
# has a minimal set of tests without the additional ones.
if [[ -z "$BS_TESTS" ]]; then
	BS_TESTS="ON"
fi

# Concurrent make jobs
if [[ -z "$BS_COMPILE_JOBS" ]]; then
	BS_COMPILE_JOBS="4"
fi

# Easier override
if [[ ! -z "$JOBS" ]]; then
	BS_COMPILE_JOBS="$JOBS"
fi

# Where to install the artifacts
if [[ -z "$BS_INSTALL_PREFIX" ]]; then
	BS_INSTALL_PREFIX="/opt/llvm"
fi

# Easier override
if [[ ! -z "$PREFIX" ]]; then
	BS_INSTALL_PREFIX="$PREFIX"
fi

# DO NOT include llvm/ in $BS_SOURCE_DIR
if [[ -z "$BS_SOURCE_DIR" ]]; then
	BS_SOURCE_DIR="$HOME/llvm_source"
fi
if [[ -z "$BS_BUILD_DIR" ]]; then
	BS_BUILD_DIR="$HOME/llvm_build"
fi

# LLVM_VERSION="7.0.0"
BS_TARGET_ARCH="Unknown"

# https://llvm.org/docs/GettingStarted.html#local-llvm-configuration
BS_ARCH=$(uname -m)
if [[ $(uname -s) = "AIX" ]]; then
	BS_ARCH="aix";
fi

# These should be OK. "power" captures "Power Macintosh".
# libcxx and libcxxabi only seems to work on X86 Linux.
LOWER_ARCH=$(echo "$BS_ARCH" | tr '[:upper:]' '[:lower:]')
case "$LOWER_ARCH" in
	i86pc)
		echo "Setting BS_TOOLS=OFF BS_LIBCXX=OFF for X86"
		BS_TOOLS="OFF"
		BS_LIBCXX="OFF"
		BS_TARGET_ARCH="X86" ;;
	i.86)
		echo "Setting BS_LIBCXX=ON for X86"
		BS_LIBCXX="ON"
		BS_TARGET_ARCH="X86" ;;
	i386|i686)
		echo "Setting BS_LIBCXX=ON for X86"
		BS_LIBCXX="ON"
		BS_TARGET_ARCH="X86" ;;
	amd64|x86_64)
		echo "Setting BS_LIBCXX=ON for X86"
		BS_LIBCXX="ON"
		BS_TARGET_ARCH="X86" ;;
	aix|ppc*|power*)
		echo "Setting BS_LIBCXX=OFF for PowerPC"
		BS_LIBCXX="OFF"
		BS_TARGET_ARCH="PowerPC" ;;
	eabihf|arm*)
		BS_TARGET_ARCH="ARM" ;;
	aarch*)
		BS_TARGET_ARCH="AArch64" ;;
	mips*)
		echo "Setting BS_LIBCXX=OFF for MIPS"
		BS_LIBCXX="OFF"
		BS_TARGET_ARCH="Mips" ;;
	sun|sparc*)
		echo "Setting BS_LIBCXX=OFF for SPARC"
		BS_LIBCXX="OFF"
		BS_TARGET_ARCH="Sparc" ;;
	*)
		echo "Unknown host platform $BS_ARCH"
		exit 1
esac

if true; then
	echo
	echo "*****************************************************************************"
	echo "BS_SOURCE_DIR: $BS_SOURCE_DIR"
	echo "BS_BUILD_DIR: $BS_BUILD_DIR"
	echo "BS_TARGET_ARCH: $BS_TARGET_ARCH"
	echo "BS_COMPILE_JOBS: $BS_COMPILE_JOBS"
	echo "BS_INSTALL_PREFIX: $BS_INSTALL_PREFIX"
	echo "BS_TOOLS: $BS_TOOLS"
	echo "BS_LIBCXX: $BS_LIBCXX"
	echo "BS_TESTS: $BS_TESTS"
	echo "*****************************************************************************"
	echo
fi

################################################################
# Exit
################################################################

CURRENT_DIR=$(pwd)

function finish {
  # Swallow failure on exit
  cd "$CURRENT_DIR" || true
}
trap finish EXIT

################################################################
# Setup and clean old caches
################################################################

if [[ -d "$BS_BUILD_DIR" ]]; then
	rm -rf "$BS_BUILD_DIR"
fi

mkdir -p "$BS_SOURCE_DIR/llvm"
mkdir -p "$BS_BUILD_DIR"

################################################################
# LLVM base
################################################################

mkdir -p "$BS_SOURCE_DIR/llvm"
if ! cd "$BS_SOURCE_DIR/llvm"; then
	echo "Failed to enter $BS_SOURCE_DIR/llvm"
	exit 1
fi

if [[ ! -f llvm-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/llvm-7.0.0.src.tar.xz;
	then
		echo "Attempting download LLVM using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/llvm-7.0.0.src.tar.xz;
		then
			echo "Failed to download LLVM sources"
			exit 1
		fi
	fi
fi

if [[ ! -f llvm-7.0.0.src.unpacked ]];
then
	if ! xz -cd llvm-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack LLVM sources"
		exit 1
	fi
	touch llvm-7.0.0.src.unpacked
fi

################################################################
# Clang front end
################################################################

mkdir -p "$BS_SOURCE_DIR/llvm/tools/clang"
if ! cd "$BS_SOURCE_DIR/llvm/tools/clang"; then
	echo "Failed to enter directory"
	exit 1
fi

if [[ ! -f cfe-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/cfe-7.0.0.src.tar.xz;
	then
		echo "Attempting download Clang front end using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/cfe-7.0.0.src.tar.xz;
		then
			echo "Failed to download Clang front end sources"
			exit 1
		fi
	fi
fi

if [[ ! -f cfe-7.0.0.src.unpacked ]];
then
	if ! xz -cd cfe-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Clang front end sources"
		exit 1
	fi
	touch cfe-7.0.0.src.unpacked
fi

################################################################
# Clang Tools
################################################################

mkdir -p "$BS_SOURCE_DIR/llvm/tools/clang/tools/extra"
if ! cd "$BS_SOURCE_DIR/llvm/tools/clang/tools/extra"; then
	echo "Failed to enter directory"
	exit 1
fi

if [[ ! -f clang-tools-extra-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/clang-tools-extra-7.0.0.src.tar.xz;
	then
		echo "Attempting download Clang Tools using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/clang-tools-extra-7.0.0.src.tar.xz;
		then
			echo "Failed to download Clang Tools sources"
			exit 1
		fi
	fi
fi

if [[ ! -f clang-tools-extra-7.0.0.src.unpacked ]];
then
	if ! xz -cd clang-tools-extra-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Clang Tools sources"
		exit 1
	fi
	touch clang-tools-extra-7.0.0.src.unpacked
fi

################################################################
# LLD Linker
################################################################

mkdir -p "$BS_SOURCE_DIR/llvm/tools/lld"
if ! cd "$BS_SOURCE_DIR/llvm/tools/lld"; then
	echo "Failed to enter directory"
	exit 1
fi

if [[ ! -f lld-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/lld-7.0.0.src.tar.xz;
	then
		echo "Attempting download LLD Linker using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/lld-7.0.0.src.tar.xz;
		then
			echo "Failed to download LLD Linker sources"
			exit 1
		fi
	fi
fi

if [[ ! -f lld-7.0.0.src.unpacked ]];
then
	if ! xz -cd lld-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack LLD Linker sources"
		exit 1
	fi
	touch lld-7.0.0.src.unpacked
fi

################################################################
# Polly optimizer
################################################################

mkdir -p "$BS_SOURCE_DIR/llvm/tools/polly"
if ! cd "$BS_SOURCE_DIR/llvm/tools/polly"; then
	echo "Failed to enter directory"
	exit 1
fi

if [[ ! -f polly-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/polly-7.0.0.src.tar.xz;
	then
		echo "Attempting download Polly Optimizer using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/polly-7.0.0.src.tar.xz;
		then
			echo "Failed to download Polly Optimizer sources"
			exit 1
		fi
	fi
fi

if [[ ! -f polly-7.0.0.src.unpacked ]];
then
	if ! xz -cd polly-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Polly Optimizer sources"
		exit 1
	fi
	touch polly-7.0.0.src.unpacked
fi

################################################################
# Compiler-RT
################################################################

if [[ "$BS_TOOLS" = "ON" ]]; then

mkdir -p "$BS_SOURCE_DIR/llvm/projects/compiler-rt"
if ! cd "$BS_SOURCE_DIR/llvm/projects/compiler-rt"; then
	echo "Failed to enter directory"
	exit 1
fi

if [[ ! -f compiler-rt-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/compiler-rt-7.0.0.src.tar.xz;
	then
		echo "Attempting download Compiler-RT using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/compiler-rt-7.0.0.src.tar.xz;
		then
			echo "Failed to download Compiler-RT sources"
			exit 1
		fi
	fi
fi

if [[ ! -f compiler-rt-7.0.0.src.unpacked ]];
then
	if ! xz -cd compiler-rt-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Compiler-RT sources"
		exit 1
	fi
	touch compiler-rt-7.0.0.src.unpacked
fi

# BS_TOOLS
fi

################################################################
# libc++
################################################################

if [[ "$BS_LIBCXX" = "ON" ]]; then

mkdir -p "$BS_SOURCE_DIR/llvm/projects/libcxx"
if ! cd "$BS_SOURCE_DIR/llvm/projects/libcxx"; then
	echo "Failed to enter directory"
	exit 1
fi

if [[ ! -f libcxx-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/libcxx-7.0.0.src.tar.xz;
	then
		echo "Attempting download libc++ using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/libcxx-7.0.0.src.tar.xz;
		then
			echo "Failed to download libc++ sources"
			exit 1
		fi
	fi
fi

if [[ ! -f libcxx-7.0.0.src.unpacked ]];
then
	if ! xz -cd libcxx-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libc++ sources"
		exit 1
	fi
	touch libcxx-7.0.0.src.unpacked
fi

# BS_LIBCXX
fi

################################################################
# libc++abi
################################################################

if [[ "$BS_LIBCXX" = "ON" ]]; then

mkdir -p "$BS_SOURCE_DIR/llvm/projects/libcxxabi"
if ! cd "$BS_SOURCE_DIR/llvm/projects/libcxxabi"; then
	echo "Failed to enter directory"
	exit 1
fi

if [[ ! -f libcxxabi-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/libcxxabi-7.0.0.src.tar.xz;
	then
		echo "Attempting download libc++abi using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/libcxxabi-7.0.0.src.tar.xz;
		then
			echo "Failed to download libc++abi sources"
			exit 1
		fi
	fi
fi

if [[ ! -f libcxxabi-7.0.0.src.unpacked ]];
then
	if ! xz -cd libcxxabi-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libc++abi sources"
		exit 1
	fi
	touch libcxxabi-7.0.0.src.unpacked
fi

# BS_LIBCXX
fi

################################################################
# libunwind
################################################################

# TODO: Figure out how and when to use this.
# https://bcain-llvm.readthedocs.io/projects/libunwind/

if false; then

mkdir -p "$BS_SOURCE_DIR/llvm/projects/libunwind"
if ! cd "$BS_SOURCE_DIR/llvm/projects/libunwind"; then
	echo "Failed to enter directory"
	exit 1
fi

if [[ ! -f libunwind-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/libunwind-7.0.0.src.tar.xz;
	then
		echo "Attempting download libunwind using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/libunwind-7.0.0.src.tar.xz;
		then
			echo "Failed to download libunwind sources"
			exit 1
		fi
	fi
fi

if [[ ! -f libunwind-7.0.0.src.unpacked ]];
then
	if ! xz -cd libunwind-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libunwind sources"
		exit 1
	fi
	touch libunwind-7.0.0.src.unpacked
fi

# Don't build
fi

################################################################
# Test suite
################################################################

# - https://llvm.org/docs/TestingGuide.html
# - https://llvm.org/docs/TestSuiteGuide.html

if [[ "$BS_TESTS" = "ON" ]]; then

# https://llvm.org/docs/GettingStarted.html#checkout-llvm-from-subversion
mkdir -p "$BS_SOURCE_DIR/llvm/projects/test-suite"
if ! cd "$BS_SOURCE_DIR/llvm/projects/test-suite"; then
	echo "Failed to enter directory"
	exit 1
fi

if [[ ! -f test-suite-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/test-suite-7.0.0.src.tar.xz;
	then
		echo "Attempting download Test Suite using insecure channel."
		if ! wget "$INSECURE" https://releases.llvm.org/7.0.0/test-suite-7.0.0.src.tar.xz;
		then
			echo "Failed to download Test Suite sources"
			exit 1
		fi
	fi
fi

if [[ ! -f test-suite-7.0.0.src.unpacked ]];
then
	if ! xz -cd test-suite-7.0.0.src.tar.xz | "$TAR" --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Test Suite sources"
		exit 1
	fi
	touch test-suite-7.0.0.src.unpacked
fi

# BS_TESTS
fi

################################################################
# Patch for https://bugzilla.redhat.com/show_bug.cgi?id=1538817
################################################################

if [[ "$BS_TARGET_ARCH" = "PowerPC" ]]; then

if [[ "$BS_LIBCXX" = "ON" ]];
then
	if [[ ! -f "$BS_SOURCE_DIR/llvm/projects/libcxx/thread.patched" ]];
	then
		echo "Patching libcxx/include/thread"
		if ! cd "$BS_SOURCE_DIR/llvm/projects/libcxx"; then
			echo "Failed to enter directory"
			exit 1
		fi

		THIS_FILE=include/thread
		sed -i "s/_LIBCPP_CONSTEXPR duration<long double> _Max/const duration<long double> _Max/g" "$THIS_FILE" > "$THIS_FILE.patched"
		mv "$THIS_FILE.patched" "$THIS_FILE"
		touch "$BS_SOURCE_DIR/llvm/projects/libcxx/thread.patched"
	fi
fi

# BS_TARGET_ARCH=PowerPC
fi

################################################################
# Patches from https://reviews.llvm.org/D54787
################################################################

# Needed for PowerPC. Also see https://bugs.llvm.org/show_bug.cgi?id=39704
if [[ "$BS_TARGET_ARCH" = "PowerPC" ]]; then

if [[ ! -f "$BS_SOURCE_DIR/llvm/tools/clang/lib/Headers/altivec.h.patched" ]];
then
	echo "Patching altivec.h"

	if ! cd "$BS_SOURCE_DIR/llvm/tools/clang/lib/Headers/"; then
		echo "Failed to enter directory"
		exit 1
	fi

	URL='https://reviews.llvm.org/file/data/pqvafnefzlkhyubairgc/PHID-FILE-t22yd7z53iacq5375jrt/lib_Headers_altivec.h'

	if wget "$URL" -O altivec.h;
	then
		touch "altivec.h.patched"
	else
		echo "Attempting to download altivec.h over insecure channel"
		if wget "$INSECURE" "$URL" -O altivec.h;
			touch "altivec.h.patched"
		then
			echo "Failed to patch altivec.h"
		fi
	fi
fi

# Also see https://bugs.llvm.org/show_bug.cgi?id=39704#c13
mkdir -p "$BS_SOURCE_DIR/llvm/tools/clang/test/CodeGen/"

# if ! cd "$BS_SOURCE_DIR/llvm/test/CodeGen/"; then
if ! cd "$BS_SOURCE_DIR/llvm/tools/clang/test/CodeGen/"; then
	echo "Failed to enter directory"
	exit 1
fi

# Part of 'make check', not LLVM Test Suite
if [[ ! -f "test_CodeGen_builtins-ppc-altivec.c.patched" ]];
then
	echo "Patching test_CodeGen_builtins-ppc-altivec.c"

	URL='https://reviews.llvm.org/file/data/vzh7jxxovv6dkijjtx65/PHID-FILE-vclvlhuqaauv753flmvi/test_CodeGen_builtins-ppc-altivec.c'

	if wget "$URL" -O test_CodeGen_builtins-ppc-altivec.c;
	then
		touch "test_CodeGen_builtins-ppc-altivec.c.patched"
	else
		echo "Attempting to download test_CodeGen_builtins-ppc-altivec.c over insecure channel"
		if wget "$INSECURE" "$URL" -O test_CodeGen_builtins-ppc-altivec.c;
		then
			touch "test_CodeGen_builtins-ppc-altivec.c.patched"
		else
			echo "Failed to patch test_CodeGen_builtins-ppc-altivec.c"
		fi
	fi
fi

# if ! cd "$BS_SOURCE_DIR/llvm/test/CodeGen/"; then
if ! cd "$BS_SOURCE_DIR/llvm/tools/clang/test/CodeGen/"; then
	echo "Failed to enter directory"
	exit 1
fi

# Part of 'make check', not LLVM Test Suite
if [[ ! -f "test_CodeGen_builtins-ppc-vsx.c.patched" ]];
then
	echo "Patching test_CodeGen_builtins-ppc-vsx.c"

	URL='https://reviews.llvm.org/file/data/xdlnjqv4y6zc76r6kouh/PHID-FILE-5njcjgb57h6gncc6y5he/test_CodeGen_builtins-ppc-vsx.c'

	if wget "$URL" -O test_CodeGen_builtins-ppc-vsx.c;
	then
		touch "test_CodeGen_builtins-ppc-vsx.c.patched"
	else
		echo "Attempting to download test_CodeGen_builtins-ppc-vsx.c over insecure channel"
		if wget "$INSECURE" "$URL" -O test_CodeGen_builtins-ppc-vsx.c;
		then
			touch "test_CodeGen_builtins-ppc-vsx.c.patched"
		else
			echo "Failed to patch test_CodeGen_builtins-ppc-vsx.c"
		fi
	fi
fi

# BS_TARGET_ARCH=PowerPC
fi

################################################################
# Build
################################################################

if ! cd "$BS_BUILD_DIR"; then
	echo "Failed to enter $BS_BUILD_DIR"
	exit 1
fi

CMAKE_ARGS=()
CMAKE_ARGS+=("-DLLVM_PATH=$BS_SOURCE_DIR/llvm")
CMAKE_ARGS+=("-DCMAKE_INSTALL_PREFIX=$BS_INSTALL_PREFIX")
CMAKE_ARGS+=("-DLLVM_TARGETS_TO_BUILD=$BS_TARGET_ARCH")
CMAKE_ARGS+=("-DLLVM_PARALLEL_COMPILE_JOBS=$BS_COMPILE_JOBS")
CMAKE_ARGS+=("-DCMAKE_BUILD_TYPE=Release")
CMAKE_ARGS+=("-DLLVM_INCLUDE_TOOLS=ON")

# I don't know how to set this. Also see
# https://stackoverflow.com/q/53459921/608639
if [[ "$BS_LIBCXX" = "OFF" ]]; then
	CMAKE_ARGS+=("-DLIBCXX_LIBCPPABI_VERSION=''")
fi

if [[ "$BS_TESTS" = "ON" ]]; then
	CMAKE_ARGS+=("-DLLVM_BUILD_TESTS=ON")
else
	CMAKE_ARGS+=("-DLLVM_BUILD_TESTS=OFF")
fi

# Add CC and CXX to CMake if provided in the environment.
if [[ ! -z "$CC" ]]; then
	CMAKE_ARGS+=("-DCMAKE_C_COMPILER=$CC")
fi
if [[ ! -z "$CXX" ]]; then
	CMAKE_ARGS+=("-DCMAKE_CXX_COMPILER=$CXX")
fi

if true; then
	echo
	echo "*****************************************************************************"
	echo "CMake arguments: ${CMAKE_ARGS[*]}"
	echo "*****************************************************************************"
	echo
fi

if ! "$CMAKE" "${CMAKE_ARGS[@]}" "$BS_SOURCE_DIR/llvm";
then
	echo "Failed to cmake LLVM sources"
	exit 1
fi

if ! "$MAKE" -j "$BS_COMPILE_JOBS" VERBOSE=1;
then
	echo "Failed to make LLVM sources"
	exit 1
fi

if ! "$MAKE" -j "$BS_COMPILE_JOBS" check;
then
	echo "Failed to test LLVM sources"
	exit 1
fi

echo "*****************************************************************************"
echo "It looks like the build and test succeeded. You next step are:"
echo "  cd $BS_BUILD_DIR"
echo "  sudo make install"
echo "Remember to clear Bash program cache after install:"
echo "  hash -r"
echo "Finally and optionally:"
echo "  cd ~"
echo "  rm -rf \"$BS_SOURCE_DIR/llvm\" \"$BS_BUILD_DIR\""
echo "*****************************************************************************"

exit 0

