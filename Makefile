# Compilen y corran los ejemplos de esta presentacion con Verilator,
# generando ondas para verlas con Surfer.
#
# Uso:
#   make adders       - compila y corre half/full/ripple_carry_adder (adders/)
#   make wave-adders  - corre adders y abre adders/adders_tb.fst en Surfer
#   make view         - abre adders/waveform.fst incluido, sin simular
#   make alu8         - compila y corre alu8_tb (alu8/), reporta PASS/FAIL
#   make wave-alu8    - corre alu8 y abre alu8/alu8_tb.vcd en Surfer
#   make view-alu8    - abre alu8/waveform.vcd incluido, sin simular
#   make core-min     - compila y corre core_min_tb: nucleo RV32I minimo (add/sub/addi)
#   make wave-core-min   - corre core-min y abre la onda en Surfer
#   make view-core-min   - abre core_min/waveform.fst incluido, sin simular
#   make core-min2-alu     - ALU completa (R-type + I-type, 19 operaciones)
#   make core-min2-branch  - los 6 branches, taken + not-taken
#   make core-min2-jump    - jal/jalr (llamada+retorno, lazo hacia atras)
#   make core-min2-all     - corre los 3 anteriores en secuencia
#   make wave-core-min2         - alias de wave-core-min2-jump (default)
#   make wave-core-min2-alu     - corre core-min2-alu y abre la onda en Surfer
#   make wave-core-min2-branch  - corre core-min2-branch y abre la onda en Surfer
#   make wave-core-min2-jump    - corre core-min2-jump y abre la onda en Surfer
#   make view-core-min2-alu     - abre waveform_alu.fst incluido, sin simular
#   make view-core-min2-branch  - abre waveform_branch.fst incluido, sin simular
#   make view-core-min2-jump    - abre waveform_jump.fst incluido, sin simular
#   make core-full-alu/branch/jump/upper/mem  - bloques de core_full (RV32I base completo)
#   make core-full            - capstone: suma un arreglo de enteros en memoria
#   make core-full-all        - corre los 5 bloques + el capstone en secuencia
#   make wave-core-full-<bloque>  - corre ese bloque y abre la onda en Surfer
#   make core-full-bitstream  - sintetiza core_full para el Arty A7-100T con Vivado (via SiliconCompiler)
#   make core-full-program    - programa el Arty A7-100T con el bitstream generado (openFPGALoader)
#   make clean        - borra binarios y ondas generadas
#
# Nota: el proyecto vive bajo una ruta con espacios (iCloud Drive), y el
# Makefile que genera Verilator internamente no soporta eso -- por eso
# --Mdir apunta fuera de esta carpeta, a $(BUILD_DIR).

BUILD_DIR  := $(HOME)/verilator_builds
LZ4_PREFIX := /opt/homebrew/opt/lz4

ADDERS_DIR    := adders
ALU8_DIR      := alu8
CORE_MIN_DIR  := core_min
CORE_MIN2_DIR := core_min2
CORE_FULL_DIR := core_full

VLFLAGS := --binary --timing -sv --trace-fst \
           -Wno-IEEEMAYDEPRECATE -Wno-TIMESCALEMOD -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
           -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-UNOPTFLAT \
           -CFLAGS "-I$(LZ4_PREFIX)/include" -LDFLAGS "-L$(LZ4_PREFIX)/lib -llz4"

# alu8/ es Verilog puro (sin SystemVerilog), por eso no lleva -sv: asi
# el flujo de compilacion valida lo mismo que exige Silicluster v3.
ALU8_VLFLAGS := --binary --timing --trace-fst \
           -Wno-IEEEMAYDEPRECATE -Wno-TIMESCALEMOD -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
           -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-UNOPTFLAT \
           -CFLAGS "-I$(LZ4_PREFIX)/include" -LDFLAGS "-L$(LZ4_PREFIX)/lib -llz4"

ADDERS_SRCS := $(ADDERS_DIR)/half_adder.sv $(ADDERS_DIR)/full_adder.sv \
               $(ADDERS_DIR)/ripple_carry_adder.sv $(ADDERS_DIR)/adders_tb.sv
ALU8_SRCS   := $(ALU8_DIR)/alu8.v $(ALU8_DIR)/alu8_tb.v

CORE_MIN_SRCS   := $(CORE_MIN_DIR)/risc_v_32_i_pkg.sv $(CORE_MIN_DIR)/ArithmeticLogicUnit.sv \
                    $(CORE_MIN_DIR)/ImmediateSignExtend.sv $(CORE_MIN_DIR)/RegisterFile.sv \
                    $(CORE_MIN_DIR)/CoreControlUnit_min.sv $(CORE_MIN_DIR)/InstructionMemory_min.sv \
                    $(CORE_MIN_DIR)/ProcessorCoreMin.sv $(CORE_MIN_DIR)/core_min_tb.sv

# Modulos comunes de core_min2: extiende core_min con la ALU completa
# (R-type + I-type), ComparatorUnit (branches + slt/sltu/slti/sltiu) y
# el salto (jal/jalr). Sin memoria de datos ni lui/auipc todavia.
CORE_MIN2_COMMON := $(CORE_MIN2_DIR)/risc_v_32_i_pkg.sv $(CORE_MIN2_DIR)/ArithmeticLogicUnit.sv \
                     $(CORE_MIN2_DIR)/ImmediateSignExtend.sv $(CORE_MIN2_DIR)/RegisterFile.sv \
                     $(CORE_MIN2_DIR)/ComparatorUnit.sv $(CORE_MIN2_DIR)/CoreControlUnit_min2.sv \
                     $(CORE_MIN2_DIR)/InstructionMemory_min2.sv $(CORE_MIN2_DIR)/ProcessorCoreMin2.sv

# Modulos comunes de core_full: nucleo RV32I base completo (34
# instrucciones con semantica real, fence/ecall/ebreak como no-op). Igual
# que con CORE_MIN2_COMMON, la memoria de datos (DataMemory_full.sv) se
# agrega aparte solo en los bloques que la necesitan (mem, capstone).
CORE_FULL_COMMON := $(CORE_FULL_DIR)/risc_v_32_i_pkg.sv $(CORE_FULL_DIR)/ArithmeticLogicUnit.sv \
                     $(CORE_FULL_DIR)/ImmediateSignExtend.sv $(CORE_FULL_DIR)/RegisterFile.sv \
                     $(CORE_FULL_DIR)/ComparatorUnit.sv $(CORE_FULL_DIR)/LoadAndStoreUnit.sv \
                     $(CORE_FULL_DIR)/CoreControlUnit_full.sv $(CORE_FULL_DIR)/InstructionMemory_full.sv \
                     $(CORE_FULL_DIR)/ProcessorCoreFull.sv

CORE_FULL_DMEM := $(CORE_FULL_DIR)/DataMemory_full.sv

.PHONY: adders wave-adders view alu8 wave-alu8 view-alu8 \
        core-min wave-core-min view-core-min \
        core-min2-alu core-min2-branch core-min2-jump core-min2-all \
        wave-core-min2 wave-core-min2-alu wave-core-min2-branch wave-core-min2-jump \
        view-core-min2-alu view-core-min2-branch view-core-min2-jump \
        core-full-alu core-full-branch core-full-jump core-full-upper core-full-mem \
        core-full core-full-all \
        wave-core-full-alu wave-core-full-branch wave-core-full-jump \
        wave-core-full-upper wave-core-full-mem wave-core-full \
        core-full-bitstream core-full-program clean

adders:
	verilator $(VLFLAGS) --top-module adders_tb --Mdir $(BUILD_DIR)/adders_tb $(ADDERS_SRCS) -o sim_adders_tb
	cd $(ADDERS_DIR) && $(BUILD_DIR)/adders_tb/sim_adders_tb

wave-adders: adders
	surfer $(ADDERS_DIR)/adders_tb.fst

view-adders:
	surfer $(ADDERS_DIR)/waveform.fst

alu8:
	verilator $(ALU8_VLFLAGS) --top-module alu8_tb --Mdir $(BUILD_DIR)/alu8_tb $(ALU8_SRCS) -o sim_alu8_tb
	cd $(ALU8_DIR) && $(BUILD_DIR)/alu8_tb/sim_alu8_tb

wave-alu8: alu8
	surfer $(ALU8_DIR)/alu8_tb.vcd

view-alu8:
	surfer $(ALU8_DIR)/waveform.vcd

core-min:
	verilator $(VLFLAGS) --top-module core_min_tb --Mdir $(BUILD_DIR)/core_min_tb $(CORE_MIN_SRCS) -o sim_core_min_tb
	cd $(CORE_MIN_DIR) && $(BUILD_DIR)/core_min_tb/sim_core_min_tb

wave-core-min: core-min
	surfer $(CORE_MIN_DIR)/core_min_tb.fst

view-core-min:
	surfer $(CORE_MIN_DIR)/waveform.fst

core-min2-alu:
	verilator $(VLFLAGS) --top-module core_min2_alu_tb --Mdir $(BUILD_DIR)/core_min2_alu_tb \
	          $(CORE_MIN2_COMMON) $(CORE_MIN2_DIR)/core_min2_alu_tb.sv -o sim_core_min2_alu_tb
	cd $(CORE_MIN2_DIR) && $(BUILD_DIR)/core_min2_alu_tb/sim_core_min2_alu_tb

core-min2-branch:
	verilator $(VLFLAGS) --top-module core_min2_branch_tb --Mdir $(BUILD_DIR)/core_min2_branch_tb \
	          $(CORE_MIN2_COMMON) $(CORE_MIN2_DIR)/core_min2_branch_tb.sv -o sim_core_min2_branch_tb
	cd $(CORE_MIN2_DIR) && $(BUILD_DIR)/core_min2_branch_tb/sim_core_min2_branch_tb

core-min2-jump:
	verilator $(VLFLAGS) --top-module core_min2_jump_tb --Mdir $(BUILD_DIR)/core_min2_jump_tb \
	          $(CORE_MIN2_COMMON) $(CORE_MIN2_DIR)/core_min2_jump_tb.sv -o sim_core_min2_jump_tb
	cd $(CORE_MIN2_DIR) && $(BUILD_DIR)/core_min2_jump_tb/sim_core_min2_jump_tb

wave-core-min2: wave-core-min2-jump

wave-core-min2-alu: core-min2-alu
	surfer $(CORE_MIN2_DIR)/core_min2_alu_tb.fst

wave-core-min2-branch: core-min2-branch
	surfer $(CORE_MIN2_DIR)/core_min2_branch_tb.fst

wave-core-min2-jump: core-min2-jump
	surfer $(CORE_MIN2_DIR)/core_min2_jump_tb.fst

view-core-min2-alu:
	surfer $(CORE_MIN2_DIR)/waveform_alu.fst

view-core-min2-branch:
	surfer $(CORE_MIN2_DIR)/waveform_branch.fst

view-core-min2-jump:
	surfer $(CORE_MIN2_DIR)/waveform_jump.fst

core-min2-all: core-min2-alu core-min2-branch core-min2-jump

core-full-alu:
	verilator $(VLFLAGS) --top-module core_full_alu_tb --Mdir $(BUILD_DIR)/core_full_alu_tb \
	          $(CORE_FULL_COMMON) $(CORE_FULL_DIR)/core_full_alu_tb.sv -o sim_core_full_alu_tb
	cd $(CORE_FULL_DIR) && $(BUILD_DIR)/core_full_alu_tb/sim_core_full_alu_tb

core-full-branch:
	verilator $(VLFLAGS) --top-module core_full_branch_tb --Mdir $(BUILD_DIR)/core_full_branch_tb \
	          $(CORE_FULL_COMMON) $(CORE_FULL_DIR)/core_full_branch_tb.sv -o sim_core_full_branch_tb
	cd $(CORE_FULL_DIR) && $(BUILD_DIR)/core_full_branch_tb/sim_core_full_branch_tb

core-full-jump:
	verilator $(VLFLAGS) --top-module core_full_jump_tb --Mdir $(BUILD_DIR)/core_full_jump_tb \
	          $(CORE_FULL_COMMON) $(CORE_FULL_DIR)/core_full_jump_tb.sv -o sim_core_full_jump_tb
	cd $(CORE_FULL_DIR) && $(BUILD_DIR)/core_full_jump_tb/sim_core_full_jump_tb

core-full-upper:
	verilator $(VLFLAGS) --top-module core_full_upper_tb --Mdir $(BUILD_DIR)/core_full_upper_tb \
	          $(CORE_FULL_COMMON) $(CORE_FULL_DIR)/core_full_upper_tb.sv -o sim_core_full_upper_tb
	cd $(CORE_FULL_DIR) && $(BUILD_DIR)/core_full_upper_tb/sim_core_full_upper_tb

core-full-mem:
	verilator $(VLFLAGS) --top-module core_full_mem_tb --Mdir $(BUILD_DIR)/core_full_mem_tb \
	          $(CORE_FULL_COMMON) $(CORE_FULL_DMEM) $(CORE_FULL_DIR)/core_full_mem_tb.sv -o sim_core_full_mem_tb
	cd $(CORE_FULL_DIR) && $(BUILD_DIR)/core_full_mem_tb/sim_core_full_mem_tb

core-full:
	verilator $(VLFLAGS) --top-module core_full_tb --Mdir $(BUILD_DIR)/core_full_tb \
	          $(CORE_FULL_COMMON) $(CORE_FULL_DMEM) $(CORE_FULL_DIR)/core_full_tb.sv -o sim_core_full_tb
	cd $(CORE_FULL_DIR) && $(BUILD_DIR)/core_full_tb/sim_core_full_tb

core-full-all: core-full-alu core-full-branch core-full-jump core-full-upper core-full-mem core-full

wave-core-full: core-full
	surfer $(CORE_FULL_DIR)/core_full_tb.fst

wave-core-full-alu: core-full-alu
	surfer $(CORE_FULL_DIR)/core_full_alu_tb.fst

wave-core-full-branch: core-full-branch
	surfer $(CORE_FULL_DIR)/core_full_branch_tb.fst

wave-core-full-jump: core-full-jump
	surfer $(CORE_FULL_DIR)/core_full_jump_tb.fst

wave-core-full-upper: core-full-upper
	surfer $(CORE_FULL_DIR)/core_full_upper_tb.fst

wave-core-full-mem: core-full-mem
	surfer $(CORE_FULL_DIR)/core_full_mem_tb.fst

# Sintesis + bitstream para el Arty A7-100T, via SiliconCompiler + Vivado
# (FPGAXilinxFlow). Requiere Vivado instalado y en el PATH.
core-full-bitstream:
	cd $(CORE_FULL_DIR)/fpga && python3 sc_run_fpga.py

# Programa el Arty A7-100T por JTAG con el bitstream mas reciente.
# Requiere openFPGALoader (y la placa conectada).
core-full-program:
	openFPGALoader -b arty_a7_100t $(CORE_FULL_DIR)/fpga/build/core_full_fpga/job0/bitstream/0/outputs/TopArtyA7.bit

clean:
	rm -rf $(BUILD_DIR)/adders_tb $(BUILD_DIR)/alu8_tb $(BUILD_DIR)/core_min_tb \
	       $(BUILD_DIR)/core_min2_alu_tb $(BUILD_DIR)/core_min2_branch_tb $(BUILD_DIR)/core_min2_jump_tb \
	       $(BUILD_DIR)/core_full_alu_tb $(BUILD_DIR)/core_full_branch_tb $(BUILD_DIR)/core_full_jump_tb \
	       $(BUILD_DIR)/core_full_upper_tb $(BUILD_DIR)/core_full_mem_tb $(BUILD_DIR)/core_full_tb \
	       $(ADDERS_DIR)/adders_tb.fst $(ALU8_DIR)/alu8_tb.fst $(ALU8_DIR)/alu8_tb.vcd \
	       $(CORE_MIN_DIR)/core_min_tb.fst \
	       $(CORE_MIN2_DIR)/core_min2_alu_tb.fst $(CORE_MIN2_DIR)/core_min2_branch_tb.fst \
	       $(CORE_MIN2_DIR)/core_min2_jump_tb.fst \
	       $(CORE_FULL_DIR)/core_full_alu_tb.fst $(CORE_FULL_DIR)/core_full_branch_tb.fst \
	       $(CORE_FULL_DIR)/core_full_jump_tb.fst $(CORE_FULL_DIR)/core_full_upper_tb.fst \
	       $(CORE_FULL_DIR)/core_full_mem_tb.fst $(CORE_FULL_DIR)/core_full_tb.fst
