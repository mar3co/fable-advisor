# Changelog

**fable-orchestrator**, originally derived from [DannyMac180/fable-advisor](https://github.com/DannyMac180/fable-advisor) at its 3.1.0 and independently maintained since 2026-07-10 (detached from the fork network). Plugin updates are version-gated — every change ships with a version bump. Entries 3.1.1–3.5.0 below predate the rename, when this project was the fable-advisor fork; 3.5.0 was never published under that name.

## 1.13.0 — 2026-07-13

Root-caused from a field report (an orchestration session, 2026-07-13): a lane wrapper sat unsupervised for ~10 minutes after its wait loop lost the wakeup that should have reaped the detached CLI.

- **`run-lane.sh wait` defaults to 90s and hard-caps any larger explicit value at 90s.** The old 240s default was designed when the harness's only limit was a 10-minute foreground cap. The harness now auto-backgrounds any foreground Bash call after ~2 minutes, so every default wait slice was forcibly converted into a background task mid-call; the wrapper ended its turn hoping the task-completion notification would re-wake it; that wakeup could race turn-end and get lost, leaving the CLI unsupervised indefinitely. Slices at ≤90s stay under the threshold with margin, so they always return synchronously and wrapper liveness no longer depends on any notification. Capping silently is semantically safe: `wait` is always called in a loop by the supervisor-using agents, so slice length is purely an efficiency knob, never a behavior change.
- **Docs failsafe on all five supervisor-using agents** (grok-implementer, codex-implementer, grok-reviewer, codex-reviewer, grok-researcher): if the harness ever auto-backgrounds a wait slice anyway, immediately run a fresh foreground `wait` slice and ignore the backgrounded one's eventual output — never end the turn to wait on a notification. Implementer docs also restate the 90s bound and `SECS / 90` slice budget math.
- **No heartbeat/marker machinery needed.** `wait` already returns `EXITED` immediately when the PID is dead at slice start (field-confirmed), so a late-waking wrapper converges in one step once the race is closed by construction.
- **Smoke test 7** in `scripts/test-run-lane.sh` asserts that an explicit huge `slice-secs` still returns `STILL-RUNNING` inside an 85–115s window against a still-alive 180s fake CLI — proving the cap, not the argument, bounds the slice.

## 1.12.0 — 2026-07-13

Root-caused from two field reports (macOS + Android sessions, 2026-07-13): every real grok implementation task was dying at its first nontrivial shell command.

- **Grok implement lane switches to `--permission-mode bypassPermissions`.** grok CLI 0.2.99's headless permission resolver auto-cancels any `run_terminal_command` it cannot statically classify — `for`/`while` loops, `$VAR` expansion, `export` prefixes (the exact boundary is version-dependent) — and one cancellation kills the whole single-turn run with exit 0 and a narration-only final. That was the true cause of both reported failure signatures ("batched permission cancellation" and "narration-only finals before verification"): 7 real-task deaths across three repos, all on loop/`$VAR`-shaped verification commands, batching irrelevant (solo repros die identically). Live-verified on 0.2.99: `acceptEdits`, `dontAsk`, `auto`, and even `--always-approve` all still cancel; `--allow` rules never match unclassifiable commands; only `bypassPermissions` executes them. Not a security relaxation: the `--deny` rules (`sudo`/`git push`/`curl`/`wget`) were always the real enforcement layer and remain enforced under bypass — a denied command returns a policy error to the model and the run continues. The 1.11.0 claim that "headless runs execute commands regardless of permission mode" was verified on simple commands only and is corrected everywhere it appeared. Review/research lanes were never exposed (their `--tools` allowlists exclude the terminal tool).
- **`doctor.sh` gains a permission canary**: the old LANE-OK live check only exercised the solo-simple-command path, so doctor reported the lane healthy while every real task died. Doctor now also forces a loop/`$VAR` command under the implement lane's exact production flags and fails loudly (with the events.jsonl evidence pointer) if the CLI cancels it. The pass condition is a nonce the command reads from a file whose contents never appear in the prompt — the model cannot fabricate a pass without actually executing, so the canary proves headless execution rather than trusting a self-reported token.
- **`run-lane.sh` records lane exit status**: each CLI now runs in a subshell that appends `EXIT: <code>` to LOG on natural exit (no line means the group was killed), ending the "crashed vs exited cleanly" ambiguity that blocked the field diagnosis. Note the cancellation bug exits 0 — the canary and the wrapper's events.jsonl check are the detectors for that, not the exit code.
- **`grok-implementer.md` names the failure**: on an early/mid-task death with a narration-only final, the wrapper now greps the run's grok session `events.jsonl` for `permission_cancelled` FIRST — a hit is a deterministic CLI bug, so it skips the pointless identical relaunch, goes straight to backstop verify/commit, and names the diagnosis in the report.
- **Worktree lanes and gitignored per-machine config** (Android field report, finding 2): fresh `isolation: "worktree"` checkouts don't carry `local.properties`/`.env`/keystores, so every lane's first build failed. The orchestration skill now tells the architect to provision such files in the spec, and both implementer docs codify the recovery (copy from parent checkout, `git check-ignore`, never stage, note in `GAPS`).
- **Reviewer docs codify blob-reading discipline** (observed improvised by both codex reviewers in the field): when the reviewed commit is not checked out, read cited lines via `git show <sha>:<path>` — never the working tree, whose bytes can differ; the grok reviewer's prompt (no shell in its lane) instead pins the inlined diff as the authoritative bytes. Wrapper spot-checks follow the same rule.
- **Documented lane limitation**: grok auto-loads the repo's `AGENTS.md` and the user's global `~/.claude/CLAUDE.md` as project instructions on every run (verified: no flag, env var, or `--system-prompt-override` disables it on 0.2.99). The implementer doc now warns that the lane is not context-clean of Claude-directed instructions and that specs must restate any constraint that could conflict. Upstream asks (this and the cancellation bug, including the `--always-approve` contract violation) are drafted for xAI.

## 1.11.0 — 2026-07-13

Adopted from field use (#6, #7, #8) plus live-probe findings about what the CLIs actually enforce.

- **The spec contract gains a sixth part: commit ownership** (#8). Lanes commit their own work on the current branch by default once verification passes — the wrapper records the starting HEAD before launch, commits as backstop if the CLI didn't, scopes the commit to the task's files, and both implementer reports gain a required `COMMIT:` field (hash, or an explicit "uncommitted — spec said caller commits"). A verified-but-uncommitted tree can no longer be returned silently as complete. Committing is not shipping: cold review runs on the committed ref, and the architect owns squash/merge at integration.
- **Cold reviewers take REFS, never diff files** (#6). A diff file in a shared directory can be clobbered by a concurrent lane between write and read — a clean review of the wrong bytes is indistinguishable from a real clean review. The codex-review lane now runs `codex exec review` (instructions name the target ref; the CLI derives the diff itself; `sandbox_mode` pinned read-only; `--json` makes LOG a machine-parseable event stream; verified end-to-end on planted bugs, including that instructions-mode scopes to the named commit — the subcommand's `--commit`/`--base` flags are mutually exclusive with custom instructions on codex-cli 0.144.1). The grok reviewer resolves the ref to a SHA and generates the diff directly inside its mktemp'd prompt assembly; both report the resolved ref as the review's identity.
- **Grok lane permissions rebuilt on what is actually enforced.** Live probes on grok 0.2.99 showed `--permission-mode acceptEdits` is parsed but not enforced (headless grok ran `git commit` and network `curl` under it) and `--sandbox read-only` did not block a CWD write on macOS — the README's old safety claim was imaginary. The implement lane now carries enforced `--deny` rules against the obvious forms of `sudo`/`git push`/`curl`/`wget` (documented honestly as a prefix-matched deny-list, not confinement), and the review and research lanes are restricted via enforced `--tools` allowlists with the MCP bridge tools disallowed (allowlists, because grok silently accepts unknown tool names — a denylist typo fails open, live-verified). `acceptEdits` stays for forward-compat only.
- **Narration-of-intent is a task failure by rule** (#7). Grok can run commands headlessly (the old "acceptEdits blocks commands" premise was wrong), so both implementer spec templates now demand pasted verification output — plus the commit hash under lane ownership — as completed actions, and a final message narrating future steps ("running X, then committing") with no captured output is claim-only BY RULE — the wrapper re-runs verification unconditionally.
- `run-lane.sh` rejects empty or non-regular-file specs loudly; smoke tests cover the new codex-review invocation, the grok deny rules, and the per-lane tool restrictions.

## 1.10.0 — 2026-07-12

- **Codex fast mode**: a new optional CLAUDE.md line — `fable-orchestrator: codex fast mode = on` — opts both codex lanes (implementer and reviewer, in every lane mode) into the Codex CLI's fast service tier. Know the trade: ~1.5x output speed for ~2–2.5x credit burn (never cheaper), ChatGPT sign-in required (API-key auth can't use it). The architect forwards it as a `FAST MODE: on` spec line; the wrappers translate that into `LANE_CODEX_FAST=1`, which makes `run-lane.sh` add `-c service_tier=fast -c features.fast_mode=true` (smoke-tested: flags land only under the variable, grok lanes unaffected). Degrade is loud, never fatal: a fast launch that dies early is relaunched once at standard tier and the report carries a `FAST MODE: did not apply` line. `doctor.sh` reads the setting (project scope over user scope) and, when on, live-checks the fast tier — a fast-only failure is a warning with the ChatGPT-sign-in pointer, not a lane failure. Setup gains a fast-mode question (asked right after lane mode, off by default) with idempotent write rules; absence of the line means off.

## 1.9.0 — 2026-07-12

Adopted from field use (#4, #5).

- **Lane wrappers may never end their turn with the CLI alive** (#4, the dangerous mode): all five supervisor-using agents now run every `wait` slice as an explicit FOREGROUND command — backgrounding the wait and "waiting for a notification" is banned by name, because no notification re-wakes a finished agent while the detached CLI keeps editing, committing, or pushing an apparently-settled branch. If a wrapper's turn must end mid-run, it reaps first and reports `partial` honestly.
- **Reap evidence in the report**: `run-lane.sh reap` now confirms the process group is actually dead (`(group dead)` vs a loud `WARNING: group still alive` with exit 1), and both implementer reports gain a required `PROCESS:` field carrying that pasted output — a report without liveness evidence is visibly malformed. Smoke test asserts the confirmation. (Read-only lanes get the foreground rule but not the field: a surviving reviewer can't mutate the tree.)
- **Architect-side backstop** in the skill and README: a lane completion without a structured report is an error state, not a success — check `git status`/`git log`, `pgrep` for surviving lane processes, group-kill them, and re-run any verification performed while a detached process was alive. Checklist item 3 now points here (still seven items — an amendment, not growth).
- **Wrapper reuse bounded**: SendMessage continuation of a lane wrapper is for follow-ups on the same task only, never a long-lived pipe across many tasks — field data shows end-of-task discipline degrading past a couple hundred thousand transcript tokens while judgment still looks fine. Fresh wrapper per task.
- **Early-death retry legalized** (#4 mode A): a CLI that dies within the first minute leaving no diff gets one relaunch with the identical spec, noted in the report; a second early death reports `unavailable` with the evidence. The one-invocation rule states the exception.
- **Grok auth preflight retries once** (#5): a not-authenticated result from `grok models` can be a transient token-refresh race, so all three grok agents retry the check once after ~5s before failing the lane; only a persistent failure reports unavailable, with wording that no longer asserts ``run `grok login` `` as a certain diagnosis. CLI-not-installed stays an immediate no-retry fail. `doctor.sh` grants its grok live check the same single retry.

## 1.8.0 — 2026-07-11

- **`/fable-orchestrator:setup`**: interactive post-install wizard — detects installed CLIs and existing configuration, asks lane mode (grok/codex/mix, every option annotated with CLI status, none hidden), scope (user or project CLAUDE.md), and always-on; writes the two config lines idempotently (replaces an existing lane line in place, never duplicates the trigger, honest "no changes needed" on a no-op re-run); offers a doctor run at the end. Detect-and-warn only: it never installs CLIs, never touches settings.json, and writes to nothing but the one chosen CLAUDE.md.
- **Fable-gated always-on trigger**: the canonical trigger line (written by setup, documented in the README) now begins "When the session model is Fable" — sessions on other models skip the flow instead of running an architect pattern their model wasn't chosen for. Setup detects a pre-existing unconditional trigger and offers to upgrade it in place.
- **`/fable-orchestrator:doctor`**: slash-command wrapper for `scripts/doctor.sh` — plugin installs get lane validation without hunting down the script's cache path (`${CLAUDE_PLUGIN_ROOT}` resolves it). The README points here first, and setup's skip note references it. The README's update instructions also moved into their own section.
- **README restructuring**: "Make it always-on" now shows only the gated trigger (the lane line was a duplicate of "Choose your implementation routing", which it now points to), and a new "Without always-on (per-task trigger)" subsection under "Use it" documents invoking the flow manually.

## 1.7.0 — 2026-07-11

Adopted from field use (#1).

- **Background by default**: new "Waiting on lanes" doctrine section — every lane runs in the background (the Agent tool's default; the doctrine bans forcing `run_in_background: false`), and the architect ends its turn on a one-line status and acts on the completion notification. A synchronous wait buys nothing (a blocked call generates no tokens, and a notification resume costs the same near-fully-cached context re-read) while holding the session hostage to the lane's wall clock — the user can't interject until the turn closes. Synchronous invocation stays available as the rare, announced exception for results that must compose in-turn. Surfaced in the README rules; the checklist stays frozen at seven (it indexes delegation steps, and this governs the wait, not the delegation).

## 1.6.0 — 2026-07-11

Adopted from a fifth external Grok 4.5 review — all four items, one with a design choice.

- **Spike promotion gate** (the design choice: preferred over "security paths are never spikes"): spike status lasts only while the code is throwaway — spike code promoted toward main re-enters the review tiers as normal behavior-bearing work before merge. A hard ban would push legitimate auth prototyping back to informal undeclared downgrades; the gate bans nothing while closing the real leak path. Spike declarations on security/auth paths are flagged as a smell worth one explicit confirmation.
- **Checklist completed and frozen at seven items**: item 4 is now the full review-tier decision (spike/mechanical → verify only; behavior-bearing → opposite-family cold; security → add the silent-failure read), and a new item covers load-bearing research verification. The old item 4 actively contradicted the spike tier, not merely omitted it. Frozen: the checklist is an index, and further growth would turn it into a second dense body.
- **Spikes surfaced in the README** rules section, matching the skill.

## 1.5.0 — 2026-07-11

Partly adopted from a fourth external Grok 4.5 review.

- **Citation spot-check fixed**: reviewers now verify citations against the WORKING TREE, not "exists in the diff" — post-image line numbers usually don't appear as literals in unified diff text, so the old instruction false-flagged good citations.
- **Refutation queue honesty**: the wrapper *flags* citation problems, it doesn't pre-clear them — the skill now says so, and the architect refutes cited findings first, taking `UNCITED` items last as cheap skims. (A hard prefilter that drops uncited findings was rejected: it would violate the reviewers' no-silent-drop rule.)
- **`grok-researcher` on the supervisor**: new `grok-research` lane alias (read-only, 600s default); long scans with a raised `TIMEOUT:` no longer die at the harness's 10-minute foreground wall. `run-lane.sh` now defaults the budget by lane type (600s review/research, 1800s implement).
- **Declared spikes**: a named verification-only tier for caller-declared throwaway/prototype work — declared, never inferred, restated in the report. An honest escape valve beats silent self-downgrade under pressure.
- **Smoke test asserts permissions**: the fake CLIs record argv; tests now lock `workspace-write` for codex implement, `read-only` for codex-review, and no `acceptEdits` for grok-research (five tests, all green).
- Copy fixes: grok-reviewer's body rationale now matches the vs-implementer invariant (was vs-architect); the flowchart's verify node reflects conditional verification; "runs twice" and "one authoritative run" reconciled (producer dev loop + wrapper acceptance when the log is inconclusive); Requirements state the degraded one-CLI bill (grok types, Opus reviews, on Anthropic quota); Parallelism adds worktree isolation with serial merges for heavy fan-out.

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
