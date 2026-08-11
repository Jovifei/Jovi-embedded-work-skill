[CmdletBinding()]
param(
    [ValidateSet('codex-memory','update-project-docs')][string[]]$SkillName = @('codex-memory','update-project-docs'),
    [string]$SourceRoot = '',
    [string]$InstallRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [string]$RegistryPath = (Join-Path $env:LOCALAPPDATA 'codex-skill-deploy\installed.json'),
    [switch]$Apply,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }

function Get-CMCanonical([string]$Path) { return [System.IO.Path]::GetFullPath($Path).TrimEnd('\') }
function Test-CMChild([string]$Root, [string]$Path) { $r = Get-CMCanonical $Root; $p = Get-CMCanonical $Path; return $p.StartsWith($r + '\', [System.StringComparison]::OrdinalIgnoreCase) }
function Get-CMManifest([string]$Root) {
    $items = @()
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File) {
        $relative = $file.FullName.Substring($Root.Length).TrimStart('\','/') -replace '\\','/'
        $items += [ordered]@{ path = $relative; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); bytes = $file.Length }
    }
    return @($items | Sort-Object path)
}
function Get-CMManifestHash($Manifest) {
    $json = $Manifest | ConvertTo-Json -Depth 8 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Write-CMAtomicJson([string]$Path, $Value) {
    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $temp = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    [System.IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) { $backup = $Path + '.' + [guid]::NewGuid().ToString('N') + '.bak'; [System.IO.File]::Replace($temp, $Path, $backup); if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force } } else { [System.IO.File]::Move($temp, $Path) }
}

try {
    $plans = @()
    foreach ($name in $SkillName) {
        $source = Get-CMCanonical (Join-Path $SourceRoot $name)
        $target = Get-CMCanonical (Join-Path $InstallRoot $name)
        if (-not (Test-CMChild -Root $SourceRoot -Path $source)) { throw "Skill source escaped source root: $source" }
        if (-not (Test-CMChild -Root $InstallRoot -Path $target)) { throw "Skill target escaped install root: $target" }
        if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md') -PathType Leaf)) { throw "Skill source is incomplete: $source" }
        $versionPath = Join-Path $source 'version.json'
        if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) { throw "Skill version metadata is absent: $versionPath" }
        $version = Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]$version.name -ne $name -or [string]::IsNullOrWhiteSpace([string]$version.version)) { throw "Skill version metadata is invalid: $versionPath" }
        $manifest = Get-CMManifest $source
        $backupPath = Join-Path (Join-Path (Join-Path (Split-Path -Parent $RegistryPath) 'backups') $name) (([string]$version.version) + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $plans += [pscustomobject]@{ name = $name; version = [string]$version.version; source = $source; target = $target; file_count = $manifest.Count; manifest_sha256 = Get-CMManifestHash $manifest; manifest = $manifest; backup_path = if (Test-Path -LiteralPath $target -PathType Container) { $backupPath } else { $null } }
    }
    if ($DryRun -or -not $Apply) { [ordered]@{ status = 'DRY_RUN'; message = 'Skill deployment preview; no installed Skill was changed.'; data = @{ plans = $plans } } | ConvertTo-Json -Depth 20; exit 0 }

    $registry = if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) { Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{ schema_version = 1; skills = @() } }
    $records = @($registry.skills)
    foreach ($plan in $plans) {
        $stage = Join-Path $InstallRoot ('.' + $plan.name + '.stage.' + [guid]::NewGuid().ToString('N'))
        [System.IO.Directory]::CreateDirectory($stage) | Out-Null
        try {
            foreach ($item in Get-ChildItem -LiteralPath $plan.source -Force) { Copy-Item -LiteralPath $item.FullName -Destination $stage -Recurse -Force }
            if ($plan.backup_path) {
                [System.IO.Directory]::CreateDirectory((Split-Path -Parent $plan.backup_path)) | Out-Null
                Copy-Item -LiteralPath $plan.target -Destination $plan.backup_path -Recurse -Force
            }
            if (Test-Path -LiteralPath $plan.target) { Remove-Item -LiteralPath $plan.target -Recurse -Force }
            Move-Item -LiteralPath $stage -Destination $plan.target
            $installedManifest = Get-CMManifest $plan.target
            $installedHash = Get-CMManifestHash $installedManifest
            if ($installedHash -ne $plan.manifest_sha256) { throw "Installed manifest mismatch for $($plan.name)." }
            $records = @($records | Where-Object { [string]$_.name -ne $plan.name })
            $records += [pscustomobject]@{ name = $plan.name; version = $plan.version; target = $plan.target; manifest_sha256 = $installedHash; backup_path = $plan.backup_path; installed_at = (Get-Date).ToUniversalTime().ToString('o'); source_root = $plan.source; source_revision = ((git -C (Split-Path -Parent $plan.source) rev-parse HEAD 2>$null) -join '').Trim() }
        } catch {
            if (Test-Path -LiteralPath $plan.target) { Remove-Item -LiteralPath $plan.target -Recurse -Force }
            if ($plan.backup_path -and (Test-Path -LiteralPath $plan.backup_path -PathType Container)) { Copy-Item -LiteralPath $plan.backup_path -Destination $plan.target -Recurse -Force }
            throw
        } finally {
            if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
        }
    }
    Write-CMAtomicJson -Path $RegistryPath -Value ([ordered]@{ schema_version = 1; updated_at = (Get-Date).ToUniversalTime().ToString('o'); skills = @($records) })
    [ordered]@{ status = 'PASS'; message = 'Versioned Skill deployment completed with manifest verification.'; data = @{ registry_path = $RegistryPath; skills = @($records) } } | ConvertTo-Json -Depth 20
} catch {
    [ordered]@{ status = 'BLOCKED'; message = $_.Exception.Message; data = $null } | ConvertTo-Json -Depth 8
    exit 1
}
