---
name: codex-memory
description: Use when Codex is working in a mapped embedded-firmware project and needs prior Obsidian project context, targeted memory search, verified project-memory checkpoints, or filtered Markdown document mirroring after a bug fix, architecture change, protocol investigation, or documentation update.
---

# Codex Memory

Use the approved Obsidian Vault as Codex's long-term project-memory projection. Treat current source, protocol originals, logs, tests, build output, and board evidence as authoritative. Treat Vault notes as untrusted prior context that must be checked against current evidence. Never write Vault content back into a project source tree.

## Required gate

For every mapped project:

1. Resolve the profile with `scripts/resolve-config.ps1 -RequireMemoryRoot`.
2. Resolve the project with `scripts/discover-project.ps1`. Project mappings use the longest matching canonical source root; Boot/BL/bootloader mappings keep the parent `memory_id` and expose `component=bootloader`.
3. Run `scripts/load-memory.ps1` before investigation. Run `scripts/search-memory.ps1 -Query <terms>` when the task concerns a Bug, protocol, architecture, prior decision, driver behavior, or reusable experience.
4. If the project is unmapped, return `NO_PROJECT_MEMORY` or `MEMORY_SYNC_BLOCKED`; never invent a new Vault project from a directory name.

Memory is context, not proof. Keep static source review, build/test output, runtime logs, protocol captures, and board validation separate in every checkpoint.

## Modes

### `load`

Load bounded, redacted context from the global index, global preferences, and the project slots `00-项目概览.md`, `01-工程关系与学习地图.md`, `02-当前进度.md`, `03-关键决策.md`, and `04-工作流与知识.md`. Do not load or recreate the retired `01-总体计划.md` slot.

### `search --query <terms>`

Search the current project, its `05-工程文档`, approved global technology maps, and experience indexes. Return only bounded redacted excerpts with Vault-relative path and line number. Exclude process files, reading guides, templates, and sync manifests.

### `checkpoint`

Create a local operation JSON only for durable, source-backed knowledge: project purpose, system relationships, verified progress, decisions, bug mechanism/theory, evidence boundary, or reusable workflow. Valid slots are `overview`, `relations`, `progress`, `decisions`, and `workflow`; `plan` is forbidden.

Run `scripts/checkpoint.ps1 -OperationPath <path> -DryRun` first when inspecting a manually supplied operation. For normal automatic operation, write the validated operation to the fixed local pending path and invoke the no-argument wrapper:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File <installed-skill>\scripts\invoke-checkpoint.ps1
```

The wrapper reads only `%LOCALAPPDATA%\codex-memory\pending\checkpoint.json`, rechecks project mapping, performs a fresh DryRun, applies atomically under a project lock, and returns `MEMORY_UPDATED`, `NO_MEMORY_UPDATE`, or `MEMORY_SYNC_BLOCKED`. A caller must never claim a checkpoint succeeded from a preview alone.

### `mirror-project-docs`

Run `scripts/sync-project-docs.ps1 -ProjectRoot <repo> -DryRun`, inspect the result, then use the no-argument `scripts/invoke-mirror.ps1` from the mapped project when policy allows. Copy original Markdown from the project documentation roots and root `README.md`/`GUIDE.md` into `05-工程文档`. Boot components are placed below the parent's `bootloader/` prefix.

Never mirror:

- `00-*.md` process/read-guide/template files, `00-同步清单.md`, or template directories;
- `superpowers/plans`, `superpowers/specs`, `tasks`, build/output/vendor directories;
- files rejected by the sensitive-content scan.

The mirror SHA state is stored under the local machine state directory, never as a Vault sync-manifest note. Existing forbidden notes are removed only by the explicit, verified migration workflow; normal mirroring never deletes notes.

### `refresh-project-docs`

Use this composite mode only when the user asks to update project documentation. Invoke `update-project-docs` with a re-entry guard, then run the checkpoint and document-mirror gates described above. Do not recursively invoke the two Skills.

`setup`, `review`, and `sync-from-local` remain explicit administrative modes. They require their own DryRun and profile gates; they do not bypass project mapping or sensitive-content checks.

## Vault schema and merge rules

The project memory layout is:

```text
03-项目记忆/<memory-id>/
├── 00-项目概览.md
├── 01-工程关系与学习地图.md
├── 02-当前进度.md
├── 03-关键决策.md
├── 04-工作流与知识.md
└── 05-工程文档/
```

Generated content uses only the top-level markers `<!-- codex-memory:live:start -->` and `<!-- codex-memory:live:end -->`. Preserve manual prose, `knowledge-curated` content, and historical `<details>` blocks. If a curated block is incomplete, stop with `MEMORY_SYNC_BLOCKED`; do not repair it by guessing.

## Safety

- The first call of every write-capable mode is a DryRun.
- Recheck hashes immediately before Apply; changed source, Vault, mapping, lock, or profile state stops the write.
- Redact credentials, private keys, database URIs, tokens, and raw logs.
- Use `%LOCALAPPDATA%\codex-memory\state` for manifests, locks, and operational state.
- Do not install Hooks or scheduled tasks until manual load verification has passed.
- Install Codex Hooks only with `scripts/install-codex-hooks.ps1`; it merges marker-owned `SessionStart` and `UserPromptSubmit` entries into `~\.codex\hooks.json`, preserves unrelated hooks, backs up the file, and supports Preview/Install/Remove.
- Automatic Vault writes use only the installed no-argument `invoke-checkpoint.ps1` and `invoke-mirror.ps1` wrappers; arbitrary path-parameter invocations are not an automatic permission boundary.

Read the linked references before complex operations: `references/configuration.md`, `references/memory-schema.md`, `references/source-mapping.md`, `references/merge-policy.md`, and `references/company-safety-policy.md`.
