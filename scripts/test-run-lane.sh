#!/usr/bin/env bash
# test-run-lane.sh — smoke test for run-lane.sh process supervision. No API calls.
# A PATH-shimmed fake `codex` (parent that spawns a child worker) exercises the
# orphan-child bug class: reap and the watchdog must kill the whole process
# group, not just the top PID. Takes ~30 seconds.
set -u
cd "$(dirname "$0")" || exit 1
RL=./run-lane.sh
FAILS=0
pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAILS=$((FAILS + 1)); }

SHIM=$(mktemp -d)
for CLI in codex grok; do
cat > "$SHIM/$CLI" << EOF
#!/usr/bin/env bash
# fake $CLI: records argv, spawns a child worker, then runs as the parent
printf '%s ' "\$@" > "$SHIM/last-args"
sleep "\${FAKE_CHILD:-300}" &
sleep "\${FAKE_PARENT:-300}"
EOF
chmod +x "$SHIM/$CLI"
done
export PATH="$SHIM:$PATH"
SPEC=$(mktemp -t test-spec.XXXXXX)
echo test > "$SPEC"

launch() {  # $1=parent-secs $2=child-secs $3=budget-secs [$4=lane] → sets PID WD LOG
  local out
  out=$(FAKE_PARENT=$1 FAKE_CHILD=$2 "$RL" start "${4:-codex}" "$SPEC" "$3")
  PID=$(awk '/^PID:/{print $2}' <<< "$out")
  WD=$(awk '/^WATCHDOG:/{print $2}' <<< "$out")
  LOG=$(awk '/^LOG:/{print $2}' <<< "$out")
}
group_alive() { pgrep -g "$1" >/dev/null 2>&1; }

echo "test 1: reap kills the whole process group (orphan-child class)"
launch 300 300 600
sleep 1
grep -q 'workspace-write' "$SHIM/last-args" && pass "codex lane invoked with workspace-write sandbox" || fail "codex lane args lack workspace-write"
CHILD=$(pgrep -g "$PID" | grep -v "^$PID$" | head -1)
[ -n "$CHILD" ] && pass "child worker present in group ($CHILD)" || fail "no child worker found in group"
ROUT=$("$RL" reap "$PID" "$WD")
if group_alive "$PID"; then fail "group survived reap (orphans left)"; else pass "parent and child both dead after reap"; fi
grep -q "REAPED: $PID (group dead)" <<< "$ROUT" && pass "reap confirmed group death in its output" || fail "reap output lacks group-death confirmation: '$ROUT'"

echo "test 2: natural exit is detected and the watchdog self-terminates"
launch 2 2 600
R=$("$RL" wait "$PID" 30)
[ "$R" = EXITED ] && pass "wait detected natural exit" || fail "wait printed '$R', expected EXITED"
sleep 12   # watchdog polls every 10s; it must notice the dead lane and exit on its own
if kill -0 "$WD" 2>/dev/null; then fail "watchdog still alive after lane exited (stale-kill hazard)"; else pass "watchdog self-terminated"; fi
"$RL" reap "$PID" "$WD" >/dev/null

echo "test 3: watchdog group-kills at budget and logs it"
launch 300 300 5
sleep 12   # budget 5s rounds up to one 10s poll; kill lands by ~10s
if group_alive "$PID"; then fail "group survived the watchdog budget"; else pass "watchdog killed the whole group at budget"; fi
grep -q "WATCHDOG: killed" "$LOG" && pass "watchdog kill recorded in LOG" || fail "no WATCHDOG line in LOG"
"$RL" reap "$PID" "$WD" >/dev/null

echo "test 4: codex-review runs exec review with instruction prompt, read-only, and reaps"
EMPTY=$(mktemp -t test-empty.XXXXXX)
OUT=$("$RL" start codex-review "$EMPTY" 600 2>&1)
grep -q 'STATUS: unavailable' <<< "$OUT" && pass "empty spec file fails loudly" || fail "lane launched with an empty spec: '$OUT'"
SPECDIR=$(mktemp -d)
OUT=$("$RL" start codex-review "$SPECDIR" 600 2>&1)
grep -q 'STATUS: unavailable' <<< "$OUT" && pass "directory as spec fails loudly" || fail "lane launched with a directory spec: '$OUT'"
launch 2 2 600 codex-review
sleep 1
grep -q 'exec review' "$SHIM/last-args" && pass "codex-review invokes the exec review subcommand" || fail "codex-review args lack 'exec review'"
grep -qE -- '- $' "$SHIM/last-args" && pass "codex-review reads instructions from stdin via '-'" || fail "codex-review args lack the trailing '-' prompt: $(cat "$SHIM/last-args")"
grep -q 'sandbox_mode="read-only"' "$SHIM/last-args" && pass "codex-review pins sandbox_mode read-only" || fail "codex-review args lack read-only sandbox_mode"
grep -q -- '--json' "$SHIM/last-args" && pass "codex-review emits JSONL events" || fail "codex-review args lack --json"
R=$("$RL" wait "$PID" 30)
[ "$R" = EXITED ] && pass "codex-review lane ran and exited" || fail "codex-review wait printed '$R'"
"$RL" reap "$PID" "$WD" >/dev/null
group_alive "$PID" && fail "codex-review group survived reap" || pass "codex-review group reaped"

echo "test 5: grok lanes carry enforced guardrails per lane type"
launch 2 2 600 grok
sleep 1
grep -q 'Bash(sudo\*)' "$SHIM/last-args" && grep -q 'Bash(git push\*)' "$SHIM/last-args" \
  && pass "grok implement lane carries deny rules" || fail "grok implement lane missing deny rules: $(cat "$SHIM/last-args")"
"$RL" reap "$PID" "$WD" >/dev/null
launch 2 2 600 grok-review
sleep 1
grep -q -- '--tools read_file,grep,list_dir' "$SHIM/last-args" && pass "grok-review restricted to read-only tool allowlist" || fail "grok-review args lack the tool allowlist"
grep -q 'acceptEdits' "$SHIM/last-args" && fail "grok-review args contain acceptEdits" || pass "grok-review invoked without acceptEdits"
"$RL" reap "$PID" "$WD" >/dev/null
launch 2 2 600 grok-research
sleep 1
grep -q 'acceptEdits' "$SHIM/last-args" && fail "grok-research args contain acceptEdits" || pass "grok-research invoked without acceptEdits"
grep -q -- '--tools web_search,open_page,open_page_with_find,x_user_search,x_semantic_search,x_keyword_search,x_thread_fetch,read_file,list_dir,grep' "$SHIM/last-args" \
  && grep -q -- '--disallowed-tools use_tool,search_tool' "$SHIM/last-args" \
  && pass "grok-research restricted to web+read allowlist, MCP bridge disallowed" || fail "grok-research restriction args wrong: $(cat "$SHIM/last-args")"
R=$("$RL" wait "$PID" 30)
[ "$R" = EXITED ] && pass "grok-research lane ran and exited" || fail "grok-research wait printed '$R'"
"$RL" reap "$PID" "$WD" >/dev/null
group_alive "$PID" && fail "grok-research group survived reap" || pass "grok-research group reaped"

echo "test 6: LANE_CODEX_FAST=1 gates the fast-tier flags to codex lanes only"
export LANE_CODEX_FAST=1
launch 2 2 600
sleep 1
grep -q 'service_tier=fast' "$SHIM/last-args" && grep -q 'features.fast_mode=true' "$SHIM/last-args" \
  && pass "codex lane carries both fast-tier overrides" || fail "codex lane missing fast-tier overrides: $(cat "$SHIM/last-args")"
"$RL" reap "$PID" "$WD" >/dev/null
launch 2 2 600 grok
sleep 1
grep -q 'fast' "$SHIM/last-args" && fail "grok lane leaked fast-tier flags" || pass "grok lane unaffected by LANE_CODEX_FAST"
"$RL" reap "$PID" "$WD" >/dev/null
unset LANE_CODEX_FAST
launch 2 2 600
sleep 1
grep -q 'service_tier=fast' "$SHIM/last-args" && fail "fast-tier flags present without LANE_CODEX_FAST" || pass "codex lane omits fast-tier flags when unset"
"$RL" reap "$PID" "$WD" >/dev/null

printf '\n%s\n' "$([ "$FAILS" -eq 0 ] && echo "ALL PASS" || echo "$FAILS FAILURE(S)")"
[ "$FAILS" -eq 0 ]
