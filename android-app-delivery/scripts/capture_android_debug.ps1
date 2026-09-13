[CmdletBinding()]
param(
    [string]$AdbPath,
    [Parameter(Mandatory)][string]$PackageName,
    [string]$Serial,
    [string]$MainActivity,
    [ValidateRange(1,60)][int]$DurationSeconds = 10,
    [string]$EvidenceDirectory,
    [string]$JsonPath
)

. (Join-Path $PSScriptRoot 'common.ps1')

if (!$AdbPath) { $AdbPath = Get-CommandPath 'adb' }
if (!$EvidenceDirectory) { $EvidenceDirectory = Join-Path $env:TEMP ("android-app-delivery\" + [guid]::NewGuid().ToString('N')) }
New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
if (!$AdbPath -or !(Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; package_name=$PackageName; blockers=@('adb was not found.') }) 1
}
$adbRoot = Split-Path -Parent $AdbPath
$preRaw = @(& (Join-Path $PSScriptRoot 'device_preflight.ps1') -AdbPath $AdbPath -Serial $Serial -PackageName $PackageName 2>$null)
$pre = $null
try { $pre = ($preRaw -join [Environment]::NewLine) | ConvertFrom-Json } catch { }
if (!$pre -or $pre.status -ne 'PASS' -or !$pre.selected_serial) {
    Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; package_name=$PackageName; blockers=@('ADB preflight did not return a single usable device.'); device_preflight=$pre }) 1
}
$selectedSerial = $pre.selected_serial
$launch = $null
$manualGates = @('Unlock the device if it is locked.', 'Complete login, OTP, Tesla consent, virtual-key pairing, and Android permission prompts manually if shown.')
if ($MainActivity) {
    $launch = Invoke-CapturedTool -FilePath $AdbPath -Arguments @('-s',$selectedSerial,'shell','am','start','-n',("{0}/{1}" -f $PackageName,$MainActivity)) -WorkingDirectory $adbRoot
}
Start-Sleep -Seconds $DurationSeconds
$pidRun = Invoke-CapturedTool -FilePath $AdbPath -Arguments @('-s',$selectedSerial,'shell','pidof',$PackageName) -WorkingDirectory $adbRoot
$pidText = (($pidRun.output -join ' ').Trim())
$logPath = Join-Path $EvidenceDirectory 'logcat-sample.log'
$logRun = Invoke-CapturedTool -FilePath $AdbPath -Arguments @('-s',$selectedSerial,'logcat','-d','-v','threadtime','-t','3000') -WorkingDirectory $adbRoot -LogPath $logPath
$logLines = @($logRun.output)
$findings = @($logLines | Where-Object { $_ -match '(?i)FATAL EXCEPTION|\bANR\b|Room|SQLite|has died|Force finishing' } | Select-Object -First 100)
$fatal = @($findings | Where-Object { $_ -match '(?i)FATAL EXCEPTION' }).Count
$anr = @($findings | Where-Object { $_ -match '(?i)\bANR\b' }).Count
$status = 'PASS'
$blockers = @()
if (!$MainActivity) { $status = 'PARTIAL'; $blockers += 'MainActivity was not supplied; launch was not attempted.' }
if ($launch -and $launch.exit_code -ne 0) { $status = 'FAIL'; $blockers += 'Activity launch command failed.' }
if ($fatal -gt 0 -or $anr -gt 0) { $status = 'FAIL'; $blockers += 'FATAL or ANR evidence was found in the bounded log sample.' }
if ($pidRun.exit_code -ne 0 -or !$pidText) { if ($status -eq 'PASS') { $status = 'PARTIAL' }; $blockers += 'The app process was not observed after the sample window; it may be waiting at a manual gate.' }
$result = [ordered]@{
    status=$status; package_name=$PackageName; selected_serial=$selectedSerial; main_activity=$MainActivity; duration_seconds=$DurationSeconds
    launch=if ($launch) { [pscustomobject]@{ exit_code=$launch.exit_code; status=if ($launch.exit_code -eq 0) { 'PASS' } else { 'FAIL' } } } else { $null }
    process=[pscustomobject]@{ pid=$pidText; alive=[bool]$pidText }
    log_path=$logPath; findings=$findings; fatal_count=$fatal; anr_count=$anr; manual_gates=$manualGates; blockers=$blockers
    safety=@('Bounded read-only log capture; log buffer was not cleared.', 'No credentials or verification codes were entered.')
}
if ($JsonPath) { $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8 }
Read-JsonInput ([pscustomobject]$result) $(if ($status -eq 'PASS' -or $status -eq 'PARTIAL') { 0 } else { 1 })
