# =====================================================================
# Invoke-ChildClaude.ps1
# Dispatcher: parent claude (glm-5.2 on Volcengine) - plans and reviews
# Executor: child claude (cheaper model via --settings override) - works
# Token strategy: fresh session by default (prefix cache hits), -ResumeId
#   only when next task depends on previous output. Failed tasks usually
#   redo in a new session to avoid inheriting bad context.
# Override: --settings file beats ~/.claude/settings.json env.
# =====================================================================

$script:SKILL_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:PROFILES_DIR = Join-Path $script:SKILL_DIR "profiles"

function Invoke-ChildClaude {
    <#
    .SYNOPSIS
        Dispatch a task to child claude (cheaper model via --settings override).
    .PARAMETER Task
        Task description with acceptance criteria. Be specific to save tokens.
    .PARAMETER Profile
        Model profile name in scripts/profiles/. Default "mimo".
    .PARAMETER ResumeId
        Session id to resume (for dependent multi-step tasks). Empty = new session.
    .PARAMETER WorkingDirectory
        Directory to run child claude in. If set, must be a valid directory
        (hard-fails otherwise to prevent editing the wrong repo).
    .PARAMETER MaxTurns
        Cap on tool-call turns. Default 5.
    .PARAMETER AllowedTools
        Comma-separated tool whitelist. Keep narrow; state path boundaries in Task.
    .PARAMETER AppendSystemPrompt
        Extra system prompt to constrain child behavior.
    .OUTPUTS
        pscustomobject: Success, Result, Cost, Turns, ModelUsed, SessionId,
                        Profile, Resumed, WorkingDirectory, Stderr, RawStderr
    #>
    param(
        [Parameter(Mandatory, Position = 0)][string]$Task,
        [string]$Profile = "mimo",
        [string]$ResumeId = "",
        [string]$WorkingDirectory = "",
        [int]$MaxTurns = 5,
        [string]$AllowedTools = "Read,Edit,Write,Glob,Grep",
        [string]$AppendSystemPrompt = ""
    )

    # Pre-flight: profile exists
    $settingsPath = Join-Path $script:PROFILES_DIR "$Profile.json"
    if (-not (Test-Path $settingsPath)) {
        return [pscustomobject]@{
            Success = $false; Result = "profile not found: $settingsPath"
            IsError = $true; Profile = $Profile; Resumed = [bool]$ResumeId
            WorkingDirectory = $WorkingDirectory; Stderr = ""; RawStderr = ""
        }
    }

    # Pre-flight: claude CLI in PATH
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            Success = $false; Result = "claude CLI not found in PATH"
            IsError = $true; Profile = $Profile; Resumed = [bool]$ResumeId
            WorkingDirectory = $WorkingDirectory; Stderr = ""; RawStderr = ""
        }
    }

    # Pre-flight: WorkingDirectory must be a valid directory if specified.
    # Hard-fail (not silent fallback) prevents child claude editing the wrong repo.
    if ($WorkingDirectory) {
        if (-not (Test-Path $WorkingDirectory -PathType Container)) {
            return [pscustomobject]@{
                Success = $false
                Result = "WorkingDirectory is not a valid directory: $WorkingDirectory"
                IsError = $true; Profile = $Profile; Resumed = [bool]$ResumeId
                WorkingDirectory = $WorkingDirectory; Stderr = ""; RawStderr = ""
            }
        }
    }

    $claudeArgs = @(
        "-p", $Task,
        "--output-format", "json",
        "--max-turns", $MaxTurns,
        "--allowedTools", $AllowedTools,
        "--settings", $settingsPath
    )
    if ($ResumeId) {
        $claudeArgs = @("--resume", $ResumeId) + $claudeArgs
    }
    if ($AppendSystemPrompt) {
        $claudeArgs += @("--append-system-prompt", $AppendSystemPrompt)
    }

    # Capture stderr to a temp file. PS 5.1 2>&1 wraps native stderr as
    # NativeCommandError (breaks JSON parse); 2>$null hides quota/auth/model
    # errors. Temp file keeps diagnostics for the caller.
    $errFile = [System.IO.Path]::GetTempFileName()
    $pushed = $false
    $rawStderr = ""
    try {
        if ($WorkingDirectory) {
            Push-Location $WorkingDirectory
            $pushed = $true
        }
        $raw = & claude @claudeArgs 2>$errFile | Out-String
    } finally {
        if ($pushed) { Pop-Location }
    }

    if (Test-Path $errFile) {
        $rawStderr = (Get-Content $errFile -Raw).Trim()
        try { [System.IO.File]::Delete($errFile) } catch {}
    }

    # Clean stderr: strip PS NativeCommandError wrapper, keep real error text.
    # RawStderr preserves the original for troubleshooting if cleaning is too aggressive.
    $stderr = $rawStderr
    $stderr = $stderr -replace '(?s)At C:.*?NativeCommandError\s*', ''
    $stderr = $stderr -replace '(?m)^\s*\+.*$', ''
    $stderr = $stderr -replace '(?m)^\s*~\s*$', ''
    $stderr = $stderr -replace '(?s)Warning: no stdin.*?longer\.', ''
    $stderr = $stderr -replace '(?s)a slow command.*?longer\.', ''
    $stderr = $stderr -replace '(?s)no stdin data received.*?longer\.', ''
    $stderr = $stderr -replace '(?m)^\s*claude\.exe\s*:\s*', ''
    $stderr = $stderr -replace "(`r?`n){2,}", "`n"
    $stderr = $stderr.Trim()

    try {
        # Tolerate whitespace: matches {"type":"result" or { "type" : "result"
        $m = [regex]::Match($raw, '\{\s*"type"\s*:\s*"result"')
        if ($m.Success) {
            $raw = $raw.Substring($m.Index).Trim()
        }
        $obj = $raw | ConvertFrom-Json
        $modelUsed = $null
        if ($obj.modelUsage) {
            $modelUsed = ($obj.modelUsage.PSObject.Properties.Name | Select-Object -First 1)
        }
        return [pscustomobject]@{
            Success   = -not [bool]$obj.is_error
            Result    = $obj.result
            Cost      = $obj.total_cost_usd
            Turns     = $obj.num_turns
            ModelUsed = $modelUsed
            IsError   = [bool]$obj.is_error
            SessionId = $obj.session_id
            Profile   = $Profile
            Resumed   = [bool]$ResumeId
            WorkingDirectory = $WorkingDirectory
            Stderr    = $stderr
            RawStderr = $rawStderr
        }
    } catch {
        return [pscustomobject]@{
            Success = $false; Result = $raw; Cost = $null; Turns = $null
            ModelUsed = $null; IsError = $true; SessionId = $null
            Profile = $Profile; Resumed = [bool]$ResumeId
            WorkingDirectory = $WorkingDirectory
            Stderr = $stderr; RawStderr = $rawStderr
        }
    }
}

function Get-ChildClaudeArtifact {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path $Path) { return Get-Content $Path -Raw } else { return "[not found: $Path]" }
}