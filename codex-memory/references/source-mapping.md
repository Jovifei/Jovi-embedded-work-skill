# Source Mapping

Use current repository evidence in this order. Prefer a directly verified newer artifact over an older planning note, and label the evidence level accurately.

1. all allowlisted Markdown below `docs/`, with `docs/README.md` and `docs/GUIDE.md` read first
2. root README, root GUIDE, and explicitly maintained task ledgers
3. Git status, current revision, implementation, tests, and command output
4. existing project memory only as prior context, never as proof

Map by meaning rather than numeric prefixes. Architecture and requirements feed overview; milestones and task ledgers feed plan; test reports and Git evidence feed progress; accepted tradeoffs feed decisions; repeatable verified commands feed workflow. Summarize the actual project docs in the workflow note, then mirror the safe Markdown originals to `05-工程文档/` with source-relative paths and hashes. Do not replace the summary with an external path or link, create a slot just to say “none”, or infer a percentage without evidence.

Read `/update-project-docs` only as a separate upstream workflow. Call it only in explicit `refresh-project-docs` mode and preserve its confirmation and repository-scope gates.
