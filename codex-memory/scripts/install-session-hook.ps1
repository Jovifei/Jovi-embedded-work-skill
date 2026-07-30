[CmdletBinding(DefaultParameterSetName = 'Preview')]
param(
    [Parameter(ParameterSetName = 'Install')][switch]$Install,
    [Parameter(ParameterSetName = 'Remove')][switch]$Remove,
    [Parameter(ParameterSetName = 'Install')][switch]$ManualLoadVerified,
    [string]$SettingsPath = (Join-Path $env:USERPROFILE '.claude\settings.json')
)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) { throw 'Claude settings file is absent; do not create it automatically.' }
    $settings = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $scriptPath = Join-Path $PSScriptRoot 'load-memory.ps1'
    $marker = 'codex-memory-session-load'
    $command = 'powershell.exe -NoProfile -File "' + $scriptPath + '" -Format Context 2>$null # ' + $marker
    if ($null -eq $settings.hooks) { $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
    if ($null -eq $settings.hooks.SessionStart) { $settings.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue @() }
    $sessionStart = @($settings.hooks.SessionStart)
    $matches = @()
    foreach ($entry in $sessionStart) { foreach ($hook in @($entry.hooks)) { if ([string]$hook.command -like "*$marker*") { $matches += $hook } } }
    $data = @{ settings_path = $SettingsPath; existing_session_start_entries = $sessionStart.Count; matching_hooks = $matches.Count; command = $command }
    if ($PSCmdlet.ParameterSetName -eq 'Preview') { (Get-CMResult -Status 'DRY_RUN' -Message 'Hook install preview only; settings were not changed.' -Data $data) | ConvertTo-Json -Depth 8; exit 0 }
    if ($Install) {
        if (-not $ManualLoadVerified) { throw 'Manual load verification is required before hook installation.' }
        if ($matches.Count -eq 0) { $settings.hooks.SessionStart = @($sessionStart) + @([pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; command = $command }) }) }
        $backup = $SettingsPath + '.codex-memory.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.bak'
        [System.IO.File]::Copy($SettingsPath, $backup, $false)
        Write-CMAtomicJson -Path $SettingsPath -Value $settings
        (Get-CMResult -Status 'PASS' -Message 'SessionStart hook merged; existing hooks were preserved and settings were backed up.' -Data @{ backup = $backup; added = ($matches.Count -eq 0) }) | ConvertTo-Json -Depth 7
        exit 0
    }
    $remaining = @()
    foreach ($entry in $sessionStart) {
        $kept = @($entry.hooks | Where-Object { [string]$_.command -notlike "*$marker*" })
        if ($kept.Count -gt 0) { $entry.hooks = $kept; $remaining += $entry }
    }
    $settings.hooks.SessionStart = $remaining
    $backup = $SettingsPath + '.codex-memory.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.bak'
    [System.IO.File]::Copy($SettingsPath, $backup, $false)
    Write-CMAtomicJson -Path $SettingsPath -Value $settings
    (Get-CMResult -Status 'PASS' -Message 'Only codex-memory SessionStart hook entries were removed; unrelated hooks were preserved.' -Data @{ backup = $backup; removed = $matches.Count }) | ConvertTo-Json -Depth 7
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6; exit 1
}

