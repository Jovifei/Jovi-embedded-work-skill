[CmdletBinding(DefaultParameterSetName = 'Preview')]
param(
    [ValidateSet('home','company')][string]$Profile = 'home',
    [Parameter(ParameterSetName = 'Install')][switch]$Install,
    [Parameter(ParameterSetName = 'Remove')][switch]$Remove,
    [Parameter(ParameterSetName = 'Install')][switch]$ManualReviewVerified
)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $taskName = 'CodexMemory-DailyReview'
    if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) { throw 'Windows ScheduledTasks module is unavailable.' }
    $runner = Join-Path $PSScriptRoot 'run-daily-review.ps1'
    $actionText = 'powershell.exe -NoProfile -File "' + $runner + '" -Profile ' + $Profile
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    $managedDescription = 'CodexMemoryManaged schema=1; runs codex-memory daily review from sanitized archive events.'
    $data = @{ task_name = $taskName; profile = $Profile; existing = [bool]$existing; action = $actionText; schedule = 'daily 01:00 local time' }
    if ($PSCmdlet.ParameterSetName -eq 'Preview') { (Get-CMResult -Status 'DRY_RUN' -Message 'Task install preview only; no scheduled task was created.' -Data $data) | ConvertTo-Json -Depth 7; exit 0 }
    if ($Install) {
        if (-not $ManualReviewVerified) { throw 'A successful manual review dry-run and actual review are required before task installation.' }
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -File "' + $runner + '" -Profile ' + $Profile)
        $trigger = New-ScheduledTaskTrigger -Daily -At 1:00am
        $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew
        if ($existing -and [string]$existing.Description -ne $managedDescription) { throw 'A task with this name exists but is not managed by codex-memory.' }
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description $managedDescription -Force | Out-Null
        (Get-CMResult -Status 'PASS' -Message 'Daily review task installed.' -Data $data) | ConvertTo-Json -Depth 7; exit 0
    }
    if ($existing -and [string]$existing.Description -ne $managedDescription) { throw 'Refusing to remove a same-named task not managed by codex-memory.' }
    if ($existing) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
    (Get-CMResult -Status 'PASS' -Message 'CodexMemory-DailyReview removed; no other task was touched.' -Data $data) | ConvertTo-Json -Depth 7
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6; exit 1
}

