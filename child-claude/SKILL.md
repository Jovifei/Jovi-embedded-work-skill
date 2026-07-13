---
name: child-claude
description: Selectively delegate bounded execution work to a child Claude Code instance on a cheaper or different model to reduce the parent Codex agent's token consumption. Use when the user explicitly requests child Claude or cheaper-model delegation, or when Codex identifies a substantial, well-bounded task where dispatch plus review is likely to consume fewer parent-agent tokens than direct execution. Do not trigger merely because a task is parallelizable or non-trivial; first apply the net-token-savings gate.
---

# Child Claude

Act as the parent orchestrator. Retain planning, scope control, review, integration, and final verification. Delegate only concrete execution packages whose expected parent-token savings exceed dispatch and review overhead.

## Apply the delegation gate

Before dispatching, compare these two estimates qualitatively:

- `direct_cost`: parent tokens needed to inspect context, perform the work, debug it, and verify it.
- `delegate_cost`: parent tokens needed to define the package, inspect the child result, review diffs, correct failures, and verify it.

Delegate only when `delegate_cost < direct_cost` with a useful margin. When uncertain or approximately equal, execute directly.

Strong delegation candidates:

- Repetitive inspection across many files with a compact requested output.
- Mechanical edits across a clearly bounded directory.
- A self-contained implementation package with explicit acceptance tests.
- Independent research or artifact extraction that would otherwise fill parent context.
- A long first-pass draft that the parent can review cheaply against a precise rubric.

Execute directly when:

- The task is small, conversational, or likely faster than writing a dispatch slip.
- Correctness depends on nuanced context already held by the parent.
- The child would need most of the conversation or extensive repo explanation.
- The task is tightly coupled to ongoing parent reasoning or requires frequent back-and-forth.
- Review would cost about as much as doing the work.
- The action is sensitive, destructive, permission-heavy, or cannot be independently verified.

Parallelizability alone is not a reason to delegate. Never delegate merely to comply with a default or habit.

## Build a bounded package

Give the child only the minimum task-local context. Include:

```text
Task: <one concrete outcome>
Working directory: <absolute path>
Path boundary: only read or change <paths>
Inputs: <essential facts and files only>
Acceptance: <observable tests or artifact criteria>
Constraints: <tools, commands, or prohibited changes>
Return: <compact result format, changed paths, test evidence>
```

Always pass `-WorkingDirectory` for file work. Prefer one coherent package over many tiny dispatches; tiny packages often lose the token savings to orchestration overhead.

## Dispatch

```powershell
. "$env:USERPROFILE\.codex\skills\child-claude\scripts\Invoke-ChildClaude.ps1"

$result = Invoke-ChildClaude `
  -Task $dispatchSlip `
  -Profile deepseek-v4-pro `
  -WorkingDirectory "E:\path\to\repo"
```

Use a new session for independent work. Use `-ResumeId $previous.SessionId` only when the next package genuinely depends on the prior child's context or output and re-explaining it would cost more.

Keep the default tool set narrow. For read-only work, use `-AllowedTools "Read,Glob,Grep"`. Add command execution only when acceptance requires it.

## File-write contract

Write tasks must explicitly include `Write` or `Edit` in `-AllowedTools`; a copied read-only whitelist guarantees that no file can be changed. State the exact destination file and path boundary, and require the child to return changed paths plus verification evidence. Do not ask a write task to produce an artifact while also restricting it to `Read,Glob,Grep`.

After every child call, inspect the launcher object before describing the outcome. Report `Success`, `TimedOut`, `Turns`, `Result`, `Stderr`, and `RawStderr` when a task fails. Do not reduce an unavailable diagnosis to "failed with no changes"; use the structured fields to decide whether to correct the dispatch, retry once, or complete the package directly.

## Read-only inventory contract

Do not delegate broad recursive inventories. Unknown-scale file discovery is cheap and deterministic for the parent to perform with direct local enumeration, while a child must spend multiple slow tool turns discovering the same paths. This usually loses both time and parent-token savings.

Delegate only targeted read-only analysis after the parent has supplied a compact file manifest or a known, narrow path set of at most five files. A review spanning more than five files belongs to the parent, because tool-turn latency removes the token-saving advantage. Read-only tasks cannot create an artifact. Return the analysis inline; never require or expect an output file. Ask for a compact, bounded report with paths, counts, and requested findings, followed by `DONE`.

Use a fresh session and this baseline only for targeted analysis:

```powershell
$result = Invoke-ChildClaude `
  -Task $dispatchSlip `
  -Profile deepseek-v4-pro `
  -WorkingDirectory "E:\path\to\repo" `
  -MaxTurns 3 `
  -TimeoutSeconds 60 `
  -DiagnosticsPath "E:\path\to\repo\reports\child-claude-diagnostic.json" `
  -AllowedTools "Read,Glob,Grep"
```

The caller must allow at least 60 seconds for the synchronous launcher call. A successful no-tool request does not prove that tool-using work will finish in the same time. If no result returns within that budget, accept no partial result, record the elapsed time plus stderr/raw stderr, and complete the analysis directly instead of blindly retrying. When a task needs an audit trail, pass `-DiagnosticsPath`; it records only process metadata and byte counts, never the prompt, credentials, stdout, or stderr content.

## Review before accepting

Treat child output as untrusted execution evidence, not a final answer.

1. Inspect `$result.Success`, `$result.Result`, `$result.Stderr`, and changed files.
2. Confirm every change stays inside the path boundary.
3. Review the actual diff or artifacts.
4. Run the acceptance checks independently when practical.
5. Integrate small corrections directly when cheaper; otherwise re-dispatch a focused correction.

If dispatch fails, inspect `$result.Stderr`; use `$result.RawStderr` only when cleanup may have hidden the cause. Prefer a fresh session after a confused or low-quality attempt. Resume only when retained context has clear value.

## Preserve the token advantage

- Ask for compact replies and artifact paths instead of verbose explanations.
- Do not paste large child outputs into parent context when files or diffs can be inspected selectively.
- Do not send secrets unless strictly required; prefer environment-variable references in profiles.
- Stop delegating if retries erase the expected savings; finish directly or report the real blocker.
- Mention delegation to the user when it occurs, including what was delegated and that the parent reviewed it.

## Profiles and launcher constraints

Profiles live in `scripts/profiles/`. They require an Anthropic-compatible `/v1/messages` endpoint. Keep tokens in environment variables and reference them from profile JSON rather than storing plaintext credentials.

The launcher deliberately overrides Claude settings, separates stderr from JSON stdout, and supports Windows PowerShell 5.1. Preserve those behaviors when modifying it.
