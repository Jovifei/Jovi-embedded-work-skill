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

function ConvertTo-WindowsCommandLineArgument {
    param([Parameter(Mandatory)][string]$Value)

    if ($Value.Length -eq 0) { return '""' }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Write-ChildClaudeDiagnostics {
    param(
        [string]$Path,
        [hashtable]$Data
    )

    if (-not $Path) { return }
    try {
        $directory = Split-Path -Parent $Path
        if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
        $json = [pscustomobject]$Data | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    } catch {}
}

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
    .PARAMETER TimeoutSeconds
        Hard wall-clock limit for the child process. On expiry, return a
        structured timeout result and terminate the child process tree.
    .PARAMETER DiagnosticsPath
        Optional JSON path for process-level diagnostics. Never contains the
        task text, credentials, or child stdout/stderr content.
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
        [string]$AppendSystemPrompt = "",
        [int]$TimeoutSeconds = 180,
        [string]$DiagnosticsPath = ""
    )

    if ($TimeoutSeconds -lt 1) {
        return [pscustomobject]@{
            Success = $false; Result = "TimeoutSeconds must be at least 1"
            IsError = $true; TimedOut = $false; Profile = $Profile; Resumed = [bool]$ResumeId
            WorkingDirectory = $WorkingDirectory; Stderr = ""; RawStderr = ""
        }
    }

    # Pre-flight: profile exists
    $settingsPath = Join-Path $script:PROFILES_DIR "$Profile.json"
    if (-not (Test-Path $settingsPath)) {
        return [pscustomobject]@{
            Success = $false; Result = "profile not found: $settingsPath"
            IsError = $true; Profile = $Profile; Resumed = [bool]$ResumeId
            WorkingDirectory = $WorkingDirectory; Stderr = ""; RawStderr = ""
        }
    }

    # Hydrate env-var references used by the profile (for example "$MIMO_API_KEY")
    # from persistent User/Machine env into this short-lived PowerShell process.
    $effectiveSettingsPath = $settingsPath
    $tempSettingsPath = ""
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $resolvedSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $hasResolvedRefs = $false
        if ($settings.env) {
            foreach ($prop in $settings.env.PSObject.Properties) {
                $value = [string]$prop.Value
                if ($value.StartsWith('$') -and $value.Length -gt 1) {
                    $varName = $value.Substring(1)
                    if (-not [Environment]::GetEnvironmentVariable($varName, 'Process')) {
                        $persisted = [Environment]::GetEnvironmentVariable($varName, 'User')
                        if (-not $persisted) {
                            $persisted = [Environment]::GetEnvironmentVariable($varName, 'Machine')
                        }
                        if ($persisted) {
                            [Environment]::SetEnvironmentVariable($varName, $persisted, 'Process')
                        }
                    }
                    $resolved = [Environment]::GetEnvironmentVariable($varName, 'Process')
                    if ($resolved) {
                        $resolvedSettings.env.($prop.Name) = $resolved
                        $hasResolvedRefs = $true
                    }
                }
            }
        }
        if ($hasResolvedRefs) {
            $tempSettingsPath = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".json")
            $resolvedJson = $resolvedSettings | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($tempSettingsPath, $resolvedJson, [System.Text.UTF8Encoding]::new($false))
            $effectiveSettingsPath = $tempSettingsPath
        }
    } catch {
        return [pscustomobject]@{
            Success = $false; Result = "failed to read profile settings: $settingsPath"
            IsError = $true; Profile = $Profile; Resumed = [bool]$ResumeId
            WorkingDirectory = $WorkingDirectory; Stderr = $_.Exception.Message; RawStderr = $_.Exception.ToString()
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
        "--settings", $effectiveSettingsPath
    )
    if ($ResumeId) {
        $claudeArgs = @("--resume", $ResumeId) + $claudeArgs
    }
    if ($AppendSystemPrompt) {
        $claudeArgs += @("--append-system-prompt", $AppendSystemPrompt)
    }

    # Use a real process with asynchronous stream reads so the launcher can
    # enforce a wall-clock timeout without blocking on a full output pipe.
    $startedAt = [DateTime]::UtcNow
    $rawStderr = ""
    $raw = ""
    $timedOut = $false
    $launchError = ""
    $terminationError = ""
    $processId = $null
    $exitCode = $null
    $stdoutBytes = 0
    $stderrBytes = 0
    try {
        $claudeCommand = Get-Command claude -ErrorAction Stop
        $claudeExecutable = $claudeCommand.Source
        if ([System.IO.Path]::GetExtension($claudeExecutable) -ieq '.ps1') {
            $nativeExecutable = Join-Path (Split-Path $claudeExecutable -Parent) 'node_modules\@anthropic-ai\claude-code\bin\claude.exe'
            $cmdWrapper = [System.IO.Path]::ChangeExtension($claudeExecutable, '.cmd')
            if (Test-Path $nativeExecutable -PathType Leaf) {
                $claudeExecutable = $nativeExecutable
            } elseif (Test-Path $cmdWrapper -PathType Leaf) {
                $claudeExecutable = $cmdWrapper
            }
        }
        $argumentLine = (($claudeArgs | ForEach-Object { ConvertTo-WindowsCommandLineArgument ([string]$_) }) -join ' ')
        # Start-Process in Windows PowerShell 5.1 can reject an inherited
        # environment that contains both Path and PATH. ProcessStartInfo
        # launches correctly with that environment and preserves redirected IO.
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $claudeExecutable
        $startInfo.Arguments = $argumentLine
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        if ($WorkingDirectory) { $startInfo.WorkingDirectory = $WorkingDirectory }
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        if (-not $process.Start()) { throw 'child process did not start' }
        $processId = $process.Id
        $stdoutReadTask = $process.StandardOutput.ReadToEndAsync()
        $stderrReadTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            try {
                # Run taskkill under cmd.exe so its non-zero exit code cannot
                # escape as a PowerShell terminating error in callers using
                # $ErrorActionPreference = 'Stop'.
                & $env:ComSpec /d /c "taskkill /PID $($process.Id) /T /F >nul 2>nul" | Out-Null
            } catch {
                $terminationError = $_.Exception.Message
            }
            if (-not $process.WaitForExit(5000)) {
                if ($terminationError) { $terminationError += " | " }
                $terminationError += 'child process still running after taskkill grace period'
            }
        }
        if ($process.HasExited) { $exitCode = $process.ExitCode }
        $raw = $stdoutReadTask.Result
        $rawStderr = $stderrReadTask.Result
    } catch {
        $launchError = $_.Exception.Message
    } finally {
        $stdoutBytes = [System.Text.Encoding]::UTF8.GetByteCount($raw)
        $stderrBytes = [System.Text.Encoding]::UTF8.GetByteCount($rawStderr)
        if ($tempSettingsPath -and (Test-Path $tempSettingsPath)) {
            try { [System.IO.File]::Delete($tempSettingsPath) } catch {}
        }
        if ($process) { try { $process.Dispose() } catch {} }
    }

    Write-ChildClaudeDiagnostics -Path $DiagnosticsPath -Data @{
        startedAtUtc = $startedAt.ToString('o')
        completedAtUtc = [DateTime]::UtcNow.ToString('o')
        elapsedMilliseconds = [int]([DateTime]::UtcNow - $startedAt).TotalMilliseconds
        profile = $Profile
        timeoutSeconds = $TimeoutSeconds
        timedOut = $timedOut
        processId = $processId
        exitCode = $exitCode
        stdoutBytes = $stdoutBytes
        stderrBytes = $stderrBytes
        launchError = $launchError
        terminationError = $terminationError
    }

    $rawStderr = $rawStderr.Trim()

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

    if ($launchError) {
        return [pscustomobject]@{
            Success = $false; Result = "failed to start child Claude: $launchError"; Cost = $null; Turns = $null
            ModelUsed = $null; IsError = $true; TimedOut = $false; SessionId = $null
            Profile = $Profile; Resumed = [bool]$ResumeId; WorkingDirectory = $WorkingDirectory
            Stderr = $stderr; RawStderr = $rawStderr
        }
    }

    if ($timedOut) {
        $timeoutMessage = "child Claude timed out after $TimeoutSeconds seconds"
        if ($stderr) { $stderr = "$timeoutMessage`n$stderr" } else { $stderr = $timeoutMessage }
        return [pscustomobject]@{
            Success = $false; Result = $timeoutMessage; Cost = $null; Turns = $null
            ModelUsed = $null; IsError = $true; TimedOut = $true; SessionId = $null
            Profile = $Profile; Resumed = [bool]$ResumeId; WorkingDirectory = $WorkingDirectory
            Stderr = $stderr; RawStderr = $rawStderr
        }
    }

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
            TimedOut  = $false
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
            TimedOut = $false
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
