# =============================================================
# Makefile - APB GPIO (PULP Platform) compile & simulate flow
# Target simulator: Mentor/Siemens QuestaSim
# =============================================================

# ---- Tools -----------------------------------------------------
VLIB    = vlib
VLOG    = vlog
VSIM    = vsim
VMAP    = vmap

# ---- Directories -------------------------------------------------
RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim
WORK    = work

# ---- Source lists --------------------------------------------------
RTL_SRCS = $(RTL_DIR)/apb_gpio.sv
TB_SRCS  = $(TB_DIR)/tb_apb_gpio.sv

TOP      = tb_apb_gpio

# ---- Compile flags -------------------------------------------------
VLOG_FLAGS = -sv -mfcu +acc -work $(WORK)

# ---- Default target --------------------------------------------------
.PHONY: all
all: sim

# ---- Create the work library --------------------------------------------
$(WORK):
	$(VLIB) $(WORK)
	$(VMAP) work $(WORK)

# ---- Compile RTL + testbench --------------------------------------------
.PHONY: compile
compile: $(WORK)
	$(VLOG) $(VLOG_FLAGS) $(RTL_SRCS)
	$(VLOG) $(VLOG_FLAGS) $(TB_SRCS)

# ---- Run simulation in batch mode (console transcript only) --------------
.PHONY: sim
sim: compile
	$(VSIM) -c -do "run -all; quit -f" $(WORK).$(TOP)

# ---- Run simulation with GUI + waveform ----------------------------------
.PHONY: sim-gui
sim-gui: compile
	$(VSIM) -do "add wave -radix binary /$(TOP)/uut/*; add wave -radix hex /$(TOP)/gpio_out; add wave -radix hex /$(TOP)/gpio_dir; run -all" $(WORK).$(TOP)

# ---- Clean generated files ------------------------------------------------
.PHONY: clean
clean:
	rm -rf $(WORK) transcript vsim.wlf $(SIM_DIR)/*.vcd
	rm -f  *.log

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make compile   - compile RTL + testbench into the 'work' library"
	@echo "  make sim       - compile then run in batch mode (transcript only)"
	@echo "  make sim-gui   - compile then run in the QuestaSim GUI with waveforms"
	@echo "  make clean     - remove work library and simulation artifacts"
