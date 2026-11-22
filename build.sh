#!/bin/bash
# Builds language_builder for Linux into ../build/language_builder/language_builder (same directory as build.bat)
#
# Usage: build.sh [-d|-r]       -d debug (default, address + undefined behavior sanitizer), -r release
#
# Needs cOMS next to this repository (../cOMS, the engine defines the file formats)
#
# No cpu feature flags (-msse4.2, -mavx2, ...): cOMS uses its portable code paths -> the binary runs on every cpu
# of the architecture it was built on (x86_64, aarch64, ...). CXX overrides the compiler (default g++).
# -ffp-contract=off: no fused multiply-add (gcc uses it by default on aarch64) -> the same output on every platform
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DESTINATION_DIR="$SCRIPT_DIR/../build/language_builder"
CXX="${CXX:-g++}"

if [ ! -f "$SCRIPT_DIR/../cOMS/stdlib/Types.h" ]; then
    echo "ERROR: cOMS not found next to this repository ($SCRIPT_DIR/../cOMS)"
    exit 1
fi

BUILD_TYPE="DEBUG"
BUILD_FLAGS="-g -O0 -DDEBUG -fsanitize=address -fsanitize=undefined -fno-omit-frame-pointer"
if [ "$1" = "-r" ]; then
    BUILD_TYPE="RELEASE"
    BUILD_FLAGS="-O2 -DNDEBUG"
fi

mkdir -p "$DESTINATION_DIR"

echo "Building language_builder ($BUILD_TYPE, $(uname -m))"

$CXX $BUILD_FLAGS -Wall -Wextra -std=c++20 \
    -ffp-contract=off \
    -Wno-unused-result -Wno-unused-parameter -Wno-unused-function \
    -DUNICODE -D_UNICODE \
    -pthread \
    "$SCRIPT_DIR/language_builder.cpp" \
    -o "$DESTINATION_DIR/language_builder"
