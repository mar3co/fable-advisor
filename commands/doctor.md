---
description: Validate the CLI lanes — presence, auth, and model access via one tiny live call per installed CLI — and print the plugin version
---

# fable-orchestrator doctor

Run the doctor script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
```

Relay its full output to the user. If any line reads `FAIL`, point at the fix
it names (`grok login` / `codex login`); if a CLI is missing, point at the
install it names. Do not install, log in, or edit anything — this command only
diagnoses.

Note for the user up front: each live check sends one tiny prompt per
installed CLI — a real but negligible API cost.
