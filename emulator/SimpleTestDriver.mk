default: all

base_dir = $(abspath ..)
generated_dir = $(abspath ./generated-src)
generated_dir_debug = $(abspath ./generated-src-debug)
sim_dir = $(abspath .)
output_dir = $(sim_dir)/output

include $(base_dir)/Makefrag

emu = sim-$(PROJECT)-$(CONFIG)
emu_debug = sim-$(PROJECT)-$(CONFIG)-debug


all: $(emu)
debug: $(emu_debug)

clean:
	rm -rf *.o *.a emulator-* $(generated_dir) $(generated_dir_debug) DVEfiles $(output_dir)

.PHONY: default all debug clean

#--------------------------------------------------------------------
# Verilator Generation
#--------------------------------------------------------------------
firrtl = $(generated_dir)/$(long_name).fir
verilog = \
  $(generated_dir)/$(long_name).v \
  $(generated_dir)/$(long_name).behav_srams.v \
  $(sim_dir)/SimpleTestDriver.v


.SECONDARY: $(firrtl) $(verilog)

$(generated_dir)/%.fir $(generated_dir)/%.d: $(ROCKET_CHIP_JAR) $(bootrom_img)
	mkdir -p $(dir $@)
	cd $(base_dir) && $(GENERATOR) -td $(generated_dir) -T $(PROJECT).$(MODEL) -C $(CONFIG) $(CHISEL_OPTIONS)

%.v %.conf: %.fir $(ROCKET_CHIP_JAR)
	mkdir -p $(dir $@)
	$(FIRRTL) $(patsubst %,-i %,$(filter %.fir,$^)) \
    -o $*.v \
    -X verilog \
    --infer-rw $(MODEL) \
    --repl-seq-mem -c:$(MODEL):-o:$*.conf \
    -faf $*.anno.json \
    -td $(generated_dir)/$(long_name)/ \
    -fct $(subst $(SPACE),$(COMMA),$(FIRRTL_TRANSFORMS)) \
    $(FIRRTL_OPTIONS) \


$(generated_dir)/$(long_name).behav_srams.v : $(generated_dir)/$(long_name).conf $(VLSI_MEM_GEN)
	cd $(generated_dir) && \
	$(VLSI_MEM_GEN) $(generated_dir)/$(long_name).conf > $@.tmp && \
	mv -f $@.tmp $@


VERILATOR := verilator --cc --exe
THREADS ?= 1

VERILATOR_FLAGS := --top-module Main \
  -DSTOP_COND=0 \
  -DPRINTF_COND=0 \
  -URANDOMIZE_GARBAGE_ASSIGN -URANDOMIZE_MEM_INIT \
  -O3


$(emu): $(verilog) $(sim_dir)/SimpleHarness.cpp

	mkdir -p $(generated_dir)/$(long_name)
	$(VERILATOR) $(VERILATOR_FLAGS) --top Main -Mdir $(generated_dir)/$(long_name) \
	-o $(abspath $(sim_dir))/$@ $(verilog) $(sim_dir)/SimpleHarness.cpp
	$(MAKE) VM_PARALLEL_BUILDS=1 -C $(generated_dir)/$(long_name) -f VMain.mk