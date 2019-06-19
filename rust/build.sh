#!/bin/sh -ex

HOST=$(rustc -vV | grep host: | cut -d ' ' -f 2)
VERSION="+nightly-2019-05-22"
CARGO_ARGS="${VERSION} -v build --target=${RUST_TARGET} --release"

publish_sysroot() {
    local CLEAN_DIR_IF_CHANGED=$1
    shift
    local SYSROOT=$1
    shift
    local SYSROOT_LIB="${SYSROOT}/lib/rustlib/${RUST_TARGET}/lib"
    local SYSROOT_LIB_HOST="${SYSROOT}/lib/rustlib/${HOST}/lib"
    mkdir -p ${SYSROOT_LIB} ${SYSROOT_LIB_HOST}
    mkdir -p ${SYSROOT_LIB}-new ${SYSROOT_LIB_HOST}-new

    for src in $@; do
        cp -a $src/${RUST_TARGET}/release/deps/. ${SYSROOT_LIB}-new
        cp -a $src/release/deps/. ${SYSROOT_LIB_HOST}-new
    done
    if ! diff -qr ${SYSROOT_LIB} ${SYSROOT_LIB}-new || ! diff -qr ${SYSROOT_LIB_HOST} ${SYSROOT_LIB_HOST}-new; then
        rm -rf ${CLEAN_DIR_IF_CHANGED}
    fi
    rm -r ${SYSROOT_LIB} ${SYSROOT_LIB_HOST}
    mv ${SYSROOT_LIB}-new ${SYSROOT_LIB}
    mv ${SYSROOT_LIB_HOST}-new ${SYSROOT_LIB_HOST}
}

# Build std
cargo ${CARGO_ARGS} \
    --target-dir=${SYSROOT_BUILD}-stage1 \
    --manifest-path=./sysroot-stage1/Cargo.toml -p std
publish_sysroot ${SYSROOT_BUILD}-stage2 ${SYSROOT}-stage1 ${SYSROOT_BUILD}-stage1
# Build Zephyr crates
RUSTFLAGS="${RUSTFLAGS} --sysroot ${SYSROOT}-stage1" cargo ${CARGO_ARGS} \
    --target-dir=${SYSROOT_BUILD}-stage2 \
    --manifest-path=./sysroot-stage2/Cargo.toml

publish_sysroot ${APP_BUILD} ${SYSROOT} ${SYSROOT_BUILD}-stage1 ${SYSROOT_BUILD}-stage2

export RUSTFLAGS="${RUSTFLAGS} --sysroot ${SYSROOT}"
cargo ${CARGO_ARGS} --target-dir=${APP_BUILD} --manifest-path=${CARGO_MANIFEST}