---
name: orchestration
description: Routing doctrine for the architect-as-orchestrator pattern — how a session running the smartest model delegates implementation to cheaper cross-vendor lanes to minimize cost. USE WHEN delegating implementation work, choosing between grok-implementer/codex-implementer lanes, writing a spec for a subagent, deciding whether to consult fable-advisor, managing session cost or token spend, or running any multi-task build where the session is the architect.
---

# Orchestration — the architect's routing doctrine

The session is the architect: it owns requirements, architecture, decomposition, specs, routing, and verification. It should almost never type implementation code. Implementation routing follows the session's configured mode — **grok** (fixed, the unconfigured default), **codex** (fixed), or **mix**, where the architect routes each task by kind (see "Choosing your implementation routing"). The unconfigured default is fixed-grok: cheap typing with assurance from verification and the review tiers, and a fixed binding cannot drift.

## Cost discipline — the prime directive

The session model is the most expensive lane in the system, on both input and output tokens. The whole economic case for this pattern is keeping its token volume low: spend Fable on judgment; the CLI producers carry the code volume, with a thin Sonnet wrapper supervising each lane (preflight, wait slices, re-verification — real but modest overhead, stated honestly). Three rules follow.

**Emit judgment, not volume.** The architect's output is decomposition, specs, routing decisions, verdicts on diffs, and short reports. It does not type implementation code, test bodies, boilerplate, or config files. A code block longer than an interface signature or a few illustrative lines is a spec that hasn't been delegated yet — stop and delegate it. Fixing a lane's bug by hand is the same failure in disguise: send a corrected spec back to the cheap lane instead.

**Keep the context lean.** Everything in the architect's context is re-read at architect prices on every turn. Delegate broad exploration, codebase searches, and log-grepping to a cheap read-only agent and keep only the conclusions; read files yourself only when the decision genuinely depends on the exact code. Don't paste long files, full diffs, or verbose command output into the conversation when a path reference or an excerpt will do.

**Reason once, then hand off.** Do the hard thinking — the architecture, the interface design, the debugging hypothesis — in one pass, capture it in the spec, and let the cheap lane carry it from there. Re-deriving decisions across turns burns the premium twice.

What stays with the architect regardless of cost: decomposition, interface design, hypothesis selection when debugging, spec writing, lane routing, and judging verification evidence. Those tokens are what the premium is for — everything else is a candidate for delegation.

## The lanes

| Lane | Producer | Invoke | Route here when |
|---|---|---|---|
| Implementation | Grok 4.5 | `grok-implementer` agent | All implementation in **grok** mode (the unconfigured default). In **mix** mode: mechanical work the spec fully determines — wiring, CRUD, boilerplate, make-the-types-match. Requires the [Grok CLI](https://x.ai/cli). |
| Implementation | GPT-5.6 Sol (high reasoning) | `codex-implementer` agent | All implementation in **codex** mode. In **mix** mode: correctness-critical work — concurrency, auth/security, migrations, subtle state, anything the spec can't fully pin. Requires the codex CLI. |
| Research / review | Grok 4.5 | `grok-researcher` / `grok-reviewer` agents | Not implementation lanes: breadth-first live-web/X research (`grok-researcher`), or a cold second review lens on a diff (`grok-reviewer`). Codebase lookups (where-is-X-defined, list-callers, inventories) go to a cheap in-process read-only agent instead — faster and more accurate for file:line work than an external CLI hop. |
| Judgment | Fable 5 | `fable-advisor` agent | Not an implementation lane. See "Commitment boundaries" below. |

Implementation goes to ONE lane — never race the CLI lanes on the same spec, even for correctness-critical work. Assurance comes from reviewing the diff (see "Review tiers"), not from duplicate implementations; the architect judging two diffs pays twice for typing and once more for the judging.

The fallback chain is the same in every mode and every step is announced explicitly, never silently absorbed: if the chosen lane is unavailable (service offline, auth failure, usage limit, CLI missing, timeout), re-route the same spec to the other CLI lane if it is installed — cross-vendor separation survives the outage. If both CLI lanes are unavailable, the final fallback is ALWAYS a Claude Opus subagent (Agent tool, `model: "opus"`). Availability is discovered at run time, not declared in config — a user with only one CLI needs no special mode; the chain routes around the gap loudly. Verification and review do not relax under fallback — a substitute lane makes them matter more.

## Choosing your implementation routing

Three modes, declared with one line in any CLAUDE.md that applies to the session — canonical forms:

```
fable-advisor: implementation lane = grok    (the unconfigured default)
fable-advisor: implementation lane = codex
fable-advisor: implementation lane = mix
```

- **grok** — every implementation task goes to `grok-implementer`. Fixed; cheap typing when specs are strong, with assurance from verification and the review tiers.
- **codex** — every implementation task goes to `codex-implementer`. Fixed; maximum reasoning on every diff, for shops that want fewer subtle bugs over token savings.
- **mix** — the architect routes each task by kind: mechanical work the spec fully determines (wiring, CRUD, boilerplate, make-the-types-match) → grok; correctness-critical work (concurrency, auth/security, migrations, subtle state, anything the spec can't fully pin) → codex at high reasoning. When in doubt, codex. State the chosen lane and why in one line when delegating.

Honor the intent, not the exact string — any clear statement of implementation-lane preference in the user's instructions counts (e.g. "grok is my default implementation lane", "let the orchestrator pick the implementation model"). Mode changes routing only: the fallback chain, spec contract, verification, and review rules apply identically in all three.

## The spec contract

Implementers share none of your conversation context. Every delegation prompt carries all five parts:

1. **Objective** — what to build or change, one paragraph
2. **Files** — exact paths to create or modify
3. **Interfaces** — signatures, types, or API shapes the code must match
4. **Constraints** — project conventions, things not to touch
5. **Verification** — the command(s) that prove it works

Estimate the task's wall clock honestly in every spec and include a `TIMEOUT: <seconds>` line whenever the estimate differs meaningfully from the implementation lanes' 1800-second default (the research/review lanes default to 600). An undersized budget kills a legitimate run mid-flight; an oversized one delays detection of a genuinely hung lane — accuracy beats generosity in both directions.

A spec you can't finish writing is a signal the decision isn't made yet — that's architect work, not a reason to hand the ambiguity to a cheaper model.

## Parallelism

Independent specs (no shared files, no ordering dependency) launch as parallel agents in a single message. Sequential chains and single-file surgery stay serial. One writer per module or package; schema and migration work is always serial — "no shared files" is necessary but not sufficient, because adjacent files, generated code, and lockfiles collide too.

## Commitment boundaries

Consult `fable-advisor` (read-only, verdict in under 300 words) at the moments that decide whether the next hour is wasted:

- Before committing to an architecture, data migration, API shape, or refactor strategy
- Whenever the same problem has resisted two distinct attempts
- Once before declaring a multi-step deliverable done

Pass it the decision, the constraints, the options considered, the exact file paths to read, and the decisive evidence pasted in (failing test output, traces, the numbers) — the advisor cannot run commands, and a verdict on unstated evidence is a guess. Act on the verdict or surface the disagreement — never silently ignore it. (If the session itself already runs on Fable, the advisor still earns its keep as a context-clean skeptic reading the actual code.)

## Review tiers

Verification (below) is not review. Verification asks "did it do what the spec said, and do the checks pass?" Cold review asks "what is wrong that the author — and the architect's own framing — didn't see?" The architect reading a lane's diff is verification with cross-vendor eyes, not cold review: the architect wrote the spec and is primed by it. Tier by the diff:

- **Mechanical diffs** (renames, literal moves, no behavior change): verification only.
- **Behavior-bearing diffs**: add one cold `grok-reviewer` pass — diff only, no intent framing.
- **Security / auth / concurrency / migration paths**: additionally have a strong Claude model read every error / nil / empty / timeout branch for silent failure (a read-only session pass or an Opus subagent). Omission-type misses never appear in any reviewer's report, so this tier is about completeness, not a second opinion.

If in doubt whether a diff is mechanical, it isn't.

## Verification

Reports are claims, not evidence. Before accepting any lane's work: read the diff, and re-run the verification command (or spot-check its quoted output against the working tree). "Should work", "tests should pass", or a report with no command output means the task is not done. A lane that reports a spec gap gets a corrected spec, not a "use your judgment".
