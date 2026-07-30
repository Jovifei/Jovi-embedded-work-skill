[CmdletBinding()]
param([ValidateSet('home','company')][string]$Profile = 'home', [ValidateRange(30,900)][int]$TimeoutSeconds = 600)
. (Join-Path $PSScriptRoot 'common.ps1')

$mutex = New-Object System.Threading.Mutex($false, 'Local\CodexMemoryDailyReview')
$acquired = $false
$stdout = $null
$stderr = $null
try {
    $acquired = $mutex.WaitOne(0)
    if (-not $acquired) { throw 'LOCKED: daily review is already running.' }
    $logDir = Join-Path (Get-CMLocalRoot) 'logs'
    [System.IO.Directory]::CreateDirectory($logDir) | Out-Null
    $stdout = Join-Path $logDir ('.daily-review-' + [guid]::NewGuid().ToString('N') + '.out')
    $stderr = Join-Path $logDir ('.daily-review-' + [guid]::NewGuid().ToString('N') + '.err')
    $prompt = '/codex-memory review --profile ' + $Profile
    $process = Start-Process -FilePath 'claude' -ArgumentList @('-p',$prompt) -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { $process.Kill() }
    $resultPath = Join-Path $logDir ('daily-review-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    $result = [ordered]@{ timestamp = (Get-Date).ToUniversalTime().ToString('o'); profile = $Profile; timed_out = $timedOut; exit_code = if ($timedOut) { $null } else { $process.ExitCode }; command = 'claude -p /codex-memory review --profile <profile>'; status = if ($timedOut) { 'TIMEOUT' } elseif ($process.ExitCode -eq 0) { 'PASS' } else { 'FAIL' } }
    Write-CMAtomicJson -Path $resultPath -Value $result
    $result | ConvertTo-Json -Depth 6
    if ($timedOut -or $process.ExitCode -ne 0) { exit 1 }
} catch {
    (Get-CMResult -Status $(if ($_.Exception.Message -like 'LOCKED*') { 'LOCKED' } else { 'FAIL' }) -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6; exit 1
} finally {
    foreach ($temporary in @($stdout, $stderr)) { if ($temporary -and (Test-Path -LiteralPath $temporary)) { [System.IO.File]::Delete($temporary) } }
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
