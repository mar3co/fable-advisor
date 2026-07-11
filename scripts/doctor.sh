#!/usr/bin/env bash
# fable-orchestrator doctor — validate every CLI lane before a task needs it.
# Live checks send one trivial prompt per lane (a real, tiny API call).
set -u

PASS=0; WARN=0; FAIL=0
ok()  { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
warn(){ printf '  warn %s\n' "$1"; WARN=$((WARN+1)); }
bad() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

VER=$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$(dirname "$0")/../.claude-plugin/plugin.json" 2>/dev/null | head -1)
echo "fable-orchestrator doctor — mar3co/fable-orchestrator, v${VER:-unknown}"
echo "(independently maintained; originally derived from DannyMac180's fable-advisor)"
echo

T=$(command -v gtimeout || command -v timeout || true)

echo "timeout binary"
if [ -n "$T" ]; then
  ok "found: $T"
else
  warn "none found — doctor's own live checks run uncapped (lanes are unaffected: run-lane.sh ships its own pure-bash watchdog)"
fi

echo "codex lanes (implementer, reviewer: gpt-5.6-sol)"
if ! command -v codex >/dev/null 2>&1; then
  warn "codex CLI not installed — codex lanes degrade: implementation falls back per mode, cold review of grok diffs falls back to an Opus cold pass (install: npm i -g @openai/codex, then: codex login)"
else
  ok "CLI present: $(codex --version 2>/dev/null | head -1)"
  OUT=$(mktemp -t doctor-codex.XXXXXX)
  if printf 'Reply with exactly: LANE-OK' | ${T:+$T 180} codex exec \
       --model gpt-5.6-sol --sandbox workspace-write --skip-git-repo-check \
       --cd "$(pwd)" --output-last-message "$OUT" - >/dev/null 2>&1 \
     && grep -q 'LANE-OK' "$OUT"; then
    ok "auth + gpt-5.6-sol access confirmed"
  else
    bad "live check failed (auth or model access) — try: codex login"
  fi
fi

echo "grok lanes (default implementer, researcher, reviewer: grok-4.5)"
if ! command -v grok >/dev/null 2>&1; then
  warn "grok CLI not installed — grok lanes degrade: implementation falls back per mode, cold review of codex diffs falls back to an Opus cold pass, research is unavailable (install from https://x.ai/cli, then: grok login)"
else
  ok "CLI present: $(grok --version 2>/dev/null | head -1)"
  SPEC=$(mktemp -t doctor-grok.XXXXXX)
  printf 'Reply with exactly: LANE-OK' > "$SPEC"
  if ${T:+$T 180} grok --prompt-file "$SPEC" -m grok-4.5 \
       --output-format plain --cwd "$(pwd)" 2>/dev/null | grep -q 'LANE-OK'; then
    ok "auth + grok-4.5 access confirmed"
  else
    bad "live check failed (auth or model access) — try: grok login"
  fi
fi

echo "claude lanes (fable-advisor, Opus final fallback)"
echo "  note: pinned Claude models are resolved by Claude Code and fall back to the"
echo "  session model SILENTLY if unavailable — verify Fable/Opus access with /model."

printf '\n%d ok, %d warnings, %d failures\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -eq 0 ]
