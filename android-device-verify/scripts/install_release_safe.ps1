[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApkPath,
    [string]$AdbPath,
    [Parameter(Mandatory)][string]$PackageName,
    [string]$Serial,
    [string]$ExpectedCertificateSha256,
    [ValidateSet('Physical','Emulator')][string]$TargetType = 'Physical',
    [string]$ProjectPath,
    [string]$JsonPath
)

. (Join-Path $PSScriptRoot 'common.ps1')

if (!$AdbPath) { $AdbPath = Get-CommandPath 'adb' }
$verifyParams = @{ ApkPath=$ApkPath; ProjectPath=$ProjectPath; ExpectedPackage=$PackageName; RequireRelease=($TargetType -eq 'Physical') }
if ($ExpectedCertificateSha256) { $verifyParams.ExpectedCertificateSha256 = $ExpectedCertificateSha256 }
$verifyRaw = @(& (Join-Path $PSScriptRoot 'verify_apk.ps1') @verifyParams 2>$null)
$verify = $null
try { $verify = ($verifyRaw -join [Environment]::NewLine) | ConvertFrom-Json } catch { }
if (!$verify -or $verify.status -ne 'PASS') {
    Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; apk_path=$ApkPath; package_name=$PackageName; blockers=@('APK verification did not return PASS.'); apk_verification=$verify }) 1
}
if (!$AdbPath -or !(Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; apk_path=$ApkPath; package_name=$PackageName; blockers=@('adb was not found.') }) 1
}
$adbRoot = Split-Path -Parent $AdbPath
$preRaw = @(& (Join-Path $PSScriptRoot 'device_preflight.ps1') -AdbPath $AdbPath -Serial $Serial -PackageName $PackageName 2>$null)
$pre = $null
try { $pre = ($preRaw -join [Environment]::NewLine) | ConvertFrom-Json } catch { }
if (!$pre -or $pre.status -ne 'PASS' -or !$pre.selected_serial) {
    Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; apk_path=$ApkPath; package_name=$PackageName; blockers=@('ADB preflight did not return a single usable device.'); device_preflight=$pre }) 1
}
$selectedSerial = $pre.selected_serial
$beforePackage = $pre.package

function Get-ApkCertificate {
    param([string]$Apk)
    $sdkRoot = $verify.sdk_root
    $buildTools = if ($sdkRoot) { Get-LatestBuildTools -SdkRoot $sdkRoot } else { $null }
    $signer = if ($buildTools) { Join-Path $buildTools 'apksigner.bat' } else { $null }
    if (!$signer -or !(Test-Path -LiteralPath $signer)) { return $null }
    $run = Invoke-CapturedTool -FilePath $signer -Arguments @('verify','--print-certs',$Apk) -WorkingDirectory (Split-Path -Parent $Apk)
    $text = $run.output -join [Environment]::NewLine
    if ($run.exit_code -eq 0 -and $text -match '(?im)certificate\s+SHA-256\s+digest:\s*([0-9a-f:]+)') { return $Matches[1].ToUpperInvariant() }
    return $null
}

if ($beforePackage -and $beforePackage.present) {
    $installedCert = $null
    $pm = Invoke-CapturedTool -FilePath $AdbPath -Arguments @('-s',$selectedSerial,'shell','pm','path',$PackageName) -WorkingDirectory $adbRoot
    $remoteApk = (($pm.output | Where-Object { $_ -match '^package:' } | Select-Object -First 1) -replace '^package:','').Trim()
    if ($remoteApk) {
        $localApk = Join-Path $env:TEMP ("android-app-delivery\installed-" + [guid]::NewGuid().ToString('N') + '.apk')
        $pull = Invoke-CapturedTool -FilePath $AdbPath -Arguments @('-s',$selectedSerial,'pull',$remoteApk,$localApk) -WorkingDirectory $adbRoot
        if ($pull.exit_code -eq 0 -and (Test-Path -LiteralPath $localApk -PathType Leaf)) { $installedCert = Get-ApkCertificate -Apk $localApk }
        if (Test-Path -LiteralPath $localApk -PathType Leaf) { Remove-Item -LiteralPath $localApk -Force -ErrorAction SilentlyContinue }
    }
    if (!$installedCert) {
        Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; apk_path=$ApkPath; package_name=$PackageName; selected_serial=$selectedSerial; blockers=@('Existing package certificate could not be read; installation was not attempted.') }) 1
    }
    $builtCert = ($verify.certificate_sha256 -replace '[^0-9A-Fa-f]','').ToUpperInvariant()
    $deviceCert = ($installedCert -replace '[^0-9A-Fa-f]','').ToUpperInvariant()
    if ($builtCert -ne $deviceCert) {
        Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; apk_path=$ApkPath; package_name=$PackageName; selected_serial=$selectedSerial; blockers=@('Existing package certificate does not match the APK; installation was not attempted.') }) 1
    }
}

if ($TargetType -eq 'Physical' -and [bool]$verify.debuggable) {
    Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; apk_path=$ApkPath; package_name=$PackageName; selected_serial=$selectedSerial; blockers=@('Physical devices require a non-debuggable Release APK.') }) 1
}
$apkCode = 0
try { $apkCode = [int]$verify.version_code } catch { }
$installedCode = 0
if ($beforePackage -and $beforePackage.present) { try { $installedCode = [int]$beforePackage.version_code } catch { } }
if ($beforePackage -and $beforePackage.present -and $installedCode -gt $apkCode) {
    Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; apk_path=$ApkPath; package_name=$PackageName; selected_serial=$selectedSerial; blockers=@('APK versionCode is lower than the installed version; downgrade was not requested.') }) 1
}

$install = Invoke-CapturedTool -FilePath $AdbPath -Arguments @('-s',$selectedSerial,'install','-r',$ApkPath) -WorkingDirectory $adbRoot
$postRaw = @(& (Join-Path $PSScriptRoot 'device_preflight.ps1') -AdbPath $AdbPath -Serial $selectedSerial -PackageName $PackageName 2>$null)
$post = $null
try { $post = ($postRaw -join [Environment]::NewLine) | ConvertFrom-Json } catch { }
$blockers = @()
if ($install.exit_code -ne 0) { $blockers += 'adb install -r failed.' }
if (!$post -or $post.status -ne 'PASS' -or !$post.package.present) { $blockers += 'Post-install package verification failed.' }
if ($beforePackage -and $beforePackage.present -and $post.package.first_install_time -ne $beforePackage.first_install_time) { $blockers += 'firstInstallTime changed during upgrade; data-preserving upgrade was not proven.' }
$status = if ($blockers.Count -eq 0) { 'PASS' } else { 'FAIL' }
$result = [ordered]@{
    status=$status; apk_path=$verify.apk_path; package_name=$PackageName; selected_serial=$selectedSerial; target_type=$TargetType
    install_method='adb install -r'; install_exit_code=$install.exit_code; before=$beforePackage; after=if ($post) { $post.package } else { $null }
    apk=$verify; blockers=$blockers
    safety=@('The only device mutation issued by this script is adb install -r.', 'No app-data clearing, package removal, log clearing, or destructive test command was issued.')
}
if ($JsonPath) { $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8 }
Read-JsonInput ([pscustomobject]$result) $(if ($status -eq 'PASS') { 0 } else { 1 })
