# child-claude skill

Delegate execution work to a child Claude Code instance running on a cheaper model (MiMo, DeepSeek, etc). Parent claude plans and reviews; child executes.

## Files
- `SKILL.md` — instructions Claude reads when the skill triggers
- `scripts/Invoke-ChildClaude.ps1` — dispatcher function
- `scripts/profiles/mimo.json` — MiMo config (ready to use)
- `scripts/profiles/_template.json` — blank template for new models

## Usage
```powershell
. "$env:USERPROFILE\.claude\skills\child-claude\scripts\Invoke-ChildClaude.ps1"

# new session
Invoke-ChildClaude -Task "write X to Y" -Profile mimo

# resume session (dependent task)
Invoke-ChildClaude -Task "add Z to Y" -Profile mimo -ResumeId $prev.SessionId
```

## Add a model
1. Copy `scripts/profiles/_template.json` → `<name>.json`
2. Fill the three values (token, base_url, model) — model needs an Anthropic-compatible endpoint
3. Call `-Profile <name>`

## Token strategy
- Independent task → new session (default). Prompt caching bills the system prefix at ~0.25x; no history cost.
- Dependent task → `-ResumeId`. Reuses previous session to avoid re-explaining context.

## Traps already solved
- `settings.json` env overrides process env → use `--settings` file
- PS 5.1 UTF-8 BOM required for `.ps1` with non-ASCII
- PS 5.1 `2>&1` breaks JSON parse → `2>$null` + extract `{"type":"result"`
