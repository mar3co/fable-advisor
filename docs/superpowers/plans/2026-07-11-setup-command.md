# `/fable-orchestrator:setup` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an interactive post-install setup command that configures lane mode, CLAUDE.md scope, and the always-on trigger, per `docs/superpowers/specs/2026-07-11-setup-command-design.md`.

**Architecture:** One new plugin command file (`commands/setup.md`) containing pure markdown instructions that drive a four-step wizard (detect → ask → write idempotently → validate). No scripts or code — the session model executes the instructions using Bash, AskUserQuestion, and file edits. README gains the command as the recommended install step; CHANGELOG and plugin.json carry the 1.8.0 release.

**Tech Stack:** Claude Code plugin command (markdown + YAML frontmatter), bash (detection snippet only), existing `scripts/doctor.sh`.

## Global Constraints

- Version bumps to exactly `1.8.0` in `.claude-plugin/plugin.json` (the only file carrying a version; `marketplace.json` has none). Originally planned as 1.7.0; the background-by-default release claimed that number mid-development.
- The canonical trigger line is Fable-gated: it begins `- When the session model is Fable, without being reminded:` — copied verbatim below. The mode line stays unconditional.
- The wizard must never: write outside the one chosen CLAUDE.md, install or log into a CLI, edit settings.json, check the Claude Code version, probe Fable access, or give API-key guidance.
- Commit messages: plain imperative subject, no AI-attribution trailers of any kind.
- Today's date for CHANGELOG purposes: 2026-07-11.

---

### Task 1: Create `commands/setup.md`

**Files:**
- Create: `commands/setup.md`

**Interfaces:**
- Consumes: `scripts/doctor.sh` (already in repo; invoked via `${CLAUDE_PLUGIN_ROOT}` at runtime).
- Produces: the command file whose canonical config lines Task 2's README section must match verbatim.

- [ ] **Step 1: Write the file**

Create `commands/setup.md` with exactly this content:

````markdown
---
description: Post-install setup wizard — choose your implementation lane mode (grok / codex / mix), pick user- or project-scope CLAUDE.md, optionally make the orchestration flow always-on, and validate the lanes
---

# fable-orchestrator setup

You are running the fable-orchestrator setup wizard. Follow the four steps in
order. Hard rules: write only to the single CLAUDE.md file the user chooses in
step 2; never install a CLI or run its login; never edit settings.json; never
check the Claude Code version, probe model access, or give API-key billing
guidance.

## Canonical lines

These are the only lines this wizard ever writes (only the mode value varies):

```
- When the session model is Fable, without being reminded: non-trivial implementation runs the fable-orchestrator architect-as-orchestrator flow — invoke the fable-orchestrator:orchestration skill before delegating and follow it as authoritative for routing, verification, review tiers, and advisor consults.
- fable-orchestrator: implementation lane = <grok|codex|mix>
```

The trigger is Fable-gated on purpose — sessions on other models read the
condition and skip the flow. The mode line stays unconditional: it is inert
without the trigger.

## Step 1 — Detect

One Bash call, no API usage:

```bash
command -v grok >/dev/null 2>&1 && echo "grok: installed" || echo "grok: missing"
command -v codex >/dev/null 2>&1 && echo "codex: installed" || echo "codex: missing"
for f in "$HOME/.claude/CLAUDE.md" "./CLAUDE.md"; do
  if [ -f "$f" ]; then
    echo "$f: exists"
    grep -n "fable-orchestrator: implementation lane" "$f" || true
    grep -n "fable-orchestrator:orchestration" "$f" || true
  else
    echo "$f: missing"
  fi
done
git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"
```

Present the results as a short status table: one row per CLI (✅ installed /
⚠️ not installed, with the install pointer from step 3), one row per scope
showing what is already configured ("lane = grok, always-on trigger present"
or "— none"). Auth is NOT checked here — that is doctor's job in step 4.

If BOTH scopes carry a lane line, state plainly: project scope wins in this
repo per CLAUDE.md precedence; the user-scope setting applies everywhere else.

## Step 2 — Ask

One AskUserQuestion call with three questions. Wherever the detection found an
existing setting, mark the matching option "(current setting)".

1. **Lane mode** — grok / codex / mix:
   - grok: all implementation → Grok 4.5. Cheapest typing; assurance from
     verification and cross-family review.
   - codex: all implementation → GPT-5.6 Sol at high reasoning. Fewer subtle
     bugs, higher token cost.
   - mix: the architect routes per task — mechanical, spec-determined → grok;
     correctness-critical (concurrency, auth, migrations, subtle state) → codex.
   Annotate every option with detected CLI status. A missing CLI never hides a
   mode — annotate it "CLI not found — this mode would run on its fallback
   chain until you install it"; flag mix when either CLI is missing.
2. **Scope** — user (`~/.claude/CLAUDE.md`, every project on this machine) /
   project (`./CLAUDE.md`, this repo only, overrides user scope here). Show
   existing config on each option. If the working directory is not inside a
   git repository, warn on the project option and recommend user scope.
3. **Always-on** — yes (write trigger + mode line: the flow runs every Fable
   session automatically) / no (mode line only: invoke the
   fable-orchestrator:orchestration skill manually).

If detection found a trigger line that references the orchestration skill but
is NOT Fable-gated (does not contain "When the session model is Fable") in the
file the user picked, ask one follow-up question in a second AskUserQuestion
call (it cannot join the first call — whether it applies depends on the scope
answer): offer to upgrade the line to the gated form, explaining that the
unconditional form also fires in non-Fable (e.g. Opus) sessions.

## Step 3 — Write, idempotently

Touch only the chosen file:

- Create it if missing.
- **Lane line**: if a `fable-orchestrator: implementation lane =` line exists,
  replace it in place; otherwise append the canonical mode line.
- **Trigger** (only when always-on was chosen): an existing trigger means a
  line that functions as a standing always-on instruction to run the flow —
  the canonical forms contain "without being reminded" plus the skill
  reference. A mere mention of fable-orchestrator:orchestration (e.g. a
  per-task usage note) does not count. If no existing trigger, append the
  canonical trigger line. If one exists, never add another — leave it as is,
  or rewrite it in place to the gated canonical form if the user accepted the
  upgrade.
- **No-op re-run**: if the chosen configuration already matches the file, make
  no edit — say "no changes needed" and list what was verified. Never silently
  rewrite a file.
- Show the user exactly what changed (the old and new lines).
- If the chosen mode's CLI is missing, print — never execute — the install and
  login commands: codex — `npm i -g @openai/codex`, then `codex login`;
  grok — install from https://x.ai/cli, then `grok login`.

## Step 4 — Validate

One AskUserQuestion call, recommended option first: run doctor now? Note that
it sends one tiny live prompt per installed CLI — a real but negligible API
cost. On yes, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"` and show
the result. On skip, note they can run `/fable-orchestrator:doctor` any time
later.

Close with a summary: chosen mode and what routes where, scope, always-on
status, doctor result (or the skip note), and a final reminder — start
architect sessions with `/model fable`.
````

- [ ] **Step 2: Verify the file structurally**

Run:
```bash
# from the repo root
head -3 commands/setup.md
grep -c "When the session model is Fable" commands/setup.md
grep -c "CLAUDE_PLUGIN_ROOT" commands/setup.md
grep -n "danger\|--always-approve" commands/setup.md || echo "clean"
```
Expected: line 1 is `---`, line 2 starts `description:`; the Fable-gate count is `2` (canonical block + upgrade check); `CLAUDE_PLUGIN_ROOT` count is `1`; last command prints `clean`.

- [ ] **Step 3: Commit**

```bash
git add commands/setup.md
git commit -m "Add setup command with a four-step configuration wizard"
```

---

### Task 2: README updates

**Files:**
- Modify: `README.md` (sections "Install", "Choose your implementation routing", "Make it always-on")

**Interfaces:**
- Consumes: the canonical lines from Task 1 — the README's "Make it always-on" block must match them word-for-word, modulo line-wrapping (the wizard writes each as a single line; the README displays the trigger wrapped for readability; mode value `grok` as the example).
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Add setup as the recommended step in "Install"**

In `README.md`, replace:

```markdown
Update later with `claude plugin marketplace update fable-orchestrator && claude plugin update fable-orchestrator@fable-orchestrator`. Then start your session as the architect:
```

with:

````markdown
Then run the setup wizard — it detects your CLIs and any existing configuration, asks three questions (lane mode, user- or project-scope CLAUDE.md, always-on or not), writes the config lines idempotently, and offers to validate the lanes:

```
/fable-orchestrator:setup
```

Update later with `claude plugin marketplace update fable-orchestrator && claude plugin update fable-orchestrator@fable-orchestrator`. Then start your session as the architect:
````

- [ ] **Step 2: Note the automation in "Choose your implementation routing"**

Replace:

```markdown
One line in any CLAUDE.md that applies to your session — grok is the default when nothing is declared:
```

with:

```markdown
(`/fable-orchestrator:setup` writes this line for you — this section is the manual path.) One line in any CLAUDE.md that applies to your session — grok is the default when nothing is declared:
```

- [ ] **Step 3: Gate the trigger and note the automation in "Make it always-on"**

Replace:

````markdown
Add two lines to your `CLAUDE.md` (user-level for every project, or per-project) — a standing trigger plus your mode declaration. Don't restate the doctrine itself in `CLAUDE.md`: it lives in the skill, and copies drift.

```
- Every session, without being reminded: non-trivial implementation runs the
  fable-orchestrator architect-as-orchestrator flow — invoke the
  fable-orchestrator:orchestration skill before delegating and follow it as
  authoritative for routing, verification, review tiers, and advisor consults.
- fable-orchestrator: implementation lane = grok
```
````

with:

````markdown
(`/fable-orchestrator:setup` writes these lines for you — this section is the manual path.) Add two lines to your `CLAUDE.md` (user-level for every project, or per-project) — a standing trigger plus your mode declaration. The trigger is gated on the session model, so sessions on other models (e.g. Opus) skip the flow. Don't restate the doctrine itself in `CLAUDE.md`: it lives in the skill, and copies drift.

```
- When the session model is Fable, without being reminded: non-trivial
  implementation runs the fable-orchestrator architect-as-orchestrator flow —
  invoke the fable-orchestrator:orchestration skill before delegating and
  follow it as authoritative for routing, verification, review tiers, and
  advisor consults.
- fable-orchestrator: implementation lane = grok
```
````

- [ ] **Step 4: Verify**

Run:
```bash
grep -c "fable-orchestrator:setup" README.md
grep -c "When the session model is Fable" README.md
grep -c "Every session, without being reminded" README.md
```
Expected: `3` (install block + two manual-path notes), `1`, `0`.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "Document the setup command and gate the always-on trigger to Fable"
```

---

### Task 3: Release chores — CHANGELOG and version bump

**Files:**
- Modify: `CHANGELOG.md` (new entry at top, directly under the intro paragraph)
- Modify: `.claude-plugin/plugin.json:3` (version field)

**Interfaces:**
- Consumes: nothing beyond Tasks 1–2 being committed.
- Produces: version `1.8.0`, which `scripts/doctor.sh` reads from plugin.json at runtime (no change needed there).

- [ ] **Step 1: Add the CHANGELOG entry**

Insert above the `## 1.7.0 — 2026-07-11` heading (the background-by-default entry):

```markdown
## 1.8.0 — 2026-07-11

- **`/fable-orchestrator:setup`**: interactive post-install wizard — detects installed CLIs and existing configuration, asks lane mode (grok/codex/mix, every option annotated with CLI status, none hidden), scope (user or project CLAUDE.md), and always-on; writes the two config lines idempotently (replaces an existing lane line in place, never duplicates the trigger, honest "no changes needed" on a no-op re-run); offers a doctor run at the end. Detect-and-warn only: it never installs CLIs, never touches settings.json, and writes to nothing but the one chosen CLAUDE.md.
- **Fable-gated always-on trigger**: the canonical trigger line (written by setup, documented in the README) now begins "When the session model is Fable" — sessions on other models skip the flow instead of running an architect pattern their model wasn't chosen for. Setup detects a pre-existing unconditional trigger and offers to upgrade it in place.

```

- [ ] **Step 2: Bump the version**

In `.claude-plugin/plugin.json`, change `"version": "1.7.0"` to `"version": "1.8.0"`.

- [ ] **Step 3: Verify**

Run:
```bash
grep '"version"' .claude-plugin/plugin.json
grep -n "## 1.8.0" CHANGELOG.md
bash scripts/doctor.sh 2>/dev/null | head -1
```
Expected: version line shows `1.8.0`; CHANGELOG heading found near the top; doctor's banner prints `v1.8.0` (its live checks may run — only the banner matters here; Ctrl-C/ignore the rest is fine, or accept the calls as a bonus validation).

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "Add the setup wizard, gate the always-on trigger to Fable (1.8.0)"
```

---

### Task 4: Smoke-test the wizard's write logic

No product files change in this task — it exercises the command's detection
snippet and idempotent-write rules against a scratch file, since the command
itself only becomes invocable after a plugin reload.

**Files:**
- Test: scratch file `CLAUDE.md` inside the session scratchpad directory (never inside the repo or `~/.claude`)

**Interfaces:**
- Consumes: the detection snippet and step-3 rules exactly as written in `commands/setup.md` (Task 1).

- [ ] **Step 1: Run the detection snippet verbatim**

Copy the `## Step 1 — Detect` bash block out of `commands/setup.md` and run it from the repo root.
Expected: `grok: installed` / `codex: installed` lines (per this machine), an `exists` line for `$HOME/.claude/CLAUDE.md` with its two grep hits, `./CLAUDE.md: missing`, and the repo path from `git rev-parse`. No errors.

- [ ] **Step 2: Exercise the write rules on a scratch CLAUDE.md**

In the scratchpad directory:
1. Fresh write — create `CLAUDE.md` containing the canonical gated trigger plus `- fable-orchestrator: implementation lane = grok`.
2. Mode switch — apply the "replace in place" rule to change `grok` → `codex`; verify with `grep -c "implementation lane" CLAUDE.md` → `1` (replaced, not appended).
3. No-op re-run — re-apply the same choice; verify the file content hash is unchanged (`shasum` before/after identical).
4. Upgrade path — overwrite the trigger with the old unconditional form (`- Every session, without being reminded: …`), apply the upgrade rule, verify `grep -c "When the session model is Fable" CLAUDE.md` → `1` and `grep -c "Every session" CLAUDE.md` → `0`.

Expected: all four checks pass.

- [ ] **Step 3: Report**

No commit (nothing in the repo changed). State the four results explicitly in the completion report.
