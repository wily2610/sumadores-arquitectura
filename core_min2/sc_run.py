#!/usr/bin/env python3
"""Compilen y corran los testbenches de core_min2 con SiliconCompiler,
usando Verilator como motor de simulacion y generando una onda .fst
para verla con Surfer.

core_min2 extiende core_min hasta branches y saltos, en 3 bloques,
cada uno con su propio testbench y programa .hex:

    alu     - ALU completa (R-type + I-type, 19 operaciones)
    branch  - los 6 branches (beq/bne/blt/bge/bltu/bgeu), taken+not-taken
    jump    - jal/jalr (llamada+retorno, salto hacia atras) (default)

Loads/stores, lui/auipc y el resto de RV32I quedan para mas adelante.

Uso:
    python3 sc_run.py                 - compila y corre el bloque de saltos (jump)
    python3 sc_run.py --tb alu        - corre el bloque indicado
    python3 sc_run.py --tb branch --wave - igual, y ademas abre la onda en Surfer
    python3 sc_run.py --view          - abre la onda incluida del bloque (--tb), sin simular
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
    "RegisterFile.sv", "ComparatorUnit.sv",
    "CoreControlUnit_min2.sv", "InstructionMemory_min2.sv", "ProcessorCoreMin2.sv",
]

# block name -> top module
BLOCKS = {
    "alu":    "core_min2_alu_tb",
    "branch": "core_min2_branch_tb",
    "jump":   "core_min2_jump_tb",
}


class CoreMin2Design(Design):
    """core_min2: ALU completa + branches + jumps (sin memoria de datos
    ni lui/auipc todavia)."""

    def __init__(self, topmodule):
        super().__init__()
        self.set_name("core_min2")
        self.set_dataroot("core_min2", HERE)
        with self.active_dataroot("core_min2"):
            with self.active_fileset("rtl"):
                self.set_topmodule(topmodule)
                for f in COMMON_FILES:
                    self.add_file(f)
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
    core_min2 && ...`), para que $readmemh encuentre los .hex por su
    ruta relativa. Sin esto, SiliconCompiler corre el binario desde su
    propio directorio de build y $readmemh truena con 'file not found'."""
    result = subprocess.run([vexe_path], cwd=HERE, capture_output=True, text=True)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    return re.search(r"^FAIL:", result.stdout, re.MULTILINE) is None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tb", choices=sorted(BLOCKS), default="jump", help="bloque a correr (default: jump)")
    parser.add_argument("--wave", action="store_true", help="abrir la onda en Surfer al terminar")
    parser.add_argument("--view", action="store_true",
                        help="abrir la onda incluida del bloque (--tb), sin simular")
    args = parser.parse_args()

    if args.view:
        subprocess.call(["surfer", os.path.join(HERE, f"waveform_{args.tb}.fst")])
        return

    topmodule = BLOCKS[args.tb]

    project = Sim()
    project.set_design(CoreMin2Design(topmodule))
    project.add_fileset("testbench.verilator.v")
    project.add_fileset("rtl")

    flow = Flowgraph(f"core_min2_{args.tb}_sim")
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
