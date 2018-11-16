# Build LLVM

Recipes to download and build LLVM, Compiler front end and Compiler-RT from sources. The script builds the latest LLVM from release tarballs, which is version 7.0.

Testing on Fedora x86_64 reveals no `LD_LIBRARY_PATH` is needed to run an executable. LLVM fails to build on a old Apple PowerMac G5.

# Variables

There are several variables of interest you can tune for the build:

* `BUILD_SCRIPT_INSTALL_PREFIX` - the installation directory. The default value is `/opt/llvm`.
* `BUILD_SCRIPT_SOURCE_DIR` - scratch directory to download an unpack the sources. The default value is `$HOME/llvm_source/llvm`. The tail must include `llvm/`.
* `BUILD_SCRIPT_BUILD_DIR` - scratch directory to build the the sources. Output artifacts are in this directory. The default value is `$HOME/llvm_build`.
* `BUILD_SCRIPT_MAKE_JOBS` - the number of concurrent make jobs. The default value is `4`.

# Building the sources

`./build-llvm.sh` is all that is required to download and build the LLVM sources. You will have to manually install it.

LLVM requires GCC 4.8 or above to compile the source code. The script honors alternate compilers, and you can pass them to CMake using:

```
# Attempting a build on PowerMac with MacPorts GCC
CC=/opt/local/bin/gcc-mp-5 CXX=/opt/local/bin/g++-mp-5 ./build-llvm.sh
```

# Installing the toolchain

Afetr building the sources you have to manually install them, if desired. Perform the following steps to install the toolchain:

```
cd llvm_build
sudo make install
```