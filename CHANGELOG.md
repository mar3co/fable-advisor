# Changelog

**fable-orchestrator**, originally derived from [DannyMac180/fable-advisor](https://github.com/DannyMac180/fable-advisor) at its 3.1.0 and independently maintained since 2026-07-10 (detached from the fork network). Plugin updates are version-gated — every change ships with a version bump. Entries 3.1.1–3.5.0 below predate the rename, when this project was the fable-advisor fork; 3.5.0 was never published under that name.

## 1.4.0 — 2026-07-11

Partly adopted from a third external Grok 4.5 review.

- **Review fallback chain** (the review pipeline previously had none): when the opposite-family CLI reviewer is unavailable, the cold pass falls back to the strongest Claude model available (Opus subagent, diff-only and cold — Claude is a third family versus both CLI implementers), announced. Review is never silently skipped and never silently same-family. Requirements now say full assurance wants both CLIs: your implementer's opposite family is your reviewer.
- **Reviewers moved onto the supervisor**: `run-lane.sh` gains read-only `codex-review` / `grok-review` lane types, and both reviewer agents launch detached — a `TIMEOUT:` override above ~600s previously died at the harness's 10-minute foreground wall, the same bug class fixed for implementers in 3.4.0. Smoke test extended to cover the review lane path.
- **Verification copy contradiction fixed**: the implementers' Rules and `VERIFIED:` field still demanded an unconditional re-run, undercutting 1.1.0's conditional verification — wrappers would burn the suite twice. Copy now consistently accepts captured-log evidence. (The reviewer's suggested "machine-checkable footer" was rejected: footers land in the model-authored final message and are claims, not evidence; the machine-captured log is the evidence.)
- **Refutation bounds**: refute in severity order; after two respec → re-implement → re-review rounds on one diff, surface residual findings to the user instead of thrashing.
- **Citation coordinates**: reviewers cite post-image (new-file) `file:line` so findings map to the working tree the refutation pass reads.
- **Research verification teeth**: the verifying lane must fetch and read the sources themselves, never judge from the researcher's summaries.
- **Must-do checklist** at the top of the skill — six obligations, an index against under-pressure skipping.
- Copy fixes: doctor banner no longer claims a same-named upstream (stale since the rename); a missing CLI is now a doctor *warning* with the degradation spelled out (auth-broken stays a failure); `grok-implementer` names codex-reviewer as the usual cold lens; "route every lane by verifiability" softened to the supporting lanes it actually governs.

## 1.3.0 — 2026-07-10

- **Verifiability routing stated as the general principle**: every lane routes by how its output can fail, not by task label — invisible-omission failure modes get the strongest model. (The exploration split shipped in 1.2.0 was one instance; now the rule itself is doctrine.)
- **Research verification lane**: grok-researcher's leads are breadth, not truth — verification-grade synthesis (source-reading, adversarial fact-checking, confirmed-vs-anecdotal labeling) goes to the strongest Claude model before anything load-bearing rests on them. Completes the research pipeline the way 1.2.0's refutation pass completed review.
- Context-lean rules gain the spec-writing heuristic (read the ~40 lines around the seams, never the ~1,000-line file) and filter-at-the-tool-call discipline (`--jq`, `grep`, `tail`).

## 1.2.0 — 2026-07-10

Doctrine promoted into the skill from the maintainer's private CLAUDE.md, where it was covering gaps the plugin should own.

- **Refutation pass** defined in the review tiers — both reviewer agents already said "the caller runs the refutation pass," but the skill never defined it. The architect now refutes each cited finding against the code before acting (confirmed → corrected spec; refuted → dropped with a reason), and on security-tier diffs also refutes the *clean* report by spot-checking the riskiest branch.
- **Exploration routed by failure mode**: bounded, checkable lookups → cheap read-only agent; completeness-critical sweeps ("what else can touch this resource?") → the strongest Claude model available, because an omitted answer never appears in the report. Load-bearing exploration claims get a session-level spot-check before architecture rests on them.
- **Parallelism**: past ~4 parallel lanes, propose the harness's Workflow tool (where available; explicit user opt-in) so lane transcripts never enter the architect's context.

## 1.1.0 — 2026-07-10

Partly adopted from a second external Grok 4.5 review; the reviewer-family rule came from the maintainer.

- **`codex-reviewer` agent + cross-family review rule**: the cold reviewer must come from a different model family than the implementer — under the grok default, grok-reviewer reviewing grok's diffs was the same family grading its own homework. Grok implemented → `codex-reviewer` (GPT-5.6 Sol, `--sandbox read-only`); codex or a Claude fallback implemented → `grok-reviewer`. Skill review tiers, lanes tables, flowchart, and agent descriptions updated.
- **`run-lane.sh` process-group hardening**: `set -m` puts each lane in its own process group and every kill targets the group (`kill -- -PID`) — killing only the parent left CLI child workers as orphans still writing to the tree. The watchdog now polls and self-terminates when the lane exits naturally, closing a recycled-PID group-kill hazard the old full-budget sleep carried.
- **`scripts/test-run-lane.sh`**: no-API smoke test (PATH-shimmed fake CLI) asserting group-kill on reap, natural-exit detection with watchdog self-termination, and budget kill with logging.
- `fable-advisor` agent now enforces the evidence rule itself: it declines to rule when the decisive evidence wasn't provided, instead of guessing.
- Trivial-edit bright line in the skill: if it needs a verification command to trust, it isn't trivial.
- Honesty fixes: FAQ no longer claims every diff gets cross-vendor review "for free" (verification is automatic; cold review is the explicit tier step); intro says assurance comes from verification plus tiered review; flowchart shows the mirrored codex-mode fallback and the reviewer-family branch.
- **Conditional wrapper verification** — one authoritative run per task, not a blind re-run: the wrapper accepts the CLI's machine-captured log when it shows the verification command passing as the run's final act (with no edits after), and re-runs only otherwise. Grok lanes usually still re-run (acceptEdits blocks commands); codex lanes, which run tests in their dev loop, usually don't need to. Spec contract now asks for the smallest verification bundle that proves the change.
- README reworked wholesale for readability: consolidated rules section, deduplicated mode/fallback prose, permissions table covers all producer roles.
- Marketplace/plugin descriptions updated (modes, both reviewers).

## 1.0.1 — 2026-07-10

- README: the "always-on" recommendation now matches the plugin's design — a two-line CLAUDE.md (standing skill trigger + mode declaration) instead of the inherited doctrine-restatement paragraph, which duplicated skill content and omitted invoking the skill.

## 1.0.0 — 2026-07-10

- Renamed plugin and repo: fable-advisor → **fable-orchestrator** (`mar3co/fable-orchestrator`), with the version reset to 1.0.0 as an independent plugin. Includes everything listed under 3.5.0 below. Breaking relative to the fable-advisor releases: the install key is `fable-orchestrator@fable-orchestrator`, agent references become `fable-orchestrator:*`, and the canonical config prefix becomes `fable-orchestrator: implementation lane = …` (old `fable-advisor:` declarations are still honored by intent). The advisor agent keeps its `fable-advisor` name. The rename ends the install-time name collision with the original plugin.

## 3.5.0 — 2026-07-10

Adopted, with modifications, from an external Grok 4.5 review of the fork.

- **Implementation routing modes**: `fable-advisor: implementation lane = grok | codex | mix` (one CLAUDE.md line; grok when unconfigured). Fixed modes send everything to one lane; mix lets the architect route per task — mechanical/spec-determined → grok, correctness-critical → codex, doubt → codex. Availability is discovered, not declared: every mode falls back through the other installed CLI lane to a guaranteed Claude Opus subagent, announced.
- **`scripts/run-lane.sh`**: process supervisor owning launch, pure-bash watchdog (no coreutils dependency), bounded wait slices, and cleanup — implementer agents are now thin wrappers, and the fragile shell moved out of prompts.
- **Review tiers** in the orchestration skill: verification ≠ cold review; mechanical diffs → verification only, behavior-bearing → cold `grok-reviewer` pass, security/auth/concurrency/migrations → add a silent-failure completeness read on a strong Claude model.
- **`grok-researcher` narrowed to live web/X research** — codebase lookups (where-is-X, inventories) belong to cheap in-process read-only agents, which are faster and more accurate for file:line work than an external CLI hop.
- **Honesty pass** on README + skill: "near-parity" softened to "good enough when the architect owns the hard parts and verifies"; verification vs cold review distinguished; the three-layer cost structure (architect / Sonnet wrapper / CLI producer) stated; "cheapest adequate lane" prose reconciled with the mode doctrine.
- Advisor consults must include pasted decisive evidence (failing output, traces), not just file paths.
- Parallelism rule: one writer per module/package; schema and migration work is always serial.
- README: producer permissions table. Doctor: prints fork identity + version banner.
- Grok is the unconfigured default implementation lane (flipped from codex before release; fallback chain grok → codex → Opus).
- The skill absorbs the last externally-held doctrine: trivial edits (few-line fixes, renames, doc tweaks) stay with the architect inline, and the session drives the grok CLI directly only for short single-answer web lookups. A user's CLAUDE.md needs only two lines: a standing trigger for this skill, plus the lane declaration.

## 3.4.1 — 2026-07-10

- README: Mermaid flowchart ("How routing works") showing lane selection, the configurable default, the announced fallback chain, and the verification gate.

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
