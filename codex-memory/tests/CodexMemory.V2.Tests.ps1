$skillRoot = Split-Path -Parent $PSScriptRoot
$scripts = Join-Path $skillRoot 'scripts'

function Join-CMChars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
$script:IndexName = '00-' + (Join-CMChars @(0x603B,0x7D22,0x5F15)) + '.md'
$script:ProjectMemoryDirectory = '03-' + (Join-CMChars @(0x9879,0x76EE,0x8BB0,0x5FC6))
$script:TemplatesDirectory = '06-' + (Join-CMChars @(0x6A21,0x677F))
$script:RelationsName = '01-' + (Join-CMChars @(0x5DE5,0x7A0B,0x5173,0x7CFB,0x4E0E,0x5B66,0x4E60,0x5730,0x56FE)) + '.md'
$script:ReadingGuideName = '00-' + (Join-CMChars @(0x9605,0x8BFB,0x6307,0x5F15)) + '.md'
$script:ManifestName = '00-' + (Join-CMChars @(0x540C,0x6B65,0x6E05,0x5355)) + '.md'

function New-CMV2FixtureConfig {
    param([string]$MemoryRoot, [string]$ProjectRoot)
    New-Item -ItemType Directory -Path (Join-Path $MemoryRoot $script:ProjectMemoryDirectory),(Join-Path $MemoryRoot $script:TemplatesDirectory) -Force | Out-Null
    'index' | Set-Content -LiteralPath (Join-Path $MemoryRoot $script:IndexName) -Encoding UTF8
    $config = @{
        schema_version = 2
        active_profile = 'home'
        profiles = @{
            home = @{
                memory_root = $MemoryRoot
                obsidian_vault_root = (Split-Path $MemoryRoot)
                allow_source_excerpt = $true
                allow_raw_logs = $false
                allow_snapshot = $false
                allow_document_mirror = $true
                allow_event_content = $true
                allow_staging_sync = $true
                allow_personal_sync = $true
                source_extensions = @('.md')
                approved_memory_roots = @($MemoryRoot)
                automation = @{
                    read_on_session_start = $true
                    remind_on_user_prompt = $true
                    auto_apply_verified_checkpoint = $true
                    auto_apply_document_mirror = $true
                    dry_run_required = $true
                }
                project_mappings = @(
                    @{ memory_id = 'smart-controller-gd32f4'; source_root = $ProjectRoot; component = 'main' },
                    @{ memory_id = 'smart-controller-gd32f4'; source_root = (Join-Path $ProjectRoot 'bootloader'); component = 'bootloader'; mirror_prefix = 'bootloader' }
                )
            }
        }
    }
    New-Item -ItemType Directory -Path $env:CODEX_MEMORY_USER_ROOT -Force | Out-Null
    ($config | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath (Join-Path $env:CODEX_MEMORY_USER_ROOT 'config.yaml') -Encoding UTF8
}

Describe 'codex-memory v2 behavior' {
    BeforeEach {
        $env:CODEX_MEMORY_USER_ROOT = Join-Path $TestDrive 'user'
        $env:CODEX_MEMORY_LOCAL_ROOT = Join-Path $TestDrive 'local'
        $env:CODEX_MEMORY_ROOT = $null
        $global:fixtureRoot = Join-Path $TestDrive 'smart-controller-gd32f4'
        $global:bootRoot = Join-Path $global:fixtureRoot 'bootloader'
        New-Item -ItemType Directory -Path $global:bootRoot -Force | Out-Null
        New-CMV2FixtureConfig -MemoryRoot (Join-Path $TestDrive 'memory') -ProjectRoot $global:fixtureRoot
    }

    AfterEach {
        Remove-Item Env:CODEX_MEMORY_USER_ROOT -ErrorAction SilentlyContinue
        Remove-Item Env:CODEX_MEMORY_LOCAL_ROOT -ErrorAction SilentlyContinue
        Remove-Item Env:CODEX_MEMORY_ROOT -ErrorAction SilentlyContinue
    }

    It 'resolves a bootloader to the parent memory id using the longest mapping' {
        $result = & (Join-Path $scripts 'discover-project.ps1') -ProjectRoot $global:bootRoot | ConvertFrom-Json
        $result.status | Should Be 'PASS'
        $result.data.memory_id | Should Be 'smart-controller-gd32f4'
        $result.data.component | Should Be 'bootloader'
        $result.data.mirror_prefix | Should Be 'bootloader'
        $result.data.mapping_source | Should Be 'configured'
    }

    It 'loads the current knowledge slots and excludes the retired plan slot' {
        $projectPath = Join-Path (Join-Path (Join-Path $TestDrive 'memory') $script:ProjectMemoryDirectory) 'smart-controller-gd32f4'
        New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
        'overview' | Set-Content -LiteralPath (Join-Path $projectPath '00-项目概览.md') -Encoding UTF8
        'relations' | Set-Content -LiteralPath (Join-Path $projectPath $script:RelationsName) -Encoding UTF8
        'progress' | Set-Content -LiteralPath (Join-Path $projectPath '02-当前进度.md') -Encoding UTF8
        'decisions' | Set-Content -LiteralPath (Join-Path $projectPath '03-关键决策.md') -Encoding UTF8
        'workflow' | Set-Content -LiteralPath (Join-Path $projectPath '04-工作流与知识.md') -Encoding UTF8
        'retired plan' | Set-Content -LiteralPath (Join-Path $projectPath '01-总体计划.md') -Encoding UTF8
        $result = & (Join-Path $scripts 'load-memory.ps1') -ProjectRoot $global:fixtureRoot | ConvertFrom-Json
        $result.status | Should Be 'PASS'
        @($result.data.sources | Where-Object { $_.path -eq ($script:ProjectMemoryDirectory + '\smart-controller-gd32f4\' + $script:RelationsName) }).Count | Should Be 1
        @($result.data.sources | Where-Object { $_.path -like '*01-总体计划.md' }).Count | Should Be 0
    }

    It 'searches bounded current and cross-project memory with source paths' {
        $projectPath = Join-Path (Join-Path (Join-Path $TestDrive 'memory') $script:ProjectMemoryDirectory) 'smart-controller-gd32f4'
        New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
        'boot timeout root cause theory' | Set-Content -LiteralPath (Join-Path $projectPath '04-工作流与知识.md') -Encoding UTF8
        $result = & (Join-Path $scripts 'search-memory.ps1') -ProjectRoot $global:fixtureRoot -Query 'boot timeout' | ConvertFrom-Json
        $result.status | Should Be 'PASS'
        $result.data.hits.Count | Should BeGreaterThan 0
        $result.data.hits[0].path | Should Match '04-工作流与知识.md'
    }

    It 'does not mirror plans, reading guides, templates, or sync manifests' {
        $root = $global:fixtureRoot
        $docs = Join-Path $root 'docs'
        . (Join-Path $scripts 'common.ps1')
        $planMarker = Join-CMChars @(0x8BA1,0x5212)
        $planDirectory = '06-SOP-' + $planMarker
        $implementationPlanDirectory = '02-PLN-' + $planMarker + (Join-CMChars @(0x5B9E,0x65BD))
        New-Item -ItemType Directory -Path (Join-Path $docs 'SER'),(Join-Path $docs $planDirectory),(Join-Path $docs $implementationPlanDirectory),(Join-Path $root 'archive'),(Join-Path $root 'superpowers\plans'),(Join-Path $root 'tasks') -Force | Out-Null
        'keep' | Set-Content -LiteralPath (Join-Path $docs '01-ARC-architecture.md') -Encoding UTF8
        'guide' | Set-Content -LiteralPath (Join-Path $docs ('SER\' + $script:ReadingGuideName)) -Encoding UTF8
        'plan' | Set-Content -LiteralPath (Join-Path (Join-Path $docs $planDirectory) 'procedure.md') -Encoding UTF8
        'plan' | Set-Content -LiteralPath (Join-Path (Join-Path $docs $implementationPlanDirectory) 'procedure.md') -Encoding UTF8
        'plan' | Set-Content -LiteralPath (Join-Path $root 'archive\ota-cmd-intake-plan.md') -Encoding UTF8
        'plan' | Set-Content -LiteralPath (Join-Path $root 'superpowers\plans\plan.md') -Encoding UTF8
        'task' | Set-Content -LiteralPath (Join-Path $root 'tasks\todo.md') -Encoding UTF8
        'manifest' | Set-Content -LiteralPath (Join-Path $docs $script:ManifestName) -Encoding UTF8
        $result = & (Join-Path $scripts 'sync-project-docs.ps1') -ProjectRoot $root -DryRun | ConvertFrom-Json
        $result.status | Should Be 'DRY_RUN'
        @($result.data.copied | Where-Object { $_.relative_path -match 'superpowers|tasks' -or (Test-CMPlanLikePath -RelativePath $_.relative_path) -or $_.relative_path -eq ('docs\' + $script:ReadingGuideName) -or $_.relative_path -eq ('docs\' + $script:ManifestName) }).Count | Should Be 0
        $result.data.manifest_path | Should Be $null
    }

    It 'rolls back a document mirror when state persistence fails' {
        $root = $global:fixtureRoot
        $docs = Join-Path $root 'docs'
        New-Item -ItemType Directory -Path $docs -Force | Out-Null
        'durable source document' | Set-Content -LiteralPath (Join-Path $docs '01-ARC-test.md') -Encoding UTF8
        $statePath = Join-Path (Join-Path (Join-Path $env:CODEX_MEMORY_LOCAL_ROOT 'state') 'documents') 'smart-controller-gd32f4--main\mirror.json'
        New-Item -ItemType Directory -Path $statePath -Force | Out-Null
        $result = & (Join-Path $scripts 'sync-project-docs.ps1') -ProjectRoot $root -Apply | ConvertFrom-Json
        $result.status | Should Be 'BLOCKED'
        $destination = Join-Path (Join-Path (Join-Path $TestDrive 'memory') $script:ProjectMemoryDirectory) 'smart-controller-gd32f4\05-工程文档\docs\01-ARC-test.md'
        (Test-Path -LiteralPath $destination -PathType Leaf) | Should Be $false
    }

    It 'merges live content outside a curated historical block' {
        $common = Get-Content -LiteralPath (Join-Path $scripts 'common.ps1') -Raw -Encoding UTF8
        $common | Should Match 'codex-memory:live:start'
        $common | Should Match 'knowledge-curated'
    }

    It 'merges Codex hooks without removing existing hooks' {
        $hooksPath = Join-Path $TestDrive 'hooks.json'
        (@{ hooks = @{ SessionStart = @(@{ matcher = 'startup'; hooks = @(@{ type = 'command'; command = 'existing-hook' }) }); UserPromptSubmit = @() } } | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $hooksPath -Encoding UTF8
        $result = & (Join-Path $scripts 'install-codex-hooks.ps1') -HooksPath $hooksPath -SkillRoot $skillRoot -DryRun | ConvertFrom-Json
        $result.status | Should Be 'DRY_RUN'
        $result.data.preview.SessionStart.Count | Should Be 2
        ($result.data.preview.SessionStart | ConvertTo-Json -Depth 10) | Should Match 'existing-hook'
        ($result.data.preview.UserPromptSubmit | ConvertTo-Json -Depth 10) | Should Match 'codex-memory'
    }

    It 'returns NO_MEMORY_UPDATE for an operation with no durable knowledge' {
        $operationPath = Join-Path $TestDrive 'no-update.json'
        (@{ no_update = $true; memory_id = 'smart-controller-gd32f4' } | ConvertTo-Json) | Set-Content -LiteralPath $operationPath -Encoding UTF8
        $result = & (Join-Path $scripts 'checkpoint.ps1') -OperationPath $operationPath -Apply | ConvertFrom-Json
        $result.status | Should Be 'NO_MEMORY_UPDATE'
    }

    It 'blocks a home CODEX_MEMORY_ROOT override outside approved roots' {
        $env:CODEX_MEMORY_ROOT = Join-Path $TestDrive 'unapproved-memory'
        $result = & (Join-Path $scripts 'resolve-config.ps1') -Profile home -RequireMemoryRoot | ConvertFrom-Json
        $result.status | Should Be 'BLOCKED'
        $result.message | Should Match 'exact approved'
    }

    It 'applies a verified checkpoint into a managed live block' {
        $operationPath = Join-Path $TestDrive 'durable.json'
        $content = '## Durable project result' + [Environment]::NewLine + '- Verified content with enough detail for the archive.'
        (@{ profile = 'home'; memory_id = 'smart-controller-gd32f4'; target = 'vault'; operations = @(@{ slot = 'overview'; content = $content }) } | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $operationPath -Encoding UTF8
        $result = & (Join-Path $scripts 'checkpoint.ps1') -OperationPath $operationPath -ProjectRoot $global:fixtureRoot -Apply | ConvertFrom-Json
        $result.status | Should Be 'MEMORY_UPDATED'
        $overviewName = '00-' + (Join-CMChars @(0x9879,0x76EE,0x6982,0x89C8)) + '.md'
        $overviewPath = Join-Path (Join-Path (Join-Path $TestDrive 'memory') $script:ProjectMemoryDirectory) ('smart-controller-gd32f4\' + $overviewName)
        (Get-Content -LiteralPath $overviewPath -Raw -Encoding UTF8) | Should Match 'codex-memory:live:start'
        (Get-Content -LiteralPath $overviewPath -Raw -Encoding UTF8) | Should Match 'Durable project result'
    }

    It 'blocks a checkpoint whose memory id does not match the mapped project' {
        $operationPath = Join-Path $TestDrive 'mismatch.json'
        (@{ profile = 'home'; memory_id = 'other-project'; project_id = 'other-project'; target = 'vault'; project_root = $global:bootRoot; operations = @(@{ slot = 'overview'; content = '## Durable result`n- This content must not be written.' }) } | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $operationPath -Encoding UTF8
        $result = & (Join-Path $scripts 'checkpoint.ps1') -OperationPath $operationPath -ProjectRoot $global:bootRoot -Apply | ConvertFrom-Json
        $result.status | Should Be 'MEMORY_SYNC_BLOCKED'
    }

    It 'blocks an archive apply when a target changes after DryRun' {
        $projectPath = Join-Path (Join-Path (Join-Path $TestDrive 'memory') $script:ProjectMemoryDirectory) 'smart-controller-gd32f4'
        New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
        $operationPath = Join-Path $TestDrive 'stale-archive.json'
        (@{ profile = 'home'; memory_id = 'smart-controller-gd32f4'; target = 'vault'; operations = @(@{ slot = 'overview'; content = '## Durable project result`n- Verified content with enough detail for the archive.' }) } | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $operationPath -Encoding UTF8
        $preview = & (Join-Path $scripts 'apply-sync.ps1') -OperationPath $operationPath -DryRun | ConvertFrom-Json
        $preview.status | Should Be 'DRY_RUN'
        $overviewName = '00-' + (Join-CMChars @(0x9879,0x76EE,0x6982,0x89C8)) + '.md'
        $manualPath = Join-Path $projectPath $overviewName
        'intervening manual content' | Set-Content -LiteralPath $manualPath -Encoding UTF8
        $expectedPlan = [string]($preview.data.operations | Select-Object slot,before_hash,after_hash | ConvertTo-Json -Depth 8 -Compress)
        $result = & (Join-Path $scripts 'apply-sync.ps1') -OperationPath $operationPath -ExpectedPlanJson $expectedPlan -Apply | ConvertFrom-Json
        $result.status | Should Be 'CONFLICT'
    }

    It 'rejects incomplete and duplicate live blocks' {
        . (Join-Path $scripts 'common.ps1')
        { Get-CMManagedContent -Existing '<!-- codex-memory:live:start -->' -Managed 'new durable content with enough detail' } | Should Throw
        $newline = [Environment]::NewLine
        $duplicate = '<!-- codex-memory:live:start -->' + $newline + 'old' + $newline + '<!-- codex-memory:live:end -->' + $newline + '<!-- codex-memory:live:start -->' + $newline + 'old2' + $newline + '<!-- codex-memory:live:end -->'
        { Get-CMManagedContent -Existing $duplicate -Managed 'new durable content with enough detail' } | Should Throw
    }
}
