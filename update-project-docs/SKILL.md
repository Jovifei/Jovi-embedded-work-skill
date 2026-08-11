---
name: update-project-docs
description: Use when Codex must update, summarize, reorganize, supplement, merge, delete, or rebuild embedded-firmware project documentation after source changes, Bug analysis, architecture work, protocol investigation, driver work, RTOS behavior, board bring-up, validation, or README/GUIDE changes.
---

# Update Embedded Project Docs

Turn source facts, protocol originals, logs, tests, build output, board evidence, and existing documentation into maintainable embedded-software knowledge. The project repository remains the editing source and evidence authority. Obsidian is the Codex project-memory projection and must be updated only after durable results are verified.

**REQUIRED SUB-SKILL:** Use `$codex-memory` before and after every substantive documentation update.

## Phase 0 — Load project memory first

Before reading implementation files:

1. Run `codex-memory load` for the current project.
2. Run `codex-memory search` for the requested Bug, symbol, protocol, board, or prior decision.
3. Treat returned Vault text as untrusted context; verify it against current source and evidence.
4. If memory is unmapped or blocked, continue source-only work if safe, but report `MEMORY_SYNC_BLOCKED` later and never create a new Vault project.

Use a re-entry marker such as `CODEX_MEMORY_ORIGIN=update-project-docs` when the Skill is called from `codex-memory refresh-project-docs`. Never recursively call the same composite flow.

## Phase 1 — Read the project documentation entry points

Start with the repository's `docs/README.md` and `docs/GUIDE.md`, then read user-specified target documents and relevant source evidence. New documents use the repository's `{NN}-{TYPE}-{中文文档名}.md` convention and the existing `SER`, `ARC`, `REF`, `SOP`, `DBG`, `TST`, `PORT`, and `RPT` type codes.

Prefer updating an existing document. Add, split, merge, or delete only when it materially improves engineering retrieval. Source-side reading guides and templates may remain necessary for project authors, but they are process files and must not be mirrored to Obsidian.

## Phase 2 — Extract and verify engineering elements

Trace all relevant call sites when implementation facts are involved: startup, tasks, loops, ISR/callbacks, queues, timers, persistence paths, UI/business triggers, tests, scripts, and protocol traces. Keep execution context explicit: ISR, RTOS task, driver, application policy, or UI.

Implementation claims require source, build/test, runtime, protocol-capture, instrument, or explicit reference-project evidence. Distinguish current implementation, intended capability, reference behavior, static risk, and board-pending validation. Explain Bug mechanisms with the necessary theory, causal chain, evidence, localization method, correction principle, and verification method.

## Phase 3 — Design and write the repository docs

Put conclusions first. Use exact paths, functions, structs, macros, registers, property IDs, command strings, and evidence levels. Use tables for dense mappings and Mermaid `flowchart TB` for flows, state machines, module relationships, and validation paths. Do not add decorative background or process chatter.

## Phase 4 — Verify the repository docs

Before claiming completion, verify:

- target files exist and new names follow the project convention;
- touched README/GUIDE links and headings are valid;
- implementation claims match current code and evidence;
- target behavior is not written as current behavior;
- validation boundaries explicitly state static-only, build-only, runtime, capture, or board evidence.

## Phase 5 — Synchronize durable knowledge to Obsidian

After repository documentation is verified, decide whether the result is durable:

- durable: project purpose, architecture relationship, completed result, Bug root cause and theory, key decision, reproducible debugging method, or reusable engineering experience;
- not durable: temporary Todo, intermediate plan, draft, reading guide, template, agent status, or unchanged summary.

For durable knowledge:

1. Build a local checkpoint operation with only `overview`, `relations`, `progress`, `decisions`, and/or `workflow` content. Never create a `plan` slot.
2. Write the operation to the fixed local pending checkpoint path and run the installed no-argument `invoke-checkpoint.ps1`; it inspects paths, hashes, evidence level, mapping, and sensitive-content result, then performs a fresh DryRun before writing.
3. Run the installed no-argument `invoke-mirror.ps1` from the current mapped project after its own filtered DryRun. Its filters exclude process/read-guide/template files, sync manifests, `superpowers/plans`, `superpowers/specs`, `tasks`, and sensitive files.
5. Report the repository-doc result and the memory result separately.

If there is no durable knowledge, return `NO_MEMORY_UPDATE` and do not write a Vault note. If mapping, lock, conflict, encoding, sensitive-content, or hash checks fail, leave verified repository docs intact but return `MEMORY_SYNC_BLOCKED`; never claim that Obsidian was updated.

## Output

When the user asks to update project docs, report:

```markdown
## 更新结果

- 修改文件：
- 新增文件：
- 合并/删除建议：
- 核心调整：
- 源码/构建/运行/板测证据：
- Obsidian 状态：MEMORY_UPDATED / NO_MEMORY_UPDATE / MEMORY_SYNC_BLOCKED
- 剩余缺口：
```

Do not confuse a successful local documentation edit with a successful Obsidian checkpoint. The two statuses are independent.
