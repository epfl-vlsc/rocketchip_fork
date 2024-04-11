THREADS ?= 1 \
	2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32

MODEL = SimpleHarness

CONFIGS = \
	ParendiBig1CoreConfig \
	ParendiBig2CoreConfig \
	ParendiBig4CoreConfig \
	ParendiBig8CoreConfig \
	ParendiBig12CoreConfig \
	ParendiBig16CoreConfig \
	ParendiSmall1CoreConfig \
	ParendiSmall2CoreConfig \
	ParendiSmall4CoreConfig \
	ParendiSmall8CoreConfig \
	ParendiSmall12CoreConfig \
	ParendiSmall16CoreConfig

PROJECT = freechips.rocketchip.system

JVM_MEMORY ?= 16G

TARGET_CONFIGS = $(foreach cfg,$(foreach item,$(addprefix $(PROJECT).,$(CONFIGS)), $(addprefix $(item)-, $(THREADS))), $(addprefix $(cfg),t))
ESSENT_TARGETS = $(addprefix essent-,$(TARGET_CONFIGS))
VERILATOR_TARGETS = $(addprefix verilator-,$(TARGET_CONFIGS))

MAKE_GEN = $(MAKE) -f SimpleTestDriver.mk CONFIG=$* MODEL=$(MODEL) JVM_MEMORY=$(JVM_MEMORY)

generated-src/%.fir:
	$(MAKE_GEN)	gen_firrtl

generated-src/%.v: generated-src/%.fir
	$(MAKE_GEN) gen_verilog


MAKE_BIN = $(MAKE) -f SimpleTestDriver.mk CONFIG=$(word 2,$(subst -, ,$@)) MODEL=$(MODEL) JVM_MEMORY=$(JVM_MEMORY) THREADS=$(subst t, ,$(word 3,$(subst -, ,$@)))


.SECONDEXPANSION:
verilator-%: generated-src/$$(word 1,$$(subst -, ,$$*)).v
	@echo "Target = $@"
	@echo "Depends on = $<"
	$(MAKE_BIN) $(word 1,$(subst -, ,$@))_sim

essent-%: generated-src/$$(word 1,$$(subst -, ,$$*)).v
	$(MAKE_BIN) $(word 1,$(subst -, ,$@))_sim


all: verilator_binaries essent_binaries



show_essent_targets:
	@for t in $(ESSENT_TARGETS); do \
		echo $$t; \
	done;

verilator_binaries: $(VERILATOR_TARGETS)
essent_binaries: $(ESSENT_TARGETS)

clean:
	rm -rf generated-src $(VERILATOR_TARGETS) $(ESSENT_TARGETS)

