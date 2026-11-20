#!/usr/bin/env bash
# Runs every tower through the harness in parallel. Usage (repo root): bash godot/tests/_review/run_all.sh <out_dir>
# GODOT env var overrides the binary (default: godot on PATH).
set -u
OUT=${1:-/tmp/rg_sim}; GODOT=${GODOT:-godot}; mkdir -p "$OUT"
for t in arcane plasma tesla laser mortar disc anvil frost beacon; do
  ( "$GODOT" --headless --path godot res://tests/_review/path_sim.tscn -- $t combos 2>&1 | grep -E "^RES|SCRIPT ERROR" > "$OUT/sim_$t.csv"
    "$GODOT" --headless --path godot res://tests/_review/path_sim.tscn -- $t singles 2>&1 | grep -E "^RES|SCRIPT ERROR" > "$OUT/simS_$t.csv" ) &
done
wait
grep -l "SCRIPT ERROR" "$OUT"/*.csv && echo "!! script errors above" || echo "done: $OUT"
