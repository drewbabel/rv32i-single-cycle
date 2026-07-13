#!/usr/bin/env bash
# Build and run the riscv-formal suite against the core
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CORE=rv32i_single
RVF="${RISCV_FORMAL_DIR:-$HOME/Documents/code/riscv-formal}"

if [ ! -d "$RVF" ]; then
  git clone https://github.com/YosysHQ/riscv-formal.git "$RVF"
fi

DST="$RVF/cores/$CORE"
mkdir -p "$DST"
cp "$HERE/wrapper.sv" "$DST/wrapper.sv"
cp "$HERE/checks.cfg" "$DST/checks.cfg"

RTL=(
  alu_pkg alu extend pc regfile imem dmem
  alu_decoder control_decoder control_unit datapath riscv_single
)
SRC=()
for m in "${RTL[@]}"; do SRC+=("$ROOT/rtl/$m.sv"); done
sv2v -D RISCV_FORMAL "${SRC[@]}" > "$DST/$CORE.v"

cd "$DST"
python3 "$RVF/checks/genchecks.py"
make -C checks
