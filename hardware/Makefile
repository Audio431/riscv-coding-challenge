# Verilator flow for the CAM coding challenge.
#
# Lint gate follows Sargantana's scripts/veri_lint_strict.sh (verilator --lint-only,
# non-zero exit on any diagnostic). Warning flags follow CVA6's verilate command.

VERILATOR := verilator
MDIR      := obj_dir

RTL_DIR := rtl
TB_DIR  := tb
MODULE  ?= cam

RTL := $(RTL_DIR)/$(MODULE).sv
TB  := $(TB_DIR)/tb_$(MODULE).sv
TOP ?= tb_$(MODULE)

WARN_FLAGS := -Wall \
              -Werror-PINMISSING \
              -Werror-IMPLICIT \
              -Wno-DECLFILENAME \
              -Wno-UNUSED

# Default target to lint when none is given on the command line.
FILE ?= $(RTL)

.PHONY: all lint lint-all sim run clean

all: lint sim

# Lint a single file:  make lint FILE=rtl/cam.sv
lint:
	$(VERILATOR) --lint-only $(WARN_FLAGS) $(FILE)

# Lint every RTL file in the tree, excluding testbenches.
lint-all:
	@find rtl -name '*.sv' ! -name 'tb_*' -print0 | \
	  xargs -0 -n1 $(VERILATOR) --lint-only $(WARN_FLAGS)

sim:
	$(VERILATOR) --binary --timing $(WARN_FLAGS) --Mdir $(MDIR) \
	  $(RTL) $(TB) --top-module $(TOP)

run: sim
	./$(MDIR)/V$(TOP)

clean:
	rm -rf $(MDIR)
