#!/bin/sh
# Runs the pass and diffs its output against the frozen expected counts.
set -e
OPT="$1"; PLUGIN="$2"; IR="$3"; EXPECTED="$4"
"$OPT" -load-pass-plugin="$PLUGIN" -passes=count-mem-ops -disable-output "$IR" 2>&1 \
  | diff -u "$EXPECTED" -
echo "check: OK"