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

For a file-write package, set `-WorkingDirectory` to the common parent directory of every target whenever possible. This makes the target boundary native to Claude CLI and avoids a cross-directory permission wait. If a bounded task genuinely must read or write outside that directory, pass only those existing directories through `-AdditionalDirectories`; the launcher forwards them as Claude CLI `--add-dir` permissions. Do not rely on a natural-language path boundary to authorize a directory outside `WorkingDirectory`.

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

## 30-second liveness checks, 90-second completion boundary, and parent fallback

For every package that passes the delegation gate, use a 30-second liveness check and a 90-second overall timeout for each child attempt. This is a bounded dispatch policy, not an excuse for repeated blind retries.

1. Launch the child with `-WatchdogIntervalSeconds 30`, `-TimeoutSeconds 90`, and a distinct `-DiagnosticsPath` for the attempt.
2. At every watchdog check, confirm that the process is still alive. Claude CLI commonly writes its JSON only on completion, so no stdout at 30 seconds is not by itself evidence of a hang.
3. If it returns a successful, structured result inside the overall timeout, review and verify it normally.
4. Classify diagnostics before retrying: a non-empty `launchError` is a launch failure; a completed process without valid JSON is a malformed-result failure; a process killed at the 90-second boundary is a completion timeout. An alive process with no output at a 30-second liveness check is only `running`, because final-only JSON output has no streaming completion signal.
5. For a timeout or failed result, record `Success`, `TimedOut`, `Turns`, `Result`, `Stderr`, `RawStderr`, process id, launch error, elapsed time, and the diagnostics file. Treat it as one failed attempt and accept no partial output.
6. Re-dispatch the same bounded package in a fresh session. Do not resume a failed session or silently broaden its scope.
7. After three consecutive failed attempts for that package, stop delegating and execute it directly in the parent. Tell the user that the parent took over, then run the original acceptance checks.

The synchronous caller must allow at least 100 seconds per attempt to accommodate the 90-second overall timeout and bounded cleanup grace period. A living process that has not produced an accepted structured result at a 30-second watchdog check remains in progress; it is not evidence of a hang, launch failure, or acceptable partial work.

Run one child at a time per machine/profile. Do not fan out independent packages with `Start-Job`, `ForEach-Object -Parallel`, or simultaneous shells: upstream providers can rate-limit the burst, while Claude CLI may wait internally and appear as a misleading 90-second completion timeout. The launcher fails a second simultaneous request immediately with `child Claude dispatch busy`.

If a fresh no-tool smoke that previously worked begins timing out, stop child retries and perform one minimal authenticated HTTP probe against the configured `/v1/messages` endpoint. A `429` means upstream rate limiting: do not retry, wait for the provider window or let the parent execute the work. A `401` means credentials must be repaired. Do not treat either response as an isolation fault.

## File-write contract

Write tasks must explicitly include `Write` or `Edit` in `-AllowedTools`; a copied read-only whitelist guarantees that no file can be changed. State the exact destination file and path boundary, and require the child to return changed paths plus verification evidence. Do not ask a write task to produce an artifact while also restricting it to `Read,Glob,Grep`.

An external write path needs two independent controls: include `Write` or `Edit` in `-AllowedTools`, and either make its common parent the `-WorkingDirectory` or grant its parent explicitly with `-AdditionalDirectories`. If either is absent, keep the edit in the parent rather than retrying a child that may wait for headless permission approval.

Headless child sessions cannot reliably surface a Claude CLI approval prompt to the Codex user. Before enabling automatic child edits, obtain the user's approval for the exact destination directories and the exact write scope. Then, and only then, pass `-PermissionMode acceptEdits`. Keep the default permission mode for read-only work or unapproved writes. Never use `bypassPermissions`; `acceptEdits` is limited to the already-approved package and does not replace parent diff review.

```powershell
# User-approved write package: exact target scope and parent directory already stated.
$result = Invoke-ChildClaude `
  -Task $dispatchSlip `
  -Profile deepseek-v4-pro `
  -WorkingDirectory "E:\approved\target-parent" `
  -PermissionMode acceptEdits `
  -AllowedTools "Read,Edit,Write,Glob,Grep"
```

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
  -WatchdogIntervalSeconds 30 `
  -TimeoutSeconds 90 `
  -DiagnosticsPath "E:\path\to\repo\reports\child-claude-diagnostic-attempt-1.json" `
  -AllowedTools "Read,Glob,Grep"
```

Use the three-attempt watchdog above rather than a blind retry. When a task needs an audit trail, pass `-DiagnosticsPath`; it records only process metadata and byte counts, never the prompt, credentials, stdout, or stderr content.

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

The launcher deliberately isolates the child from user/project/local Claude settings and external MCP configuration, then loads only its explicit profile. This prevents global hooks, plugins, and MCP startup from consuming the bounded completion window. It also separates stderr from JSON stdout and supports Windows PowerShell 5.1. Preserve those behaviors when modifying it.
