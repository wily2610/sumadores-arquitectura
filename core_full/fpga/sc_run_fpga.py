#!/usr/bin/env python3
"""Sintetiza core_full para el Arty A7-100T (xc7a100tcsg324-1) con
SiliconCompiler, usando el flujo FPGAXilinxFlow (Vivado: elaborate ->
syn_fpga -> place -> route -> bitstream). Requiere Vivado instalado y en
el PATH -- SiliconCompiler no trae un sintetizador Xilinx propio.

El bitstream resultante se puede programar con openFPGALoader:

    openFPGALoader -b arty_a7_100t <bitstream.bit>

o con el target `make core-full-program` del Makefile raiz del repo.

Uso:
    python3 sc_run_fpga.py                    - sintetiza con el programa capstone
    python3 sc_run_fpga.py --program mem.hex  - sintetiza con otro programa .hex
"""
import argparse
import os

from siliconcompiler import Design, FPGA
from siliconcompiler.fpga import FPGADevice
from siliconcompiler.flows.fpgaflow import FPGAXilinxFlow
from siliconcompiler.tools.vivado import syn_fpga as vivado_syn

FPGA_HERE = os.path.dirname(os.path.abspath(__file__))
CORE_HERE = os.path.dirname(FPGA_HERE)

TOPMODULE = "TopArtyA7"
FPGA_PARTNAME = "xc7a100tcsg324-1"

CORE_FILES = [
    "risc_v_32_i_pkg.sv", "ArithmeticLogicUnit.sv", "ImmediateSignExtend.sv",
    "RegisterFile.sv", "ComparatorUnit.sv", "LoadAndStoreUnit.sv",
    "CoreControlUnit_full.sv", "InstructionMemory_full.sv", "DataMemory_full.sv",
    "ProcessorCoreFull.sv",
]


class TopArtyA7Design(Design):
    """core_full envuelto para el Arty A7-100T."""

    def __init__(self):
        super().__init__()
        self.set_name("core_full_fpga")
        self.set_dataroot("core_full", CORE_HERE)
        with self.active_dataroot("core_full"):
            with self.active_fileset("rtl"):
                self.set_topmodule(TOPMODULE)
                for f in CORE_FILES:
                    self.add_file(f)
        self.set_dataroot("core_full_fpga", FPGA_HERE)
        with self.active_dataroot("core_full_fpga"):
            with self.active_fileset("rtl"):
                self.add_file("TopArtyA7.sv")
                self.add_file("arty_a7_100t.xdc")


def _write_hex_copy_prescript(program_file: str) -> str:
    """Genera un prescript de Vivado que copia el .hex del programa al
    directorio de trabajo de la sintesis -- TopArtyA7.sv solo conoce el
    nombre del archivo, y $readmemh (dentro de InstructionMemory_full.sv)
    lo busca por ruta relativa al directorio donde corre Vivado, no al
    directorio donde viven los fuentes."""
    hex_abspath = os.path.join(CORE_HERE, program_file)
    if not os.path.isfile(hex_abspath):
        raise FileNotFoundError(f"No se encontro el programa: {hex_abspath}")
    script_path = os.path.join(FPGA_HERE, "_copy_hex_generated.tcl")
    with open(script_path, "w") as f:
        f.write(f'file copy -force "{hex_abspath}" .\n')
    return script_path


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--program", default="program_rv32i_full.hex",
                        help="programa .hex a cargar en InstructionMemory_full (default: capstone)")
    args = parser.parse_args()

    prescript = _write_hex_copy_prescript(args.program)

    fpga_device = FPGADevice("arty_a7_100t")
    fpga_device.set_partname(FPGA_PARTNAME)

    project = FPGA(TopArtyA7Design())
    project.add_fileset("rtl")
    project.set_fpga(fpga_device)

    project.set_flow(FPGAXilinxFlow(language="systemverilog"))

    synth_task = vivado_syn.SynthesisTask.find_task(project)
    synth_task.set_dataroot("core_full_fpga_gen", FPGA_HERE)
    with synth_task.active_dataroot("core_full_fpga_gen"):
        synth_task.add_prescript(os.path.basename(prescript))

    project.run()
    project.summary()


if __name__ == "__main__":
    main()
