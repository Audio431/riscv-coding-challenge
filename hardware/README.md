# 4-entry, 32-bit Content Addressable Memory

A CAM stores values and is searched by content rather than by address. This
module holds four 32-bit entries. Writes are addressed and synchronous; the
search compares all four entries in parallel and answers in the same cycle.

## Interface

| Signal       | Dir | Width | Description                                |
| ------------ | --- | ----- | ------------------------------------------ |
| `clk`        | in  | 1     | clock                                      |
| `rst_n`      | in  | 1     | asynchronous reset, active low             |
| `wr_en`      | in  | 1     | write strobe                               |
| `wr_addr`    | in  | 2     | which of the four entries to write         |
| `wr_data`    | in  | 32    | value stored into that entry               |
| `search_key` | in  | 32    | value to search for                        |
| `match`      | out | 1     | high when `search_key` is in a valid entry |

## Implementation

Each entry carries a valid bit in `entry_valid`. Reset clears `entry_valid`
only, so an entry never written since reset is ignored by the search regardless
of what it holds.
 
The search is a comparison per entry, each gated by that entry's valid bit, OR
reduced into `match`.

## Design choices

The problem statement fixes the depth and the width and leaves the rest open, so
three questions had to be answered here: what counts as a match, what the module
reports, and how the comparison is built.

**Binary CAM rather than ternary.** A TCAM carries a mask per entry and ignores
the masked bits during the compare, which is what prefix matching needs. The
problem statement asks only for match and miss on a full 32-bit value, so the
mask storage and the wider compare would be unused logic here.

**`match` as a single bit rather than a one-hot vector or an encoded index.**
One-hot reports which entries matched; an encoder reduces that to a position.
Callers need either when the entry index selects associated data, but this
module is asked for match and miss, so the OR reduction is the whole answer. A
caller that needs positions would be a different interface.

**Four parallel comparators rather than a RAM-based lookup.** The alternative
stores the mapping in a memory and indexes it, which amortises well once the
entry count is large. At a depth of four it buys nothing: each comparator is a
handful of gates, and the memory would be an external dependency.

## Assumptions

- No write forwarding. A write lands in the flops at the clock edge, so a search
  in the same cycle sees the entry as it was before the write.
- Duplicates are permitted. Writing one value into several entries is legal and
  produces a single `match`; uniqueness is not enforced in hardware.
- One write per cycle, selected by `wr_addr`. There is no invalidate port, so an
  entry leaves the searchable set only by being overwritten or by reset.

## Coverage

`tb/tb_cam.sv` runs fifteen checks and prints `PASS` only if all of them hold.

- Miss after reset, for a zero key and for an arbitrary key
- Hit on a written entry
- Miss on a key that was never written
- Miss when `wr_en` is low while `wr_addr` and `wr_data` change, so the write
  strobe is shown to gate the store
- Hit on entries 0 through 3, so the search is not fixed to one position
- Miss on a value that has been overwritten, and hit on the value replacing it
- Single hit when the same value occupies two entries
- Miss when a write and a matching search occur in the same cycle, and hit on
  the cycle after, which is the no-forwarding assumption above
- Miss after a second reset, so validity is cleared rather than the data

## Limitations

The testbench proves the cases listed above and nothing beyond them. The
structure extends to greater depth by widening `wr_addr` and `entry_valid`,
at the cost of one comparator per entry and a wider OR tree; at large depths the
reduction becomes the timing-critical path and would need pipelining, which is
outside the scope of this exercise. Nothing here has been synthesised, so no
area or frequency claim is made. The results above come from Verilator, which is
two-state; a four-state simulator could expose uninitialised behaviour that does
not appear here.

## Tooling

The lint gate follows Sargantana's `veri_lint_strict.sh`: `verilator
--lint-only`, failing on any diagnostic. The simulation warning flags follow
CVA6's verilate command. `make lint` covers the RTL; the testbench is checked
with the same flags when the simulation is built.

## Running

```bash
make lint    # lint the RTL
make run     # build and run the testbench
make clean   # remove the build directory
```

Requires Verilator 5.x for `--binary`. Verified with 5.050 on macOS.
