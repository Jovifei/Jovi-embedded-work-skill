[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourceMapPath,
    [string]$SourceRoot = 'D:\work',
    [string]$LegacyMicroInverterRoot = 'D:\MicroInverter\Project',
    [ValidateSet('home','company')][string]$Profile = 'home',
    [switch]$Apply,
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'common.ps1')

function Get-CMParentMemoryId {
    param([string]$SourcePath, [string]$CurrentId)
    $leaf = [System.IO.Path]::GetFileName($SourcePath)
    if ($leaf -match '^smart-controller-gd32f4_bootloader$') { return 'smart-controller-gd32f4' }
    if ($leaf -match '^ess-smart-ct-v2_bootloder$') { return 'ess-smart-ct-v2' }
    if ($leaf -match '^external-4G-module-gd32f303_bootloader$') { return 'external-4g-module-gd32f303' }
    return $CurrentId
}

try {
    if (-not (Test-Path -LiteralPath $SourceMapPath -PathType Leaf)) { throw "Source mapping file is absent: $SourceMapPath" }
    $resolvedProfile = Get-CMProfile -Profile $Profile
    $config = $resolvedProfile.Config
    $sourceMap = ConvertTo-CMObject -Path $SourceMapPath
    $mappings = @()
    $seen = @{}
    foreach ($item in @($sourceMap)) {
        $currentId = ConvertTo-CMSafeId ([string]$item.memory_id)
        foreach ($rawRoot in @($item.source_roots)) {
            $sourcePath = [string]$rawRoot
            if (-not [System.IO.Path]::IsPathRooted($sourcePath)) { throw "Source mapping root must be absolute: $sourcePath" }
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) { continue }
            $memoryId = ConvertTo-CMSafeId (Get-CMParentMemoryId -SourcePath $sourcePath -CurrentId $currentId)
            $isBoot = $memoryId -ne $currentId -or ([System.IO.Path]::GetFileName($sourcePath) -match '(?i)bootloader|bootloder')
            if ($isBoot) { $memoryId = ConvertTo-CMSafeId (Get-CMParentMemoryId -SourcePath $sourcePath -CurrentId $memoryId) }
            $key = (Get-CMCanonicalPath $sourcePath).ToLowerInvariant()
            if ($seen.ContainsKey($key)) { continue }
            $seen[$key] = $true
            $mapping = [ordered]@{ memory_id = $memoryId; project_id = $memoryId; source_root = (Get-CMCanonicalPath $sourcePath); component = if ($isBoot) { 'bootloader' } else { 'main' } }
            if ($isBoot) { $mapping.mirror_prefix = 'bootloader' }
            $mappings += [pscustomobject]$mapping
        }
    }
    $v2 = Join-Path $SourceRoot 'mppt-charger-120w-v2'
    if ((Test-Path -LiteralPath $v2 -PathType Container) -and -not $seen.ContainsKey((Get-CMCanonicalPath $v2).ToLowerInvariant())) {
        $mappings += [pscustomobject]@{ memory_id = 'mppt-charger-120w-v2'; project_id = 'mppt-charger-120w-v2'; source_root = (Get-CMCanonicalPath $v2); component = 'main' }
    }
    # This repository already has a durable Vault project and is the source of
    # the pre-existing microinverter_sdk memory. Keep it attached to its
    # current source tree without inventing a new top-level memory project.
    if (Test-Path -LiteralPath $LegacyMicroInverterRoot -PathType Container) {
        $legacyRoot = Get-CMCanonicalPath $LegacyMicroInverterRoot
        if (-not $seen.ContainsKey($legacyRoot.ToLowerInvariant())) {
            $seen[$legacyRoot.ToLowerInvariant()] = $true
            $mappings += [pscustomobject]@{ memory_id = 'microinverter_sdk'; project_id = 'microinverter_sdk'; source_root = $legacyRoot; component = 'main' }
        }
        $legacyBoot = Join-Path $legacyRoot 'software\bootuser'
        if (Test-Path -LiteralPath $legacyBoot -PathType Container) {
            $legacyBoot = Get-CMCanonicalPath $legacyBoot
            if (-not $seen.ContainsKey($legacyBoot.ToLowerInvariant())) {
                $seen[$legacyBoot.ToLowerInvariant()] = $true
                $mappings += [pscustomobject]@{ memory_id = 'microinverter_sdk'; project_id = 'microinverter_sdk'; source_root = $legacyBoot; component = 'bootloader'; mirror_prefix = 'bootloader' }
            }
        }
    }
    $updated = ($config | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
    $updated.schema_version = 2
    foreach ($profileName in @('home','company')) {
        if ($null -eq $updated.profiles.$profileName) { continue }
        $profileObject = $updated.profiles.$profileName
        $profileProperties = @($profileObject.PSObject.Properties | ForEach-Object { $_.Name })
        if ($profileProperties -notcontains 'automation' -or $null -eq $profileObject.automation) { $profileObject | Add-Member -Force -NotePropertyName automation -NotePropertyValue ([pscustomobject]@{ read_on_session_start = ($profileName -eq 'home'); remind_on_user_prompt = ($profileName -eq 'home'); auto_apply_verified_checkpoint = ($profileName -eq 'home'); auto_apply_document_mirror = ($profileName -eq 'home'); dry_run_required = $true }) }
        if ($profileName -eq $Profile) { $updated.profiles.$profileName | Add-Member -Force -NotePropertyName project_mappings -NotePropertyValue @($mappings) }
        elseif ($profileProperties -notcontains 'project_mappings' -or $null -eq $profileObject.project_mappings) { $updated.profiles.$profileName | Add-Member -Force -NotePropertyName project_mappings -NotePropertyValue @() }
    }
    $preview = [ordered]@{ config_path = $resolvedProfile.ConfigPath; schema_version = 2; profile = $Profile; mapping_count = $mappings.Count; project_mappings = @($mappings); config = $updated }
    if ($DryRun -or -not $Apply) {
        (Get-CMResult -Status 'DRY_RUN' -Message 'V2 configuration migration preview; no config was written.' -Data $preview) | ConvertTo-Json -Depth 20
        exit 0
    }
    $backup = $resolvedProfile.ConfigPath + '.v1.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.bak'
    if (Test-Path -LiteralPath $resolvedProfile.ConfigPath) { [System.IO.File]::Copy($resolvedProfile.ConfigPath, $backup, $false) }
    Write-CMAtomicJson -Path $resolvedProfile.ConfigPath -Value $updated
    (Get-CMResult -Status 'PASS' -Message 'Configuration migrated to schema v2 with project mappings.' -Data @{ config_path = $resolvedProfile.ConfigPath; backup = $backup; mapping_count = $mappings.Count; project_mappings = @($mappings) }) | ConvertTo-Json -Depth 16
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 8
    exit 1
}
