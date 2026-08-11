Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CMUserRoot {
    if ($env:CODEX_MEMORY_USER_ROOT) { return $env:CODEX_MEMORY_USER_ROOT }
    return (Join-Path $env:USERPROFILE '.codex-memory')
}

function Get-CMLocalRoot {
    if ($env:CODEX_MEMORY_LOCAL_ROOT) { return $env:CODEX_MEMORY_LOCAL_ROOT }
    return (Join-Path $env:LOCALAPPDATA 'codex-memory')
}

function Get-CMConfigPath {
    return (Join-Path (Get-CMUserRoot) 'config.yaml')
}

function ConvertTo-CMObject {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Configuration not found: $Path" }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        try { $text = ([System.Text.UTF8Encoding]::new($false, $true)).GetString($bytes) }
        catch { $text = [System.Text.Encoding]::Default.GetString($bytes) }
        $text = $text.TrimStart([char]0xFEFF)
        return ($text | ConvertFrom-Json)
    }
    catch { throw "Configuration must be JSON-compatible YAML: $Path" }
}

function Get-CMProfile {
    param([string]$Profile)
    $configPath = Get-CMConfigPath
    $config = ConvertTo-CMObject -Path $configPath
    $selected = if ($Profile) { $Profile } else { [string]$config.active_profile }
    if ([string]::IsNullOrWhiteSpace($selected)) { throw 'No active profile is configured.' }
    $entry = $config.profiles.$selected
    if ($null -eq $entry) { throw "Unknown profile: $selected" }
    return [pscustomobject]@{ Name = $selected; Config = $config; Entry = $entry; ConfigPath = $configPath }
}

function Test-CMPathWithin {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Candidate)
    $rootPath = Get-CMCanonicalPath $Root
    $candidatePath = Get-CMCanonicalPath $Candidate
    if ($candidatePath.Equals($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $candidatePath.StartsWith($rootPath + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-CMProjectMapping {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot, [Parameter(Mandatory = $true)]$ProfileEntry)
    if (-not ($ProfileEntry.PSObject.Properties.Name -contains 'project_mappings')) { return $null }
    $candidateRoot = Get-CMCanonicalPath $ProjectRoot
    $matches = @()
    foreach ($raw in @($ProfileEntry.project_mappings)) {
        if ($null -eq $raw) { continue }
        $sourceRoots = @()
        if ($raw.PSObject.Properties.Name -contains 'source_root' -and $raw.source_root) { $sourceRoots += [string]$raw.source_root }
        if ($raw.PSObject.Properties.Name -contains 'source_roots') { $sourceRoots += @($raw.source_roots | ForEach-Object { [string]$_ }) }
        foreach ($sourceRoot in $sourceRoots) {
            if ([string]::IsNullOrWhiteSpace($sourceRoot)) { continue }
            if (-not [System.IO.Path]::IsPathRooted($sourceRoot)) { throw "Project mapping source_root must be absolute: $sourceRoot" }
            try { $mappedRoot = Get-CMCanonicalPath $sourceRoot } catch { continue }
            if (-not (Test-CMPathWithin -Root $mappedRoot -Candidate $candidateRoot)) { continue }
            $memoryId = if ($raw.PSObject.Properties.Name -contains 'memory_id') { [string]$raw.memory_id } else { [string]$raw.project_id }
            if ([string]::IsNullOrWhiteSpace($memoryId)) { throw 'Project mapping must define memory_id or project_id.' }
            $matches += [pscustomobject]@{
                memory_id = ConvertTo-CMSafeId $memoryId
                project_id = ConvertTo-CMSafeId $(if ($raw.PSObject.Properties.Name -contains 'project_id' -and $raw.project_id) { [string]$raw.project_id } else { $memoryId })
                source_root = $mappedRoot
                component = if ($raw.PSObject.Properties.Name -contains 'component' -and $raw.component) { [string]$raw.component } else { 'main' }
                mirror_prefix = if ($raw.PSObject.Properties.Name -contains 'mirror_prefix' -and $raw.mirror_prefix) { [string]$raw.mirror_prefix } else { $null }
                docs_root = if ($raw.PSObject.Properties.Name -contains 'docs_root' -and $raw.docs_root) { if (-not (Test-CMSafeRelativePath ([string]$raw.docs_root))) { throw "Project mapping docs_root must be a safe relative path: $($raw.docs_root)" }; [string]$raw.docs_root } else { $null }
                match_length = $mappedRoot.Length
            }
        }
    }
    $ordered = @($matches | Sort-Object -Property match_length -Descending)
    if ($ordered.Count -gt 1 -and $ordered[0].match_length -eq $ordered[1].match_length) {
        $top = @($ordered | Where-Object { $_.match_length -eq $ordered[0].match_length })
        $keys = @($top | ForEach-Object { $_.memory_id + '|' + $_.source_root } | Select-Object -Unique)
        if ($keys.Count -gt 1) { throw 'Ambiguous project mappings have the same longest source_root length.' }
    }
    return @($ordered | Select-Object -First 1)
}

function Get-CMHash {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function ConvertTo-CMNullableHash {
    param($Value)
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    $text = $text.Trim().ToLowerInvariant()
    if ($text -notmatch '^[a-f0-9]{64}$') { throw 'Invalid SHA-256 value in synchronization plan.' }
    return $text
}

function Get-CMCanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Test-CMSamePath {
    param([Parameter(Mandatory = $true)][string]$Left, [Parameter(Mandatory = $true)][string]$Right)
    return (Get-CMCanonicalPath $Left).Equals((Get-CMCanonicalPath $Right), [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-CMSafeRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or [System.IO.Path]::IsPathRooted($Path) -or $Path -match '(^|[\\/])\.\.([\\/]|$)' -or $Path -match '[:*?"<>|]') { return $false }
    return $true
}

function ConvertTo-CMSafeId {
    param([Parameter(Mandatory = $true)][string]$Value)
    $value = $Value.Trim().ToLowerInvariant()
    $value = [regex]::Replace($value, '[^a-z0-9._-]+', '-')
    $value = $value.Trim('-', '.', '_')
    if ([string]::IsNullOrWhiteSpace($value)) { throw 'Project identifier is empty after normalization.' }
    return $value.Substring(0, [Math]::Min(80, $value.Length))
}

function Test-CMSensitiveText {
    param([string]$Text)
    if ($null -eq $Text) { return $false }
    $patterns = @(
        '(?im)^\s*(api[_-]?key|token|password|passwd|secret|client_secret|authorization)\s*[:=]',
        '(?i)-----BEGIN (?:RSA |EC |OPENSSH |)?PRIVATE KEY-----',
        '(?i)(mongodb(?:\+srv)?|postgres(?:ql)?|mysql)://[^\s]+'
    )
    foreach ($pattern in $patterns) { if ([regex]::IsMatch($Text, $pattern)) { return $true } }
    return $false
}

function ConvertTo-CMRedactedText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $redacted = [regex]::Replace($Text, '(?im)^(\s*(?:api[_-]?key|token|password|passwd|secret|client_secret|authorization)\s*[:=]\s*).+$', '$1[REDACTED]')
    $redacted = [regex]::Replace($redacted, '(?i)(mongodb(?:\+srv)?|postgres(?:ql)?|mysql)://[^\s]+', '[REDACTED_DATABASE_URI]')
    $redacted = [regex]::Replace($redacted, '(?s)-----BEGIN (?:RSA |EC |OPENSSH |)?PRIVATE KEY-----.+?-----END (?:RSA |EC |OPENSSH |)?PRIVATE KEY-----', '[REDACTED_PRIVATE_KEY]')
    return $redacted
}

function Test-CMMemoryRoot {
    param([Parameter(Mandatory = $true)][string]$MemoryRoot)
    $required = @('00-总索引.md', '03-项目记忆', '06-模板')
    foreach ($item in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $MemoryRoot $item))) { return $false }
    }
    return $true
}

function Get-CMProjectMemoryPath {
    param([Parameter(Mandatory = $true)][string]$MemoryRoot, [Parameter(Mandatory = $true)][string]$ProjectId)
    return (Join-Path (Join-Path $MemoryRoot '03-项目记忆') (ConvertTo-CMSafeId $ProjectId))
}

function Get-CMStatePath {
    param([Parameter(Mandatory = $true)][string]$ProjectId)
    return (Join-Path (Join-Path (Join-Path (Get-CMLocalRoot) 'state') (ConvertTo-CMSafeId $ProjectId)) '_sync-state.json')
}

function Get-CMDocumentStatePath {
    param([Parameter(Mandatory = $true)][string]$ProjectId, [string]$Component = 'main')
    $stateId = ConvertTo-CMSafeId ($ProjectId + '--' + $Component)
    return (Join-Path (Join-Path (Join-Path (Join-Path (Get-CMLocalRoot) 'state') 'documents') $stateId) 'mirror.json')
}

function Test-CMPlanLikePath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    foreach ($segment in ($RelativePath -split '[\\/]')) {
        if ($segment -match '计划|规划') { return $true }
        if ($segment -match '(?i)(?:^|[-_.])plan(?:s|ning)?(?:[-_.]|$)') { return $true }
        if ($segment -match '(?i)(?:^|[-_.])pln(?:[-_.]|$)') { return $true }
    }
    return $false
}

function Get-CMFileSnapshot {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return [pscustomobject]@{ exists = $true; bytes = [System.IO.File]::ReadAllBytes($Path) }
    }
    return [pscustomobject]@{ exists = $false; bytes = $null }
}

function Restore-CMFileSnapshot {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Snapshot)
    if ([bool]$Snapshot.exists) {
        Write-CMAtomicBytes -Path $Path -Bytes ([byte[]]$Snapshot.bytes)
    } elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
        Remove-Item -LiteralPath $Path -Force
    }
}

function Write-CMAtomicText {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Content)
    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $temp = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    [System.IO.File]::WriteAllText($temp, $Content, (New-Object System.Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) {
        $backup = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.bak')
        [System.IO.File]::Replace($temp, $Path, $backup)
        if (Test-Path -LiteralPath $backup) { [System.IO.File]::Delete($backup) }
    } else {
        [System.IO.File]::Move($temp, $Path)
    }
}

function Write-CMAtomicBytes {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $temp = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    [System.IO.File]::WriteAllBytes($temp, $Bytes)
    if (Test-Path -LiteralPath $Path) {
        $backup = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.bak')
        [System.IO.File]::Replace($temp, $Path, $backup)
        if (Test-Path -LiteralPath $backup) { [System.IO.File]::Delete($backup) }
    } else {
        [System.IO.File]::Move($temp, $Path)
    }
}

function Write-CMAtomicJson {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value)
    Write-CMAtomicText -Path $Path -Content ($Value | ConvertTo-Json -Depth 12)
}

function Enter-CMLock {
    param([Parameter(Mandatory = $true)][string]$Name)
    $lockDir = Join-Path (Get-CMLocalRoot) 'locks'
    [System.IO.Directory]::CreateDirectory($lockDir) | Out-Null
    $safe = ConvertTo-CMSafeId $Name
    $path = Join-Path $lockDir ($safe + '.lock')
    try { return [System.IO.File]::Open($path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
    catch { throw "LOCKED: another codex-memory operation holds $safe" }
}

function Get-CMManagedContent {
    param([string]$Existing, [Parameter(Mandatory = $true)][string]$Managed)
    # The curated block is user-maintained historical knowledge and is never replaced.
    $curatedStart = '<!-- knowledge-curated:start -->'
    $curatedEnd = '<!-- knowledge-curated:end -->'
    $start = '<!-- codex-memory:live:start -->'
    $end = '<!-- codex-memory:live:end -->'
    $block = $start + "`r`n" + $Managed.Trim() + "`r`n" + $end
    if ([string]::IsNullOrWhiteSpace($Existing)) { return $block + "`r`n" }
    $pattern = [regex]::Escape($start) + '(?s:.*?)' + [regex]::Escape($end)
    $startCount = ([regex]::Matches($Existing, [regex]::Escape($start))).Count
    $endCount = ([regex]::Matches($Existing, [regex]::Escape($end))).Count
    if ($startCount -ne $endCount) { throw 'Live memory block is incomplete.' }
    if ($startCount -gt 1) { throw 'Live memory contains duplicate blocks.' }
    if ($startCount -eq 1) {
        $regex = New-Object System.Text.RegularExpressions.Regex($pattern)
        return $regex.Replace($Existing, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }, 1)
    }
    if ($Existing -match [regex]::Escape($curatedStart) -and $Existing -notmatch [regex]::Escape($curatedEnd)) { throw 'Curated memory block is incomplete.' }
    return $Existing.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
}

function Get-CMResult {
    param([string]$Status, [string]$Message, $Data)
    return [pscustomobject]@{ status = $Status; message = $Message; data = $Data }
}
