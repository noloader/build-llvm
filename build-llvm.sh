#!/usr/bin/env bash

# https://llvm.org/docs/GettingStarted.html#getting-started-quickly-a-summary
# https://llvm.org/docs/CMake.html#quick-start

################################################################
# Variables
################################################################

LLVM_SOURCE_DIR="$HOME/llvm_source"
LLVM_BUILD_DIR="$HOME/llvm_build"
CURRENT_DIR=$(pwd)

################################################################
# Exit
################################################################

function finish {
  cd "$CURRENT_DIR"
}
trap finish EXIT

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

if ! xz -cd llvm-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
then
	echo "Failed to unpack LLVM sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
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
		echo "Attempting download Compiler Front End using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/cfe-7.0.0.src.tar.xz;  
		then
			echo "Failed to download Compiler Front End sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if ! xz -cd cfe-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
then
	echo "Failed to unpack Compiler Front End sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
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

if ! xz -cd compiler-rt-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
then
	echo "Failed to unpack Compiler-RT sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

################################################################
# Tools Extras
################################################################

mkdir -p "$LLVM_SOURCE_DIR/projects"
cd "$LLVM_SOURCE_DIR/projects"

if [[ ! -f clang-tools-extra-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/clang-tools-extra-7.0.0.src.tar.xz;
	then
		echo "Attempting download Tools Extras using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/clang-tools-extra-7.0.0.src.tar.xz;  
		then
			echo "Failed to download Tools Extras sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if ! xz -cd clang-tools-extra-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
then
	echo "Failed to unpack Tools Extras sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
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

if ! xz -cd polly-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
then
	echo "Failed to unpack Polly Optimizer sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

################################################################
# Build
################################################################

cd "$LLVM_BUILD_DIR"

if ! cmake -DCMAKE_INSTALL_PREFIX="/opt/llvm" -DLLVM_SRC_ROOT="$LLVM_SOURCE_DIR" -LLVM_CONFIG_PATH="$LLVM_SOURCE_DIR" -DLLVM_TARGETS_TO_BUILD="PowerPC" -DLLVM_INCLUDE_TOOLS="ON" -DLLVM_BUILD_TESTS="ON" "$LLVM_SOURCE_DIR";
then
	echo "Failed to build LLVM sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi
