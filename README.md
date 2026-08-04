# RISC-V coding challenge

Two tasks, each with its own README.

- [`hardware/`](hardware) A 4-entry, 32-bit content addressable memory in
  SystemVerilog, with a self-checking testbench. Fifteen checks pass under
  Verilator 5.050.
- [`software/`](software) An LLVM pass counting loads, stores and memory
  intrinsics per function, with the expected counts frozen and diffed by a
  `check` target.

Atip Kajitamkul
