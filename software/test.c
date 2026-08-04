/*
 * Test input for the count-mem-ops pass.
 *
 * Ground truth is counted from the generated IR (build/test.ll), never from
 * reading this file: at -O0 every argument and local is spilled to an alloca,
 * so the source-level intuition is always off. Expected counts live in
 * expected.txt.
 */
#include <string.h>

/* Baseline: no explicit memory access in the source. -O0 argument spills
   still produce a small, known count; a pass that over-counts trips here
   first. */
int pure_add(int a, int b) { return a + b; }

/* Load-dominated: catches a swapped or mislabeled counter. */
int read_only(int *p) { return p[0] + p[1]; }

/* Store-heavy in the source, but alloca traffic evens the ratio out at -O0.
   The exact split only becomes clear in the IR. */
void write_only(int *p, int v) {
  p[0] = v;
  p[1] = v;
}

/* Mixed load/store with a loop: the original hand-verified anchors. */
int sum(int *p, int n) {
  int s = 0;
  for (int i = 0; i < n; i++)
    s += p[i];
  return s;
}

void scale(int *p, int n, int k) {
  for (int i = 0; i < n; i++)
    p[i] = p[i] * k;
}

/* On macOS, fortified headers lower these libc calls to __memcpy_chk /
   __memset_chk: plain calls the pass cannot see through. Kept deliberately
   as the "memory effects hidden behind an opaque call" case. */
void copy_buf(char *dst, const char *src, int n) { memcpy(dst, src, n); }
void clear_buf(char *dst, int n) { memset(dst, 0, n); }

/* __builtin_memcpy always lowers to the llvm.memcpy intrinsic, independent
   of platform headers: the guaranteed explicit-intrinsic case. */
void copy_buf_builtin(char *dst, const char *src) {
  __builtin_memcpy(dst, src, 8);
}

int main(void) {
  int a[4] = {1, 2, 3, 4}; /* implicit llvm.memcpy from a constant global */
  char buf[8];
  scale(a, 4, 3);
  clear_buf(buf, 8);
  copy_buf(buf, (const char *)a, 8);
  copy_buf_builtin(buf, (const char *)a);
  return pure_add(sum(a, 4), read_only(a));
}