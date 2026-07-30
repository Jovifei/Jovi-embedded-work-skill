# Source Mapping

Use current repository evidence in this order. Prefer a directly verified newer artifact over an older planning note, and label the evidence level accurately.

1. `docs/README.md`, then `docs/GUIDE.md`
2. root README and explicitly maintained task ledgers
3. Git status, current revision, implementation, tests, and command output
4. existing project memory only as prior context, never as proof

Map by meaning rather than numeric prefixes. Architecture and requirements feed overview; milestones and task ledgers feed plan; test reports and Git evidence feed progress; accepted tradeoffs feed decisions; repeatable verified commands feed workflow. Do not create a slot just to say “none” or infer a percentage without evidence.

Read `/update-project-docs` only as a separate upstream workflow. Call it only in explicit `refresh-project-docs` mode and preserve its confirmation and repository-scope gates.

