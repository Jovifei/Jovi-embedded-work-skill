[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Query,
    [ValidateSet('home','company')][string]$Profile,
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$ProjectId,
    [ValidateRange(1,100)][int]$MaxHits = 20,
    [ValidateRange(1000,30000)][int]$MaxCharacters = 12000
)
. (Join-Path $PSScriptRoot 'common.ps1')

function Test-CMSearchablePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $name = [System.IO.Path]::GetFileName($Path)
    $relative = $Path -replace '\\','/'
    if ($name -match '^(?i:00-.*(?:\u9605|\u8BFB|\u6307|\u5F15|\u6A21|\u677F|\u540C|\u6B65|template|guide|manifest|sync).*)\.md$') { return $false }
    if ($relative -match '(^|/)(superpowers/plans|superpowers/specs|tasks)(/|$)') { return $false }
    return $true
}

try {
    if ([string]::IsNullOrWhiteSpace($Query)) { throw 'Search query must not be empty.' }
    $terms = @($Query -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $configArgs = @{ RequireMemoryRoot = $true }
    if ($Profile) { $configArgs.Profile = $Profile }
    $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') @configArgs | ConvertFrom-Json
    if ($config.status -ne 'PASS') { throw $config.message }
    $projectArgs = @{ ProjectRoot = $ProjectRoot }
    if ($ProjectId) { $projectArgs.ProjectId = $ProjectId }
    $project = & (Join-Path $PSScriptRoot 'discover-project.ps1') @projectArgs | ConvertFrom-Json
    if ($project.status -ne 'PASS') { throw $project.message }

    $memoryRoot = [string]$config.data.memory_root
    $currentId = ConvertTo-CMSafeId ([string]$project.data.memory_id)
    $projectRoot = Get-CMProjectMemoryPath -MemoryRoot $memoryRoot -ProjectId $currentId
    if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) {
        (Get-CMResult -Status 'NO_PROJECT_MEMORY' -Message 'No project memory exists; search did not create notes.' -Data @{ project_id = $project.data.project_id; memory_id = $currentId; hits = @() }) | ConvertTo-Json -Depth 8
        exit 0
    }

    $roots = @($projectRoot)
    $projectMemoryDirectory = '03-' + (-join ([int[]]@(0x9879,0x76EE,0x8BB0,0x5FC6) | ForEach-Object { [char]$_ }))
    $allProjectsRoot = Join-Path $memoryRoot $projectMemoryDirectory
    if (Test-Path -LiteralPath $allProjectsRoot -PathType Container) {
        $roots += @(Get-ChildItem -LiteralPath $allProjectsRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $currentId })
    }
    foreach ($globalFile in @(Get-ChildItem -LiteralPath $memoryRoot -File -Filter '*.md' -ErrorAction SilentlyContinue)) { $roots += $globalFile.FullName }
    foreach ($globalDirectory in @(Get-ChildItem -LiteralPath $memoryRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^0[12]-' })) { $roots += $globalDirectory.FullName }
    $files = @()
    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root -PathType Leaf) { $files += Get-Item -LiteralPath $root; continue }
        if (Test-Path -LiteralPath $root -PathType Container) { $files += @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue) }
    }
    $unique = @{}
    $hits = @()
    $used = 0
    foreach ($file in $files) {
        $key = (Get-CMCanonicalPath $file.FullName).ToLowerInvariant()
        if ($unique.ContainsKey($key) -or -not (Test-CMSearchablePath $file.FullName)) { continue }
        $unique[$key] = $true
        $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = [string]$lines[$i]
            $matchedTerm = @($terms | Where-Object { $line.IndexOf([string]$_, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object -First 1)
            if ($matchedTerm.Count -eq 0) { continue }
            $excerpt = ConvertTo-CMRedactedText $line
            if ($excerpt.Length -gt 800) { $excerpt = $excerpt.Substring(0, 800) + ' [truncated]' }
            $relative = $file.FullName.Substring($memoryRoot.Length).TrimStart('\','/')
            $hitProject = $currentId
            if (Test-CMPathWithin -Root $allProjectsRoot -Candidate $file.FullName) {
                $projectRelative = $file.FullName.Substring($allProjectsRoot.Length).TrimStart('\','/')
                if ($projectRelative) { $hitProject = $projectRelative.Split('\')[0] }
            }
            $hit = [pscustomobject]@{ project_id = $hitProject; path = $relative; line = $i + 1; matched_term = [string]$matchedTerm[0]; excerpt = $excerpt }
            $hits += $hit
            $used += $excerpt.Length
            if ($hits.Count -ge $MaxHits -or $used -ge $MaxCharacters) { break }
        }
        if ($hits.Count -ge $MaxHits -or $used -ge $MaxCharacters) { break }
    }
    (Get-CMResult -Status 'PASS' -Message 'Bounded project memory search completed.' -Data @{ project_id = $project.data.project_id; memory_id = $currentId; query = $Query; hit_count = $hits.Count; characters = $used; hits = @($hits) }) | ConvertTo-Json -Depth 10
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6
    exit 1
}
