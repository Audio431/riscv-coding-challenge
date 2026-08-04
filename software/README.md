# count-mem-ops

An out-of-tree LLVM pass (new pass manager, module pass) that walks every
function in a module, counts memory operations, and prints per-function counts
plus a module total:

```
pure_add: 2 loads, 2 stores, 0 mem intrinsics
...
main: 0 loads, 1 stores, 1 mem intrinsics
total: 36 loads, 27 stores, 2 mem intrinsics
```

## Requirements

LLVM 22 and CMake 3.20+. Developed and tested against Homebrew's `llvm 22.1.8`
on macOS (arm64). The plugin header is included from
`llvm/Plugins/PassPlugin.h`, which is where LLVM 22 keeps it; older releases may
place it elsewhere.

## Running

```sh
./run.sh                               # build the plugin and print the counts
cmake --build build --target check     # rerun and diff against expected.txt
cmake --build build --target distclean # remove build/ entirely
```

`run.sh` configures into `build/`, builds the plugin, lowers `test.c` to IR
(`build/test.ll`, via `clang -O0 -S -emit-llvm`), and runs the pass on it
through `opt`. On systems without Homebrew, point `LLVM_DIR` at your LLVM
installation:

```sh
LLVM_DIR=/path/to/llvm/lib/cmake/llvm ./run.sh
```

`check` is the target to use for a pass or fail answer: it diffs the output
against `expected.txt` and fails on any drift. The generated IR is kept as a
file rather than piped, so any surprising count can be verified by reading
`build/test.ll` directly.

## The metric

Three categories per function, over unoptimized IR: `LoadInst`, `StoreInst`,
and memory intrinsics (`llvm.memcpy` / `memmove` / `memset`, matched via
`MemIntrinsic`). Function declarations are skipped.

Because the input is `-O0` IR, the counts include the load and store traffic
from argument and local spills to allocas. The metric measures the IR as
emitted, not the program's real memory behaviour, and the same C code counts
differently at other optimization levels.

## Limitations

The boundary of the metric is the function body. The pass counts instructions,
so memory effects hidden behind opaque calls contribute nothing. On macOS this
includes plain `memcpy` and `memset`, which the fortified SDK headers lower to
`__memcpy_chk` and `__memset_chk` library calls. `test.c` keeps that case on
purpose (`copy_buf`, `clear_buf`) alongside `__builtin_memcpy`
(`copy_buf_builtin`), which always lowers to the `llvm.memcpy` intrinsic
regardless of platform headers.

Atomic read-modify-write and compare-exchange instructions are not counted; see
Future work below.

The frozen numbers in `expected.txt` are tied to clang 22.1.8. `-O0` codegen can
shift between compiler versions, and drift from that alone is not a pass bug.

## How it was built

The pass grew ground-truth-first. The first version was a skeleton that only
visited each function and printed its name. The memory operations in the
original test program were then counted by hand from `build/test.ll` (17 loads,
13 stores across `sum`, `scale` and `main`), and only once those numbers existed
was the counting logic written and checked against them. Every later addition,
the intrinsics category and each new test case, followed the same order: read
the IR, count by hand, then make the pass agree.

## Testing

Test cases in `test.c` were chosen by criteria, not accumulated. Each function
earns its place by answering one question:

- **Can the pass over-count?** A baseline with no memory access in the source
  (`pure_add`) must stay at its small, known spill count.
- **Are the counters wired to the right columns?** One load-dominated and one
  store-heavy function (`read_only`, `write_only`) make a swapped or mislabeled
  counter visible immediately.
- **Does every counted category appear, through every path into it?** Loads and
  stores come from the loop anchors (`sum`, `scale`); the intrinsic category is
  reached both explicitly (`__builtin_memcpy`) and implicitly (array
  initialization in `main`).
- **Is the known blind spot represented?** The fortified libc functions
  (`copy_buf`, `clear_buf`) produce opaque calls the pass cannot see, kept as a
  live example of the limitation above.

Expected counts were read off `build/test.ll`, never inferred from the C source,
since `-O0` spills defeat source-level intuition.

## Future work

Atomics are the one memory-op family the counter knowingly misses. An
`atomicrmw` is a load, a modification and a store fused into one indivisible
instruction, yet it is neither a `LoadInst`, a `StoreInst` nor a `MemIntrinsic`,
so it falls through all three categories silently. The handling is also
asymmetric today: an atomic load is just a `LoadInst` with an ordering attached
and already lands in the load column, while `atomicrmw` and `cmpxchg` vanish.

RISC-V ships atomics as a named extension ("A"), and these IR instructions lower
almost one-to-one onto its AMO and LR/SC instructions, so a fourth category
matching `AtomicRMWInst` and `AtomicCmpXchgInst` would account for exactly the
operations that extension exists to provide. The change is one more `else if`, a
pair of test functions and a refreshed `expected.txt`, deferred here to keep the
delivered scope frozen.