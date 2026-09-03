# Implementation Notes

## Source Basis

The old `小学期/计组/CPU_sim` project implements a direct-wired five-stage
pipeline with Vivado ROM IP, byte-addressed RAM, forwarding, load-use stalls,
and branch flushing. The `risc-v-cpu-pipeline` directory reorganizes the same
idea into stage-level modules and adds a board-facing bus plus LED, switch, and
seven-segment interfaces.

This refactor keeps the CPU-focused part clean and simulation-friendly. It does
not depend on generated Vivado IP, so the design can be compiled from source and
tested with a small memory file.

## Architecture

The CPU is a five-stage RV32I pipeline:

- IF fetches from `instr_mem` using a byte-addressed PC.
- ID decodes the instruction, reads the register file, and creates immediates.
- EX selects forwarded operands, runs the ALU, and resolves branches/jumps.
- MEM performs byte-addressed loads and stores in `data_mem`.
- WB selects ALU, memory, or PC+4 data and writes the register file.

Branches and jumps are predicted as not taken. A taken branch or jump is
resolved in EX, then the wrong-path IF/ID and ID/EX contents are flushed.

## Supported Instructions

The control path covers the common RV32I integer subset:

- R type: `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`
- I type: `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`
- Memory: `lb`, `lh`, `lw`, `lbu`, `lhu`, `sb`, `sh`, `sw`
- Control: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `jal`, `jalr`
- Upper immediates: `lui`, `auipc`

The testbench treats `ecall` as a halt marker.

## Hazard Handling

The forwarding unit selects EX/MEM or MEM/WB results for both EX operands. It
does not forward load data from EX/MEM because the value is not ready there.
The hazard unit detects a load-use dependency between ID/EX and IF/ID, freezes
PC and IF/ID for one cycle, and injects a bubble into ID/EX.

The register file writes on the falling edge. That mirrors the timing pattern
used in the old organized pipeline and avoids ambiguity when WB writes a
register needed by an instruction currently decoding.

## Simulation

`sim/program.mem` contains a small hand-encoded program that checks:

- ALU arithmetic and immediate instructions
- EX/MEM and MEM/WB forwarding
- load-use stall insertion
- store then load
- taken and not-taken branches
- `lui`, `auipc`, `jal`, `jalr`
- byte and halfword loads/stores with sign and zero extension
- signed and unsigned set-less-than behavior

`sim/tb_cpu.v` observes final register and memory values and reports pass/fail.
