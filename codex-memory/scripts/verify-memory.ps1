[CmdletBinding()]
param([ValidateSet('home','company')][string]$Profile, [string]$ProjectId)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $configArgs = @{ RequireMemoryRoot = $true }
    if ($Profile) { $configArgs.Profile = $Profile }
    $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') @configArgs | ConvertFrom-Json
    if ($config.status -ne 'PASS') { throw $config.message }
    $root = [string]$config.data.memory_root
    $checks = [ordered]@{ memory_root_markers = Test-CMMemoryRoot $root; project_id = $ProjectId; overview_exists = $null; incomplete_managed_blocks = @(); sensitive_managed_files = @(); forbidden_process_files = @() }
    if ($ProjectId) {
        $project = Get-CMProjectMemoryPath -MemoryRoot $root -ProjectId $ProjectId
        $overview = Join-Path $project '00-项目概览.md'
        $checks.overview_exists = Test-Path -LiteralPath $overview -PathType Leaf
        if (Test-Path -LiteralPath $project) {
            foreach ($file in Get-ChildItem -LiteralPath $project -Recurse -Filter '*.md' -File) {
                $text = [string](Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)
                $starts = ([regex]::Matches($text, '<!-- codex-memory:live:start -->')).Count
                $ends = ([regex]::Matches($text, '<!-- codex-memory:live:end -->')).Count
                if ($starts -ne $ends) { $checks.incomplete_managed_blocks += $file.Name }
                if (Test-CMSensitiveText $text) { $checks.sensitive_managed_files += $file.Name }
                $relative = $file.FullName.Substring($project.Length).TrimStart('\','/')
                if ($file.Name -eq '01-总体计划.md' -or $file.Name -eq '00-同步清单.md' -or $relative -match '(^|[\\/])(?:superpowers[\\/]plans|superpowers[\\/]specs|tasks)([\\/]|$)' -or (Test-CMPlanLikePath -RelativePath $relative) -or ($relative -match '(^|[\\/])05-[^\\/]+([\\/]|$)' -and $file.Name -match '^(?i:00-.*(?:\u9605|\u8BFB|\u6307|\u5F15|\u6A21|\u677F|\u540C|\u6B65|template|guide|manifest|sync).*)\.md$')) { $checks.forbidden_process_files += $relative }
            }
        }
    }
    $ok = $checks.memory_root_markers -and ($checks.incomplete_managed_blocks.Count -eq 0) -and ($checks.sensitive_managed_files.Count -eq 0) -and ($checks.forbidden_process_files.Count -eq 0) -and ($null -eq $checks.overview_exists -or $checks.overview_exists)
    (Get-CMResult -Status $(if ($ok) { 'PASS' } else { 'FAIL' }) -Message 'Memory verification completed.' -Data $checks) | ConvertTo-Json -Depth 8
    if (-not $ok) { exit 1 }
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6; exit 1
}
