#!/usr/bin/env python3
"""Compilen y corran los testbenches de core_full con SiliconCompiler,
usando Verilator como motor de simulacion y generando una onda .fst
para verla con Surfer.

core_full es el nucleo RV32I base completo (34 instrucciones con
semantica real, mas fence/ecall/ebreak decodificadas como no-op), en
6 bloques, cada uno con su propio testbench y programa .hex:

    alu     - ALU completa (R-type + I-type, 19 operaciones)
    branch  - los 6 branches (beq/bne/blt/bge/bltu/bgeu), taken+not-taken
    jump    - jal/jalr (llamada+retorno, salto hacia atras)
    upper   - lui/auipc + el idioma lui+addi de 32 bits
    mem     - loads/stores (byte/half/word, little-endian)
    full    - capstone: suma un arreglo de enteros en memoria (default)

Uso:
    python3 sc_run.py                 - compila y corre el capstone (full)
    python3 sc_run.py --tb alu        - corre el bloque indicado
    python3 sc_run.py --tb mem --wave - igual, y ademas abre la onda en Surfer
    python3 sc_run.py --view          - abre el waveform.fst incluido, sin simular
"""
import argparse
import os
import re
import subprocess
import sys

from siliconcompiler import Design, Sim, Flowgraph
from siliconcompiler.tools.verilator import compile as verilator_compile
from siliconcompiler.tools.verilator.compile import CompileTask

HERE = os.path.dirname(os.path.abspath(__file__))

LZ4_PREFIXES = ("/opt/homebrew/opt/lz4", "/usr/local/opt/lz4")

VERILATOR_WARNINGS_OFF = [
    "-Wno-WIDTHEXPAND", "-Wno-WIDTHTRUNC", "-Wno-CASEINCOMPLETE",
    "-Wno-UNOPTFLAT", "-Wno-TIMESCALEMOD", "-Wno-IEEEMAYDEPRECATE", "-Wno-LATCH",
]

COMMON_FILES = [
    "risc_v_32_i_pkg.sv", "ArithmeticLogicUnit.sv", "ImmediateSignExtend.sv",
    "RegisterFile.sv", "ComparatorUnit.sv", "LoadAndStoreUnit.sv",
    "CoreControlUnit_full.sv", "InstructionMemory_full.sv", "ProcessorCoreFull.sv",
]
DMEM_FILE = "DataMemory_full.sv"

# block name -> (top module, needs DataMemory_full?)
BLOCKS = {
    "alu":    ("core_full_alu_tb",    False),
    "branch": ("core_full_branch_tb", False),
    "jump":   ("core_full_jump_tb",   False),
    "upper":  ("core_full_upper_tb",  False),
    "mem":    ("core_full_mem_tb",    True),
    "full":   ("core_full_tb",        True),
}


class CoreFullDesign(Design):
    """core_full: RV32I base completo (fence/ecall/ebreak como no-op)."""

    def __init__(self, topmodule, use_dmem):
        super().__init__()
        self.set_name("core_full")
        self.set_dataroot("core_full", HERE)
        with self.active_dataroot("core_full"):
            with self.active_fileset("rtl"):
                self.set_topmodule(topmodule)
                for f in COMMON_FILES:
                    self.add_file(f)
                if use_dmem:
                    self.add_file(DMEM_FILE)
            with self.active_fileset("testbench.verilator.v"):
                self.set_topmodule(topmodule)
                self.add_file(f"{topmodule}.sv")


def _configure_verilator_task(project):
    task = CompileTask.find_task(project)
    task.set_verilator_main(True)
    task.add_commandline_option(["--trace-fst", *VERILATOR_WARNINGS_OFF])
    for lz4_prefix in LZ4_PREFIXES:
        if os.path.isdir(lz4_prefix):
            task.add_verilator_cincludes(f"{lz4_prefix}/include")
            task.add_verilator_ldflags([f"-L{lz4_prefix}/lib", "-llz4"])
            break


def _run_executable(vexe_path):
    """Corre el .vexe con cwd=HERE, igual que los targets de make (`cd
    core_full && ...`), para que $readmemh encuentre los .hex por su
    ruta relativa. Sin esto, SiliconCompiler corre el binario desde su
    propio directorio de build y $readmemh truena con 'file not found'."""
    result = subprocess.run([vexe_path], cwd=HERE, capture_output=True, text=True)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    return re.search(r"^FAIL:", result.stdout, re.MULTILINE) is None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tb", choices=sorted(BLOCKS), default="full", help="bloque a correr (default: full)")
    parser.add_argument("--wave", action="store_true", help="abrir la onda en Surfer al terminar")
    parser.add_argument("--view", action="store_true",
                        help="abrir el waveform.fst incluido, sin simular")
    args = parser.parse_args()

    if args.view:
        subprocess.call(["surfer", os.path.join(HERE, "waveform.fst")])
        return

    topmodule, use_dmem = BLOCKS[args.tb]

    project = Sim()
    project.set_design(CoreFullDesign(topmodule, use_dmem))
    project.add_fileset("testbench.verilator.v")
    project.add_fileset("rtl")

    flow = Flowgraph(f"core_full_{args.tb}_sim")
    flow.node("compile", verilator_compile.CompileTask())
    project.set_flow(flow)

    _configure_verilator_task(project)

    project.run()
    project.summary()

    vexe = project.find_result(step="compile", index="0", directory="outputs",
                               filename=f"{topmodule}.vexe")
    passed = _run_executable(vexe)

    if args.wave:
        fst = os.path.join(HERE, f"{topmodule}.fst")
        if os.path.exists(fst):
            project.show(fst)
        else:
            print(f"No se encontro la onda {topmodule}.fst")

    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
