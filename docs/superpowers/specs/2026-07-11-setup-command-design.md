# `/fable-orchestrator:setup` — post-install setup wizard

**Date:** 2026-07-11
**Status:** approved design, pre-implementation

## Purpose

One command that takes a fresh install to a working configuration: pick the
implementation lane mode, choose where the configuration lives, optionally make
the flow always-on, and optionally validate the lanes — replacing the README's
manual "Choose your implementation routing" and "Make it always-on" steps.

## Artifact

One new file: `commands/setup.md`. Pure markdown instructions for the session
model (frontmatter `description` for the `/`-menu); no scripts, no code.
Invoked as `/fable-orchestrator:setup` (namespaced; `/setup` when unambiguous).

## Wizard flow

### Step 1 — Detect (one Bash call, no API usage)

- `command -v grok`, `command -v codex` — CLI presence only (auth is doctor's job).
- Existence and current content of `~/.claude/CLAUDE.md` (user scope) and
  `./CLAUDE.md` (project scope): any `fable-orchestrator: implementation lane =`
  line and any always-on trigger referencing the orchestration skill.

Present the results as a status table (CLI rows with ✅/⚠️, config rows showing
what is already set where). If both scopes carry a lane line, state that project
scope wins per CLAUDE.md precedence.

Explicitly excluded: no Claude Code version check; no Fable-access probing or
API-key-user guidance.

### Step 2 — Ask (one AskUserQuestion call, three questions)

1. **Lane mode** — grok / codex / mix. Each option annotated with detected CLI
   status ("codex CLI not found — this mode would run on its fallback chain
   until you install it"; mix flagged if either CLI is missing). No mode is
   hidden. Currently-configured mode marked "(current setting)".
2. **Scope** — user (`~/.claude/CLAUDE.md`, all projects) / project
   (`./CLAUDE.md`, this repo). Options show existing config where present.
3. **Always-on** — add the standing trigger line, or write only the mode line.

### Step 3 — Write, idempotently

- Create the target CLAUDE.md if missing.
- Replace an existing `fable-orchestrator: implementation lane =` line in the
  chosen file rather than appending a second.
- Skip the trigger if an equivalent one is already present — any line in the
  target file referencing the `fable-orchestrator:orchestration` skill counts.
- If nothing changes (re-run with same choices), say "no changes needed" and
  list what was verified — never silently rewrite.
- Lines written are exactly the two from the README's "Make it always-on"
  section (trigger + mode declaration).
- Missing CLIs: print install/login commands (`npm i -g @openai/codex` +
  `codex login`; https://x.ai/cli + `grok login`) — never execute them.

### Step 4 — Validate (opt-in, default yes)

Offer `bash scripts/doctor.sh` via AskUserQuestion, noting it sends one tiny
live prompt per installed CLI. Run it on yes; on skip, print the command for
later. Close with a summary (mode, scope, always-on, doctor status) and a
reminder to start architect sessions with `/model fable`.

## Edge cases

- **Re-run to switch modes:** lane line replaced in place, not duplicated.
- **Project scope outside a git repo / project root unclear:** warn and offer
  user scope instead.
- **Both scopes configured with different modes:** wizard states that project
  wins in this repo and user scope applies elsewhere.

## Out of scope (considered, rejected)

- Installing or logging into CLIs on the user's behalf (detect + warn only).
- Editing `settings.json` permissions to pre-authorize lane commands.
- Claude Code version check.
- Fable-access detection or `/model opus` fallback guidance for API-key users.

## Also touched

- **README:** "Install" section gains a line pointing at
  `/fable-orchestrator:setup` as the easy path; manual instructions stay.
- **CHANGELOG:** new entry.
- **plugin.json:** version bump to 1.7.0.

## Testing

Manual: run the command fresh (no config), as a re-run (config present, same
choices → "no changes needed"), and as a mode switch (line replaced, not
appended). Verify no writes occur outside the chosen CLAUDE.md.
