[CmdletBinding()]
param([ValidateSet('home','company')][string]$Profile, [datetime]$Date = (Get-Date), [switch]$Apply, [switch]$DryRun)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $profileConfig = Get-CMProfile -Profile $Profile
    $day = $Date.ToString('yyyy-MM-dd')
    $eventDir = Join-Path (Join-Path (Get-CMLocalRoot) 'events') $day
    $events = @()
    if (Test-Path -LiteralPath $eventDir -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $eventDir -Filter '*.json' -File) {
            try {
                $event = ConvertTo-CMObject -Path $file.FullName
                if ($event.schema_version -eq 1 -and $event.writer -eq 'codex-memory' -and $event.archive_success -eq $true -and $event.project_id -and $event.evidence -and -not (Test-CMSensitiveText ($event | ConvertTo-Json -Depth 8))) { $event.project_id = ConvertTo-CMSafeId ([string]$event.project_id); $events += $event }
            } catch {}
        }
    }
    if (-not $events.Count) { (Get-CMResult -Status 'NO_EVENTS' -Message 'No successful archive events exist for this date.' -Data @{ date = $day; event_directory = $eventDir }) | ConvertTo-Json -Depth 7; exit 0 }
    $projects = $events | Group-Object project_id
    $lines = @()
    $lines += "# 每日复盘 — $day"
    $lines += ''
    $lines += '<!-- codex-memory:auto:start -->'
    $lines += '## 已归档项目'
    foreach ($group in $projects) {
        $lines += "### $($group.Name)"
        foreach ($event in $group.Group) {
            if ($event.goal) { $lines += "- 目标：$(ConvertTo-CMRedactedText ([string]$event.goal))" }
            foreach ($item in @($event.completed)) { $lines += "- 完成：$(ConvertTo-CMRedactedText ([string]$item))" }
            foreach ($item in @($event.evidence)) { $lines += "- 证据：$(ConvertTo-CMRedactedText ([string]$item))" }
            foreach ($item in @($event.next_actions)) { $lines += "- 下一步：$(ConvertTo-CMRedactedText ([string]$item))" }
        }
        $lines += ''
    }
    $lines += '<!-- codex-memory:auto:end -->'
    $draft = $lines -join "`r`n"
    if (Test-CMSensitiveText $draft) { throw 'Review draft failed sensitive-content scan.' }
    if ($DryRun -or -not $Apply) {
        (Get-CMResult -Status 'DRY_RUN' -Message 'Daily review draft built; no Vault note was written.' -Data @{ date = $day; event_count = $events.Count; projects = @($projects | ForEach-Object Name); draft = $draft }) | ConvertTo-Json -Depth 10
        exit 0
    }
    $configArgs = @{ RequireMemoryRoot = $true }
    if ($Profile) { $configArgs.Profile = $Profile }
    $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') @configArgs | ConvertFrom-Json
    if ($config.status -ne 'PASS') { throw $config.message }
    $path = Join-Path (Join-Path ([string]$config.data.memory_root) '05-每日复盘') ($day + '.md')
    $existing = if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw -Encoding UTF8 } else { '' }
    $managed = [regex]::Replace($draft, '(?s)^.*?<!-- codex-memory:auto:start -->\s*', '')
    $managed = [regex]::Replace($managed, '\s*<!-- codex-memory:auto:end -->.*$', '')
    $final = if ($existing) { Get-CMManagedContent -Existing $existing -Managed $managed } else { $draft + "`r`n" }
    $lock = Enter-CMLock -Name ('daily-review-' + $day)
    try { Write-CMAtomicText -Path $path -Content $final } finally { $lock.Dispose() }
    (Get-CMResult -Status 'PASS' -Message 'Daily review written from successful sanitized events only.' -Data @{ date = $day; event_count = $events.Count; path = $path; sha256 = Get-CMHash $path }) | ConvertTo-Json -Depth 10
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 7; exit 1
}

