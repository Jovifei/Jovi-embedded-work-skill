# Memory Schema v2

`03-项目记忆/<memory-id>/` contains durable project knowledge and original project documents.

| Slot | File | Purpose |
| --- | --- | --- |
| overview | `00-项目概览.md` | project purpose, scope, current role, and evidence boundary |
| relations | `01-工程关系与学习地图.md` | relationships with Boot/BL/related projects and reusable learning paths |
| progress | `02-当前进度.md` | completed work, verification evidence, and unresolved boundaries |
| decisions | `03-关键决策.md` | durable technical choices and their reasons |
| workflow | `04-工作流与知识.md` | verified debugging methods, theory, runbooks, and transferable experience |
| document mirror | `05-工程文档/` | filtered, direct Markdown copies from project documentation roots and root README/GUIDE |

`01-总体计划.md` is retired and must not be created by new operations. Plans, Todo files, reading guides, templates, agent status, and sync manifests are process data, not project memory.

Generated content belongs only between `<!-- codex-memory:live:start -->` and `<!-- codex-memory:live:end -->`. Preserve manual prose, `knowledge-curated` blocks, and historical details. A live block may be appended after historical content, never inserted inside a historical `<details>` block.

Mirror hashes and skipped-file reasons live under `%LOCALAPPDATA%\codex-memory\state\documents\<memory-id>\mirror.json`; no manifest note is generated in the Vault.
