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

# codex fast mode setting: project CLAUDE.md wins over user scope, absent means off
FAST_MODE=off
for f in "$HOME/.claude/CLAUDE.md" "./CLAUDE.md"; do
  V=$(sed -n 's/.*fable-orchestrator: codex fast mode[[:space:]]*=[[:space:]]*\([A-Za-z]*\).*/\1/p' "$f" 2>/dev/null | head -1)
  [ -n "$V" ] && FAST_MODE=$(printf '%s' "$V" | tr '[:upper:]' '[:lower:]')
done

echo "codex lanes (implementer, reviewer: gpt-5.6-sol; fast mode: $FAST_MODE)"
if ! command -v codex >/dev/null 2>&1; then
  warn "codex CLI not installed — codex lanes degrade: implementation falls back per mode, cold review of grok diffs falls back to an Opus cold pass (install: npm i -g @openai/codex, then: codex login)"
else
  ok "CLI present: $(codex --version 2>/dev/null | head -1)"
  OUT=$(mktemp -t doctor-codex.XXXXXX)
  codex_live() {  # $1 = "fast" to run with the fast-tier flags
    FF=""
    [ "${1:-}" = fast ] && FF="-c service_tier=fast -c features.fast_mode=true"
    : > "$OUT"
    printf 'Reply with exactly: LANE-OK' | ${T:+$T 180} codex exec \
      --model gpt-5.6-sol $FF \
      --sandbox workspace-write --skip-git-repo-check \
      --cd "$(pwd)" --output-last-message "$OUT" - >/dev/null 2>&1 \
      && grep -q 'LANE-OK' "$OUT"
  }
  if [ "$FAST_MODE" = "on" ]; then
    if codex_live fast; then
      ok "auth + gpt-5.6-sol access confirmed (fast tier)"
    elif codex_live; then
      warn "fast tier failed but standard tier works — lanes will degrade to standard per the retry rule (fast mode needs ChatGPT sign-in, not an API key, and model support; try: codex login)"
    else
      bad "live check failed at both tiers (auth or model access) — try: codex login"
    fi
  else
    if codex_live; then
      ok "auth + gpt-5.6-sol access confirmed"
    else
      bad "live check failed (auth or model access) — try: codex login"
    fi
  fi
fi

echo "grok lanes (default implementer, researcher, reviewer: grok-4.5)"
if ! command -v grok >/dev/null 2>&1; then
  warn "grok CLI not installed — grok lanes degrade: implementation falls back per mode, cold review of codex diffs falls back to an Opus cold pass, research is unavailable (install from https://x.ai/cli, then: grok login)"
else
  ok "CLI present: $(grok --version 2>/dev/null | head -1)"
  SPEC=$(mktemp -t doctor-grok.XXXXXX)
  printf 'Reply with exactly: LANE-OK' > "$SPEC"
  grok_live() { ${T:+$T 180} grok --prompt-file "$SPEC" -m grok-4.5 \
                  --output-format plain --cwd "$(pwd)" 2>/dev/null | grep -q 'LANE-OK'; }
  GROK_LIVE_OK=0
  if grok_live; then
    ok "auth + grok-4.5 access confirmed"; GROK_LIVE_OK=1
  elif sleep 5 && grok_live; then
    ok "auth + grok-4.5 access confirmed (first attempt failed — likely transient, e.g. a token refresh)"; GROK_LIVE_OK=1
  else
    bad "live check failed twice (auth or model access) — try: grok login"
  fi
  if [ "$GROK_LIVE_OK" = 1 ]; then
    # Permission canary. A trivial LANE-OK prompt only exercises solo simple
    # commands; grok 0.2.99's headless permission resolver auto-cancels shell
    # commands it cannot statically classify (loops, $VAR expansion, export
    # prefixes), which kills the run at its first real verification command.
    # Force the trigger shape under the implement lane's exact production
    # flags, so doctor fails when real tasks would. The pass condition is a
    # NONCE the command reads from a file the model never sees the contents
    # of — a model that replies without executing cannot produce it, so a
    # pass is proof of headless execution, not a self-reported claim.
    NONCE="cn-$$-$RANDOM$RANDOM"
    NFILE=$(mktemp -t doctor-grok-nonce.XXXXXX)
    printf '%s\n' "$NONCE" > "$NFILE"
    CSPEC=$(mktemp -t doctor-grok-canary.XXXXXX)
    cat > "$CSPEC" <<CANARY_EOF
Run exactly this command in the terminal, as a single tool call, without modifying it:

for f in $NFILE; do cat "\$f"; done

Then reply with the exact line the command printed. If the command was blocked, cancelled, or failed, reply BLOCKED plus the error text.
CANARY_EOF
    grok_canary() { ${T:+$T 180} grok --prompt-file "$CSPEC" -m grok-4.5 \
                      --output-format plain --cwd "$(pwd)" \
                      --permission-mode bypassPermissions \
                      --deny 'Bash(sudo*)' --deny 'Bash(git push*)' \
                      --deny 'Bash(curl*)' --deny 'Bash(wget*)' 2>/dev/null | grep -q "$NONCE"; }
    if grok_canary || grok_canary; then    # one retry for model non-compliance; a pass needs the nonce, which only real execution can produce
      ok "implement-lane permission canary passed (loop/\$VAR command ran headlessly, nonce proven)"
    else
      bad "permission canary failed twice — the grok CLI likely cancelled the command (headless permission bug class, known on 0.2.99); real implementation tasks will die at their first verification command. Evidence: grep the newest events.jsonl under ~/.grok/sessions/ for permission_cancelled"
    fi
  fi
fi

echo "claude lanes (fable-advisor, Opus final fallback)"
echo "  note: pinned Claude models are resolved by Claude Code and fall back to the"
echo "  session model SILENTLY if unavailable — verify Fable/Opus access with /model."

printf '\n%d ok, %d warnings, %d failures\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -eq 0 ]
