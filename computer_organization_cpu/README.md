# Computer Organization CPU

This directory contains a cleaned-up Verilog implementation for the computer
organization part of the summer-term hardware lab.

The CPU is a five-stage RV32I pipeline intended for Vivado behavioral
simulation. It is derived from the ideas in `小学期/计组/CPU_sim` and
`小学期/计组/risc-v-cpu-pipeline`, but uses a simpler source tree and a
behavioral instruction memory so the testbench can run without regenerating a
Vivado memory IP.

## Layout

- `computer_organization_cpu.xpr`: Vivado project file; open this directly.
- `src/`: CPU RTL modules.
- `sim/`: self-checking testbench and instruction memory image.
- `docs/implementation.md`: design and implementation notes.

## Vivado Simulation

Open this file directly in Vivado:

```text
D:/comp-org-asm-hardware/computer_organization_cpu/computer_organization_cpu.xpr
```

Then run:

```text
Flow Navigator -> Simulation -> Run Simulation -> Run Behavioral Simulation
```

The simulation top is `tb_cpu`. The design top is `cpu_core`.

The testbench prints `CPU TEST PASSED` when the pipeline executes the included
program correctly.
