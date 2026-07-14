# riscv-single-cycle

[![CI](https://github.com/drewbabel/riscv-single-cycle/actions/workflows/ci.yml/badge.svg)](https://github.com/drewbabel/riscv-single-cycle/actions/workflows/ci.yml)

A configurable single-cycle RV32I processor written in SystemVerilog.

The core executes the RV32I base integer instruction set at one instruction per clock. The program counter addresses instruction memory, the `control_unit` decodes the fetched word combinationally, the register file supplies operands, the `alu` computes, and the ALU result, a loaded word, or the return address writes back, all within a single cycle. Because decode is combinational, the only sequential state is the `pc` register, the register file, and data memory.

Data memory is organized as 32-bit words and supports byte, halfword, and word accesses through per-byte write strobes and a load-extend stage. `control_decoder` maps each opcode to the datapath control lines, `alu_decoder` derives the ALU operation from `funct3` and `funct7`, and `extend` builds the I, S, B, U, and J immediates. The `datapath` wires the blocks together and holds the ALU-operand, write-back, and next-PC multiplexers that the control lines steer. Instruction memory is word-addressed and loads its image from a hex file.

The design, testbenches, formal proofs, and co-simulation harness were written from scratch. A riscv-formal proof verifies the assembled core against the RISC-V specification, and Spike lockstep co-simulation confirms every instruction matches a reference simulator across hand-written and randomized programs.

![Single-cycle datapath block diagram](docs/datapath_block.svg)

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `XLEN` | `32` | Data and register width |
| `DEPTH` | `64` | Instruction and data memory depth in words |

## Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst_n` | in | 1 | Synchronous active-low reset |
| `pc` | out | `XLEN` | Program counter of the fetched instruction |
| `alu_result` | out | `XLEN` | ALU output, also the data memory address |
| `write_data` | out | `XLEN` | Store data driven to data memory |
| `mem_write` | out | 1 | Data memory write strobe |

## Instructions

| Format | Instructions |
|--------|--------------|
| Register (`OP`) | `add` `sub` `sll` `slt` `sltu` `xor` `srl` `sra` `or` `and` |
| Immediate (`OP-IMM`) | `addi` `slti` `sltiu` `xori` `ori` `andi` `slli` `srli` `srai` |
| Load (`LOAD`) | `lb` `lbu` `lh` `lhu` `lw` |
| Store (`STORE`) | `sb` `sh` `sw` |
| Branch (`BRANCH`) | `beq` `bne` `blt` `bge` `bltu` `bgeu` |
| Jump | `jal` `jalr` |
| Upper immediate | `lui` `auipc` |

Loads and stores support byte, halfword, and word widths. The `FENCE`, `ECALL`, `EBREAK`, and CSR instructions are not implemented, and misaligned accesses are not yet trapped.

## Verification

The riscv-formal proof wraps `riscv_single` in the RISC-V Formal Interface and checks every retired instruction against the RISC-V specification. The core does not yet implement traps, so the proof assumes aligned instruction fetches and data accesses. The machine-mode trap unit will add the misaligned cases. Run the proof with `bash formal/rvfi/run.sh`.

Spike lockstep co-simulation runs the core against Spike and compares the register and memory write of every retired instruction, across hand-written programs and a randomized generator that exercises byte, halfword, and word accesses.

Every module also has a self-checking testbench built on an independent reference model, and the `alu` carries an exhaustive SymbiYosys proof:
- `result` matches an independent reference model for every operation
- `zero`, `lt`, and `ltu` match the reference for every operand pair

## Results

![Arithmetic program waveform](docs/program_waveform.svg)

![Branch loop waveform](docs/loop_waveform.svg)

## Building and running

Every module builds from the top-level Makefile.

```
make MOD=alu                   # run a module's testbench
make wave MOD=alu              # run the testbench and open the waveform in Surfer
make formal MOD=alu            # run the module's SymbiYosys proof
bash formal/rvfi/run.sh        # run the full riscv-formal proof of the core
make hex PROG=program          # assemble tests/program.s to a hex image
make cosim PROG=cosim1         # lockstep-compare a program against Spike
./synth_stats.sh riscv_single  # report a module's synthesis cost
```

## Synthesis

Synthesized for the Digilent Basys 3 (Xilinx Artix-7). sv2v first converts the SystemVerilog to Verilog-2005, since Yosys cannot parse the package-scoped port types.

| Module | LUTs | Flip-flops | Carry cells |
|--------|------|------------|-------------|
| `pc` | 0 | 32 | 0 |
| `alu_decoder` | 5 | 0 | 0 |
| `control_decoder` | 15 | 0 | 0 |
| `control_unit` | 21 | 0 | 0 |
| `extend` | 31 | 0 | 0 |
| `alu` | 492 | 0 | 22 |
| `regfile` | 922 | 992 | 0 |
| `riscv_single` | 1969 | 1045 | 38 |

### Tool versions

Icarus Verilog 13.0, Yosys 0.66, SymbiYosys 0.66 with Yices 2, sv2v 0.0.13, the RISC-V GNU toolchain (`riscv64-elf-gcc` 16.1.0), Spike 1.1.1, Python 3.11, and Surfer.
