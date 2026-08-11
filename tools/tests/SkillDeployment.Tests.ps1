$tools = Split-Path -Parent $PSScriptRoot
$deploy = Join-Path $tools 'deploy-skills.ps1'
$rollback = Join-Path $tools 'rollback-skills.ps1'

Describe 'versioned Skill deployment' {
    BeforeEach {
        $install = Join-Path $TestDrive 'installed'
        $registry = Join-Path $TestDrive 'state\installed.json'
    }

    It 'previews and deploys both versioned Skills with a manifest' {
        $preview = & $deploy -SourceRoot (Split-Path -Parent $tools) -InstallRoot $install -RegistryPath $registry -DryRun | ConvertFrom-Json
        $preview.status | Should Be 'DRY_RUN'
        $preview.data.plans.Count | Should Be 2
        $result = & $deploy -SourceRoot (Split-Path -Parent $tools) -InstallRoot $install -RegistryPath $registry -Apply | ConvertFrom-Json
        $result.status | Should Be 'PASS'
        (Get-Content -LiteralPath (Join-Path $install 'codex-memory\version.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version | Should Be '2.0.0'
        (Get-Content -LiteralPath $registry -Raw -Encoding UTF8 | ConvertFrom-Json).skills.Count | Should Be 2
    }

    It 'creates a recoverable backup and rolls back the installed Skill' {
        $first = & $deploy -SkillName codex-memory -SourceRoot (Split-Path -Parent $tools) -InstallRoot $install -RegistryPath $registry -Apply | ConvertFrom-Json
        $result = & $deploy -SkillName codex-memory -SourceRoot (Split-Path -Parent $tools) -InstallRoot $install -RegistryPath $registry -Apply | ConvertFrom-Json
        $result.status | Should Be 'PASS'
        $record = @((Get-Content -LiteralPath $registry -Raw -Encoding UTF8 | ConvertFrom-Json).skills | Where-Object { $_.name -eq 'codex-memory' })[0]
        (Test-Path -LiteralPath $record.backup_path -PathType Container) | Should Be $true
        $preview = & $rollback -SkillName codex-memory -InstallRoot $install -RegistryPath $registry -DryRun | ConvertFrom-Json
        $preview.status | Should Be 'DRY_RUN'
        $rolled = & $rollback -SkillName codex-memory -InstallRoot $install -RegistryPath $registry -Apply | ConvertFrom-Json
        $rolled.status | Should Be 'PASS'
        (Test-Path -LiteralPath (Join-Path $install 'codex-memory\SKILL.md') -PathType Leaf) | Should Be $true
    }
}
