#!/usr/bin/env bash
# Run every working guard in scripts/_qa/ and report a single verdict.
#
#   ./scripts/_qa/run_all_guards.sh
#
# Exit code is 0 only when every guard passes, so CI can gate on it.
#
# ponytail: scripts/_qa/ mixes guards with ASSET GENERATORS (extract_*.py,
# build_*_spriteframes.gd, build_cyberpunk_tileset.gd). Those write PNGs and
# .tres files into the repo at runtime, and some guards recurse forever.
# So the list below is explicit on purpose: running the directory blindly
# is how the old qa_runner.gd hung and polluted the worktree.
#
# This script replaces scripts/_qa/qa_runner.gd, which never worked: it
# referenced three classes that exist nowhere (DamageResolver,
# LocalCppEvaluator, SandboxClient) so it failed to compile, and it called
# SceneTree.quit() with no argument, so it exited 0 no matter what.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

GODOT="${GODOT:-godot}"
# ponytail: 2500 y no 400 porque el guard de batalla espera las fases
# REALES de la pelea (0.8 s) y compila de verdad (~1 s por compile). En
# headless los frames vuelan y 400 frames no cubren ni 2 segundos.
TIMEOUT_FRAMES="${TIMEOUT_FRAMES:-2500}"

# Guards that run as a SceneTree script: godot --headless -s <script>.
SCRIPT_GUARDS=(
  walls_smoke_test
  tile_catalog_guard
  spriteframe_dims_guard
  challenge_registry_guard
  atlas_smoke_test
  atlas_alpha_floor_guard
  project_godot_2d_guard
)

# Guards that run as a mounted scene: godot --headless <scene>.
SCENE_GUARDS=(
  scenes/qa/battle_retry_guard.tscn
  scenes/qa/main_menu_layout_guard.tscn
  scenes/qa/battle_portrait_guard.tscn
  scenes/qa/battle_layout_guard.tscn
  scenes/qa/combat_ui_guard.tscn
  scenes/qa/platformer_guard.tscn
  scenes/qa/code_transition_guard.tscn
  scenes/qa/level_01_guard.tscn
  scenes/qa/challenge_gate_guard.tscn
  scenes/qa/cpp_sandbox_guard.tscn
  scenes/qa/battle_sandbox_guard.tscn
  scenes/qa/curriculum_guard.tscn
  scenes/qa/battle_economy_guard.tscn
  scenes/qa/play_log_guard.tscn
  scenes/qa/level_guard.tscn
  scenes/qa/tool_panel_guard.tscn
)

TOTAL=0
FAILED=0
FAILED_NAMES=()

run_one() {
  local label="$1"
  shift
  TOTAL=$((TOTAL + 1))
  local log
  log="$(mktemp)"
  "$@" >"$log" 2>&1
  local code=$?
  local summary
  summary="$(grep -oE 'PASSED: [0-9]+ \| FAILED: [0-9]+' "$log" | tail -1)"
  if [ "$code" -eq 0 ] && [ -n "$summary" ]; then
    printf '  %-34s OK   %s\n' "$label" "$summary"
  else
    printf '  %-34s FAIL %s\n' "$label" "${summary:-exit=$code}"
    grep -E 'FAIL:|SCRIPT ERROR|Parse Error' "$log" | head -3 | sed 's/^/      /'
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$label")
  fi
  rm -f "$log"
}

echo "=== running guards ==="
for g in "${SCRIPT_GUARDS[@]}"; do
  run_one "$g" "$GODOT" --headless -s "scripts/_qa/$g.gd" --quit-after "$TIMEOUT_FRAMES"
done
for s in "${SCENE_GUARDS[@]}"; do
  run_one "$(basename "$s" .tscn)" "$GODOT" --headless "$s" --quit-after "$TIMEOUT_FRAMES"
done

echo
if [ "$FAILED" -eq 0 ]; then
  echo "ALL GREEN: $TOTAL/$TOTAL guards passed"
  exit 0
fi
echo "FAILED: $FAILED/$TOTAL guards failed -> ${FAILED_NAMES[*]}"
exit 1
