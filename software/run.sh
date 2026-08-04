#!/bin/sh
# Entry point for the challenge: configure, build the pass, run it on test.c.
# Set LLVM_DIR to your LLVM's lib/cmake/llvm if it isn't in homebrew.
set -e
cd "$(dirname "$0")"

if [ -z "$LLVM_DIR" ]; then
  if command -v brew >/dev/null 2>&1; then
    LLVM_DIR="$(brew --prefix llvm)/lib/cmake/llvm"
  else
    echo "error: LLVM_DIR is not set and homebrew was not found." >&2
    echo "usage: LLVM_DIR=/path/to/llvm/lib/cmake/llvm $0" >&2
    exit 1
  fi
fi

cmake -B build -DLLVM_DIR="$LLVM_DIR"
cmake --build build --target run