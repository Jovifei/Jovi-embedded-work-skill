[CmdletBinding()]
param(
    [string]$AdbPath,
    [string]$Serial,
    [string]$PackageName,
    [string]$JsonPath
)

. (Join-Path $PSScriptRoot 'common.ps1')

if (!$AdbPath) { $AdbPath = Get-CommandPath 'adb' }
if (!$AdbPath -or !(Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; adb_path=$AdbPath; devices=@(); blockers=@('adb was not found.') }) 1
}
$adbRoot = Split-Path -Parent $AdbPath
$deviceResult = Invoke-CapturedTool -FilePath $AdbPath -Arguments @('devices','-l') -WorkingDirectory $adbRoot
$rows = @()
foreach ($line in $deviceResult.output) {
    if (!$line -or $line -match '^\s*List of devices') { continue }
    if ($line -match '^\s*(\S+)\s+(device|offline|unauthorized|unknown)(?:\s+(.*))?$') {
        $rows += [pscustomobject]@{ serial=$Matches[1]; state=$Matches[2]; details=($Matches[3] | ForEach-Object { $_.Trim() }) }
    }
}
$selected = $null
$blockers = @()
if ($Serial) {
    $selected = $rows | Where-Object { $_.serial -eq $Serial } | Select-Object -First 1
    if (!$selected) { $blockers += 'Requested serial is not present in adb devices.' }
} elseif ($rows.Count -ne 1) {
    if ($rows.Count -eq 0) { $blockers += 'No ADB device is connected.' }
    else { $blockers += 'Multiple ADB targets are connected; specify -Serial.' }
} else { $selected = $rows[0] }
if ($selected -and $selected.state -ne 'device') { $blockers += "ADB target state is '$($selected.state)'; only 'device' is accepted." }

$installed = $null
if ($selected -and $selected.state -eq 'device' -and $PackageName) {
    $dump = Invoke-CapturedTool -FilePath $AdbPath -Arguments @('-s',$selected.serial,'shell','dumpsys','package',$PackageName) -WorkingDirectory $adbRoot
    $text = $dump.output -join [Environment]::NewLine
    if ($dump.exit_code -eq 0 -and $text -notmatch '(?im)Unable to find package') {
        $versionCode = if ($text -match '(?im)versionCode=([^\s]+)') { $Matches[1] } else { $null }
        $versionName = if ($text -match '(?im)versionName=([^\s]+)') { $Matches[1] } else { $null }
        $firstInstall = if ($text -match '(?im)firstInstallTime=([^\r\n]+)') { $Matches[1].Trim() } else { $null }
        $dataDir = if ($text -match '(?im)dataDir=([^\s]+)') { $Matches[1] } else { $null }
        $installed = [pscustomobject]@{ present=$true; package_name=$PackageName; version_code=$versionCode; version_name=$versionName; first_install_time=$firstInstall; data_dir=$dataDir }
    } else {
        $installed = [pscustomobject]@{ present=$false; package_name=$PackageName; version_code=$null; version_name=$null; first_install_time=$null; data_dir=$null }
    }
}

$model = $null
if ($selected -and $selected.state -eq 'device') {
    $modelRun = Invoke-CapturedTool -FilePath $AdbPath -Arguments @('-s',$selected.serial,'shell','getprop','ro.product.model') -WorkingDirectory $adbRoot
    $model = (($modelRun.output | Select-Object -First 1).Trim())
}
$result = [ordered]@{
    status=if ($blockers.Count -eq 0) { 'PASS' } else { 'BLOCKED' }
    adb_path=$AdbPath; device_count=$rows.Count; devices=$rows; selected_serial=if ($selected) { $selected.serial } else { $null }
    selected_state=if ($selected) { $selected.state } else { $null }; model=$model; package=$installed; blockers=$blockers
    safety=@('Read-only ADB preflight; no package data or log buffer was changed.', 'A serial is required for multi-device environments.')
}
if ($JsonPath) { $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8 }
Read-JsonInput ([pscustomobject]$result) $(if ($blockers.Count -eq 0) { 0 } else { 1 })
