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
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\\')
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
    return (Join-Path (Join-Path (Join-Path (Get-CMUserRoot) 'state') (ConvertTo-CMSafeId $ProjectId)) '_sync-state.json')
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
    $start = '<!-- codex-memory:auto:start -->'
    $end = '<!-- codex-memory:auto:end -->'
    $block = $start + "`r`n" + $Managed.Trim() + "`r`n" + $end
    if ([string]::IsNullOrWhiteSpace($Existing)) { return $block + "`r`n" }
    $pattern = [regex]::Escape($start) + '(?s:.*?)' + [regex]::Escape($end)
    if ([regex]::IsMatch($Existing, $pattern)) {
        $regex = New-Object System.Text.RegularExpressions.Regex($pattern)
        return $regex.Replace($Existing, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }, 1)
    }
    return $Existing.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
}

function Get-CMResult {
    param([string]$Status, [string]$Message, $Data)
    return [pscustomobject]@{ status = $Status; message = $Message; data = $Data }
}

