---
name: orchestration
description: Routing doctrine for the architect-as-orchestrator pattern — how a session running the smartest model delegates implementation to cheaper cross-vendor lanes to minimize cost. USE WHEN delegating implementation work, choosing between grok-implementer/codex-implementer lanes, writing a spec for a subagent, deciding whether to consult fable-advisor, managing session cost or token spend, or running any multi-task build where the session is the architect.
---

# Orchestration — the architect's routing doctrine

The session is the architect: it owns requirements, architecture, decomposition, specs, routing, and verification. It should almost never type implementation code — the one exception is trivial edits (few-line fixes, renames, doc/comment tweaks), which stay with the architect inline; everything else is delegated. The bright line: if it needs a verification command to trust, it isn't trivial. Implementation routing follows the session's configured mode — **grok** (fixed, the unconfigured default), **codex** (fixed), or **mix**, where the architect routes each task by kind (see "Choosing your implementation routing"). The unconfigured default is fixed-grok: cheap typing with assurance from verification and the review tiers, and a fixed binding cannot drift.

## The checklist

Every delegation, no exceptions — details in the sections below:

1. **Mode** — grok (unconfigured default) | codex | mix, per the session's CLAUDE.md declaration.
2. **Spec** — all six parts (commit ownership included), an honest `TIMEOUT:` when it differs from the default (plus `FAST MODE: on` on codex-lane delegations when configured), the smallest verification bundle that proves the change.
3. **Report back** — read the diff; demand execution evidence (captured log or wrapper re-run), never a claim, and the report's `COMMIT:` field — a hash, or an explicit "uncommitted — spec said caller commits". A completion without a structured report is an error state, not a success — settle the lane (see "A completion without a report is not a success") before touching the branch.
4. **Review tier** — caller-declared spike or mechanical diff: verify only (spikes are declared, never inferred). Behavior-bearing: one cold review from the model family that did NOT implement it (if that lane is down: Opus cold, announced). Security/auth/concurrency: add the silent-failure completeness read.
5. **Findings** — refutation pass, cited-first in severity order; max two respec rounds, then surface residuals to the user.
6. **Load-bearing research** — verified by a strong Claude lane that fetches the sources itself, before anything rests on it.
7. **Commitment boundary / declaring done** — consult `fable-advisor` with exact files and pasted evidence.

Every fallback is announced; verification and review never relax under fallback.

## Cost discipline — the prime directive

The session model is the most expensive lane in the system, on both input and output tokens. The whole economic case for this pattern is keeping its token volume low: spend Fable on judgment; the CLI producers carry the code volume, with a thin Sonnet wrapper supervising each lane (preflight, wait slices, re-verification — real but modest overhead, stated honestly). Three rules follow.

**Emit judgment, not volume.** The architect's output is decomposition, specs, routing decisions, verdicts on diffs, and short reports. It does not type implementation code, test bodies, boilerplate, or config files. A code block longer than an interface signature or a few illustrative lines is a spec that hasn't been delegated yet — stop and delegate it. Fixing a lane's bug by hand is the same failure in disguise: send a corrected spec back to the cheap lane instead.

**Keep the context lean.** Everything in the architect's context is re-read at architect prices on every turn. Delegate exploration and log-grepping, keep only the conclusions, and route the supporting lanes — exploration, research, review — by how their output can fail — by VERIFIABILITY, not task label: bounded, checkable lookups — where is X defined, list the callers, inventory the endpoints — go to a cheap read-only agent, because a wrong answer is visible and cheap to re-check; completeness-critical sweeps — "what else can touch this resource?", "are there other write paths?" — go to the strongest Claude model available (Agent tool, `model: "opus"`), because their failure mode is an invisible omission that never appears in the report and silently poisons the architecture built on it. Read files yourself only when the decision genuinely depends on the exact code — usually the ~40 lines around the seams, never the ~1,000-line file — and don't paste long files, full diffs, or verbose command output into the conversation when an excerpt will do: filter at the tool call (`--jq`, `grep`, `tail`) so raw dumps never enter context at all.

**Reason once, then hand off.** Do the hard thinking — the architecture, the interface design, the debugging hypothesis — in one pass, capture it in the spec, and let the cheap lane carry it from there. Re-deriving decisions across turns burns the premium twice.

What stays with the architect regardless of cost: decomposition, interface design, hypothesis selection when debugging, spec writing, lane routing, and judging verification evidence. Any load-bearing exploration claim ("nothing else touches X") gets a session-level spot-check before an architectural decision rests on it. Those tokens are what the premium is for — everything else is a candidate for delegation.

## The lanes

| Lane | Producer | Invoke | Route here when |
|---|---|---|---|
| Implementation | Grok 4.5 | `grok-implementer` agent | All implementation in **grok** mode (the unconfigured default). In **mix** mode: mechanical work the spec fully determines — wiring, CRUD, boilerplate, make-the-types-match. Requires the [Grok CLI](https://x.ai/cli). |
| Implementation | GPT-5.6 Sol (high reasoning) | `codex-implementer` agent | All implementation in **codex** mode. In **mix** mode: correctness-critical work — concurrency, auth/security, migrations, subtle state, anything the spec can't fully pin. Requires the codex CLI. |
| Research | Grok 4.5 | `grok-researcher` agent | Not an implementation lane: breadth-first live-web/X research. Codebase lookups (where-is-X-defined, list-callers, inventories) go to a cheap in-process read-only agent instead — faster and more accurate for file:line work than an external CLI hop. |
| Review | Grok 4.5 / GPT-5.6 Sol | `grok-reviewer` / `codex-reviewer` agents | Cold second review lens on a behavior-bearing diff — pick the family the implementer ISN'T: grok implemented → `codex-reviewer`; codex implemented → `grok-reviewer`; a Claude fallback lane implemented → either. |
| Judgment | Fable 5 | `fable-advisor` agent | Not an implementation lane. See "Commitment boundaries" below. |

The session may drive the `grok` CLI directly only for short single-answer web lookups; anything with long output (breadth research, review) runs inside the researcher/reviewer lanes so raw transcripts never enter the architect's context.

Research leads are breadth, not truth. Before anything load-bearing rests on the researcher's findings, verification-grade synthesis — fetching and reading the sources themselves (open the URLs; never judge from the researcher's summaries alone), adversarially fact-checking, labeling confirmed vs anecdotal — goes to the strongest Claude model available (Agent tool, `model: "opus"`): mislabeling an anecdote as confirmed is another invisible-omission failure, so it gets the strongest model, not the cheapest.

Implementation goes to ONE lane — never race the CLI lanes on the same spec, even for correctness-critical work. Assurance comes from reviewing the diff (see "Review tiers"), not from duplicate implementations; the architect judging two diffs pays twice for typing and once more for the judging.

The fallback chain is the same in every mode and every step is announced explicitly, never silently absorbed: if the chosen lane is unavailable (service offline, auth failure, usage limit, CLI missing, timeout), re-route the same spec to the other CLI lane if it is installed — cross-vendor separation survives the outage. If both CLI lanes are unavailable, the final fallback is ALWAYS a Claude Opus subagent (Agent tool, `model: "opus"`). Availability is discovered at run time, not declared in config — a user with only one CLI needs no special mode; the chain routes around the gap loudly. Verification and review do not relax under fallback — a substitute lane makes them matter more.

## Choosing your implementation routing

Three modes, declared with one line in any CLAUDE.md that applies to the session — canonical forms:

```
fable-orchestrator: implementation lane = grok    (the unconfigured default)
fable-orchestrator: implementation lane = codex
fable-orchestrator: implementation lane = mix
```

- **grok** — every implementation task goes to `grok-implementer`. Fixed; cheap typing when specs are strong, with assurance from verification and the review tiers.
- **codex** — every implementation task goes to `codex-implementer`. Fixed; maximum reasoning on every diff, for shops that want fewer subtle bugs over token savings.
- **mix** — the architect routes each task by kind: mechanical work the spec fully determines (wiring, CRUD, boilerplate, make-the-types-match) → grok; correctness-critical work (concurrency, auth/security, migrations, subtle state, anything the spec can't fully pin) → codex at high reasoning. When in doubt, codex. State the chosen lane and why in one line when delegating.

Honor the intent, not the exact string — any clear statement of implementation-lane preference in the user's instructions counts (e.g. "grok is my default implementation lane", "let the orchestrator pick the implementation model"). Mode changes routing only: the fallback chain, spec contract, verification, and review rules apply identically in all three.

### Codex fast mode

One more optional line opts the codex lanes into the Codex CLI's fast service tier — canonical form:

```
fable-orchestrator: codex fast mode = on
```

Absent or `off` means off. When on, add a `FAST MODE: on` line to every codex-lane delegation — implementer and reviewer, in every lane mode (codex-reviewer cold-reviews grok diffs even in grok mode); the lane wrappers translate it into the supervisor's fast-tier flags. Fast is a speed trade, not a saving: ~1.5x output speed for ~2–2.5x credit burn, and it requires ChatGPT sign-in (API-key auth cannot use it). If the fast launch fails, the lane retries once at standard tier and reports the downgrade — a loud degrade, never a blocked task. Grok lanes are unaffected. As with the lane mode, honor the intent, not the exact string.

## The spec contract

Implementers share none of your conversation context. Every delegation prompt carries all six parts:

1. **Objective** — what to build or change, one paragraph
2. **Files** — exact paths to create or modify
3. **Interfaces** — signatures, types, or API shapes the code must match
4. **Constraints** — project conventions, things not to touch
5. **Verification** — the command(s) that prove it works: the smallest bundle that exercises the change, not the full suite (full suites run at integration points; the command may legitimately run twice — once in the producer's dev loop, once at wrapper acceptance when the captured log is inconclusive — so its cost matters)
6. **Commit** — who commits: `lane` (the default when unstated) or `caller`. Under `lane`, the wrapper records the starting HEAD before launch, the work is committed on the current branch once verification passes (by the CLI or by the wrapper as backstop, scoped to the files the task actually changed), and the report carries the hash. Committing is not shipping: cold review runs on the committed diff by ref, respec rounds land follow-up commits, and the architect owns squash/merge at integration points. A spec that says `COMMIT: caller` gets a verified working tree back instead — but say it explicitly; a constraint line about commit *style* is a message convention, never a transfer of ownership. Lane-owned commits also sharpen the parallelism rule: concurrent lanes committing in one shared checkout contend on the git index and can sweep each other's staged work, so parallel implementation lanes that will commit get separate worktrees (see "Parallelism"), or that batch's spec says `COMMIT: caller`.

Estimate the task's wall clock honestly in every spec and include a `TIMEOUT: <seconds>` line whenever the estimate differs meaningfully from the implementation lanes' 1800-second default (the research/review lanes default to 600). An undersized budget kills a legitimate run mid-flight; an oversized one delays detection of a genuinely hung lane — accuracy beats generosity in both directions. When codex fast mode is configured (see "Codex fast mode" above), codex-lane delegations also carry a `FAST MODE: on` line — like `TIMEOUT:`, lane configuration alongside the spec, not part of it.

A spec you can't finish writing is a signal the decision isn't made yet — that's architect work, not a reason to hand the ambiguity to a cheaper model.

## Parallelism

Independent specs (no shared files, no ordering dependency) launch as parallel agents in a single message. Sequential chains and single-file surgery stay serial. One writer per module or package; schema and migration work is always serial — "no shared files" is necessary but not sufficient, because adjacent files, generated code, and lockfiles collide too. For heavy fan-out where parallel implementers must touch adjacent areas anyway, isolate each lane in its own git worktree (the Agent tool supports `isolation: "worktree"`) and merge serially, verifying after each merge rather than only per lane.

Past roughly four parallel lanes, raw agent calls stop scaling — every report lands in the architect's context. Where the harness's Workflow tool is available, propose orchestrating the fan-out through it instead: lane transcripts never enter the architect's context and the control flow is deterministic. It requires the user's explicit opt-in — ask, don't assume.

## Waiting on lanes — background by default

Run every lane — implementation, review, research, advisor — in the background. That is already the Agent tool's default, and SendMessage continuations have no foreground mode at all — so the failure this section bans is explicitly passing `run_in_background: false` to wait in-turn. End the turn with a one-line status and act on the completion notification. A sequential dependency is not a reason to wait synchronously: the notification resumes the architect with full context either way, at the same near-fully-cached re-read cost, while a synchronous wait holds the turn open for the lane's whole wall clock — the user can't interject, re-prioritize, or stop the work until it closes. (The lane's CLI already runs detached inside the agent; this is about the architect's own Agent call, which is what blocks the session.) Invoke synchronously only when the result must compose with in-context state within the same turn — rare — and say so in one line. Keep wake-up status messages to a line or two so notification re-invocations stay cheap. This makes the single-lane case consistent with the parallel fan-out above instead of a different, turn-blocking mode.

## A completion without a report is not a success

The lane wrappers launch their CLI detached; the wrapper's structured report (`GROK REPORT`, `CODEX REPORT`, …) — including its `PROCESS:` reap evidence on implementation lanes — is the architect's only signal that the lane is settled. If a lane task completes with anything else as its result (a "waiting" message, a narration fragment, silence), treat the working tree as UNSETTLED: an orphaned CLI process may still be alive, editing, committing, or pushing minutes after the task "completed". Before dispatching anything else to that tree or trusting your own verification of it: check `git status` / `git log` for surprises, check for surviving lane processes (`pgrep -f 'grok --prompt-file'`, `pgrep -f 'codex exec'`), and group-kill anything found via its process GROUP, not its PID — `PG=$(ps -o pgid= -p <pid> | tr -d ' '); kill -- "-$PG"; sleep 2; kill -9 -- "-$PG"` (a pgrep hit is not necessarily the group leader, so `kill -- -<pid>` can miss or hit the wrong group). These checks are best-effort — an escaped process can detach from its group or not match the argv patterns — so the tree is the final authority: verification performed while a detached process was alive is void; re-run it once `git status` / `git log` are confirmed quiet and stay quiet.

Related discipline: reuse a lane wrapper via SendMessage only for follow-ups on the SAME task (a respec round, a clarification on its diff). Do not run many tasks through one long-lived wrapper — the observed failure mode is end-of-task discipline (waiting, reaping, reporting) degrading as the wrapper's transcript grows past a couple hundred thousand tokens, while its judgment still looks fine. A fresh wrapper per task costs one preflight and sidesteps it.

## Commitment boundaries

Consult `fable-advisor` (read-only, verdict in under 300 words) at the moments that decide whether the next hour is wasted:

- Before committing to an architecture, data migration, API shape, or refactor strategy
- Whenever the same problem has resisted two distinct attempts
- Once before declaring a multi-step deliverable done

Pass it the decision, the constraints, the options considered, the exact file paths to read, and the decisive evidence pasted in (failing test output, traces, the numbers) — the advisor cannot run commands, and a verdict on unstated evidence is a guess. Act on the verdict or surface the disagreement — never silently ignore it. (If the session itself already runs on Fable, the advisor still earns its keep as a context-clean skeptic reading the actual code.)

## Review tiers

Verification (below) is not review. Verification asks "did it do what the spec said, and do the checks pass?" Cold review asks "what is wrong that the author — and the architect's own framing — didn't see?" The architect reading a lane's diff is verification with cross-vendor eyes, not cold review: the architect wrote the spec and is primed by it. Tier by the diff:

- **Mechanical diffs** (renames, literal moves, no behavior change): verification only.
- **Declared spikes** (the caller explicitly marks the task throwaway/prototype, not headed to main): verification only, with the spike status restated in the report. A spike is DECLARED by the caller, never inferred — silently downgrading real work to spike treatment under pressure is exactly the failure this named tier exists to prevent. Spike status lasts only while the code is throwaway: if spike code is later promoted toward main, the promoted diff re-enters these tiers as normal behavior-bearing work (cold review, plus the security pass where it applies) before merge. A spike declaration on security/auth paths is a smell worth one explicit confirmation that the work is genuinely throwaway.
- **Behavior-bearing diffs**: add one cold review pass — diff only, no intent framing — from a model family DIFFERENT from the implementer's: grok implemented → `codex-reviewer`; codex implemented → `grok-reviewer`; a Claude fallback lane implemented → either. Hand the reviewer a REF — a commit SHA or a base branch (the reviewer resolves and reports concrete SHAs) — never a diff file: resolved refs are immutable content addresses, while a diff file in a shared directory can be overwritten by a concurrent lane between write and read, and a clean review of the wrong bytes is indistinguishable from a real clean review. (The lane-commits default above exists partly for this: a committed diff always has a ref.) Reviewing the uncommitted working tree is allowed for pre-commit checks but is NOT immutable — prefer committed refs. A reviewer from the author's own family shares the author's blind spots and is not a second lens. If the opposite-family CLI reviewer is unavailable, the cold pass falls back to the strongest Claude model available (Agent tool, `model: "opus"`, diff-only and cold — Claude is a third family versus both CLI implementers), announced like every substitution. Review is never silently skipped and never silently same-family.
- **Security / auth / concurrency / migration paths**: additionally have a strong Claude model read every error / nil / empty / timeout branch for silent failure (a read-only session pass or an Opus subagent). Omission-type misses never appear in any reviewer's report, so this tier is about completeness, not a second opinion.

If in doubt whether a diff is mechanical, it isn't.

Reviewer findings are claims, not verdicts — the architect runs the **refutation pass** before acting. For each finding: read the cited `file:line` against the actual code and try to refute it. Refuted → drop it, with a one-line reason. Confirmed → a corrected spec goes back to the implementation lane, never a hand-fix. Cold lenses trade precision for recall, so false positives are expected — each costs one refutation, while every unique true positive is pure gain. On security-tier diffs, also refute the *clean* report: "no findings" is itself a claim, so spot-check the diff's riskiest branch yourself before accepting it — the unchallenged "it's fine" is where bugs hide.

Refute in severity order — the wrapper has flagged citation problems (`UNCITED`), not pre-cleared them: refute cited findings first, and take `UNCITED` items last as cheap skims rather than full refutations. The top of the queue decides ship/no-ship. And bound the loop: after two respec → re-implement → re-review rounds on the same diff, stop and surface the residual findings to the user with your recommendation instead of thrashing.

## Verification

Reports are claims, not evidence — but machine-captured logs are. Exactly one authoritative verification run per task, not three: the wrapper accepts the CLI's captured log when it shows the verification command executing and passing as the run's final act, and re-runs the command itself otherwise (its report says which). The architect reads the diff and spot-checks the report's evidence; full re-runs happen at integration points (merging, declaring a deliverable done), not after every lane report. "Should work", "tests should pass", or a report with no execution evidence means the task is not done. A lane that reports a spec gap gets a corrected spec, not a "use your judgment".
