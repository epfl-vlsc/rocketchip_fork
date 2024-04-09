default: all

base_dir = $(abspath ..)
generated_dir = $(abspath ./generated-src)
generated_dir_debug = $(abspath ./generated-src-debug)
sim_dir = $(abspath .)
output_dir = $(sim_dir)/output

include $(base_dir)/Makefrag

THREADS ?= 1

emu = verilator-$(PROJECT)-$(CONFIG)-$(THREADS)t
emu_debug = $(emu)-debug

emu_essent = essent-$(PROJECT)-$(CONFIG)-$(THREADS)t

all: $(emu)
debug: $(emu_debug)

.PHONY: default all debug clean

#--------------------------------------------------------------------
# Verilator Generation
#--------------------------------------------------------------------
firrtl = $(generated_dir)/$(long_name).fir
verilog = \
  $(generated_dir)/$(long_name).v \
  $(generated_dir)/$(long_name).behav_srams.v \
  $(sim_dir)/SimpleTestDriver.v

essent_dir ?= /scratch/emami/graphcore/repcut/
essent = java -Xms8G -Xmx32G -Xss10M -cp $(essent_dir)/utils/bin/essent.jar essent.Driver
essent_CXX ?= clang++-12
kahypar_path = $(sim_dir)/kahypar/build/kahypar/application/

kahypar_bin = $(kahypar_path)/KaHyPar


$(kahypar_bin):
	mkdir -p kahypar/build && cd kahypar/build && \
  cmake .. -G "Unix Makefiles" -DKAHYPAR_USE_MINIMAL_BOOST=On -DCMAKE_BUILD_TYPE=Release && \
  $(MAKE) KaHyPar

build_kahypar: $(kahypar_bin)


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


VERILATOR := verilator --cc --exe --threads $(THREADS)


VERILATOR_FLAGS := --top-module Main \
  -DSTOP_COND=1 \
  -DPRINTF_COND=Main.verbose \
  -URANDOMIZE_GARBAGE_ASSIGN -URANDOMIZE_MEM_INIT \
  -O3

verilator_sim: $(emu)
essent_sim: $(emu_essent)

$(emu): $(verilog) $(sim_dir)/SimpleHarness_verilator.cpp
	mkdir -p $(generated_dir)/$(long_name)
	$(VERILATOR) $(VERILATOR_FLAGS) --top Main -Mdir $(generated_dir)/$(long_name) \
	-o $(abspath $(sim_dir))/$@ $(verilog) $(sim_dir)/SimpleHarness_verilator.cpp
	$(MAKE) VM_PARALLEL_BUILDS=1 -C $(generated_dir)/$(long_name) -f VMain.mk

essent_model = $(generated_dir)/$(emu_essent).h

essent_cxx_flags = \
  -std=c++11 \
  -DESSENT_MODEL=\"$(essent_model)\" \
  -fno-slp-vectorize -fbracket-depth=1024 \
  -I$(essent_dir)/firrtl-sig

ifeq ($(THREADS),1)
	essent_cxx_flags += -DNO_THREADS
else
  essent_cxx_flags += -lpthread
endif


# RepCut needs KaHyPar to be in PATH
PATH := $(PATH):$(kahypar_path)

$(essent_model): $(firrtl) $(kahypar_bin)
	$(essent) -O0 --parallel $(THREADS) $(firrtl)
	mv $(generated_dir)/SimpleHarness.h $@

$(emu_essent): $(sim_dir)/SimpleHarness_essent.cpp $(essent_model)
	$(essent_CXX) -O3 $(essent_cxx_flags)  \
    $(sim_dir)/SimpleHarness_essent.cpp -o $@

clean:
	rm -rf $(generated_dir) verilator-* essent-* repcut-*