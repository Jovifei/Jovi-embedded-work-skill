$skillRoot = Split-Path -Parent $PSScriptRoot
$scripts = Join-Path $skillRoot 'scripts'

function New-CMFixtureConfig {
    param([string]$MemoryRoot, [string]$Profile = 'home')
    New-Item -ItemType Directory -Path (Join-Path $MemoryRoot '03-项目记忆') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $MemoryRoot '06-模板') -Force | Out-Null
    'index' | Set-Content -LiteralPath (Join-Path $MemoryRoot '00-总索引.md') -Encoding UTF8
    $companyRoot = if ($Profile -eq 'company') { $MemoryRoot } else { '' }
    $config = @{ schema_version = 1; active_profile = $Profile; profiles = @{ home = @{ memory_root = $MemoryRoot; obsidian_vault_root = (Split-Path $MemoryRoot); allow_source_excerpt = $true; allow_raw_logs = $false; allow_snapshot = $false; allow_event_content = $true; allow_staging_sync = $true; allow_personal_sync = $true; source_extensions = @('.md'); approved_memory_roots = @($MemoryRoot) }; company = @{ memory_root = $companyRoot; obsidian_vault_root = if ($companyRoot) { (Split-Path $companyRoot) } else { '' }; allow_source_excerpt = $false; allow_raw_logs = $false; allow_snapshot = $false; allow_event_content = $true; allow_staging_sync = $true; allow_personal_sync = $false; source_extensions = @('.md'); approved_memory_roots = if ($companyRoot) { @($companyRoot) } else { @() } } } }
    New-Item -ItemType Directory -Path $env:CODEX_MEMORY_USER_ROOT -Force | Out-Null
    ($config | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath (Join-Path $env:CODEX_MEMORY_USER_ROOT 'config.yaml') -Encoding UTF8
}

Describe 'codex-memory safety gates' {
    BeforeEach {
        $env:CODEX_MEMORY_USER_ROOT = Join-Path $TestDrive 'user'
        $env:CODEX_MEMORY_LOCAL_ROOT = Join-Path $TestDrive 'local'
        $env:CODEX_MEMORY_ROOT = $null
        $global:fixtureRoot = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $global:fixtureRoot -Force | Out-Null
    }
    AfterEach { Remove-Item Env:CODEX_MEMORY_USER_ROOT -ErrorAction SilentlyContinue; Remove-Item Env:CODEX_MEMORY_LOCAL_ROOT -ErrorAction SilentlyContinue; Remove-Item Env:CODEX_MEMORY_ROOT -ErrorAction SilentlyContinue }

    It 'blocks load when no configuration exists' {
        $result = & (Join-Path $scripts 'resolve-config.ps1') | ConvertFrom-Json
        $result.status | Should Be 'BLOCKED'
    }

    It 'prefers an explicit project id over project configuration' {
        '{"project_id":"configured-id"}' | Set-Content -LiteralPath (Join-Path $global:fixtureRoot '.project-memory.yaml') -Encoding UTF8
        $result = & (Join-Path $scripts 'discover-project.ps1') -ProjectRoot $global:fixtureRoot -ProjectId 'explicit id' | ConvertFrom-Json
        $result.data.project_id | Should Be 'explicit-id'
        $result.data.identity_source | Should Be 'explicit'
    }

    It 'does not write configuration during setup preview' {
        $result = & (Join-Path $scripts 'setup.ps1') -Profile company | ConvertFrom-Json
        $result.status | Should Be 'READY_FOR_APPLY'
        (Test-Path -LiteralPath (Join-Path $env:CODEX_MEMORY_USER_ROOT 'config.yaml')) | Should Be $false
    }

    It 'requires an explicit VaultRoot for home setup' {
        $result = & (Join-Path $scripts 'setup.ps1') -Profile home | ConvertFrom-Json
        $result.status | Should Be 'BLOCKED'
        $result.message | Should Match 'requires -VaultRoot'
        (Test-Path -LiteralPath (Join-Path $env:CODEX_MEMORY_USER_ROOT 'config.yaml')) | Should Be $false
    }

    It 'keeps manual content while replacing a managed block' {
        $memory = Join-Path $TestDrive 'memory'
        New-Item -ItemType Directory -Path (Join-Path $memory '03-项目记忆') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $memory '06-模板') -Force | Out-Null
        'index' | Set-Content -LiteralPath (Join-Path $memory '00-总索引.md') -Encoding UTF8
        $config = @{ schema_version = 1; active_profile = 'home'; profiles = @{ home = @{ memory_root = $memory; obsidian_vault_root = (Split-Path $memory); allow_source_excerpt = $true; allow_raw_logs = $false; allow_snapshot = $false; allow_event_content = $true; allow_staging_sync = $true; allow_personal_sync = $true; source_extensions = @('.md') }; company = @{ memory_root = ''; obsidian_vault_root = ''; allow_source_excerpt = $false; allow_raw_logs = $false; allow_snapshot = $false; allow_event_content = $true; allow_staging_sync = $true; allow_personal_sync = $false; source_extensions = @('.md') } } }
        New-Item -ItemType Directory -Path $env:CODEX_MEMORY_USER_ROOT -Force | Out-Null
        ($config | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath (Join-Path $env:CODEX_MEMORY_USER_ROOT 'config.yaml') -Encoding UTF8
        $operation = @{ profile = 'home'; project_id = 'fixture'; target = 'vault'; operations = @(@{ slot = 'overview'; content = '## Purpose`n- Verified memory content with enough substance.' }) }
        $operationPath = Join-Path $TestDrive 'operation.json'; ($operation | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $operationPath -Encoding UTF8
        (& (Join-Path $scripts 'apply-sync.ps1') -OperationPath $operationPath -Apply | ConvertFrom-Json).status | Should Be 'PASS'
        $overview = Join-Path $memory '03-项目记忆\fixture\00-项目概览.md'
        Add-Content -LiteralPath $overview -Value "`nManual preservation note."
        $operation.operations[0].content = '## Purpose`n- Updated verified memory content with enough substance.'
        ($operation | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $operationPath -Encoding UTF8
        (& (Join-Path $scripts 'apply-sync.ps1') -OperationPath $operationPath -Apply | ConvertFrom-Json).status | Should Be 'PASS'
        (Get-Content -LiteralPath $overview -Raw) | Should Match 'Manual preservation note'
        (Get-Content -LiteralPath $overview -Raw) | Should Match 'Updated verified memory content'
    }

    It 'falls back safely when the repository has no docs directory' {
        $result = & (Join-Path $scripts 'discover-project.ps1') -ProjectRoot $global:fixtureRoot | ConvertFrom-Json
        $result.status | Should Be 'PASS'
        @($result.data.preferred_docs).Count | Should Be 0
    }

    It 'keeps company profile fail-closed without an approved memory root' {
        $result = & (Join-Path $scripts 'setup.ps1') -Profile company -Apply | ConvertFrom-Json
        $result.status | Should Be 'PASS'
        $resolved = & (Join-Path $scripts 'resolve-config.ps1') -Profile company -RequireMemoryRoot | ConvertFrom-Json
        $resolved.status | Should Be 'BLOCKED'
    }

    It 'builds all three-way initial sync outcomes without writing' {
        $memory = Join-Path $TestDrive 'memory'; New-CMFixtureConfig -MemoryRoot $memory
        $staging = Join-Path $env:CODEX_MEMORY_LOCAL_ROOT 'staging\repo'
        $vault = Join-Path $memory '03-项目记忆\repo'
        New-Item -ItemType Directory -Path $staging,$vault -Force | Out-Null
        'stage' | Set-Content -LiteralPath (Join-Path $staging '00-项目概览.md') -Encoding UTF8
        'vault-only' | Set-Content -LiteralPath (Join-Path $vault '01-总体计划.md') -Encoding UTF8
        'same' | Set-Content -LiteralPath (Join-Path $staging '02-当前进度.md') -Encoding UTF8
        'same' | Set-Content -LiteralPath (Join-Path $vault '02-当前进度.md') -Encoding UTF8
        'left' | Set-Content -LiteralPath (Join-Path $staging '03-关键决策.md') -Encoding UTF8
        'right' | Set-Content -LiteralPath (Join-Path $vault '03-关键决策.md') -Encoding UTF8
        $plan = & (Join-Path $scripts 'build-sync-plan.ps1') -ProjectRoot $global:fixtureRoot -ProjectId repo | ConvertFrom-Json
        $plan.status | Should Be 'CONFLICT'
        (@($plan.data.operations | Where-Object { $_.slot -eq '00-项目概览.md' })[0].action) | Should Be 'COPY_TO_VAULT'
        (@($plan.data.operations | Where-Object { $_.slot -eq '01-总体计划.md' })[0].action) | Should Be 'BASELINE_VAULT'
        (@($plan.data.operations | Where-Object { $_.slot -eq '02-当前进度.md' })[0].action) | Should Be 'BASELINE_EQUAL'
        (@($plan.data.operations | Where-Object { $_.slot -eq '03-关键决策.md' })[0].action) | Should Be 'CONFLICT'
    }

    It 'blocks company snapshots even with an otherwise valid approved root' {
        $memory = Join-Path $TestDrive 'memory'; New-CMFixtureConfig -MemoryRoot $memory -Profile company
        $source = Join-Path $TestDrive 'source.md'; 'safe markdown' | Set-Content -LiteralPath $source -Encoding UTF8
        $result = & (Join-Path $scripts 'create-snapshot.ps1') -Profile company -SourcePath $source -ProjectId repo -DryRun | ConvertFrom-Json
        $result.status | Should Be 'BLOCKED'
        $result.message | Should Match 'does not permit snapshots'
    }

    It 'rejects event writes that did not follow a successful archive' {
        $memory = Join-Path $TestDrive 'memory'; New-CMFixtureConfig -MemoryRoot $memory
        $event = @{ project_id = 'repo'; evidence = @('test summary') }
        $path = Join-Path $TestDrive 'event.json'; ($event | ConvertTo-Json) | Set-Content -LiteralPath $path -Encoding UTF8
        $result = & (Join-Path $scripts 'write-event.ps1') -EventPath $path -DryRun | ConvertFrom-Json
        $result.status | Should Be 'BLOCKED'
    }

    It 'leaves Claude settings untouched during hook preview' {
        $settings = Join-Path $TestDrive 'settings.json'
        (@{ hooks = @{ SessionStart = @(@{ hooks = @(@{ type = 'command'; command = 'existing-safe-hook' }) }) } } | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $settings -Encoding UTF8
        $before = (Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash
        $result = & (Join-Path $scripts 'install-session-hook.ps1') -SettingsPath $settings | ConvertFrom-Json
        $after = (Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash
        $result.status | Should Be 'DRY_RUN'
        $after | Should Be $before
    }

    It 'creates no task during scheduled-task preview' {
        $result = & (Join-Path $scripts 'install-scheduled-task.ps1') -Profile home | ConvertFrom-Json
        $result.status | Should Be 'DRY_RUN'
        (Get-ScheduledTask -TaskName 'CodexMemory-DailyReview' -ErrorAction SilentlyContinue) | Should Be $null
    }

    It 'blocks a company environment override to an unapproved root' {
        $memory = Join-Path $TestDrive 'company-memory'; New-CMFixtureConfig -MemoryRoot $memory -Profile company
        $other = Join-Path $TestDrive 'other-memory'
        New-Item -ItemType Directory -Path (Join-Path $other '03-项目记忆'),(Join-Path $other '06-模板') -Force | Out-Null
        'index' | Set-Content -LiteralPath (Join-Path $other '00-总索引.md') -Encoding UTF8
        $env:CODEX_MEMORY_ROOT = $other
        $result = & (Join-Path $scripts 'resolve-config.ps1') -Profile company -RequireMemoryRoot | ConvertFrom-Json
        $result.status | Should Be 'BLOCKED'
        $result.message | Should Match 'forbids CODEX_MEMORY_ROOT overrides'
    }

    It 'applies a valid initial staging-to-vault copy and ignores serialized destination paths' {
        $memory = Join-Path $TestDrive 'memory'; New-CMFixtureConfig -MemoryRoot $memory
        $staging = Join-Path $env:CODEX_MEMORY_LOCAL_ROOT 'staging\apply-repo'; New-Item -ItemType Directory -Path $staging -Force | Out-Null
        'initial stage' | Set-Content -LiteralPath (Join-Path $staging '00-项目概览.md') -Encoding UTF8
        $plan = & (Join-Path $scripts 'build-sync-plan.ps1') -ProjectRoot $global:fixtureRoot -ProjectId apply-repo | ConvertFrom-Json
        $plan.data.operations[0].vault_path = (Join-Path $TestDrive 'attacker.md')
        $path = Join-Path $TestDrive 'sync.json'; ($plan | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $path -Encoding UTF8
        $result = & (Join-Path $scripts 'apply-sync.ps1') -SyncPlanPath $path -Apply | ConvertFrom-Json
        $result.status | Should Be 'PASS'
        (Test-Path -LiteralPath (Join-Path $memory '03-项目记忆\apply-repo\00-项目概览.md')) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $TestDrive 'attacker.md')) | Should Be $false
    }

    It 'excludes unmarked local JSON from daily review' {
        $memory = Join-Path $TestDrive 'memory'; New-CMFixtureConfig -MemoryRoot $memory
        $eventDirectory = Join-Path $env:CODEX_MEMORY_LOCAL_ROOT ('events\' + (Get-Date -Format 'yyyy-MM-dd'))
        New-Item -ItemType Directory -Path $eventDirectory -Force | Out-Null
        (@{ schema_version = 1; project_id = 'repo'; evidence = @('forged') } | ConvertTo-Json) | Set-Content -LiteralPath (Join-Path $eventDirectory 'forged.json') -Encoding UTF8
        $result = & (Join-Path $scripts 'build-daily-review.ps1') -Profile home -DryRun | ConvertFrom-Json
        $result.status | Should Be 'NO_EVENTS'
    }

    It 'builds a review only from a sanitized successful archive event' {
        $memory = Join-Path $TestDrive 'memory'; New-CMFixtureConfig -MemoryRoot $memory
        $event = @{ archive_success = $true; project_id = 'review-repo'; goal = 'verify event flow'; evidence = @('Pester fixture passed'); completed = @('archive completed'); changed_files = @('docs/README.md'); source_revision = 'test-revision' }
        $path = Join-Path $TestDrive 'success-event.json'; ($event | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $path -Encoding UTF8
        $written = & (Join-Path $scripts 'write-event.ps1') -Profile home -EventPath $path -Apply | ConvertFrom-Json
        $written.status | Should Be 'PASS'
        $review = & (Join-Path $scripts 'build-daily-review.ps1') -Profile home -DryRun | ConvertFrom-Json
        $review.status | Should Be 'DRY_RUN'
        $review.data.draft | Should Match 'review-repo'
    }
}

