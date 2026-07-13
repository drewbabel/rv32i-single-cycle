#!/usr/bin/env python3
"""Lockstep co-simulation of the RV32I core against Spike

Run with
    python3 tests/cosim.py <prog>

Runs tests/<prog>.s on the core and on Spike, compares architectural
state after every retired instruction, first mismatch is a core bug.
The core links at 0x0 and Spike at 0x80000000, so PCs and absolute-PC
results (jal jalr auipc) are offset-corrected and data-memory writes
are masked to the word index
"""

import os
import re
import subprocess
import sys

BASE = 0x8000_0000
DEPTH = 64
MASK32 = 0xFFFF_FFFF
ABS_PC_OPS = {0x17, 0x6F, 0x67}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RTL = [os.path.join(ROOT, "rtl", "alu_pkg.sv")] + [
    os.path.join(ROOT, "rtl", f)
    for f in sorted(os.listdir(os.path.join(ROOT, "rtl")))
    if f.endswith(".sv") and f != "alu_pkg.sv"
]

RVGCC = "riscv64-elf-gcc"
GCC_COMMON = ["-march=rv32i", "-mabi=ilp32", "-nostdlib", "-nostartfiles"]


def sh(cmd):
    subprocess.run(cmd, check=True, cwd=ROOT)


def build(prog):
    src = os.path.join("tests", f"{prog}.s")
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    # DUT image at 0x0 -> hex for readmemh
    dut_elf = os.path.join("build", f"{prog}.elf")
    dut_hex = os.path.join("tests", f"{prog}.hex")
    sh([RVGCC, *GCC_COMMON, "-T", "tests/link.ld", "-o", dut_elf, src])
    sh(["riscv64-elf-objcopy", "-O", "verilog", "--verilog-data-width=4", dut_elf, dut_hex])
    # Spike image at 0x80000000
    spike_elf = os.path.join("build", f"{prog}_spike.elf")
    sh([RVGCC, *GCC_COMMON, "-T", "tests/link_spike.ld", "-o", spike_elf, src])
    return dut_hex, spike_elf


def run_dut(dut_hex):
    sim = os.path.join("build", "cosim_sim")
    sh(["iverilog", "-g2012", "-s", "cosim", "-o", sim, *RTL, os.path.join("tb", "cosim.sv")])
    out = subprocess.run(["vvp", sim, f"+hex={dut_hex}", "+n=2000"],
                         cwd=ROOT, capture_output=True, text=True).stdout
    trace = []
    for line in out.splitlines():
        m = re.match(r"COMMIT ([0-9a-f]+) (\d+) ([0-9a-f]+) (\d+) ([0-9a-f]+) ([0-9a-f]+)", line)
        if not m:
            continue
        pc, rd, val, mw, maddr, mval = m.groups()
        rd_i = int(rd)
        val_i = (int(val, 16) & MASK32) if rd_i else 0
        st_word = (int(maddr, 16) >> 2) & (DEPTH - 1) if mw == "1" else None
        st_val = int(mval, 16) & MASK32 if mw == "1" else None
        trace.append((int(pc, 16), rd_i, val_i, st_word, st_val))
    return trace


# spike commit line, priv then pc then instr then tail
SPIKE_RE = re.compile(r"core\s+\d+:\s+\d+\s+0x([0-9a-f]+)\s+\(0x([0-9a-f]+)\)(.*)")


def run_spike(spike_elf, n):
    proc = subprocess.Popen(
        ["spike", "--isa=rv32i", f"--pc={hex(BASE)}", "-l", "--log-commits", spike_elf],
        cwd=ROOT, stderr=subprocess.PIPE, text=True, bufsize=1)
    trace = []
    for line in proc.stderr:
        m = SPIKE_RE.match(line)
        if not m:
            continue
        pc_raw, instr_hex, tail = m.groups()
        opcode = int(instr_hex, 16) & 0x7F
        rd, val = 0, 0
        rm = re.search(r"(?:^|\s)x(\d+)\s+0x([0-9a-f]+)", tail)
        if rm:
            rd = int(rm.group(1))
            val = int(rm.group(2), 16) & MASK32
            if opcode in ABS_PC_OPS and rd != 0:
                val = (val - BASE) & MASK32
        st_word, st_val = None, None
        sm = re.search(r"mem\s+0x([0-9a-f]+)\s+0x([0-9a-f]+)", tail)
        if sm:
            st_word = (int(sm.group(1), 16) >> 2) & (DEPTH - 1)
            st_val = int(sm.group(2), 16) & MASK32
        pc = (int(pc_raw, 16) - BASE) & MASK32
        trace.append((pc, rd if rd != 0 else 0, val, st_word, st_val))
        if len(trace) >= n:
            break
    proc.kill()
    return trace


def fmt(rec):
    pc, rd, val, sw, sv = rec
    parts = [f"pc={pc:08x}", f"x{rd}={val:08x}" if rd else "x0"]
    if sw is not None:
        parts.append(f"mem[{sw}]={sv:08x}")
    return "  ".join(parts)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: python3 tests/cosim.py <prog>")
    prog = sys.argv[1]
    dut_hex, spike_elf = build(prog)
    dut = run_dut(dut_hex)
    spike = run_spike(spike_elf, len(dut))

    n = min(len(dut), len(spike))
    for i in range(n):
        if dut[i] != spike[i]:
            print(f"DIVERGENCE at instruction {i}:")
            print(f"  DUT   : {fmt(dut[i])}")
            print(f"  Spike : {fmt(spike[i])}")
            sys.exit(1)
    if len(dut) != len(spike):
        print(f"LENGTH MISMATCH: DUT retired {len(dut)}, Spike {len(spike)}")
        sys.exit(1)
    print(f"LOCKSTEP PASS: {n} instructions match Spike ({prog})")


if __name__ == "__main__":
    main()
