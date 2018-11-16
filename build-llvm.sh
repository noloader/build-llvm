#!/usr/bin/env bash

# https://llvm.org/docs/GettingStarted.html#getting-started-quickly-a-summary
# https://llvm.org/docs/CMake.html#quick-start

################################################################
# Variables
################################################################

LLVM_SOURCE_DIR="$HOME/llvm_source"
LLVM_BUILD_DIR="$HOME/llvm_build"

# LLVM_VERSION="7.0.0"
LLVM_ARCH="Unknown"

THIS_HOST=$(uname -m)
case "$THIS_HOST" in
	"x86_64")
		LLVM_ARCH="X86" ;;
	"Power Macintosh")
		LLVM_ARCH="PowerPC" ;;
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

if [[ -d "$LLVM_BUILD_DIR" ]]; then
	rm -rf "$LLVM_BUILD_DIR"
fi

mkdir -p "$LLVM_SOURCE_DIR"
mkdir -p "$LLVM_BUILD_DIR"

################################################################
# LLVM base
################################################################

mkdir -p "$LLVM_SOURCE_DIR"
cd "$LLVM_SOURCE_DIR"

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

if [[ ! -f llvm-7.0.0.src ]];
then
	if ! xz -cd llvm-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack LLVM sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch llvm-7.0.0.src
fi

################################################################
# Clang front end
################################################################

mkdir -p "$LLVM_SOURCE_DIR/tools"
cd "$LLVM_SOURCE_DIR/tools"

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

if [[ ! -f cfe-7.0.0.src ]];
then
	if ! xz -cd cfe-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Clang front end sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch cfe-7.0.0.src
fi

################################################################
# Clang Tools
################################################################

mkdir -p "$LLVM_SOURCE_DIR/tools/clang/tools"
cd "$LLVM_SOURCE_DIR/tools/clang/tools"

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

if [[ ! -f clang-tools-extra-7.0.0.src ]];
then
	if ! xz -cd clang-tools-extra-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Clang Tools sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch clang-tools-extra-7.0.0.src
fi

################################################################
# LLD Linker
################################################################

mkdir -p "$LLVM_SOURCE_DIR/tools"
cd "$LLVM_SOURCE_DIR/tools"

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

if [[ ! -f lld-7.0.0.src ]];
then
	if ! xz -cd lld-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack LLD Linker sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch lld-7.0.0.src
fi

################################################################
# Polly optimizer
################################################################

mkdir -p "$LLVM_SOURCE_DIR/tools"
cd "$LLVM_SOURCE_DIR/tools"

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

if [[ ! -f polly-7.0.0.src ]];
then
	if ! xz -cd polly-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Polly Optimizer sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch polly-7.0.0.src
fi

################################################################
# Compiler-RT
################################################################

mkdir -p "$LLVM_SOURCE_DIR/projects"
cd "$LLVM_SOURCE_DIR/projects"

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

if [[ ! -f compiler-rt-7.0.0.src ]];
then
	if ! xz -cd compiler-rt-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack Compiler-RT sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch compiler-rt-7.0.0.src
fi

################################################################
# libc++
################################################################

mkdir -p "$LLVM_SOURCE_DIR/projects"
cd "$LLVM_SOURCE_DIR/projects"

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

if [[ ! -f libcxx-7.0.0.src ]];
then
	if ! xz -cd libcxx-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libc++ sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch libcxx-7.0.0.src
fi

################################################################
# libc++abi
################################################################

mkdir -p "$LLVM_SOURCE_DIR/projects"
cd "$LLVM_SOURCE_DIR/projects"

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

if [[ ! -f libcxxabi-7.0.0.src ]];
then
	if ! xz -cd libcxxabi-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
	then
		echo "Failed to unpack libc++abi sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch libcxxabi-7.0.0.src
fi

################################################################
# Build
################################################################

cd "$LLVM_BUILD_DIR"

CMAKE_ARGS=()
CMAKE_ARGS+=(-DCMAKE_INSTALL_PREFIX="/opt/llvm")
CMAKE_ARGS+=(-DLLVM_TARGETS_TO_BUILD="$LLVM_ARCH")
# CMAKE_ARGS+=(-DLLVM_SRC_ROOT="$LLVM_SOURCE_DIR")
CMAKE_ARGS+=(-DLLVM_PARALLEL_COMPILE_JOBS="4")
CMAKE_ARGS+=(-DLLVM_INCLUDE_TOOLS="ON")
# CMAKE_ARGS+=(-DLLVM_BUILD_TESTS="ON")

if [[ ! -z "$CC" ]]; then
	CMAKE_ARGS+=(-DCMAKE_C_COMPILER="$CC")
fi

if [[ ! -z "$CXX" ]]; then
	CMAKE_ARGS+=(-DCMAKE_CXX_COMPILER="$CXX")
fi

echo "*******************************************"
echo "CMake arguments: ${CMAKE_ARGS[@]}"
echo "*******************************************"

if ! cmake "${CMAKE_ARGS[@]}" "$LLVM_SOURCE_DIR";
then
	echo "Failed to build LLVM sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
