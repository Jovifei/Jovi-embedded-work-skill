# child-claude skill

Delegate execution work to a child Claude Code instance running on a cheaper/different model (MiMo, DeepSeek, etc). Parent claude plans and reviews; child executes. Token-saving multi-model orchestration.

## Files
- `SKILL.md` — instructions Claude reads when the skill triggers
- `scripts/Invoke-ChildClaude.ps1` — dispatcher function
- `scripts/profiles/mimo.json` — MiMo config (token via `$MIMO_TOKEN` env var)
- `scripts/profiles/mimo-official.json` — MiMo official API (token via `$MIMO_OFFICIAL_TOKEN`)
- `scripts/profiles/_template.json` — blank template for new models

## Install
1. Copy `child-claude/` into `~/.claude/skills/` (Windows: `%USERPROFILE%\.claude\skills\`)
2. Set token env vars (PowerShell, current session):
   ```powershell
   $env:MIMO_TOKEN = "tp-..."            # for mimo profile
   $env:MIMO_OFFICIAL_TOKEN = "sk-..."   # for mimo-official profile
   ```
   Or `setx MIMO_TOKEN "tp-..."` for permanent. Or edit the profile json to put the token directly (local only — do not commit).
3. Trigger via `/child-claude` or natural language ("用 mimo 干 X", "派给子 claude", "delegate to child claude")

## Usage
```powershell
. "$env:USERPROFILE\.claude\skills\child-claude\scripts\Invoke-ChildClaude.ps1"

# new session, scoped to a working directory
Invoke-ChildClaude -Task "write X to Y" -Profile mimo -WorkingDirectory "E:\repo"

# resume session (dependent task)
Invoke-ChildClaude -Task "add Z" -Profile mimo -ResumeId $prev.SessionId -WorkingDirectory "E:\repo"
```

Always pass `-WorkingDirectory` for file tasks — it hard-fails if the path is invalid (prevents editing the wrong repo).

## Returns
`Success, Result, Cost, Turns, ModelUsed, SessionId, Profile, Resumed, WorkingDirectory, Stderr (cleaned), RawStderr (raw)`

On failure: read `$r.Stderr` (cleaned) for the cause. If it looks truncated, check `$r.RawStderr` (untouched original).

## Pre-flight checks (hard-fail, no silent fallback)
- profile json exists
- claude CLI in PATH
- WorkingDirectory is a valid directory

## Switch models (-Profile)
1. Copy `scripts/profiles/_template.json` -> `<name>.json`
2. Fill `ANTHROPIC_AUTH_TOKEN` (or `$VAR_NAME` env ref), `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL` (+ four `ANTHROPIC_DEFAULT_*_MODEL`)
3. Call `-Profile <name>`

Requirement: the model must expose an Anthropic-compatible endpoint. OpenAI-compatible only -> set up `claude-code-router` first as an adapter.

## Token strategy
- **Independent task -> new session** (default). Prompt caching bills the system prefix at ~0.25x; no history cost.
- **Dependent task -> `-ResumeId`**. Reuses previous session to avoid re-explaining context.
- **Failed task -> usually new session** to avoid inheriting bad context.

## Known traps (solved in this skill)
1. `~/.claude/settings.json` `env` field overrides process env vars -> use `--settings <file>` to override
2. PS 5.1 reads UTF-8-without-BOM `.ps1` as GBK -> scripts are English-commented + BOM
3. PS 5.1 `2>&1` wraps native stderr as NativeCommandError -> stderr captured to temp file; `Stderr` cleaned, `RawStderr` preserved
4. Without `-WorkingDirectory`, child runs in parent's cwd -> hard-fail if invalid