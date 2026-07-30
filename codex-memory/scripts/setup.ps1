[CmdletBinding()]
param(
    [ValidateSet('home','company')][string]$Profile = 'home',
    [string]$VaultRoot,
    [switch]$Apply
)
. (Join-Path $PSScriptRoot 'common.ps1')

$configPath = Get-CMConfigPath
if ($Profile -eq 'home') {
    if ([string]::IsNullOrWhiteSpace($VaultRoot)) { $VaultRoot = $env:OBSIDIAN_VAULT_ROOT }
    if ([string]::IsNullOrWhiteSpace($VaultRoot)) {
        (Get-CMResult -Status 'BLOCKED' -Message 'Home setup requires -VaultRoot or OBSIDIAN_VAULT_ROOT; no vault path is inferred.' -Data $null) | ConvertTo-Json -Depth 5
        exit 1
    }
    try { $homeVault = (Resolve-Path -LiteralPath $VaultRoot -ErrorAction Stop).Path.TrimEnd('\','/') }
    catch {
        (Get-CMResult -Status 'BLOCKED' -Message 'The supplied home VaultRoot does not exist.' -Data @{ vault_root = $VaultRoot }) | ConvertTo-Json -Depth 5
        exit 1
    }
    $homeMemory = Join-Path $homeVault 'codex_memory'
}
else {
    $homeVault = ''
    $homeMemory = ''
}
$profiles = [ordered]@{
    home = [ordered]@{
        obsidian_vault_root = $homeVault; memory_root = $homeMemory; classification = 'personal'
        allow_source_excerpt = $true; allow_raw_logs = $false; allow_snapshot = $false; allow_document_mirror = $true; allow_event_content = $true
        allow_staging_sync = $true; allow_personal_sync = $true; source_extensions = @('.md'); approved_memory_roots = @($homeMemory)
    }
    company = [ordered]@{
        obsidian_vault_root = ''; memory_root = ''; classification = 'internal'
        allow_source_excerpt = $false; allow_raw_logs = $false; allow_snapshot = $false; allow_document_mirror = $false; allow_event_content = $true
        allow_staging_sync = $true; allow_personal_sync = $false; source_extensions = @('.md'); approved_memory_roots = @()
    }
}
if ($Profile -eq 'home' -and -not (Test-CMMemoryRoot -MemoryRoot $homeMemory)) {
    (Get-CMResult -Status 'BLOCKED' -Message 'Home Vault does not satisfy codex_memory markers.' -Data @{ memory_root = $homeMemory }) | ConvertTo-Json -Depth 5; exit 1
}
$preview = [ordered]@{ schema_version = 1; active_profile = $Profile; profiles = $profiles }
if (-not $Apply) {
    (Get-CMResult -Status 'READY_FOR_APPLY' -Message 'No configuration was written. Re-run with -Apply after reviewing this preview.' -Data @{ config_path = $configPath; preview = $preview }) | ConvertTo-Json -Depth 10
    exit 0
}
try {
    if (Test-Path -LiteralPath $configPath) { $existing = ConvertTo-CMObject -Path $configPath; $existing.active_profile = $Profile; $profilesToWrite = if ($Profile -eq 'home') { @('home','company') } else { @('company') }; foreach ($name in $profilesToWrite) { $existing.profiles | Add-Member -Force -NotePropertyName $name -NotePropertyValue ([pscustomobject]$profiles[$name]) }; $final = $existing }
    else { $final = [pscustomobject]$preview }
    Write-CMAtomicJson -Path $configPath -Value $final
    (Get-CMResult -Status 'PASS' -Message 'Configuration written after setup gates passed.' -Data @{ config_path = $configPath; active_profile = $Profile }) | ConvertTo-Json -Depth 6
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6; exit 1
}
