[CmdletBinding()]
param([string]$ProjectRoot = (Get-Location).Path, [string]$ProjectId)
. (Join-Path $PSScriptRoot 'common.ps1')

function Get-CMLocalProjectConfig([string]$Root) {
    foreach ($name in @('.project-memory.local.yaml', '.project-memory.yaml')) {
        $path = Join-Path $Root $name
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            try {
                $value = ConvertTo-CMObject -Path $path
                $allowed = @('project_id','scope','docs_root')
                foreach ($property in $value.PSObject.Properties.Name) { if ($property -notin $allowed) { throw "Project config contains unsupported field '$property'." } }
                if (($value.PSObject.Properties.Name -contains 'docs_root') -and -not (Test-CMSafeRelativePath ([string]$value.docs_root))) { throw 'Project docs_root must be a safe relative path.' }
                return [pscustomobject]@{ path = $path; value = $value }
            } catch { throw "Project config is invalid: $path. $($_.Exception.Message)" }
        }
    }
    return $null
}

try {
    $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $config = Get-CMLocalProjectConfig $root
    $source = 'directory'
    $candidate = $ProjectId
    if ($candidate) { $source = 'explicit' }
    elseif ($config -and $config.value.project_id) { $candidate = [string]$config.value.project_id; $source = (Split-Path -Leaf $config.path) }
    else {
        $remote = (& git -C $root config --get remote.origin.url 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remote)) {
            $clean = [regex]::Replace($remote.Trim(), '^[a-z]+://[^/@]+@', '')
            $clean = $clean -replace '\.git$', ''
            $candidate = Split-Path ($clean -replace ':', '/') -Leaf
            $source = 'git_remote'
        }
    }
    if (-not $candidate) { $candidate = Split-Path -Leaf $root }
    $id = ConvertTo-CMSafeId $candidate
    $hasDocsRoot = $config -and ($config.value.PSObject.Properties.Name -contains 'docs_root') -and -not [string]::IsNullOrWhiteSpace([string]$config.value.docs_root)
    $docsRoot = if ($hasDocsRoot) { Join-Path $root ([string]$config.value.docs_root) } else { Join-Path $root 'docs' }
    $docs = @()
    foreach ($path in @((Join-Path $docsRoot 'README.md'), (Join-Path $docsRoot 'GUIDE.md'), (Join-Path $root 'README.md'))) { if (Test-Path -LiteralPath $path -PathType Leaf) { $docs += $path.Substring($root.Length).TrimStart('\\','/') } }
    $scopeId = if ($config -and ($config.value.PSObject.Properties.Name -contains 'scope')) { ConvertTo-CMSafeId ([string]$config.value.scope) } else { $null }
    $memoryId = if ($scopeId) { ConvertTo-CMSafeId ($id + '--' + $scopeId) } else { $id }
    (Get-CMResult -Status 'PASS' -Message 'Project identity resolved.' -Data @{ project_root = $root; project_id = $id; scope_id = $scopeId; memory_id = $memoryId; identity_source = $source; project_config = if ($config) { $config.path } else { $null }; docs_root = $docsRoot; preferred_docs = $docs }) | ConvertTo-Json -Depth 6
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6; exit 1
}

