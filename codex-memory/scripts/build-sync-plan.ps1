[CmdletBinding()]
param([ValidateSet('home','company')][string]$Profile, [string]$ProjectRoot = (Get-Location).Path, [string]$ProjectId)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $configArgs = @{ RequireMemoryRoot = $true }
    if ($Profile) { $configArgs.Profile = $Profile }
    $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') @configArgs | ConvertFrom-Json
    if ($config.status -ne 'PASS') { throw $config.message }
    if (-not [bool]$config.data.policy.allow_staging_sync) { throw 'Active profile forbids staging synchronization.' }
    $project = & (Join-Path $PSScriptRoot 'discover-project.ps1') -ProjectRoot $ProjectRoot -ProjectId $ProjectId | ConvertFrom-Json
    if ($project.status -ne 'PASS') { throw $project.message }
    $id = if ($project.data.memory_id) { [string]$project.data.memory_id } else { [string]$project.data.project_id }
    $staging = Join-Path (Join-Path (Get-CMLocalRoot) 'staging') $id
    $vault = Get-CMProjectMemoryPath -MemoryRoot ([string]$config.data.memory_root) -ProjectId $id
    $statePath = Get-CMStatePath -ProjectId $id
    $state = if (Test-Path -LiteralPath $statePath) { ConvertTo-CMObject -Path $statePath } else { $null }
    $slots = @('00-项目概览.md','01-总体计划.md','02-当前进度.md','03-关键决策.md','04-工作流与知识.md')
    $operations = @()
    foreach ($slot in $slots) {
        $sp = Join-Path $staging $slot; $vp = Join-Path $vault $slot
        $sh = Get-CMHash $sp; $vh = Get-CMHash $vp
        $base = if ($state -and $state.last_synced_hashes) { [string]$state.last_synced_hashes.$slot } else { $null }
        $action = 'NOOP'
        if ($null -eq $base -or $base -eq '') {
            if ($sh -and -not $vh) { $action = 'COPY_TO_VAULT' }
            elseif (-not $sh -and $vh) { $action = 'BASELINE_VAULT' }
            elseif ($sh -and $vh -and $sh -eq $vh) { $action = 'BASELINE_EQUAL' }
            elseif ($sh -and $vh -and $sh -ne $vh) { $action = 'CONFLICT' }
        } else {
            $stagingChanged = $sh -ne $base; $vaultChanged = $vh -ne $base
            if ($stagingChanged -and -not $vaultChanged) { $action = 'COPY_TO_VAULT' }
            elseif (-not $stagingChanged -and $vaultChanged) { $action = 'BASELINE_VAULT' }
            elseif ($stagingChanged -and $vaultChanged -and $sh -eq $vh) { $action = 'BASELINE_EQUAL' }
            elseif ($stagingChanged -and $vaultChanged) { $action = 'CONFLICT' }
        }
        $operations += [pscustomobject]@{ slot = $slot; action = $action; staging_path = $sp; vault_path = $vp; expected_staging_hash = $sh; expected_vault_hash = $vh; baseline_hash = $base }
    }
    $conflicts = @($operations | Where-Object { $_.action -eq 'CONFLICT' })
    $plan = [ordered]@{ schema_version = 1; profile = $config.data.profile; project_id = $id; generated_at = (Get-Date).ToUniversalTime().ToString('o'); state_path = $statePath; staging_root = $staging; vault_root = $vault; operations = $operations }
    (Get-CMResult -Status $(if ($conflicts.Count) { 'CONFLICT' } else { 'PASS' }) -Message $(if ($conflicts.Count) { 'Both staging and vault changed; no overwrite is allowed.' } else { 'Three-way sync plan built.' }) -Data $plan) | ConvertTo-Json -Depth 12
    if ($conflicts.Count) { exit 2 }
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6
    exit 1
}

