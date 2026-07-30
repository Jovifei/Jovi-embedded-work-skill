[CmdletBinding()]
param([string]$SkillParent = 'C:\Users\Admin\.claude\skills', [string]$SkillName = 'codex-memory', [switch]$VerifyExisting)
. (Join-Path $PSScriptRoot 'common.ps1')

$target = Join-Path $SkillParent $SkillName
$checks = [ordered]@{
    windows = $env:OS -eq 'Windows_NT'
    powershell_5_or_newer = $PSVersionTable.PSVersion.Major -ge 5
    python = [bool](Get-Command python -ErrorAction SilentlyContinue)
    pyyaml = $false
    claude = [bool](Get-Command claude -ErrorAction SilentlyContinue)
    parent_exists = Test-Path -LiteralPath $SkillParent -PathType Container
    target_absent = -not (Test-Path -LiteralPath $target)
    parent_writable = $false
    existing_static_structure = $false
}
try {
    $probe = Join-Path $SkillParent ('.' + $SkillName + '.' + [guid]::NewGuid().ToString('N') + '.probe')
    [System.IO.File]::WriteAllText($probe, 'probe')
    [System.IO.File]::Delete($probe)
    $checks.parent_writable = $true
} catch {}
try { python -c "import yaml" 2>$null; $checks.pyyaml = $LASTEXITCODE -eq 0 } catch {}
$checks.existing_static_structure = (Test-Path -LiteralPath (Join-Path $target 'SKILL.md') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $target 'agents\openai.yaml') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $target 'scripts') -PathType Container)
$baseOk = $checks.windows -and $checks.powershell_5_or_newer -and $checks.python -and $checks.pyyaml -and $checks.claude -and $checks.parent_exists -and $checks.parent_writable
$ok = if ($VerifyExisting) { $baseOk -and -not $checks.target_absent -and $checks.existing_static_structure } else { $baseOk -and $checks.target_absent }
(Get-CMResult -Status $(if ($ok) { 'PASS' } else { 'BLOCKED' }) -Message $(if ($ok) { if ($VerifyExisting) { 'Existing Skill preflight passed.' } else { 'Install preflight passed.' } } else { 'Install preflight failed; do not create or repair the Skill.' }) -Data $checks) | ConvertTo-Json -Depth 6
if (-not $ok) { exit 1 }

