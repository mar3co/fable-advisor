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
- When the session model is Fable, without being reminded: non-trivial implementation runs the fable-orchestrator architect-as-orchestrator flow — invoke the `fable-orchestrator:orchestration` skill before delegating and follow it as authoritative for routing, verification, review tiers, and advisor consults.
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
is NOT Fable-gated (does not begin "When the session model is Fable") in the
file the user picked, ask one follow-up question: offer to upgrade it to the
gated form, explaining that the unconditional form also fires in non-Fable
(e.g. Opus) sessions.

## Step 3 — Write, idempotently

Touch only the chosen file:

- Create it if missing.
- **Lane line**: if a `fable-orchestrator: implementation lane =` line exists,
  replace it in place; otherwise append the canonical mode line.
- **Trigger** (only when always-on was chosen): if any line referencing
  `fable-orchestrator:orchestration` already exists, do not add another —
  rewrite it to the gated canonical form only if the user accepted the
  upgrade; otherwise append the canonical trigger line.
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
the result. On skip, print the command for later.

Close with a summary: chosen mode and what routes where, scope, always-on
status, doctor result (or the skip note), and a final reminder — start
architect sessions with `/model fable`.
