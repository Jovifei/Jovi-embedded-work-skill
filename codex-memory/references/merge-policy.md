# Merge and Sync Policy

For normal archive, project evidence is authoritative. Merge only the managed block; retain manual prose before and after it. Before writes, show a dry-run plan with target paths and hashes. Apply through a same-directory temporary file and atomic replacement under a per-project lock.

For staging sync, state lives at `%USERPROFILE%\.codex-memory\state\<project-id>\_sync-state.json`. Compare staging and vault hashes to the last synced hash for each logical file:

- staging changed, vault unchanged: copy staging to vault;
- staging unchanged, vault changed: preserve vault and refresh baseline;
- both changed but equal: refresh baseline;
- both changed and different: return `CONFLICT` and write nothing.

Recheck hashes immediately before applying. A changed hash, escaped path, missing approved profile, lock contention, template incompatibility, or conflict stops the operation. Never resolve a conflict automatically.

