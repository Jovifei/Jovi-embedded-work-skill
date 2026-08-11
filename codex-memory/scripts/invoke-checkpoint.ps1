[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $pendingPath = Join-Path (Join-Path (Get-CMLocalRoot) 'pending') 'checkpoint.json'
    if (-not (Test-Path -LiteralPath $pendingPath -PathType Leaf)) {
        (Get-CMResult -Status 'NO_MEMORY_UPDATE' -Message 'No pending durable checkpoint exists.' -Data @{ pending_path = $pendingPath }) | ConvertTo-Json -Depth 8
        exit 0
    }
    $operation = ConvertTo-CMObject -Path $pendingPath
    if (-not $operation.project_root) { throw 'Pending checkpoint must contain project_root.' }
    $project = & (Join-Path $PSScriptRoot 'discover-project.ps1') -ProjectRoot ([string]$operation.project_root) | ConvertFrom-Json
    if ($project.status -ne 'PASS') { throw $project.message }
    $operationId = if ($operation.memory_id) { ConvertTo-CMSafeId ([string]$operation.memory_id) } else { ConvertTo-CMSafeId ([string]$operation.project_id) }
    if ([string]$project.data.memory_id -ne $operationId) { throw "Pending checkpoint mapping mismatch: $operationId vs $($project.data.memory_id)." }
    $result = & (Join-Path $PSScriptRoot 'checkpoint.ps1') -OperationPath $pendingPath -ProjectRoot ([string]$operation.project_root) -Apply | ConvertFrom-Json
    if ($result.status -eq 'MEMORY_UPDATED') { Remove-Item -LiteralPath $pendingPath -Force }
    $result | ConvertTo-Json -Depth 16
} catch {
    (Get-CMResult -Status 'MEMORY_SYNC_BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 8
    exit 1
}
