# Arquitectura Computacional — RTL y testbenches

## Contenido

Cada tema vive en su propia carpeta, con su RTL y su testbench juntos:

- **`adders/`**: half adder, full adder y un ripple-carry adder de 4 bits
  (`half_adder.sv`, `full_adder.sv`, `ripple_carry_adder.sv`, `adders_tb.sv`).
- **`alu8/`**: ALU de 8 bits (`alu8.v`, `alu8_tb.v`) en Verilog puro (sin
  SystemVerilog), pensada para el presupuesto de pines de un proyecto
  digital de Silicluster v3 (14 entradas / 14 salidas + clk + rst).
- **`core_min/`**: primer paso hacia un núcleo RV32I completo -- un
  datapath monociclo mínimo que ejecuta exactamente `add`, `sub` y `addi`:
  el ALU real (`ArithmeticLogicUnit.sv`), el decodificador
  (`CoreControlUnit_min.sv`), el generador de inmediato
  (`ImmediateSignExtend.sv`), el banco de registros (`RegisterFile.sv`),
  memoria de instrucciones (`InstructionMemory_min.sv`) y el núcleo
  (`ProcessorCoreMin.sv`), corriendo `program_add_sub_addi.hex`.
- **`core_min2/`**: segundo paso -- extiende `core_min/` hasta branches y
  saltos. Agrega la ALU completa (los 10 R-type y 9 I-type, ya decodificados
  por `CoreControlUnit_min2.sv`), `ComparatorUnit.sv` (branches y,
  reutilizado, `slt`/`sltu`/`slti`/`sltiu`) y el mux de PC que toma
  `jal`/`jalr`/branch tomado. Fuera de alcance todavia, decodificados como
  no-op segura: `lui`/`auipc`, loads/stores (no hay memoria de datos en
  este bloque) y `fence`/`ecall`/`ebreak`. Tres testbenches, uno por bloque
  pedagogico, cada uno con su propio programa `.hex`
  (`core_min2_alu_tb.sv`, `core_min2_branch_tb.sv`, `core_min2_jump_tb.sv`).
- **`core_full/`**: núcleo RV32I base **completo** -- las 34 instrucciones
  de `core_min2/` mas `lui`/`auipc` (`CoreControlUnit_full.sv`), memoria de
  datos byte-direccionable (`DataMemory_full.sv`, `LoadAndStoreUnit.sv`:
  `lb/lh/lw/lbu/lhu/sb/sh/sw`) y `fence`/`ecall`/`ebreak` decodificadas
  como no-op. Seis testbenches -- `alu`, `branch`, `jump`, `upper`, `mem`
  y `full`, que suma un arreglo de enteros en memoria.

## Instalación

```bash
pip install siliconcompiler
```

### Verilator + Surfer

**Linux (Ubuntu/Debian):**

```bash
sc-install -group digital-simulation
```

**macOS:**

```bash
brew install verilator
```

Surfer: <https://surfer-project.org>

**Windows:**

Instalar WSL: <https://learn.microsoft.com/windows/wsl/install>

Dentro de WSL (Ubuntu), seguir las instrucciones de Linux de arriba
(`pip install siliconcompiler` + `sc-install -group digital-simulation`).

Surfer (nativo, sin WSL): <https://gitlab.com/api/v4/projects/42073614/jobs/artifacts/main/raw/surfer_win.zip?job=windows_build>

Si ya tienen Surfer instalado pero no Verilator/siliconcompiler (o no
quieren instalar nada todavia), `make view-alu` (sumadores) y `make view-alu8`
(ALU) abren las ondas incluidas en el repo sin necesidad de simular ni
de WSL.

Verificar instalación (dentro de WSL):

```bash
verilator --version
surfer --version
```

## Ejecutar

### Sumadores (`adders/`)

```bash
python3 adders/sc_run.py
python3 adders/sc_run.py --wave
python3 adders/sc_run.py --view
```

Alternativa con Verilator directo:

```bash
make adders
make wave-adders
make view
make clean
```

### ALU de 8 bits (`alu8/`)

```bash
python3 alu8/sc_run.py
python3 alu8/sc_run.py --wave
python3 alu8/sc_run.py --view
```

Alternativa con Verilator directo:

```bash
make alu8
make wave-alu8
make view-alu8
make clean
```

`make alu8` (o `sc_run.py`) compila y corre `alu8_tb`, que imprime
`PASS`/`FAIL` por cada operación verificada.

### Núcleo RV32I mínimo (`core_min/`)

```bash
python3 core_min/sc_run.py
python3 core_min/sc_run.py --wave
python3 core_min/sc_run.py --view
```

Alternativa con Verilator directo:

```bash
make core-min
make wave-core-min
make view-core-min
make clean
```

### Núcleo RV32I hasta branches y saltos (`core_min2/`)

```bash
python3 core_min2/sc_run.py                 # jal/jalr (default)
python3 core_min2/sc_run.py --tb alu        # ALU completa
python3 core_min2/sc_run.py --tb branch     # los 6 branches
python3 core_min2/sc_run.py --tb jump       # jal/jalr
python3 core_min2/sc_run.py --wave          # cualquiera + Surfer
python3 core_min2/sc_run.py --tb branch --view   # onda incluida de branch, sin simular
python3 core_min2/sc_run.py --tb jump --view     # onda incluida de jump, sin simular
```

Alternativa con Verilator directo:

```bash
make core-min2-all   # los 3 bloques en secuencia
make core-min2-alu
make core-min2-branch
make core-min2-jump
make wave-core-min2-alu
make wave-core-min2-branch
make wave-core-min2-jump
make view-core-min2-branch
make view-core-min2-jump
make clean
```

`make core-min` compila y corre `core_min_tb`, que ejecuta
`program_add_sub_addi.hex` sobre `ProcessorCoreMin` y verifica el banco de
registros al final (`PASS`/`FAIL` por registro).

### Núcleo RV32I base completo (`core_full/`)

```bash
python3 core_full/sc_run.py                 # completo (default)
python3 core_full/sc_run.py --tb alu        # ALU completa
python3 core_full/sc_run.py --tb branch     # los 6 branches
python3 core_full/sc_run.py --tb jump       # jal/jalr
python3 core_full/sc_run.py --tb upper      # lui/auipc
python3 core_full/sc_run.py --tb mem        # loads/stores
python3 core_full/sc_run.py --wave          # cualquiera + Surfer
python3 core_full/sc_run.py --view          # onda incluida, sin simular
```

Alternativa con Verilator directo:

```bash
make core-full-all      # los 6 bloques, en secuencia
make core-full-alu
make core-full-branch
make core-full-jump
make core-full-upper
make core-full-mem
make core-full           # suma de un arreglo de enteros en memoria
make wave-core-full-alu  # (y el resto de wave-core-full-<bloque>)
make clean
```
