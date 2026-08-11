[CmdletBinding()]
param([ValidateSet('home','company')][string]$Profile, [switch]$RequireMemoryRoot)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $resolved = Get-CMProfile -Profile $Profile
    $entry = $resolved.Entry
    $configuredRoot = [string]$entry.memory_root
    $approvedRaw = if ($entry.PSObject.Properties.Name -contains 'approved_memory_roots') { @($entry.approved_memory_roots) } else { @() }
    $approvedRoots = @($approvedRaw | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($env:CODEX_MEMORY_ROOT) {
        if ($resolved.Name -eq 'company' -and -not (Test-CMSamePath -Left $env:CODEX_MEMORY_ROOT -Right $configuredRoot)) { throw 'Company profile forbids CODEX_MEMORY_ROOT overrides.' }
        if (-not $approvedRoots.Count -or -not (@($approvedRoots | Where-Object { Test-CMSamePath -Left $_ -Right $env:CODEX_MEMORY_ROOT }).Count)) { throw 'CODEX_MEMORY_ROOT must be an exact approved memory_root.' }
    }
    $memoryRoot = if ($env:CODEX_MEMORY_ROOT) { $env:CODEX_MEMORY_ROOT } else { $configuredRoot }
    $vaultRoot = [string]$entry.obsidian_vault_root
    $policy = [ordered]@{
        allow_source_excerpt = [bool]$entry.allow_source_excerpt
        allow_raw_logs = [bool]$entry.allow_raw_logs
        allow_snapshot = [bool]$entry.allow_snapshot
        allow_document_mirror = [bool]$entry.allow_document_mirror
        allow_event_content = [bool]$entry.allow_event_content
        allow_staging_sync = [bool]$entry.allow_staging_sync
        allow_personal_sync = [bool]$entry.allow_personal_sync
        source_extensions = @($entry.source_extensions)
    }
    $automationEntry = if ($entry.PSObject.Properties.Name -contains 'automation') { $entry.automation } else { $null }
    $automation = [ordered]@{
        read_on_session_start = if ($automationEntry -and ($automationEntry.PSObject.Properties.Name -contains 'read_on_session_start')) { [bool]$automationEntry.read_on_session_start } else { $resolved.Name -eq 'home' }
        remind_on_user_prompt = if ($automationEntry -and ($automationEntry.PSObject.Properties.Name -contains 'remind_on_user_prompt')) { [bool]$automationEntry.remind_on_user_prompt } else { $resolved.Name -eq 'home' }
        auto_apply_verified_checkpoint = if ($automationEntry -and ($automationEntry.PSObject.Properties.Name -contains 'auto_apply_verified_checkpoint')) { [bool]$automationEntry.auto_apply_verified_checkpoint } else { $false }
        auto_apply_document_mirror = if ($automationEntry -and ($automationEntry.PSObject.Properties.Name -contains 'auto_apply_document_mirror')) { [bool]$automationEntry.auto_apply_document_mirror } else { $false }
        dry_run_required = if ($automationEntry -and ($automationEntry.PSObject.Properties.Name -contains 'dry_run_required')) { [bool]$automationEntry.dry_run_required } else { $true }
    }
    $projectMappings = if ($entry.PSObject.Properties.Name -contains 'project_mappings') { @($entry.project_mappings) } else { @() }
    $hasRoot = -not [string]::IsNullOrWhiteSpace($memoryRoot) -and (Test-CMMemoryRoot -MemoryRoot $memoryRoot)
    if ($RequireMemoryRoot -and -not $hasRoot) { throw "Approved memory_root is missing or invalid for profile '$($resolved.Name)'." }
    if ($resolved.Name -eq 'company') {
        if ($policy.allow_personal_sync) { throw 'Company profile may not enable personal synchronization.' }
        if ($hasRoot -and (-not $approvedRoots.Count -or -not (@($approvedRoots | Where-Object { Test-CMSamePath -Left $_ -Right $memoryRoot }).Count))) { throw 'Company memory_root must appear in approved_memory_roots.' }
    }
    (Get-CMResult -Status $(if ($hasRoot) { 'PASS' } else { 'STAGING_ONLY' }) -Message 'Configuration resolved.' -Data ([ordered]@{ schema_version = [int]$(if ($resolved.Config.PSObject.Properties.Name -contains 'schema_version') { $resolved.Config.schema_version } else { 1 }); profile = $resolved.Name; config_path = $resolved.ConfigPath; obsidian_vault_root = $vaultRoot; memory_root = $memoryRoot; memory_root_valid = $hasRoot; approved_memory_roots = $approvedRoots; policy = $policy; automation = $automation; project_mappings = $projectMappings; local_root = Get-CMLocalRoot })) | ConvertTo-Json -Depth 12
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6
    exit 1
}
