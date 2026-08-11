[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OperationPath,
    [string]$ProjectRoot,
    [switch]$Apply,
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $operation = ConvertTo-CMObject -Path $OperationPath
    if ($operation.PSObject.Properties.Name -contains 'no_update' -and [bool]$operation.no_update) {
        (Get-CMResult -Status 'NO_MEMORY_UPDATE' -Message 'The caller reported no durable knowledge to archive.' -Data @{ operation_path = $OperationPath }) | ConvertTo-Json -Depth 8
        exit 0
    }
    $memoryId = if ($operation.PSObject.Properties.Name -contains 'memory_id') { ConvertTo-CMSafeId ([string]$operation.memory_id) } else { ConvertTo-CMSafeId ([string]$operation.project_id) }
    if ($ProjectRoot) {
        $project = & (Join-Path $PSScriptRoot 'discover-project.ps1') -ProjectRoot $ProjectRoot | ConvertFrom-Json
        if ($project.status -ne 'PASS') { throw $project.message }
        if ([string]$project.data.memory_id -ne $memoryId) { throw "Project mapping mismatch: operation '$memoryId' does not match discovered '$($project.data.memory_id)'." }
    }
    $preview = & (Join-Path $PSScriptRoot 'apply-sync.ps1') -OperationPath $OperationPath -DryRun | ConvertFrom-Json
    if ($preview.status -ne 'DRY_RUN') {
        (Get-CMResult -Status 'MEMORY_SYNC_BLOCKED' -Message ([string]$preview.message) -Data @{ preview = $preview }) | ConvertTo-Json -Depth 12
        exit 1
    }
    if ($DryRun -or -not $Apply) {
        (Get-CMResult -Status 'DRY_RUN' -Message 'Checkpoint preview completed; no memory files were written.' -Data @{ preview = $preview }) | ConvertTo-Json -Depth 12
        exit 0
    }
    $recheck = & (Join-Path $PSScriptRoot 'apply-sync.ps1') -OperationPath $OperationPath -DryRun | ConvertFrom-Json
    if ($recheck.status -ne 'DRY_RUN') {
        (Get-CMResult -Status 'MEMORY_SYNC_BLOCKED' -Message ([string]$recheck.message) -Data @{ preview = $preview; recheck = $recheck }) | ConvertTo-Json -Depth 12
        exit 1
    }
    $previewFingerprint = ($preview.data.operations | ConvertTo-Json -Depth 10 -Compress)
    $recheckFingerprint = ($recheck.data.operations | ConvertTo-Json -Depth 10 -Compress)
    if ($previewFingerprint -ne $recheckFingerprint) {
        (Get-CMResult -Status 'MEMORY_SYNC_BLOCKED' -Message 'Checkpoint DryRun changed before Apply; retry after reviewing the new plan.' -Data @{ preview = $preview; recheck = $recheck }) | ConvertTo-Json -Depth 12
        exit 1
    }
    $expectedPlanJson = [string]($recheck.data.operations | Select-Object slot,before_hash,after_hash | ConvertTo-Json -Depth 8 -Compress)
    $applied = & (Join-Path $PSScriptRoot 'apply-sync.ps1') -OperationPath $OperationPath -ExpectedPlanJson $expectedPlanJson -Apply | ConvertFrom-Json
    if ($applied.status -ne 'PASS') {
        (Get-CMResult -Status 'MEMORY_SYNC_BLOCKED' -Message ([string]$applied.message) -Data @{ preview = $preview; apply = $applied }) | ConvertTo-Json -Depth 12
        exit 1
    }
    (Get-CMResult -Status 'MEMORY_UPDATED' -Message 'Verified project memory checkpoint applied after a fresh dry-run.' -Data @{ preview = $preview; apply = $applied }) | ConvertTo-Json -Depth 12
} catch {
    (Get-CMResult -Status 'MEMORY_SYNC_BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 8
    exit 1
}
