# Changelog

Fork of [DannyMac180/fable-advisor](https://github.com/DannyMac180/fable-advisor); versions continue upstream's numbering (upstream is at 3.1.0). Plugin updates are version-gated — every change ships with a version bump.

## 3.4.0 — 2026-07-10

- Implementer lanes launch their CLI **detached** and supervise it in bounded wait slices, fixing the 10-minute lane shutdown on long runs: the harness caps any foreground tool call at 10 minutes, which killed the lane's supervision mid-run while the CLI kept working as an orphan. The timeout now wraps the detached process itself, so the wall clock holds even if the lane dies.
- Implementation-lane default wall clock raised 600 → 1800 seconds (long codex runs at high reasoning routinely exceed ten minutes); research/review lanes stay at 600, foreground.
- Orchestration skill: every spec must estimate its wall clock honestly and carry a `TIMEOUT: <seconds>` line when it differs meaningfully from the default — undersized budgets kill legitimate runs, oversized ones delay hang detection.

## 3.3.0 — 2026-07-10

- `scripts/doctor.sh`: one-command lane preflight — timeout binary, both CLIs (presence, auth, model access via a tiny live call per lane), and a reminder that Claude model pins degrade silently.
- Caller-tunable timeouts: a spec may carry a `TIMEOUT: <seconds>` line to raise a lane's 600-second default wall clock; all four CLI agents honor it.
- `grok-reviewer`: diff-size guard — diffs over ~1,500 lines are reviewed in per-file batches, with an `UNCOVERED` report field and a `partial` status instead of silent quality collapse.
- Grok agents capture output via `mktemp` instead of predictable `/tmp/*-$$.txt` paths, matching the codex lane and the plugin's own "never a fixed path" rule.
- Orchestration skill: advisor consults must include the exact file paths to read; spec contract documents the optional `TIMEOUT:` line.
- Plugin and marketplace descriptions mention `grok-researcher` / `grok-reviewer`.

## 3.2.1 — 2026-07-10

- README rewritten to describe the fork natively: five-lane table, configurable default lane, no-racing rationale, guaranteed Opus terminal fallback. Provenance reduced to a one-line note; upstream differences moved to the FAQ.

## 3.2.0 — 2026-07-10

- Default implementation lane is user-configurable: one CLAUDE.md line (`fable-advisor: default implementation lane = grok`) flips the default from codex to grok; intent honored over exact syntax. The other CLI lane is the first fallback; a Claude Opus subagent is always the terminal fallback. Agent descriptions state the conditional default (they are visible at routing time even when the skill body is not loaded).
- Added a `mar3co` copyright line to the LICENSE for fork modifications.

## 3.1.1 — 2026-07-10

Fork baseline, diverging from upstream 3.1.0:

- `codex-implementer` (GPT-5.6 Sol, high reasoning) becomes the default implementation lane; `grok-implementer` becomes the codex-outage fallback. Lane racing removed — assurance comes from cross-vendor review of the diff, not duplicate implementations.
- Fixed, announced fallback chain: default lane → other CLI lane → Claude Opus subagent.
- New agents: `grok-researcher` (breadth-first live-web/X research and mechanical codebase lookups, distilled and cited) and `grok-reviewer` (cold diff-only second review lens, every claim cited `file:line`).
- Removed upstream author's newsletter promotion; metadata points at the fork.
