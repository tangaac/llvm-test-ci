#!/bin/bash

# e.g 2025-07-01
timestamp() {
  date +"%Y-%m-%d"
}

# Source directory
WORK_DIR=$(pwd)/llvm
LLVM_SOURCE_DIR=${WORK_DIR}/llvm-project
TEST_SUITE_SOURCE_DIR=${WORK_DIR}/llvm-test-suite
CPU2017_DIR=${WORK_DIR}/cpu2017
CPU2006_DIR=${WORK_DIR}/cpu2006

# Build directory
LOG_DIR=$(pwd)/logs/$(timestamp)

BUILD_LLVM_DIR=${LOG_DIR}/build-llvm
BIN_DIR=$BUILD_LLVM_DIR/bin

BUILD_TEST_SUITE_LASX_DIR=${LOG_DIR}/build-test-suite-lasx
BUILD_TEST_SUITE_LSX_DIR=${LOG_DIR}/build-test-suite-lsx

# Log files
UPSTREAM_LOG=$LOG_DIR/upstream.log
RUN_LOG=$LOG_DIR/run.log
BUILD_LOG=$LOG_DIR/build.log

mkdir -p $LOG_DIR
touch $UPSTREAM_LOG
touch $RUN_LOG
touch $BUILD_LOG

fetch_llvm() {
{
    echo "====== FETCH LLVM UPSTREAM ======"

    cd $LLVM_SOURCE_DIR
    git pull 2>&1 || exit 1
    git log -1 2>& 1 || exit 1
} | tee -a $UPSTREAM_LOG
}


fetch_test_suite() {
{
    echo "====== FETCH TEST-SUITE UPSTREAM ======"

    cd $TEST_SUITE_SOURCE_DIR 
    git pull >&1 || exit 1
    git log -1 2>&1 || exit 1
} | tee -a $UPSTREAM_LOG
}

build_llvm_and_run() {
mkdir -p $BUILD_LLVM_DIR

# ===== BUILD LLVM-PROJECT =====
{
    echo "====== BUILD LLVM ======"

    cd $BUILD_LLVM_DIR
    cmake $LLVM_SOURCE_DIR/llvm \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER_LAUNCHER=sccache \
      -DCMAKE_CXX_COMPILER_LAUNCHER=sccache \
      -DLLVM_USE_LINKER=lld \
      -DLLVM_TARGETS_TO_BUILD=LoongArch \
      -DLLVM_ENABLE_PROJECTS="clang;flang;lld" \
      -G Ninja 2>&1 || exit 1
    ninja -j20 -v 2>&1 || exit 1

    echo "====== RUN LLVM REGRESSION TEST======"
} | tee -a $BUILD_LOG

# ===== RUN LLVM-PROJECT =====
{
    $BIN_DIR/llvm-lit $BUILD_LLVM_DIR/test -v 2>&1 || exit 1
} | tee -a $RUN_LOG
}


build_test_suite_and_run_lasx() {
mkdir -p $BUILD_TEST_SUITE_LASX_DIR

# BUILD LLVM-TEST-SUITE LASX
{
	echo "====== BUILD TEST-SUITE LASX ======"

	cd $BUILD_TEST_SUITE_LASX_DIR
	cmake $TEST_SUITE_SOURCE_DIR \
		-DCMAKE_CXX_COMPILER=$BIN_DIR/clang++ \
		-DCMAKE_C_COMPILER=$BIN_DIR/clang \
		-DCMAKE_Fortran_COMPILER=$BIN_DIR/flang \
		-DCMAKE_C_FLAGS="-mlasx -Wno-implicit-int -fuse-ld=$BIN_DIR/ld.lld" \
		-DCMAKE_CXX_FLAGS="-mlasx -Wno-implicit-int -fuse-ld=$BIN_DIR/ld.lld" \
		-DCMAKE_Fortran_FLAGS="-mlasx" \
		-C$TEST_SUITE_SOURCE_DIR/cmake/caches/O3.cmake \
		-DTEST_SUITE_SPEC2006_ROOT=$CPU2006_DIR \
		-DTEST_SUITE_SPEC2017_ROOT=$CPU2017_DIR \
		-DTEST_SUITE_FORTRAN=ON \
		-DTEST_SUITE_RUN_TYPE=train \
		-LAH -DCMAKE_VERBOSE_MAKEFILE=ON \
		-DCMAKE_BUILD_TYPE=Release \
		-G Ninja 2>&1 || exit 1

	ninja -v 2>&1 || exit 1
} | tee -a $BUILD_LOG

# RUN LLVM-TEST-SUITE LASX
{
    $BIN_DIR/llvm-lit $BUILD_TEST_SUITE_LASX_DIR -v 2>&1 || exit 1
} | tee -a $RUN_LOG
}

build_test_suite_and_run_lsx() {
mkdir -p $BUILD_TEST_SUITE_LSX_DIR

# ===== BUILD LLVM-TEST-SUITE lSX =====
{
	echo "====== BUILD TEST-SUITE LSX======"

	cd $BUILD_TEST_SUITE_LSX_DIR
	cmake $TEST_SUITE_SOURCE_DIR \
		-DCMAKE_CXX_COMPILER=$BIN_DIR/clang++ \
		-DCMAKE_C_COMPILER=$BIN_DIR/clang \
		-DCMAKE_Fortran_COMPILER=$BIN_DIR/flang \
		-DCMAKE_C_FLAGS="-mlsx -Wno-implicit-int -fuse-ld=$BIN_DIR/ld.lld" \
		-DCMAKE_CXX_FLAGS="-mlsx -Wno-implicit-int -fuse-ld=$BIN_DIR/ld.lld" \
		-DCMAKE_Fortran_FLAGS="-mlsx" \
		-C$TEST_SUITE_SOURCE_DIR/cmake/caches/O3.cmake \
		-DTEST_SUITE_SPEC2006_ROOT=$CPU2006_DIR \
		-DTEST_SUITE_SPEC2017_ROOT=$CPU2017_DIR \
		-DTEST_SUITE_FORTRAN=ON \
		-DTEST_SUITE_RUN_TYPE=train \
		-LAH -DCMAKE_VERBOSE_MAKEFILE=ON \
		-DCMAKE_BUILD_TYPE=Release \
		-G Ninja 2>&1 || exit 1

	ninja -v 2>&1 || exit 1
} | tee -a $BUILD_LOG

# ===== RUN LLVM-TEST-SUITE LSX =====
{
    $BIN_DIR/llvm-lit $BUILD_TEST_SUITE_LSX_DIR -v 2>&1 || exit 1
} | tee -a $RUN_LOG
}

fetch_llvm

build_llvm_and_run

fetch_test_suite

build_test_suite_and_run_lsx
build_test_suite_and_run_lasx
