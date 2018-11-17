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
#
# If you find a LLVM provided script you should use it instead. We could not
# find one so we are suffering the build process like hundreds of other
# developers before us.

# TODO
#
#  - investiagte RPATHs using ${ORIGIN}. Also see https://bit.ly/2RW4CGL
#  - investiagte install_names on OS X
#  - set LLVM_BUILD_TESTS="ON" eventually
#

################################################################
# Variables
################################################################

# CMake and Make location. Defaults to cmake program
CMAKE="${CMAKE:-cmake}"
MAKE="${MAKE:-make}"

# Where to install the artifacts
BUILD_SCRIPT_INSTALL_PREFIX="/opt/llvm"

# There must be an llvm/ in $BUILD_SCRIPT_SOURCE_DIR
BUILD_SCRIPT_SOURCE_DIR="$HOME/llvm_source/llvm"
BUILD_SCRIPT_BUILD_DIR="$HOME/llvm_build"

# Concurrent make jobs
BUILD_SCRIPT_COMPILE_JOBS="4"

# LLVM_VERSION="7.0.0"
BUILD_SCRIPT_TARGET_ARCH="Unknown"

# https://llvm.org/docs/GettingStarted.html#local-llvm-configuration
BUILD_SCRIPT_HOST=$(uname -m)
if [[ $(uname -s) = "AIX" ]]; then
	BUILD_SCRIPT_HOST="aix";
fi

case "$BUILD_SCRIPT_HOST" in
	i86pc)
		BUILD_SCRIPT_TARGET_ARCH="X86" ;;
	i.86)
		BUILD_SCRIPT_TARGET_ARCH="X86" ;;
	x86_64)
		BUILD_SCRIPT_TARGET_ARCH="X86" ;;
	amd64)
		BUILD_SCRIPT_TARGET_ARCH="X86" ;;
	aix)
		BUILD_SCRIPT_TARGET_ARCH="PowerPC" ;;
	ppc*)
		BUILD_SCRIPT_TARGET_ARCH="PowerPC" ;;
	"Power Macintosh")
		BUILD_SCRIPT_TARGET_ARCH="PowerPC" ;;
	arm*)
		BUILD_SCRIPT_TARGET_ARCH="ARM" ;;
	eabihf)
		BUILD_SCRIPT_TARGET_ARCH="ARM" ;;
	aarch32)
		BUILD_SCRIPT_TARGET_ARCH="Aarch64" ;;
	aarch64)
		BUILD_SCRIPT_TARGET_ARCH="Aarch64" ;;
	mips*)
		BUILD_SCRIPT_TARGET_ARCH="Mips" ;;
	sun)
		BUILD_SCRIPT_TARGET_ARCH="Sparc" ;;
	sparc*)
		BUILD_SCRIPT_TARGET_ARCH="Sparc" ;;
	*)
		echo "Unknown architecture"
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
	if ! xz -cd llvm-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
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
	if ! xz -cd cfe-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
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
	if ! xz -cd clang-tools-extra-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
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
	if ! xz -cd lld-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
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
	if ! xz -cd polly-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
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
	if ! xz -cd compiler-rt-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Compiler-RT sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch compiler-rt-7.0.0.src.unpacked
fi

################################################################
# libc++
################################################################

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
	if ! xz -cd libcxx-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libc++ sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch libcxx-7.0.0.src.unpacked
fi

# https://bugzilla.redhat.com/show_bug.cgi?id=1538817
if [[ ! -f thread.patched ]]; then
	echo "Patching libcxx/include/thread"
	THIS_FILE=include/thread
	sed -i "s/_LIBCPP_CONSTEXPR duration<long double> _Max/const duration<long double> _Max/g" "$THIS_FILE" > "$THIS_FILE.patched"
	mv "$THIS_FILE.patched" "$THIS_FILE"
	touch thread.patched
fi

################################################################
# libc++abi
################################################################

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
	if ! xz -cd libcxxabi-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libc++abi sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch libcxxabi-7.0.0.src.unpacked
fi

################################################################
# Build
################################################################

cd "$BUILD_SCRIPT_BUILD_DIR"

CMAKE_ARGS=()
CMAKE_ARGS+=(-DCMAKE_INSTALL_PREFIX="$BUILD_SCRIPT_INSTALL_PREFIX")
CMAKE_ARGS+=(-DLLVM_TARGETS_TO_BUILD="$BUILD_SCRIPT_TARGET_ARCH")
CMAKE_ARGS+=(-DLLVM_PARALLEL_COMPILE_JOBS="$BUILD_SCRIPT_COMPILE_JOBS")
CMAKE_ARGS+=(-DLLVM_INCLUDE_TOOLS="ON")
CMAKE_ARGS+=(-DLLVM_BUILD_TESTS="OFF")

# Add CC and CXX to CMake if provided in the environment.
if [[ ! -z "$CC" ]]; then
	CMAKE_ARGS+=(-DCMAKE_C_COMPILER="$CC")
fi
if [[ ! -z "$CXX" ]]; then
	CMAKE_ARGS+=(-DCMAKE_CXX_COMPILER="$CXX")
fi

if true; then
	echo "*****************************************************************************"
	echo "CMake arguments: ${CMAKE_ARGS[@]}"
	echo "*****************************************************************************"
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

if ! "$MAKE" -j "$BUILD_SCRIPT_COMPILE_JOBS" test;
then
	echo "Failed to test LLVM sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "*****************************************************************************"
echo "It looks like the build and test succeeded. You next step are:"
echo "  cd $BUILD_SCRIPT_BUILD_DIR"
echo "  sudo make install"
echo "Then, optionally:"
echo "  cd .."
echo "  rm -rf \"$BUILD_SCRIPT_SOURCE_DIR\" \"$BUILD_SCRIPT_BUILD_DIR\""
echo "*****************************************************************************"

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
