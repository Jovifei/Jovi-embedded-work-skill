[CmdletBinding(DefaultParameterSetName = 'Preview')]
param(
    [Parameter(ParameterSetName = 'Install')][switch]$Install,
    [Parameter(ParameterSetName = 'Remove')][switch]$Remove,
    [Parameter(ParameterSetName = 'Install')][switch]$ManualLoadVerified,
    [string]$HooksPath = (Join-Path $env:USERPROFILE '.codex\hooks.json'),
    [string]$SkillRoot = (Join-Path $env:USERPROFILE '.codex\skills\codex-memory'),
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'common.ps1')

function New-CMHookCommand {
    param([string]$Mode, [string]$Root)
    $scriptPath = Join-Path $Root 'scripts\memory-hook.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "Installed codex-memory hook script is absent: $scriptPath" }
    return 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '" -Mode ' + $Mode + ' # codex-memory-hook'
}

function Remove-CMOwnedHooks {
    param([AllowEmptyCollection()]$Entries)
    $result = @()
    foreach ($entry in @($Entries)) {
        if ($null -eq $entry) { continue }
        if ($entry.PSObject.Properties.Name -notcontains 'hooks' -or $null -eq $entry.hooks) { $result += $entry; continue }
        $clone = ($entry | ConvertTo-Json -Depth 12 | ConvertFrom-Json)
        $remaining = @($entry.hooks | Where-Object { [string]$_.command -notlike '*codex-memory-hook*' })
        if ($remaining.Count -gt 0) { $clone.hooks = $remaining; $result += $clone }
    }
    return @($result)
}

try {
    if (-not (Test-Path -LiteralPath $HooksPath -PathType Leaf)) { throw "Codex hooks file is absent: $HooksPath" }
    $hooks = Get-Content -LiteralPath $HooksPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $hooks.hooks) { $hooks | Add-Member -Force -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
    foreach ($name in @('SessionStart','UserPromptSubmit')) {
        if ($null -eq $hooks.hooks.$name) { $hooks.hooks | Add-Member -Force -NotePropertyName $name -NotePropertyValue @() }
    }
    $sessionCommand = New-CMHookCommand -Mode 'SessionStart' -Root $SkillRoot
    $promptCommand = New-CMHookCommand -Mode 'UserPromptSubmit' -Root $SkillRoot
    $sessionEntry = [pscustomobject]@{ matcher = 'startup|resume|compact'; hooks = @([pscustomobject]@{ type = 'command'; command = $sessionCommand; timeout = 20; statusMessage = 'Loading codex-memory context' }) }
    $promptEntry = [pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; command = $promptCommand; timeout = 20; statusMessage = 'Checking codex-memory context' }) }
    $sessionEntries = Remove-CMOwnedHooks -Entries $hooks.hooks.SessionStart
    $promptEntries = Remove-CMOwnedHooks -Entries $hooks.hooks.UserPromptSubmit
    $preview = $hooks | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    if ($Remove) {
        $preview.hooks.SessionStart = @($sessionEntries)
        $preview.hooks.UserPromptSubmit = @($promptEntries)
    } else {
        $preview.hooks.SessionStart = @($sessionEntries) + @($sessionEntry)
        $preview.hooks.UserPromptSubmit = @($promptEntries) + @($promptEntry)
    }
    if (-not $Install -and -not $Remove -or $DryRun) {
        (Get-CMResult -Status 'DRY_RUN' -Message 'Codex hook merge preview only; hooks.json was not changed.' -Data @{ hooks_path = $HooksPath; preview = $preview.hooks; config_preview = $preview; marker = 'codex-memory-hook' }) | ConvertTo-Json -Depth 20
        exit 0
    }
    if ($Install) {
        if (-not $ManualLoadVerified) { throw 'Manual load verification is required before Codex hook installation.' }
        $backup = $HooksPath + '.codex-memory.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.bak'
        [System.IO.File]::Copy($HooksPath, $backup, $false)
        Write-CMAtomicJson -Path $HooksPath -Value $preview
        (Get-CMResult -Status 'PASS' -Message 'Codex SessionStart and UserPromptSubmit hooks installed; unrelated hooks preserved.' -Data @{ hooks_path = $HooksPath; backup = $backup; marker = 'codex-memory-hook' }) | ConvertTo-Json -Depth 10
        exit 0
    }
    $remainingSession = Remove-CMOwnedHooks -Entries $hooks.hooks.SessionStart
    $remainingPrompt = Remove-CMOwnedHooks -Entries $hooks.hooks.UserPromptSubmit
    $hooks.hooks.SessionStart = $remainingSession
    $hooks.hooks.UserPromptSubmit = $remainingPrompt
    $backup = $HooksPath + '.codex-memory.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.bak'
    [System.IO.File]::Copy($HooksPath, $backup, $false)
    Write-CMAtomicJson -Path $HooksPath -Value $hooks
    (Get-CMResult -Status 'PASS' -Message 'Only codex-memory hooks were removed; unrelated hooks preserved.' -Data @{ hooks_path = $HooksPath; backup = $backup; marker = 'codex-memory-hook' }) | ConvertTo-Json -Depth 10
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 8
    exit 1
}
