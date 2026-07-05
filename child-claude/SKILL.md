---
name: child-claude
description: Delegate execution work to a child Claude Code instance running on a cheaper/different model (MiMo, DeepSeek, etc) to save tokens. Trigger when the user explicitly mentions child claude / delegation / cheap model / switch model (e.g. "让子claude干"/"派发任务"/"用mimo干"/"换便宜模型"), OR when a task is clearly parallelizable and the user hasn't opted out of delegation. Parent claude plans and reviews; child executes via `claude -p` with `--settings` override.
---

# child-claude: multi-model delegation orchestrator

## What this skill does
When triggered, you (parent claude) enter **orchestration mode**: you push execution to a child claude on a cheaper model, and your job becomes **plan → dispatch → review → iterate**.

- **You (parent)**: split tasks, write dispatch slips, review artifacts, judge pass/fail, do small fixups/integration/verification when that's cheaper than re-dispatch.
- **Child claude**: executes concrete coding/file ops on a cheaper model (default MiMo `mimo-v2.5-pro`), saving tokens.

## Core principle: delegate by default
Once triggered, push execution work to child claude. Do NOT write code or edit files yourself unless one of these is true:
- Task is trivial (one-sentence answer) — answering directly costs less than dispatch overhead.
- Work needs your judgment (architecture, cross-file reasoning) — you think, then dispatch the mechanical part.
- Small deterministic fixups, conflict integration, verification scripts, rolling back a failed sub-task — fine to do directly when faster than re-dispatching.

Your output is **dispatch slips + review verdicts**, not code. But you are not blocked from small integrating/verification work when that's the cheaper path to a correct result.

## Token strategy (read carefully)
Prompt caching makes the system-prefix (~70k tokens of tool defs) billed at cache price (~0.25x). But **history prefixes also bill at cache price — they are not free**. Therefore:

- **Independent task → new session** (default): pay only system-prefix cache price, no history.
- **Dependent task → resume session** (`-ResumeId`): when task B needs task A's output/files, reuse A's `SessionId` to avoid re-explaining context.
- **Failed task → usually new session**: avoid inheriting bad context; only resume if the same session's context helps fix the failure.

Decision rule: does the next subtask need the previous one's output or files? Yes → resume. No → new session. When in doubt, new session — caching already makes it cheap.

## Workflow

### 1. Split the task
Break the user's request into independently verifiable subtasks. For each, write a dispatch slip with:
- **What**: concrete action.
- **Where**: file paths — and a path boundary (only touch files under X).
- **Acceptance**: how to verify (a test that prints "passed", a file to read back).
- **Constraint**: e.g. "only create files, do not run commands" (avoids permission denials burning turns).

### 2. Dispatch
```powershell
. "$env:USERPROFILE\.claude\skills\child-claude\scripts\Invoke-ChildClaude.ps1"

# Independent task — new session, scoped to a working directory
$r = Invoke-ChildClaude -Task "..." -Profile mimo -WorkingDirectory "E:\path\to\repo"

# Dependent task — resume previous session
$r = Invoke-ChildClaude -Task "..." -Profile mimo -ResumeId $prev.SessionId -WorkingDirectory "E:\path\to\repo"
```

Always pass `-WorkingDirectory` when the task touches files — it prevents the child from editing the wrong repo/worktree.

### 3. Review
```powershell
$r | Format-List                    # Success, Result, Cost, ModelUsed, SessionId, WorkingDirectory, Stderr, RawStderr
Get-ChildClaudeArtifact "E:\..."    # read the produced file
# run tests / lint to verify quality
```
If `$r.Success` is false, read `$r.Stderr` (cleaned) for the real cause (quota, auth, model unavailable, CLI arg errors). If Stderr looks truncated or you suspect over-cleaning, read `$r.RawStderr` for the untouched original — stderr is captured to a separate file so JSON parsing stays clean.

### 4. Verdict
- **Pass** → next subtask (new session if independent, `-ResumeId` if dependent).
- **Fail** → re-dispatch with correction note (usually new session; paste what was wrong).

## Switching models (-Profile)
Each `scripts/profiles/<name>.json` is one model config. To add a model:
1. Copy `scripts/profiles/_template.json` → `<name>.json`.
2. Fill `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL` (and the four `ANTHROPIC_DEFAULT_*_MODEL` fields).
3. Call with `-Profile <name>`.

Requirement: the model must expose an **Anthropic-compatible endpoint** (`/v1/messages` style), not just OpenAI-compatible. If you only have OpenAI-compatible, set up `claude-code-router` first as an adapter.

Note: `ANTHROPIC_AUTH_TOKEN` in profile json supports `$VAR_NAME` interpolation (claude code expands it). To avoid committing tokens in plaintext, store the key in an environment variable and reference it as `"$MI_MO_TOKEN"` in the profile.

## Tool whitelist discipline
The default `-AllowedTools` is `Read,Edit,Write,Glob,Grep`. This is intentionally narrow:
- Don't add `Bash` unless the task needs commands — child claude loves to "verify" by running things, which burns turns and hits permission denials.
- State path boundaries explicitly in the Task slip ("only touch files under E:\repo\src").
- For read-only review tasks, use `-AllowedTools "Read,Glob,Grep"`.

## Known traps (do not re-step on these)
1. `~/.claude/settings.json` `env` field overrides process env vars → must use `--settings <file>` to override; setting `$env:` alone does nothing.
2. PowerShell 5.1 reads UTF-8-without-BOM `.ps1` as GBK → garbles Chinese comments, breaks parse. Keep scripts English-commented + BOM.
3. PS 5.1 `2>&1` wraps native stderr as `NativeCommandError` → breaks `ConvertFrom-Json`. This skill captures stderr to a temp file instead and parses only stdout.
4. Without `-WorkingDirectory`, child claude runs in the parent's cwd and may edit the wrong repo — always pass it for file tasks.

## Dispatch slip template
```
Task: <concrete description>
Path: <file path(s)>
Path boundary: only touch files under <dir>
Acceptance: <verifiable criterion, e.g. "test_x.py prints 'all tests passed'">
Constraint: <e.g. "only create files, do not execute commands">
Reply only: DONE
```

## Quick reference
| Want | Do |
|---|---|
| Dispatch a task | `Invoke-ChildClaude -Task "..." -WorkingDirectory "..."` |
| Use a different model | `-Profile <name>` (default `mimo`) |
| Continue a previous task | `-ResumeId $prev.SessionId` |
| Limit tool use | `-AllowedTools "Read,Write"` |
| Cap turns | `-MaxTurns 5` |
| Read what child produced | `Get-ChildClaudeArtifact "<path>"` |
| Diagnose a failure | read `$r.Stderr` (clean) or `$r.RawStderr` (raw) |
