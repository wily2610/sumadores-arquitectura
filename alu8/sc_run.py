#!/usr/bin/env python3
"""Compilen y corran el testbench de esta carpeta con SiliconCompiler,
usando Verilator como motor de simulacion y generando una onda para
verla con Surfer.

alu8.v y alu8_tb.v son Verilog puro (sin SystemVerilog), por lo que
este script valida lo mismo que exige Silicluster v3.

Uso:
    python3 sc_run.py            - compila y corre alu8_tb, reporta PASS/FAIL
    python3 sc_run.py --wave     - igual, y ademas abre la onda en Surfer
    python3 sc_run.py --view     - abre el waveform.vcd incluido, sin simular
"""
import argparse
import os
import subprocess

from siliconcompiler import Design, Sim, Flowgraph
from siliconcompiler.tools.verilator import compile as verilator_compile
from siliconcompiler.tools.verilator.compile import CompileTask
from siliconcompiler.tools.execute.exec_input import ExecInputTask

HERE = os.path.dirname(os.path.abspath(__file__))

# En macOS con Homebrew, --trace-fst de Verilator necesita liblz4, que no
# vive en una ruta de include/link por defecto. En Linux (apt/dnf) no hace
# falta nada de esto.
LZ4_PREFIXES = ("/opt/homebrew/opt/lz4", "/usr/local/opt/lz4")

VERILATOR_WARNINGS_OFF = [
    "-Wno-WIDTHEXPAND", "-Wno-WIDTHTRUNC", "-Wno-CASEINCOMPLETE",
    "-Wno-UNOPTFLAT", "-Wno-TIMESCALEMOD", "-Wno-IEEEMAYDEPRECATE", "-Wno-LATCH",
]

TOPMODULE = "alu8_tb"


class Alu8Design(Design):
    """ALU de 8 bits (alu8.v) + su testbench (alu8_tb.v), en Verilog puro."""

    def __init__(self):
        super().__init__()
        self.set_name("alu8")
        self.set_dataroot("alu8", HERE)
        with self.active_dataroot("alu8"):
            with self.active_fileset("rtl"):
                self.set_topmodule("alu8")
                self.add_file("alu8.v")
            with self.active_fileset("testbench.verilator.v"):
                self.set_topmodule(TOPMODULE)
                self.add_file("alu8_tb.v")


def _configure_verilator_task(project):
    task = CompileTask.find_task(project)
    task.set_verilator_main(True)
    task.add_commandline_option(["--trace-fst", *VERILATOR_WARNINGS_OFF])
    for lz4_prefix in LZ4_PREFIXES:
        if os.path.isdir(lz4_prefix):
            task.add_verilator_cincludes(f"{lz4_prefix}/include")
            task.add_verilator_ldflags([f"-L{lz4_prefix}/lib", "-llz4"])
            break


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wave", action="store_true", help="abrir la onda en Surfer al terminar")
    parser.add_argument("--view", action="store_true",
                        help="abrir el waveform.vcd incluido, sin simular")
    args = parser.parse_args()

    if args.view:
        subprocess.call(["surfer", os.path.join(HERE, "waveform.vcd")])
        return

    project = Sim()
    project.set_design(Alu8Design())
    project.add_fileset("testbench.verilator.v")
    project.add_fileset("rtl")

    flow = Flowgraph("alu8_sim")
    flow.node("compile", verilator_compile.CompileTask())
    flow.node("simulate", ExecInputTask())
    flow.edge("compile", "simulate")
    project.set_flow(flow)

    _configure_verilator_task(project)

    project.run()
    project.summary()

    if args.wave:
        vcd = project.find_result(step="simulate", index="0", directory=".",
                                  filename=f"{TOPMODULE}.vcd")
        if vcd:
            project.show(vcd)
        else:
            print(f"No se encontro la onda {TOPMODULE}.vcd")


if __name__ == "__main__":
    main()
