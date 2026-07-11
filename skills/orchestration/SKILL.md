---
name: orchestration
description: Routing doctrine for the architect-as-orchestrator pattern — how a session running the smartest model delegates implementation to cheaper cross-vendor lanes to minimize cost. USE WHEN delegating implementation work, choosing between grok-implementer/codex-implementer lanes, writing a spec for a subagent, deciding whether to consult fable-advisor, managing session cost or token spend, or running any multi-task build where the session is the architect.
---

# Orchestration — the architect's routing doctrine

The session is the architect: it owns requirements, architecture, decomposition, specs, routing, and verification. It should almost never type implementation code. Every implementation task gets routed to the cheapest lane that is adequate for it — escalation is deliberate, per task, never a fixed binding.

## Cost discipline — the prime directive

The session model is the most expensive lane in the system, on both input and output tokens. The whole economic case for this pattern is keeping its token volume low: spend Fable on judgment, spend Sonnet on volume. Three rules follow.

**Emit judgment, not volume.** The architect's output is decomposition, specs, routing decisions, verdicts on diffs, and short reports. It does not type implementation code, test bodies, boilerplate, or config files. A code block longer than an interface signature or a few illustrative lines is a spec that hasn't been delegated yet — stop and delegate it. Fixing a lane's bug by hand is the same failure in disguise: send a corrected spec back to the cheap lane instead.

**Keep the context lean.** Everything in the architect's context is re-read at architect prices on every turn. Delegate broad exploration, codebase searches, and log-grepping to a cheap read-only agent and keep only the conclusions; read files yourself only when the decision genuinely depends on the exact code. Don't paste long files, full diffs, or verbose command output into the conversation when a path reference or an excerpt will do.

**Reason once, then hand off.** Do the hard thinking — the architecture, the interface design, the debugging hypothesis — in one pass, capture it in the spec, and let the cheap lane carry it from there. Re-deriving decisions across turns burns the premium twice.

What stays with the architect regardless of cost: decomposition, interface design, hypothesis selection when debugging, spec writing, lane routing, and judging verification evidence. Those tokens are what the premium is for — everything else is a candidate for delegation.

## The lanes

| Lane | Producer | Invoke | Route here when |
|---|---|---|---|
| Implementation (default) | GPT-5.6 Sol (high reasoning) | `codex-implementer` agent | All implementation work, routine or correctness-critical — unless the user declared grok the default (see "Choosing your default lane"). Requires the codex CLI. |
| Implementation (alternate) | Grok 4.5 | `grok-implementer` agent | The user declared grok the default implementation lane, or the default lane is unavailable. Requires the [Grok CLI](https://x.ai/cli). |
| Research / review | Grok 4.5 | `grok-researcher` / `grok-reviewer` agents | Not implementation lanes: breadth-first live-web/X research and mechanical codebase lookups (`grok-researcher`), or a cold second review lens on a diff (`grok-reviewer`). |
| Judgment | Fable 5 | `fable-advisor` agent | Not an implementation lane. See "Commitment boundaries" below. |

Implementation goes to ONE lane — never race the CLI lanes on the same spec, even for correctness-critical work. Assurance comes from the review gauntlet (cross-vendor cold review of the diff), not from duplicate implementations; the architect judging two diffs pays twice for typing and once more for the judging.

The fallback chain is fixed and every step is announced explicitly, never silently absorbed: if the default lane is unavailable (service offline, auth failure, usage limit, CLI missing, timeout), re-route the same spec to the other CLI lane — cross-vendor separation survives the outage. If both CLI lanes are unavailable, the final fallback is always a Claude Opus subagent (Agent tool, `model: "opus"`). Verification and review do not relax under fallback — a substitute lane makes them matter more.

## Choosing your default lane

`codex-implementer` (GPT-5.6 Sol) is the default implementation lane when nothing says otherwise. To make Grok the default instead, declare it in any CLAUDE.md that applies to the session — canonical form, one line:

```
fable-advisor: default implementation lane = grok
```

Honor the intent, not the exact string — any clear statement of implementation-lane preference in the user's instructions counts (e.g. "grok is my default implementation lane"). The declaration flips the routing only: the other CLI lane becomes the first fallback, the Opus subagent stays the final fallback, and the spec contract, verification, and review rules apply identically to both lanes.

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

Independent specs (no shared files, no ordering dependency) launch as parallel agents in a single message. Sequential chains and single-file surgery stay serial.

## Commitment boundaries

Consult `fable-advisor` (read-only, verdict in under 300 words) at the moments that decide whether the next hour is wasted:

- Before committing to an architecture, data migration, API shape, or refactor strategy
- Whenever the same problem has resisted two distinct attempts
- Once before declaring a multi-step deliverable done

Pass it the decision, the constraints, the options considered, and the exact file paths to read — it is read-only, and a skeptic is only as good as the code it is pointed at. Act on the verdict or surface the disagreement — never silently ignore it. (If the session itself already runs on Fable, the advisor still earns its keep as a context-clean skeptic reading the actual code.)

## Verification

Reports are claims, not evidence. Before accepting any lane's work: read the diff, and re-run the verification command (or spot-check its quoted output against the working tree). "Should work", "tests should pass", or a report with no command output means the task is not done. A lane that reports a spec gap gets a corrected spec, not a "use your judgment".
