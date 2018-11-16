#!/usr/bin/env bash

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
# Download
################################################################

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

if [[ ! -f compiler-rt-7.0.0.src.tar.xz ]];
then
	if ! wget https://releases.llvm.org/7.0.0/compiler-rt-7.0.0.src.tar.xz;
	then
		echo "Attempting download LLVM using insecure channel."
		if ! wget --no-check-certificate https://releases.llvm.org/7.0.0/compiler-rt-7.0.0.src.tar.xz;  
		then
			echo "Failed to download LLVM sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

################################################################
# Unpack
################################################################

if ! xz -cd llvm-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
then
	echo "Failed to unpack LLVM sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if ! xz -cd cfe-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
then
	echo "Failed to unpack Compiler Front End sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if ! xz -cd compiler-rt-7.0.0.src.tar.xz | tar --strip-components=1 -xvf - ;
then
	echo "Failed to unpack Compiler-RT sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

################################################################
# Build
################################################################

cd "$LLVM_BUILD_DIR"

if ! cmake -DCMAKE_INSTALL_PREFIX="/opt/llvm" -DLLVM_TARGETS_TO_BUILD="PowerPC" -DLLVM_INCLUDE_TOOLS="ON" -DLLVM_BUILD_TESTS="ON" "$LLVM_SOURCE_DIR";
then
	echo "Failed to build LLVM sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi
