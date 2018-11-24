# Build LLVM

Recipes to download and build LLVM, Compiler front end and Compiler-RT from sources. The script builds the latest LLVM from release tarballs, which is version 7.0. The script also patches the LLVM 7.0 sources for PowerPC Issue D54787, [Vector load/store builtins overstate alignment of pointers](https://reviews.llvm.org/D54787).

Testing on Fedora x86_64 reveals no `LD_LIBRARY_PATH` is needed to run an executable. LLVM fails to build on a old Apple PowerMac G5.

# Variables

There are several variables of interest you can tune for the build:

* `CMAKE` - the tool to use for CMake. The default value is `cmake`.
* `BUILD_SCRIPT_INSTALL_PREFIX` - the installation directory. The default value is `/opt/llvm`.
* `BUILD_SCRIPT_SOURCE_DIR` - scratch directory to download an unpack the sources. The default value is `$HOME/llvm_source/llvm`. The tail must include `llvm/`.
* `BUILD_SCRIPT_BUILD_DIR` - scratch directory to build the the sources. Output artifacts are in this directory. The default value is `$HOME/llvm_build`.
* `BUILD_SCRIPT_MAKE_JOBS` - the number of concurrent make jobs. The default value is `4`.

# Building the sources

`./build-llvm.sh` is all that is required to download and build the LLVM sources. You will have to manually install it.

LLVM requires GCC 4.8 or above to compile the source code. The script honors alternate compilers, and you can pass them to CMake using:

```
# Attempt to build on PowerMac with MacPorts GCC
CC=/opt/local/bin/gcc-mp-5 CXX=/opt/local/bin/g++-mp-5 ./build-llvm.sh
```

And if you need an alternate CMake to satisfy LLVM requirements:

```
CMAKE=/opt/local/bin/cmake ./build-llvm.sh
```

# Installing the toolchain

You have to manually install the toolchain after building it, if desired. Perform the following steps to install the toolchain:

```
cd llvm_build
sudo make install
```

You can also delete `BUILD_SCRIPT_SOURCE_DIR` and `BUILD_SCRIPT_BUILD_DIR` after installation.

# libc++

The libcxx and libcxxabi recipes are mostly broken. There's a problem with a missing symbol called `__thread_local_data()`. We don't know how to work around it, and our LLVM mailing list questions have not been answered. Also see https://stackoverflow.com/q/53356172/608639 and https://stackoverflow.com/q/53459921/608639.

If you want to attempt to build libcxx and libcxxabi then set `BUILD_SCRIPT_LIBCXX=true`.

# Building CMake

LLVM requires CMake 3.4.3 or higher. You can use `build-cmake.sh` to update CMake if needed. The script builds in the `cmake_build` directory and installs itself at `$HOME/cmake`. You can change the variables by editing the top of the script.
