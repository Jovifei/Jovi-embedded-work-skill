# Memory Schema

`03-项目记忆/<project-id>/` contains logical slots. `00-项目概览.md` is required when a project is first archived. Create the other slots only for substantive, current evidence.

| Slot | File | Purpose |
| --- | --- | --- |
| overview | `00-项目概览.md` | purpose, scope, current evidence boundary |
| plan | `01-总体计划.md` | ordered remaining milestones |
| progress | `02-当前进度.md` | completed stage, verification and blocker |
| decisions | `03-关键决策.md` | durable choices and reasons |
| workflow | `04-工作流与知识.md` | validated runbook or reusable project knowledge |
| document mirror | `05-工程文档/` | direct, allowlisted Markdown copies from docs/ plus root README/GUIDE; `00-同步清单.md` records hashes and skipped sensitive files |

Agent-generated text belongs only between `<!-- codex-memory:auto:start -->` and `<!-- codex-memory:auto:end -->`. Preserve all manual text outside those markers. Add corrected evidence as a dated replacement or `superseded_by`; do not silently erase historical claims.

Successful archives may write a local event with sanitized `project_id`, goal, completed work, evidence summary, decisions, risks, next actions, relative changed files, and source revision. Events never contain raw source, complete logs, credential material, database URIs, or session transcripts.

For a substantive project archive, retain three distinct layers: curated completed Codex outcomes in progress, the project's real scope/current state in overview, and a traceable summary of the actual project documentation in workflow. The direct copies in `05-工程文档/` support retrieval; they do not replace the evidence summary.
