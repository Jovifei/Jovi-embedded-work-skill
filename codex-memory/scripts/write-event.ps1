[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EventPath, [ValidateSet('home','company')][string]$Profile, [switch]$Apply, [switch]$DryRun)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $profileConfig = Get-CMProfile -Profile $Profile
    $event = ConvertTo-CMObject -Path $EventPath
    if (-not $event.archive_success -or -not $event.project_id -or -not $event.evidence) { throw 'Event requires archive_success=true, project_id, and an evidence summary.' }
    foreach ($forbidden in @('raw_source','raw_log','transcript','credential','token','secret','content_blob')) { if ($event.PSObject.Properties.Name -contains $forbidden) { throw "Event contains forbidden field: $forbidden" } }
    $goal = if ($event.PSObject.Properties.Name -contains 'goal') { [string]$event.goal } else { '' }
    $completed = if ($event.PSObject.Properties.Name -contains 'completed') { @($event.completed) } else { @() }
    $decisions = if ($event.PSObject.Properties.Name -contains 'decisions') { @($event.decisions) } else { @() }
    $risks = if ($event.PSObject.Properties.Name -contains 'risks') { @($event.risks) } else { @() }
    $nextActions = if ($event.PSObject.Properties.Name -contains 'next_actions') { @($event.next_actions) } else { @() }
    $changedFiles = if ($event.PSObject.Properties.Name -contains 'changed_files') { @($event.changed_files) } else { @() }
    $sourceRevision = if ($event.PSObject.Properties.Name -contains 'source_revision') { [string]$event.source_revision } else { '' }
    $safe = [ordered]@{
        schema_version = 1
        writer = 'codex-memory'
        archive_success = $true
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        project_id = ConvertTo-CMSafeId ([string]$event.project_id)
        goal = ConvertTo-CMRedactedText $goal
        completed = @(foreach ($item in $completed) { ConvertTo-CMRedactedText ([string]$item) })
        evidence = @(foreach ($item in @($event.evidence)) { ConvertTo-CMRedactedText ([string]$item) })
        decisions = @(foreach ($item in $decisions) { ConvertTo-CMRedactedText ([string]$item) })
        risks = @(foreach ($item in $risks) { ConvertTo-CMRedactedText ([string]$item) })
        next_actions = @(foreach ($item in $nextActions) { ConvertTo-CMRedactedText ([string]$item) })
        changed_files = @(foreach ($item in $changedFiles) { ([string]$item).Replace('\','/') })
        source_revision = ConvertTo-CMRedactedText $sourceRevision
    }
    foreach ($path in @($safe.changed_files)) { if (-not (Test-CMSafeRelativePath $path)) { throw 'Event changed_files must be safe relative paths.' } }
    foreach ($value in @($safe.goal) + @($safe.completed) + @($safe.evidence) + @($safe.decisions) + @($safe.risks) + @($safe.next_actions) + @($safe.source_revision)) { if ((Test-CMSensitiveText $value) -or $value.Length -gt 2000) { throw 'Event content violates sensitive-content or length policy.' } }
    if (-not [bool]$profileConfig.Entry.allow_event_content) { $safe.goal = ''; $safe.completed = @(); $safe.evidence = @(); $safe.decisions = @(); $safe.risks = @(); $safe.next_actions = @(); $safe.changed_files = @(); $safe.source_revision = '' }
    $date = Get-Date -Format 'yyyy-MM-dd'
    $destination = Join-Path (Join-Path (Join-Path (Get-CMLocalRoot) 'events') $date) ((Get-Date -Format 'HHmmss') + '-' + $safe.project_id + '.json')
    if ($DryRun -or -not $Apply) { (Get-CMResult -Status 'DRY_RUN' -Message 'Event validated; no event was written.' -Data @{ destination = $destination; event = $safe }) | ConvertTo-Json -Depth 10; exit 0 }
    $lock = Enter-CMLock -Name ('event-' + $safe.project_id)
    try { Write-CMAtomicJson -Path $destination -Value $safe } finally { $lock.Dispose() }
    (Get-CMResult -Status 'PASS' -Message 'Sanitized archive event written.' -Data @{ path = $destination; sha256 = Get-CMHash $destination }) | ConvertTo-Json -Depth 7
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6; exit 1
}

