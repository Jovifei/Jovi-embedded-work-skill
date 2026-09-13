Set-StrictMode -Version Latest

function Get-CommandPath {
    param([Parameter(Mandatory)][string]$Name)
    try {
        $command = Get-Command $Name -ErrorAction Stop | Select-Object -First 1
        if ($command -and $command.Source) { return $command.Source }
        if ($command -and $command.Path) { return $command.Path }
    } catch { }
    return $null
}

function Get-AndroidSdkRoot {
    param([string]$ProjectPath)
    $candidates = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk') }
    if ($ProjectPath) {
        $localProperties = Join-Path $ProjectPath 'local.properties'
        if (Test-Path -LiteralPath $localProperties -PathType Leaf) {
            $line = Get-Content -LiteralPath $localProperties -ErrorAction SilentlyContinue |
                Where-Object { $_ -match '^\s*sdk\.dir\s*=' } | Select-Object -First 1
            if ($line -and $line -match '^\s*sdk\.dir\s*=\s*(.+?)\s*$') {
                $value = $Matches[1] -replace '\\:', ':' -replace '\\\\', '\'
                $candidates += $value
            }
        }
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

function Get-LatestBuildTools {
    param([Parameter(Mandatory)][string]$SdkRoot)
    $root = Join-Path $SdkRoot 'build-tools'
    if (!(Test-Path -LiteralPath $root -PathType Container)) { return $null }
    $versions = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { (Test-Path (Join-Path $_.FullName 'aapt2.exe')) -and (Test-Path (Join-Path $_.FullName 'apksigner.bat')) }
    if (!$versions) { return $null }
    return ($versions | Sort-Object @{ Expression = { try { [version]$_.Name } catch { [version]'0.0' } }; Descending = $true } | Select-Object -First 1).FullName
}

function Invoke-CapturedTool {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [string]$LogPath
    )
    $lines = @()
    $exitCode = 127
    $errorText = $null
    try {
        Push-Location -LiteralPath $WorkingDirectory
        try {
            $global:LASTEXITCODE = 0
            $lines = @(& $FilePath @Arguments 2>&1 | ForEach-Object { $_.ToString() })
            $exitCode = if (Test-Path variable:LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        } finally {
            Pop-Location
        }
    } catch {
        $errorText = $_.Exception.Message
        $lines = @($errorText)
        $exitCode = 127
    }
    $safeLines = @($lines | ForEach-Object { Redact-SensitiveText $_ })
    if ($LogPath) {
        try {
            $parent = Split-Path -Parent $LogPath
            if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
            [System.IO.File]::WriteAllText($LogPath, ($safeLines -join [Environment]::NewLine), (New-Object System.Text.UTF8Encoding($false)))
        } catch { }
    }
    return [pscustomobject]@{
        exit_code = $exitCode
        output = @($safeLines)
        error = $errorText
        log_path = $LogPath
    }
}

function Redact-SensitiveText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    $safe = $Text
    $safe = [regex]::Replace($safe, '(?i)(password|passwd|token|secret|appsecret|client_secret|api[_-]?key)\s*[=:]\s*[^\s,;]+', '$1=[REDACTED]')
    $safe = [regex]::Replace($safe, '(?i)(authorization\s*:\s*bearer\s+)[^\s]+', '$1[REDACTED]')
    return $safe
}

function Get-GitBaseline {
    param([Parameter(Mandatory)][string]$ProjectPath)
    $gitPath = Get-CommandPath 'git'
    $repoRoot = $null
    try {
        $cursor = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
        while ($cursor) {
            if (Test-Path -LiteralPath (Join-Path $cursor '.git')) { $repoRoot = $cursor; break }
            $parent = Split-Path -Parent $cursor
            if (!$parent -or $parent -eq $cursor) { break }
            $cursor = $parent
        }
    } catch { }
    if (!$gitPath -or !$repoRoot) {
        return [pscustomobject]@{ is_git = $false; repo_root = $null; branch = $null; commit_sha = $null; dirty = $null; status_lines = @() }
    }
    $branchResult = Invoke-CapturedTool -FilePath $gitPath -Arguments @('-C', $repoRoot, 'branch', '--show-current') -WorkingDirectory $repoRoot
    $shaResult = Invoke-CapturedTool -FilePath $gitPath -Arguments @('-C', $repoRoot, 'rev-parse', 'HEAD') -WorkingDirectory $repoRoot
    $statusResult = Invoke-CapturedTool -FilePath $gitPath -Arguments @('-C', $repoRoot, 'status', '--short') -WorkingDirectory $repoRoot
    $statusLines = @($statusResult.output | Where-Object { $_ -and $_.Trim() })
    return [pscustomobject]@{
        is_git = $true
        repo_root = $repoRoot
        branch = (($branchResult.output | Select-Object -First 1).Trim())
        commit_sha = (($shaResult.output | Select-Object -First 1).Trim())
        dirty = ($statusLines.Count -gt 0)
        status_lines = $statusLines
    }
}

function Read-JsonInput {
    param([Parameter(Mandatory)][object]$Object, [int]$ExitCode = 0)
    $Object | ConvertTo-Json -Depth 20 -Compress
    if ($ExitCode -ne 0) { exit $ExitCode }
}
