# child-claude skill

Selectively delegate a bounded execution package to a child Claude Code instance running on a cheaper or different model. The parent agent retains planning, scope control, review, integration, and final verification. This skill is not a default delegation mechanism: dispatch only when its expected parent-token savings exceed the dispatch and review cost.

## Install

Copy `child-claude/` into the appropriate global skills root:

- Codex: `%USERPROFILE%\.codex\skills\child-claude`
- Claude Code: `%USERPROFILE%\.claude\skills\child-claude`

Start a fresh task after installation; existing tasks may retain their launch-time skill catalog.

## Profiles

Profiles are under `scripts/profiles/`. They use environment-variable references only; never put a token in a committed profile.

- `deepseek-v4-pro`: Volcengine Ark coding endpoint, requires `VOLCENGINE_CODING_API_KEY`.
- `mimo`: requires `MIMO_TOKEN`.
- `mimo-official`: requires `MIMO_OFFICIAL_TOKEN`.
- `mimo-1m`: requires `MIMO_1M_TOKEN`.

To add a model, copy `_template.json`, use an Anthropic-compatible endpoint, and reference an environment variable for `ANTHROPIC_AUTH_TOKEN`.

## Usage

```powershell
. "$env:USERPROFILE\.codex\skills\child-claude\scripts\Invoke-ChildClaude.ps1"

$result = Invoke-ChildClaude `
  -Task $dispatchSlip `
  -Profile deepseek-v4-pro `
  -WorkingDirectory "E:\repo"
```

Always pass an absolute `-WorkingDirectory` for file work. For a targeted read-only analysis, supply a manifest of no more than five files, use `-AllowedTools "Read,Glob,Grep"`, `-MaxTurns 3`, `-TimeoutSeconds 60`, and optionally `-DiagnosticsPath` for metadata-only timeout diagnostics. Broad inventories belong to the parent agent.

For a write task, explicitly include `Write` or `Edit` in `-AllowedTools`, state the destination paths, and independently review the resulting diff.

## Failure handling

Inspect the complete result object before acting on a failure: `Success`, `TimedOut`, `Turns`, `Result`, `Stderr`, and `RawStderr`. A timeout does not supply usable partial evidence; narrow the package or complete it in the parent rather than blindly retrying.
