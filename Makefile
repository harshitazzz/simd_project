# Usage:  make test | make compare | make bench | make waves | make fmax | make tables | make clean
# Everything runs from this folder.  Needs: iverilog, vvp, python3 (+matplotlib for waves)
IV = iverilog -g2012
RTL = $(wildcard rtl/*.v)
BUILD = sim
LOG = results/test_log.txt

.PHONY: all test unit system compare bench waves synth fmax tables clean
all: test compare bench

$(BUILD):
	mkdir -p $(BUILD)

# ---- unit tests (one per module) + system test ----
unit: | $(BUILD)
	@mkdir -p results
	@for t in lane_alu vreg_file vctrl; do \
	  if [ -f rtl/$$t.v ] && [ -f tb/tb_$$t.v ]; then \
	    $(IV) -o $(BUILD)/tb_$$t rtl/$$t.v tb/tb_$$t.v && (cd $(BUILD) && vvp tb_$$t | grep -E "^tb_|RESULT") | tee -a $(LOG); \
	  else echo "skip $$t (file not pushed yet)"; fi; \
	done
	@! grep -q "RESULT: FAIL" $(LOG) || (echo "*** UNIT TEST FAILURE ***"; exit 1)

system: | $(BUILD)
	@for L in 1 2 4 8; do \
	  $(IV) -Ptb_simd_core.LANES=$$L -o $(BUILD)/core_$$L $(RTL) tb/tb_simd_core.v && \
	  (cd $(BUILD) && vvp core_$$L | grep -E "LANES=|RESULT") | tee -a $(LOG); \
	done
	@! grep -q "RESULT: FAIL" $(LOG) || (echo "*** SYSTEM TEST FAILURE ***"; exit 1)

test:
	@mkdir -p results; : > $(LOG)
	@$(MAKE) --no-print-directory unit system

# ---- scalar machine vs SIMD machine, same workload, same data ----
compare: | $(BUILD)
	@mkdir -p results; : > results/compare.txt
	@for L in 1 2 4 8; do \
	  $(IV) -Ptb_compare.LANES=$$L -o $(BUILD)/cmp_$$L $(RTL) tb/tb_compare.v && \
	  (cd $(BUILD) && vvp cmp_$$L | grep -E "COMPARE|RESULT") | tee -a results/compare.txt; \
	done
	@! grep -q "RESULT: FAIL" results/compare.txt || (echo "*** COMPARE FAILURE ***"; exit 1)

# ---- lane scaling with the SIMD design alone (N=1024) ----
bench: | $(BUILD)
	@mkdir -p results; : > results/bench.txt
	@for L in 1 2 4 8; do \
	  $(IV) -Ptb_bench.LANES=$$L -o $(BUILD)/bench_$$L $(RTL) tb/tb_bench.v && \
	  (cd $(BUILD) && vvp bench_$$L | grep BENCH) | tee -a results/bench.txt; \
	done
	@awk '/BENCH/ {split($$2,a,"=");split($$5,c,"=");L=a[2];cyc=c[2]; if(L==1)base=cyc; \
	  printf "lanes=%d cycles=%d speedup=%.2fx efficiency=%.1f%%\n",L,cyc,base/cyc,100*(base/cyc)/L}' results/bench.txt | tee results/speedup.txt

# ---- waveform pictures (no GTKWave needed) ----
waves: | $(BUILD)
	$(IV) -o $(BUILD)/waves $(RTL) tb/tb_waves.v && cd $(BUILD) && vvp waves
	$(IV) -Ptb_bench.LANES=1 -Ptb_bench.N=16 -o $(BUILD)/bw1 $(RTL) tb/tb_bench.v && cd $(BUILD) && vvp bw1 +once +vcd=bench_L1.vcd | grep BENCH
	$(IV) -Ptb_bench.LANES=4 -Ptb_bench.N=16 -o $(BUILD)/bw4 $(RTL) tb/tb_bench.v && cd $(BUILD) && vvp bw4 +once +vcd=bench_L4.vcd | grep BENCH
	python3 scripts/make_waveforms.py

# ---- max frequency + FPGA resources (Yosys + nextpnr-ecp5), takes several minutes ----
fmax:
	bash scripts/fmax.sh

# ---- combine cycles + Fmax -> execution time, throughput (results/summary.md) ----
tables:
	python3 scripts/make_tables.py

# ---- resource estimate with Yosys (optional) ----
synth:
	bash scripts/synth.sh

clean:
	rm -rf $(BUILD)/*
