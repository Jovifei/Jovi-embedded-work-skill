[CmdletBinding(DefaultParameterSetName = 'Archive')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Archive')][string]$OperationPath,
    [Parameter(Mandatory = $true, ParameterSetName = 'Sync')][string]$SyncPlanPath,
    [switch]$Apply,
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'common.ps1')

function Get-CMSyncAction([string]$StagingHash, [string]$VaultHash, [string]$BaselineHash) {
    if ([string]::IsNullOrWhiteSpace($BaselineHash)) {
        if ($StagingHash -and -not $VaultHash) { return 'COPY_TO_VAULT' }
        if (-not $StagingHash -and $VaultHash) { return 'BASELINE_VAULT' }
        if ($StagingHash -and $VaultHash -and $StagingHash -eq $VaultHash) { return 'BASELINE_EQUAL' }
        if ($StagingHash -and $VaultHash) { return 'CONFLICT' }
        return 'NOOP'
    }
    $stagingChanged = $StagingHash -ne $BaselineHash
    $vaultChanged = $VaultHash -ne $BaselineHash
    if ($stagingChanged -and -not $vaultChanged) { return 'COPY_TO_VAULT' }
    if (-not $stagingChanged -and $vaultChanged) { return 'BASELINE_VAULT' }
    if ($stagingChanged -and $vaultChanged -and $StagingHash -eq $VaultHash) { return 'BASELINE_EQUAL' }
    if ($stagingChanged -and $vaultChanged) { return 'CONFLICT' }
    return 'NOOP'
}

try {
    if ($PSCmdlet.ParameterSetName -eq 'Archive') {
        $request = ConvertTo-CMObject -Path $OperationPath
        $profileName = [string]$request.profile
        $rawMemoryId = if ($request.PSObject.Properties.Name -contains 'memory_id') { [string]$request.memory_id } else { [string]$request.project_id }
        $projectId = ConvertTo-CMSafeId $rawMemoryId
        $profile = Get-CMProfile -Profile $profileName
        $entry = $profile.Entry
        $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') -Profile $profileName -RequireMemoryRoot | ConvertFrom-Json
        if ($config.status -ne 'PASS') { throw $config.message }
        $target = if ($request.target) { [string]$request.target } else { 'vault' }
        if ($target -notin @('vault','staging')) { throw 'Archive target must be vault or staging.' }
        if ($target -eq 'vault') {
            $memoryRoot = [string]$config.data.memory_root
            $targetRoot = Get-CMProjectMemoryPath -MemoryRoot $memoryRoot -ProjectId $projectId
        } else {
            if (-not [bool]$entry.allow_staging_sync) { throw 'Active profile forbids local staging.' }
            $targetRoot = Join-Path (Join-Path (Get-CMLocalRoot) 'staging') $projectId
        }
        $slotFiles = @{ overview = '00-项目概览.md'; plan = '01-总体计划.md'; progress = '02-当前进度.md'; decisions = '03-关键决策.md'; workflow = '04-工作流与知识.md' }
        $planned = @()
        foreach ($operation in @($request.operations)) {
            $slot = [string]$operation.slot
            if (-not $slotFiles.ContainsKey($slot)) { throw "Unknown memory slot: $slot" }
            $content = [string]$operation.content
            if ($content.Trim().Length -lt 30) { throw "Slot '$slot' has no substantive content." }
            if (Test-CMSensitiveText $content) { throw "Slot '$slot' contains sensitive material." }
            if (-not [bool]$entry.allow_source_excerpt -and $content -match '```') { throw "Slot '$slot' contains a source excerpt prohibited by this profile." }
            if (-not [bool]$entry.allow_raw_logs -and $content -match '(?im)^\s*(?:\[[0-9]{4}[-/]\d{2}[-/]\d{2}|traceback|exception:|debug:|info:|warn(?:ing)?:|error:)') { throw "Slot '$slot' contains raw-log material prohibited by this profile." }
            $path = Join-Path $targetRoot $slotFiles[$slot]
            $existing = if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw -Encoding UTF8 } else { '' }
            $heading = if ($slot -eq 'overview') { "# $projectId — 项目概览`r`n`r`n" } else { "# $projectId — $slot`r`n`r`n" }
            $merged = if ($existing) { Get-CMManagedContent -Existing $existing -Managed $content } else { $heading + (Get-CMManagedContent -Existing '' -Managed $content) }
            $planned += [pscustomobject]@{ slot = $slot; path = $path; before_hash = Get-CMHash $path; after_hash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($merged))) -Algorithm SHA256).Hash.ToLowerInvariant(); content = $merged }
        }
        if (-not (@($planned | Where-Object { $_.slot -eq 'overview' }).Count) -and -not (Test-Path -LiteralPath (Join-Path $targetRoot $slotFiles.overview))) { throw 'A new project archive must include the overview slot.' }
        if ($DryRun -or -not $Apply) { (Get-CMResult -Status 'DRY_RUN' -Message 'Archive plan validated; no files were written.' -Data @{ project_id = $projectId; target = $target; operations = @($planned | Select-Object slot,path,before_hash,after_hash) }) | ConvertTo-Json -Depth 10; exit 0 }
        $lock = Enter-CMLock -Name ("archive-" + $projectId)
        try { foreach ($item in $planned) { Write-CMAtomicText -Path $item.path -Content $item.content } }
        finally { $lock.Dispose() }
        (Get-CMResult -Status 'PASS' -Message 'Archive operations applied through managed blocks.' -Data @{ project_id = $projectId; target = $target; files = @($planned | ForEach-Object { @{ path = $_.path; sha256 = Get-CMHash $_.path } }) }) | ConvertTo-Json -Depth 10
    } else {
        $wrapper = ConvertTo-CMObject -Path $SyncPlanPath
        $plan = if ($wrapper.data -and $wrapper.data.operations) { $wrapper.data } else { $wrapper }
        $profileName = [string]$plan.profile
        if ($profileName -notin @('home','company')) { throw 'Sync plan has an invalid profile.' }
        $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') -Profile $profileName -RequireMemoryRoot | ConvertFrom-Json
        if ($config.status -ne 'PASS') { throw $config.message }
        if (-not [bool]$config.data.policy.allow_staging_sync) { throw 'Active profile forbids staging synchronization.' }
        $projectId = ConvertTo-CMSafeId ([string]$plan.project_id)
        $stagingRoot = Join-Path (Join-Path (Get-CMLocalRoot) 'staging') $projectId
        $vaultRoot = Get-CMProjectMemoryPath -MemoryRoot ([string]$config.data.memory_root) -ProjectId $projectId
        $statePath = Get-CMStatePath -ProjectId $projectId
        $slotFiles = @('00-项目概览.md','01-总体计划.md','02-当前进度.md','03-关键决策.md','04-工作流与知识.md')
        $provided = @($plan.operations)
        if ($provided.Count -ne $slotFiles.Count -or @($provided.slot | Select-Object -Unique).Count -ne $slotFiles.Count) { throw 'Sync plan does not contain exactly one operation for each logical slot.' }
        $state = if (Test-Path -LiteralPath $statePath) { ConvertTo-CMObject -Path $statePath } else { $null }
        $rebuilt = @()
        foreach ($slot in $slotFiles) {
            $slotMatches = @($provided | Where-Object { [string]$_.slot -eq $slot })
            if ($slotMatches.Count -ne 1) { throw "Sync plan is missing or duplicates $slot." }
            $item = $slotMatches[0]
            $stagingPath = Join-Path $stagingRoot $slot
            $vaultPath = Join-Path $vaultRoot $slot
            $stagingHash = ConvertTo-CMNullableHash (Get-CMHash $stagingPath)
            $vaultHash = ConvertTo-CMNullableHash (Get-CMHash $vaultPath)
            $baseline = if ($state -and $state.last_synced_hashes) { ConvertTo-CMNullableHash $state.last_synced_hashes.$slot } else { $null }
            $action = Get-CMSyncAction -StagingHash $stagingHash -VaultHash $vaultHash -BaselineHash $baseline
            if ($action -eq 'CONFLICT' -or [string]$item.action -eq 'CONFLICT') { throw "CONFLICT: divergent staging and vault changes for $slot." }
            if ([string]$item.action -ne $action -or (ConvertTo-CMNullableHash $item.expected_staging_hash) -ne $stagingHash -or (ConvertTo-CMNullableHash $item.expected_vault_hash) -ne $vaultHash) { throw "CONFLICT: sync plan is stale or was altered for $slot." }
            $rebuilt += [pscustomobject]@{ slot = $slot; action = $action; staging_path = $stagingPath; vault_path = $vaultPath; staging_hash = $stagingHash; vault_hash = $vaultHash }
        }
        $changes = @($rebuilt | Where-Object { $_.action -eq 'COPY_TO_VAULT' })
        if ($DryRun -or -not $Apply) { (Get-CMResult -Status 'DRY_RUN' -Message 'Recomputed sync plan validated; no files were written.' -Data @{ project_id = $projectId; changes = $changes }) | ConvertTo-Json -Depth 12; exit 0 }
        $lock = Enter-CMLock -Name ("sync-" + $projectId)
        try {
            foreach ($change in $rebuilt) {
                if ((ConvertTo-CMNullableHash (Get-CMHash $change.staging_path)) -ne $change.staging_hash -or (ConvertTo-CMNullableHash (Get-CMHash $change.vault_path)) -ne $change.vault_hash) { throw "CONFLICT: hash changed after plan for $($change.slot)." }
            }
            $original = @{}; $written = @()
            try {
                foreach ($change in $changes) {
                    $original[$change.vault_path] = [pscustomobject]@{ exists = (Test-Path -LiteralPath $change.vault_path); content = if (Test-Path -LiteralPath $change.vault_path) { Get-Content -LiteralPath $change.vault_path -Raw -Encoding UTF8 } else { $null } }
                    Write-CMAtomicText -Path $change.vault_path -Content (Get-Content -LiteralPath $change.staging_path -Raw -Encoding UTF8)
                    $written += $change
                }
            } catch {
                for ($index = $written.Count - 1; $index -ge 0; $index--) {
                    $change = $written[$index]
                    $before = $original[$change.vault_path]
                    if ($before.exists) { Write-CMAtomicText -Path $change.vault_path -Content $before.content }
                    elseif (Test-Path -LiteralPath $change.vault_path) { [System.IO.File]::Delete($change.vault_path) }
                }
                throw
            }
            $hashes = [ordered]@{}
            foreach ($operation in $rebuilt) { $hashes[$operation.slot] = Get-CMHash $operation.vault_path }
            Write-CMAtomicJson -Path $statePath -Value ([ordered]@{ schema_version = 1; project_id = $projectId; profile = $profileName; last_synced_at = (Get-Date).ToUniversalTime().ToString('o'); last_synced_hashes = $hashes })
        } finally { $lock.Dispose() }
        (Get-CMResult -Status 'PASS' -Message 'Staging synchronized to approved vault.' -Data @{ project_id = $projectId; copied = $changes.Count; state_path = $statePath }) | ConvertTo-Json -Depth 10
    }
} catch {
    (Get-CMResult -Status $(if ($_.Exception.Message -like 'CONFLICT*') { 'CONFLICT' } else { 'BLOCKED' }) -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 7
    exit 1
}
