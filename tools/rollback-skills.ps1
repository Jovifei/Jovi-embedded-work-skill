[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('codex-memory','update-project-docs')][string]$SkillName,
    [string]$InstallRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [string]$RegistryPath = (Join-Path $env:LOCALAPPDATA 'codex-skill-deploy\installed.json'),
    [switch]$Apply,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

function Get-CMCanonical([string]$Path) { return [System.IO.Path]::GetFullPath($Path).TrimEnd('\') }
function Test-CMChild([string]$Root, [string]$Path) { $r = Get-CMCanonical $Root; $p = Get-CMCanonical $Path; return $p.StartsWith($r + '\', [System.StringComparison]::OrdinalIgnoreCase) }
function Write-CMAtomicJson([string]$Path, $Value) {
    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $temp = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    [System.IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) { $backup = $Path + '.' + [guid]::NewGuid().ToString('N') + '.bak'; [System.IO.File]::Replace($temp, $Path, $backup); if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force } } else { [System.IO.File]::Move($temp, $Path) }
}

try {
    if (-not (Test-Path -LiteralPath $RegistryPath -PathType Leaf)) { throw "Skill deployment registry is absent: $RegistryPath" }
    $registry = Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $record = @($registry.skills | Where-Object { [string]$_.name -eq $SkillName }) | Select-Object -First 1
    if ($null -eq $record) { throw "No deployment record exists for $SkillName." }
    $target = Get-CMCanonical ([string]$record.target)
    $installRootCanonical = Get-CMCanonical $InstallRoot
    if (-not (Test-CMChild -Root $installRootCanonical -Path $target)) { throw "Rollback target escaped install root: $target" }
    $backup = [string]$record.backup_path
    if ([string]::IsNullOrWhiteSpace($backup) -or -not (Test-Path -LiteralPath $backup -PathType Container)) { throw "No recoverable backup exists for $SkillName." }
    $preview = @{ name = $SkillName; target = $target; backup = $backup; current_version = [string]$record.version }
    if ($DryRun -or -not $Apply) { [ordered]@{ status = 'DRY_RUN'; message = 'Skill rollback preview; installed files were not changed.'; data = $preview } | ConvertTo-Json -Depth 10; exit 0 }
    $rollbackBackup = Join-Path (Split-Path -Parent $RegistryPath) ('backups\' + $SkillName + '\rollback-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if (Test-Path -LiteralPath $target -PathType Container) { [System.IO.Directory]::CreateDirectory((Split-Path -Parent $rollbackBackup)) | Out-Null; Copy-Item -LiteralPath $target -Destination $rollbackBackup -Recurse -Force; Remove-Item -LiteralPath $target -Recurse -Force }
    Copy-Item -LiteralPath $backup -Destination $target -Recurse -Force
    $version = Get-Content -LiteralPath (Join-Path $target 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $records = @($registry.skills | ForEach-Object { if ([string]$_.name -eq $SkillName) { [pscustomobject]@{ name = $SkillName; version = [string]$version.version; target = $target; manifest_sha256 = [string]$_.manifest_sha256; backup_path = $rollbackBackup; installed_at = (Get-Date).ToUniversalTime().ToString('o'); rollback_from = [string]$_.version } } else { $_ } })
    Write-CMAtomicJson -Path $RegistryPath -Value ([ordered]@{ schema_version = 1; updated_at = (Get-Date).ToUniversalTime().ToString('o'); skills = @($records) })
    [ordered]@{ status = 'PASS'; message = 'Skill rollback completed; the previous installed version was restored.'; data = @{ name = $SkillName; version = [string]$version.version; target = $target; rollback_backup = $rollbackBackup } } | ConvertTo-Json -Depth 10
} catch {
    [ordered]@{ status = 'BLOCKED'; message = $_.Exception.Message; data = $null } | ConvertTo-Json -Depth 8
    exit 1
}
