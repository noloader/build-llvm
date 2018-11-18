#!/usr/bin/env bash

# build-cmake.sh - CMake build script.

# Written and placed in public domain by Jeffrey Walton and Uri Blumenthal.
# This scripts builds the latest CMake from sources. The script is useful
# on old machines where CMake is too old to meet LLVM requirements.

################################################################
# Variables
################################################################

# Default programs and locations. CMake requires GCC on AIX
CC="${CC:-gcc}"
CXX="${CXX:-g++}"
MAKE="${MAKE:-make}"
TAR="${TAR:-tar}"

if [[ -z "$PREFIX" ]]; then
	PREFIX="$HOME/cmake"
fi

# AIX and Solaris override
if [[ "$MAKE" = "make" ]] && [[ -f "/usr/bin/gmake" ]]; then
	MAKE=/usr/bin/gmake
fi

# AIX and Solaris override
if [[ "$TAR" = "tar" ]] && [[ -f "/usr/linux/bin/tar" ]]; then
	TAR=/usr/linux/bin/tar
fi

################################################################
# Exit
################################################################

CURRENT_DIR=$(pwd)

function finish {
  cd "$CURRENT_DIR"
}
trap finish EXIT

################################################################
# CMake sources
################################################################

if [[ -d "$HOME/cmake_build" ]]; then
	rm -rf "$HOME/cmake_build"
fi

mkdir -p "$HOME/cmake_build"
cd "$HOME/cmake_build"

if [[ ! -f cmake-3.12.4.tar.gz ]];
then
	if ! wget https://cmake.org/files/v3.12/cmake-3.12.4.tar.gz;
	then
		echo "Attempting download CMake using insecure channel."
		if ! wget --no-check-certificate https://cmake.org/files/v3.12/cmake-3.12.4.tar.gz;
		then
			echo "Failed to download CMake sources"
			[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
		fi
	fi
fi

if [[ ! -f cmake-3.12.4.unpacked ]];
then
	if ! "$TAR" --strip-components=1 -xzf cmake-3.12.4.tar.gz;
	then
		echo "Failed to unpack CMake sources"
		[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
	fi
	touch cmake-3.12.4.unpacked
fi

################################################################
# CMake build
################################################################

if ! CC="$CC" CXX="$CXX" ./bootstrap --prefix="$PREFIX";
then
	echo "Failed to bootstrap CMake sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if ! "$MAKE" VERBOSE=1;
then
	echo "Failed to make CMake sources"
	[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

echo "*****************************************************************************"
echo "It looks like the build and test succeeded. You next step are:"
echo "  cd \"$HOME/cmake_build\""
echo "  sudo make install"
echo "Then, optionally:"
echo "  cd .."
echo "  rm -rf \"$HOME/cmake_build\""
echo "*****************************************************************************"

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
