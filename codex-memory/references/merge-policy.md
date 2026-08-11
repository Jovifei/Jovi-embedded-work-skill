# Merge Policy v2

Current project evidence is authoritative. Before every write, build and inspect a DryRun with target paths, before/after hashes, evidence level, and filtered document list.

Generated summary text may replace only the managed `<!-- codex-memory:live:start -->` … `<!-- codex-memory:live:end -->` block. Preserve manual prose, `<!-- knowledge-curated:start -->` … `<!-- knowledge-curated:end -->`, and historical `<details>` blocks. If a managed or curated block is incomplete, stop.

Apply through a same-directory temporary file and atomic replacement under a per-project lock. Recheck configuration, project mapping, source/Vault hashes, approved root, sensitive-content scan, and lock immediately before Apply. Never resolve divergent changes automatically.

Document mirrors copy source bytes and record hashes in local machine state. They never create a Vault sync manifest and never delete an existing note during normal refresh. Explicit migration may move process notes to the Windows Recycle Bin only after a complete DryRun and link verification.
