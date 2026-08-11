[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BackupPath,
    [string]$HooksPath = (Join-Path $env:USERPROFILE '.codex\hooks.json'),
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    if (-not (Test-Path -LiteralPath $HooksPath -PathType Leaf)) { throw "Codex hooks file is absent: $HooksPath" }
    if (-not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) { throw "Hook backup is absent: $BackupPath" }
    $hooksDirectory = (Resolve-Path -LiteralPath (Split-Path -Parent $HooksPath)).Path
    $backupDirectory = (Resolve-Path -LiteralPath (Split-Path -Parent $BackupPath)).Path
    if (-not (Test-CMSamePath -Left $hooksDirectory -Right $backupDirectory)) { throw 'Hook rollback backup must be in the same directory as hooks.json.' }
    $backupObject = Get-Content -LiteralPath $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $backupObject) { throw 'Hook rollback backup is not valid JSON.' }
    $data = @{ hooks_path = $HooksPath; backup_path = $BackupPath; action = 'restore_backup' }
    if ($DryRun) {
        (Get-CMResult -Status 'DRY_RUN' -Message 'Hook rollback preview only; hooks.json was not changed.' -Data $data) | ConvertTo-Json -Depth 8
        exit 0
    }
    $currentBackup = $HooksPath + '.codex-memory.rollback.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.bak'
    [System.IO.File]::Copy($HooksPath, $currentBackup, $false)
    Write-CMAtomicBytes -Path $HooksPath -Bytes ([System.IO.File]::ReadAllBytes($BackupPath))
    (Get-CMResult -Status 'PASS' -Message 'Codex hooks were restored from the selected backup.' -Data ($data + @{ current_backup = $currentBackup })) | ConvertTo-Json -Depth 8
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 8
    exit 1
}
