[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $projectRoot = (Get-Location).Path
    $preview = & (Join-Path $PSScriptRoot 'sync-project-docs.ps1') -ProjectRoot $projectRoot -DryRun | ConvertFrom-Json
    if ($preview.status -ne 'DRY_RUN') {
        (Get-CMResult -Status 'MEMORY_SYNC_BLOCKED' -Message ([string]$preview.message) -Data @{ preview = $preview }) | ConvertTo-Json -Depth 12
        exit 1
    }
    if ([int]$preview.data.copy_count -eq 0) {
        (Get-CMResult -Status 'NO_MEMORY_UPDATE' -Message 'No new or changed project Markdown was selected for mirroring.' -Data @{ preview = $preview }) | ConvertTo-Json -Depth 12
        exit 0
    }
    $applied = & (Join-Path $PSScriptRoot 'sync-project-docs.ps1') -ProjectRoot $projectRoot -Apply | ConvertFrom-Json
    if ($applied.status -ne 'PASS') {
        (Get-CMResult -Status 'MEMORY_SYNC_BLOCKED' -Message ([string]$applied.message) -Data @{ preview = $preview; apply = $applied }) | ConvertTo-Json -Depth 12
        exit 1
    }
    (Get-CMResult -Status 'MEMORY_UPDATED' -Message 'Project Markdown mirror applied after a fresh DryRun.' -Data @{ preview = $preview; apply = $applied }) | ConvertTo-Json -Depth 12
} catch {
    (Get-CMResult -Status 'MEMORY_SYNC_BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 8
    exit 1
}
