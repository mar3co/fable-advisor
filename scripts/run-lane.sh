#!/usr/bin/env bash
# run-lane.sh — process supervisor for fable-orchestrator CLI lanes.
#
# The harness caps any foreground tool call at 10 minutes, so lanes must never
# hold their CLI in one long call. This script owns the fragile parts:
#   start <lane> <spec-file> [secs] [model]        launch detached + watchdog,
#     lane: codex | grok (implement) |             print PID/WATCHDOG/FINAL/LOG
#           codex-review | grok-review |           (read-only lanes; secs
#           grok-research                          defaults 600 vs 1800)
#   wait <pid> [slice-secs]                        one bounded slice (default 240s),
#                                                  prints EXITED or STILL-RUNNING
#   reap <pid> [watchdog-pid]                      kill lane group + watchdog, cleanup
# Env: LANE_CODEX_FAST=1 adds the fast service tier to codex lane launches
# (~1.5x speed, ~2-2.5x credits; needs ChatGPT sign-in). Grok lanes ignore it.
# The codex-review lane runs `codex exec review`, which derives the diff
# itself from a ref named in the instructions (refs are immutable; diff files
# race under parallel lanes). Its <spec-file> is the review instructions and
# MUST name the target — e.g. "Review the changes introduced by commit <sha>."
# — because the subcommand's --commit/--base flags are mutually exclusive
# with custom instructions. codex exec review has no --cd flag: it reviews
# the repo at this script's working directory, so invoke run-lane.sh from
# the repo under review.
#
# Process-group discipline: `set -m` gives each background job its own process
# group (PGID = PID), and every kill targets the GROUP (`kill -- -PID`) — the
# CLIs spawn child workers, and killing only the parent leaves orphans still
# writing to the tree. The watchdog is pure bash (no coreutils), polls so it
# self-terminates when the lane exits naturally (a stale full-budget sleep
# could group-kill a recycled PID), and survives the calling agent, so the
# wall clock holds even if the lane dies.
set -u
set -m

CMD=${1:-}
[ $# -gt 0 ] && shift

case "$CMD" in
start)
  LANE=${1:?usage: run-lane.sh start codex|grok|codex-review|grok-review|grok-research <spec-file> [secs] [model]}
  SPEC=${2:?missing spec file}
  SECS=${3:-}
  MODEL=${4:-}
  if [ -z "$SECS" ]; then
    case "$LANE" in *-review|*-research) SECS=600 ;; *) SECS=1800 ;; esac
  fi
  [ -f "$SPEC" ] && [ -r "$SPEC" ] && [ -s "$SPEC" ] || { echo "STATUS: unavailable"; echo "REASON: spec file missing, not a regular file, unreadable, or empty: $SPEC"; exit 1; }
  FINAL=$(mktemp -t "${LANE}-final.XXXXXX")
  LOG=$(mktemp -t "${LANE}-log.XXXXXX")
  case "$LANE" in
    codex)
      command -v codex >/dev/null 2>&1 || { echo "STATUS: unavailable"; echo "REASON: codex not on PATH"; exit 1; }
      FAST=""   # LANE_CODEX_FAST=1 opts into the fast service tier (~1.5x speed, ~2-2.5x credits; needs ChatGPT sign-in)
      [ "${LANE_CODEX_FAST:-}" = "1" ] && FAST="-c service_tier=fast -c features.fast_mode=true"
      codex exec --model "${MODEL:-gpt-5.6-sol}" -c model_reasoning_effort=high $FAST \
        --sandbox workspace-write --skip-git-repo-check --cd "$(pwd)" \
        --output-last-message "$FINAL" - < "$SPEC" > "$LOG" 2>&1 &
      ;;
    codex-review)
      command -v codex >/dev/null 2>&1 || { echo "STATUS: unavailable"; echo "REASON: codex not on PATH"; exit 1; }
      FAST=""
      [ "${LANE_CODEX_FAST:-}" = "1" ] && FAST="-c service_tier=fast -c features.fast_mode=true"
      # `codex exec review` derives the diff from the ref the instructions
      # name — no diff file to clobber. sandbox_mode is pinned read-only via
      # the documented config key (the subcommand has no --sandbox flag;
      # key honored on codex-cli 0.144.1 — an unknown -c key would be
      # silently dropped, so re-verify on CLI upgrades); --json makes LOG a
      # JSONL event stream — plus one plain-text "WATCHDOG: killed …" line
      # if the watchdog fires, so consumers grep for markers rather than
      # strictly parse. Instructions arrive on stdin
      # via the positional '-' PROMPT. Custom instructions are mutually
      # exclusive with the subcommand's --commit/--base target flags
      # (verified on 0.144.1), which is why the target ref lives in the
      # instruction text instead.
      codex exec review --model "${MODEL:-gpt-5.6-sol}" -c model_reasoning_effort=high $FAST \
        -c 'sandbox_mode="read-only"' --json \
        --output-last-message "$FINAL" - < "$SPEC" > "$LOG" 2>&1 &
      ;;
    grok|grok-review|grok-research)
      command -v grok >/dev/null 2>&1 || { echo "STATUS: unavailable"; echo "REASON: grok not on PATH"; exit 1; }
      GARGS=(--prompt-file "$SPEC" -m "${MODEL:-grok-4.5}" --output-format plain --cwd "$(pwd)")
      case "$LANE" in
        grok)
          # acceptEdits is kept for forward-compat but is NOT enforcement on
          # current CLIs (verified on 0.2.99: headless runs execute commands
          # regardless of it). The deny rules below ARE enforced: no privilege
          # escalation, no pushing, no ad-hoc network from an implementation
          # lane. This is a deny-list, not confinement — grok's kernel sandbox
          # does not restrict child processes on macOS today.
          GARGS+=(--permission-mode acceptEdits
                  --deny 'Bash(sudo*)' --deny 'Bash(git push*)'
                  --deny 'Bash(curl*)' --deny 'Bash(wget*)') ;;
        grok-review)
          # Hard read-only via the tool allowlist (enforced; --sandbox and
          # --permission-mode are not), minus the MCP bridge tools that
          # bypass the allowlist.
          GARGS+=(--tools 'read_file,grep,list_dir'
                  --disallowed-tools 'use_tool,search_tool') ;;
        grok-research)
          # Researcher: allowlist of the web + read tools only (tool names
          # verified live on grok 0.2.99 — grok silently accepts UNKNOWN
          # tool names, so a denylist typo voids the restriction with no
          # error; an allowlist fails closed). MCP bridge tools leak past
          # allowlists, so they are disallowed explicitly, like grok-review.
          GARGS+=(--tools 'web_search,open_page,open_page_with_find,x_user_search,x_semantic_search,x_keyword_search,x_thread_fetch,read_file,list_dir,grep'
                  --disallowed-tools 'use_tool,search_tool') ;;
      esac
      grok "${GARGS[@]}" > "$FINAL" 2>&1 &
      LOG=$FINAL
      ;;
    *) echo "STATUS: unavailable"; echo "REASON: unknown lane '$LANE' (codex|grok|codex-review|grok-review|grok-research)"; exit 2 ;;
  esac
  PID=$!
  (
    n=0
    limit=$(( (SECS + 9) / 10 ))
    while [ "$n" -lt "$limit" ] && kill -0 "$PID" 2>/dev/null; do
      sleep 10
      n=$((n + 1))
    done
    if kill -0 "$PID" 2>/dev/null; then
      kill -- "-$PID" 2>/dev/null
      echo "WATCHDOG: killed $LANE after ${SECS}s" >> "$LOG"
    fi
  ) >/dev/null 2>&1 &
  WATCHDOG=$!
  echo "PID: $PID"
  echo "WATCHDOG: $WATCHDOG"
  echo "FINAL: $FINAL"
  echo "LOG: $LOG"
  ;;
wait)
  PID=${1:?usage: run-lane.sh wait <pid> [slice-secs]}
  SLICE=${2:-240}
  i=0
  while [ "$i" -lt "$((SLICE / 5))" ] && kill -0 "$PID" 2>/dev/null; do
    sleep 5
    i=$((i + 1))
  done
  if kill -0 "$PID" 2>/dev/null; then echo "STILL-RUNNING"; else echo "EXITED"; fi
  ;;
reap)
  PID=${1:?usage: run-lane.sh reap <pid> [watchdog-pid]}
  WATCHDOG=${2:-}
  kill -- "-$PID" 2>/dev/null
  [ -n "$WATCHDOG" ] && kill -- "-$WATCHDOG" 2>/dev/null
  sleep 2
  kill -9 -- "-$PID" 2>/dev/null
  sleep 1
  if kill -0 -- "-$PID" 2>/dev/null; then
    echo "REAPED: $PID (WARNING: group still alive)"
    exit 1
  fi
  echo "REAPED: $PID (group dead)"
  ;;
*)
  echo "usage: run-lane.sh start|wait|reap ..." >&2
  exit 2
  ;;
esac
