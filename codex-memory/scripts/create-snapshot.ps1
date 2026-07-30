[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$SourcePath, [ValidateSet('home','company')][string]$Profile, [string]$ProjectId, [switch]$Apply, [switch]$DryRun)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $configArgs = @{ RequireMemoryRoot = $true }
    if ($Profile) { $configArgs.Profile = $Profile }
    $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') @configArgs | ConvertFrom-Json
    if ($config.status -ne 'PASS') { throw $config.message }
    if (-not [bool]$config.data.policy.allow_snapshot) { throw 'Active profile does not permit snapshots.' }
    $source = (Resolve-Path -LiteralPath $SourcePath).Path
    if ([System.IO.Path]::GetExtension($source).ToLowerInvariant() -notin @($config.data.policy.source_extensions)) { throw 'Snapshot source is not on the profile allowlist.' }
    $content = Get-Content -LiteralPath $source -Raw -Encoding UTF8
    if (Test-CMSensitiveText $content) { throw 'Snapshot source contains sensitive material.' }
    if (-not $ProjectId) { $ProjectId = (& (Join-Path $PSScriptRoot 'discover-project.ps1') | ConvertFrom-Json).data.memory_id }
    $projectId = ConvertTo-CMSafeId $ProjectId
    $destination = Join-Path (Join-Path (Join-Path ([string]$config.data.memory_root) '06-项目文档镜像') $projectId) ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [System.IO.Path]::GetFileName($source))
    if ($DryRun -or -not $Apply) { (Get-CMResult -Status 'DRY_RUN' -Message 'Snapshot validated; no copy was created.' -Data @{ source = $source; destination = $destination; sha256 = Get-CMHash $source }) | ConvertTo-Json -Depth 7; exit 0 }
    $lock = Enter-CMLock -Name ('snapshot-' + $projectId)
    try { Write-CMAtomicText -Path $destination -Content $content } finally { $lock.Dispose() }
    (Get-CMResult -Status 'PASS' -Message 'Allowlisted Markdown snapshot created.' -Data @{ destination = $destination; sha256 = Get-CMHash $destination }) | ConvertTo-Json -Depth 7
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6; exit 1
}

