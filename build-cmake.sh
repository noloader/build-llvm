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
	PREFIX="/opt/cmake"
fi

if [[ -z "$JOBS" ]]; then
	JOBS="2"
fi

# AIX and Solaris override
if [[ "$MAKE" = "make" ]] && [[ $(command -v gmake) ]]; then
	MAKE=$(command -v gmake)
fi

# AIX and Solaris override
if [[ "$TAR" = "tar" ]] && [[ -f "/usr/linux/bin/tar" ]]; then
	TAR=/usr/linux/bin/tar
elif [[ "$TAR" = "tar" ]] && [[ -f "/usr/gnu/bin/tar" ]]; then
	TAR=/usr/gnu/bin/tar
fi

################################################################
# Exit
################################################################

CURRENT_DIR=$(pwd)

function finish {
  # Swallow errors on exit
  cd "$CURRENT_DIR" || true
}
trap finish EXIT

################################################################
# CMake sources
################################################################

echo "Removing previous cmake_build"
if [[ -d "$HOME/cmake_build" ]]; then
	rm -rf "$HOME/cmake_build"
fi

mkdir -p "$HOME/cmake_build"
if ! cd "$HOME/cmake_build"; then
	echo "Failed to enter $HOME/cmake_build"
	exit 1
fi

echo "Downloading CMake 3.12.14 tarball"
if [[ ! -f cmake-3.12.4.tar.gz ]];
then
	if ! wget https://cmake.org/files/v3.12/cmake-3.12.4.tar.gz;
	then
		echo "Attempting download CMake using insecure channel."
		if ! wget --no-check-certificate https://cmake.org/files/v3.12/cmake-3.12.4.tar.gz;
		then
			echo "Failed to download CMake sources"
			exit 1
		fi
	fi
fi

echo "Unpacking CMake 3.12.14 tarball"
if [[ ! -f cmake-3.12.4.unpacked ]];
then
	if ! "$TAR" --strip-components=1 -xzf cmake-3.12.4.tar.gz;
	then
		echo "Failed to unpack CMake sources"
		exit 1
	fi
	touch cmake-3.12.4.unpacked
fi

################################################################
# CMake build
################################################################

#if true; then
#	echo
#	echo "*****************************************************************************"
#	echo "CMake arguments: ${CMAKE_ARGS[*]}"
#	echo "*****************************************************************************"
#	echo
#fi

# Hack. bootstrap --help does not list a method to set these flag
# List our flags first so users can override them.
CFLAGS="-DNDEBUG -g -O2 $CFLAGS"
CXXFLAGS="-DNDEBUG -g -O2 $CXXFLAGS"

# Hack. bootstrap --help does not list a method to set this flag
# List our flags first so users can override them.
if [[ $(uname -s) = "AIX" ]]; then
	echo "Fixing LDFLAGS"
	LDFLAGS="-Wl,-bbigtoc $LDFLAGS"
fi

if ! CC="$CC" CXX="$CXX" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" ./bootstrap --prefix="$PREFIX" --parallel="$JOBS";
then
	echo "Failed to bootstrap CMake sources"
	exit 1
fi

if ! "$MAKE" -j "$JOBS" VERBOSE=1;
then
	echo "Failed to make CMake sources"
	exit 1
fi

echo "*****************************************************************************"
echo "It looks like the build and test succeeded. You next step are:"
echo "  cd \"$HOME/cmake_build\""
echo "  sudo make install"
echo "Then, optionally:"
echo "  cd .."
echo "  rm -rf \"$HOME/cmake_build\""
echo "*****************************************************************************"

exit 0

