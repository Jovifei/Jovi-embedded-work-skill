[CmdletBinding()]
param([ValidateSet('home','company')][string]$Profile, [string]$ProjectId)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $configArgs = @{ RequireMemoryRoot = $true }
    if ($Profile) { $configArgs.Profile = $Profile }
    $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') @configArgs | ConvertFrom-Json
    if ($config.status -ne 'PASS') { throw $config.message }
    $root = [string]$config.data.memory_root
    $checks = [ordered]@{ memory_root_markers = Test-CMMemoryRoot $root; project_id = $ProjectId; overview_exists = $null; incomplete_managed_blocks = @(); sensitive_managed_files = @() }
    if ($ProjectId) {
        $project = Get-CMProjectMemoryPath -MemoryRoot $root -ProjectId $ProjectId
        $overview = Join-Path $project '00-项目概览.md'
        $checks.overview_exists = Test-Path -LiteralPath $overview -PathType Leaf
        if (Test-Path -LiteralPath $project) {
            foreach ($file in Get-ChildItem -LiteralPath $project -Filter '*.md' -File) {
                $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
                $starts = ([regex]::Matches($text, '<!-- codex-memory:auto:start -->')).Count
                $ends = ([regex]::Matches($text, '<!-- codex-memory:auto:end -->')).Count
                if ($starts -ne $ends) { $checks.incomplete_managed_blocks += $file.Name }
                if (Test-CMSensitiveText $text) { $checks.sensitive_managed_files += $file.Name }
            }
        }
    }
    $ok = $checks.memory_root_markers -and ($checks.incomplete_managed_blocks.Count -eq 0) -and ($checks.sensitive_managed_files.Count -eq 0) -and ($null -eq $checks.overview_exists -or $checks.overview_exists)
    (Get-CMResult -Status $(if ($ok) { 'PASS' } else { 'FAIL' }) -Message 'Memory verification completed.' -Data $checks) | ConvertTo-Json -Depth 8
    if (-not $ok) { exit 1 }
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6; exit 1
}
