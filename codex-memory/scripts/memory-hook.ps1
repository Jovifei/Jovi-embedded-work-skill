[CmdletBinding()]
param(
    [ValidateSet('SessionStart','UserPromptSubmit')][string]$Mode = 'SessionStart'
)
. (Join-Path $PSScriptRoot 'common.ps1')

function Write-CMHookContext {
    param([string]$Context)
    @{ continue = $true; additionalContext = $Context } | ConvertTo-Json -Compress
}

try {
    $inputText = [Console]::In.ReadToEnd()
    $payload = $null
    if (-not [string]::IsNullOrWhiteSpace($inputText)) { try { $payload = $inputText | ConvertFrom-Json } catch { $payload = $null } }
    $root = if ($payload -and $payload.cwd) { [string]$payload.cwd } else { (Get-Location).Path }
    if ($Mode -eq 'SessionStart') {
        $loaded = & (Join-Path $PSScriptRoot 'load-memory.ps1') -ProjectRoot $root -Format Context -MaxCharacters 7000 2>$null
        Write-CMHookContext -Context ([string]$loaded -join "`n")
        exit 0
    }
    $prompt = ''
    if (-not [string]::IsNullOrWhiteSpace($inputText)) {
        if ($payload) { $prompt = [string]$payload.prompt } else { $prompt = $inputText }
    }
    $tokens = @(([regex]::Matches($prompt, '[A-Za-z][A-Za-z0-9_-]{3,}|[\u4e00-\u9fff]{2,}') | ForEach-Object { $_.Value } | Select-Object -Unique -First 3))
    if ($tokens.Count -gt 0) {
        $search = & (Join-Path $PSScriptRoot 'search-memory.ps1') -ProjectRoot $root -Query ($tokens -join ' ') -MaxHits 6 -MaxCharacters 3500 2>$null | ConvertFrom-Json
        if ($search.status -eq 'PASS' -and $search.data.hit_count -gt 0) {
            $lines = @('[codex-memory] Treat Obsidian as prior context and current source/evidence as authority.', '[codex-memory] Targeted memory hits:')
            foreach ($hit in @($search.data.hits)) { $lines += ('- ' + $hit.path + ':' + $hit.line + ' ' + $hit.excerpt) }
            Write-CMHookContext -Context ($lines -join "`n")
            exit 0
        }
    }
    Write-CMHookContext -Context '[codex-memory] In a mapped project, load/search Obsidian before investigation; after verified durable results, run checkpoint DryRun then Apply.'
} catch {
    Write-CMHookContext -Context '[codex-memory] Memory hook could not load context; continue with source evidence and report MEMORY_SYNC_BLOCKED if a write is required.'
}
