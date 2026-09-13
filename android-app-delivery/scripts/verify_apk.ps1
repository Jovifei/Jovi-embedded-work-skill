[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApkPath,
    [string]$ProjectPath,
    [string]$ExpectedPackage,
    [string]$ExpectedCertificateSha256,
    [switch]$RequireRelease,
    [string]$JsonPath
)

. (Join-Path $PSScriptRoot 'common.ps1')

$resolvedApk = $null
try { $resolvedApk = (Resolve-Path -LiteralPath $ApkPath -ErrorAction Stop).Path } catch { }
if (!$resolvedApk -or !(Test-Path -LiteralPath $resolvedApk -PathType Leaf)) {
    Read-JsonInput ([pscustomobject]@{ status='FAIL'; apk_path=$ApkPath; blockers=@('APK path does not exist.') }) 2
}
$sdk = Get-AndroidSdkRoot -ProjectPath $ProjectPath
$buildTools = if ($sdk) { Get-LatestBuildTools -SdkRoot $sdk } else { $null }
$aapt2 = if ($buildTools) { Join-Path $buildTools 'aapt2.exe' } else { $null }
$apksigner = if ($buildTools) { Join-Path $buildTools 'apksigner.bat' } else { $null }
if (!$aapt2 -or !$apksigner -or !(Test-Path $aapt2) -or !(Test-Path $apksigner)) {
    Read-JsonInput ([pscustomobject]@{ status='BLOCKED'; apk_path=$resolvedApk; sdk_root=$sdk; build_tools=$buildTools; blockers=@('aapt2 and apksigner from Android build-tools are required.') }) 1
}

$work = Split-Path -Parent $resolvedApk
$aapt = Invoke-CapturedTool -FilePath $aapt2 -Arguments @('dump','badging',$resolvedApk) -WorkingDirectory $work
$sign = Invoke-CapturedTool -FilePath $apksigner -Arguments @('verify','--verbose','--print-certs',$resolvedApk) -WorkingDirectory $work
$aaptText = $aapt.output -join [Environment]::NewLine
$signText = $sign.output -join [Environment]::NewLine
$package = $null; $versionCode = $null; $versionName = $null
if ($aaptText -match "package:\s+name='([^']+)'\s+versionCode='([^']+)'\s+versionName='([^']*)'") {
    $package = $Matches[1]; $versionCode = $Matches[2]; $versionName = $Matches[3]
}
$debuggable = [bool]($aaptText -match '(?m)^application-debuggable$')
$cert = $null
if ($signText -match '(?im)certificate\s+SHA-256\s+digest:\s*([0-9a-f:]+)') { $cert = $Matches[1].ToUpperInvariant() }
$hash = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash.ToUpperInvariant()
$blockers = @()
if ($aapt.exit_code -ne 0 -or !$package) { $blockers += 'aapt2 could not parse APK package metadata.' }
if ($sign.exit_code -ne 0) { $blockers += 'apksigner verification failed; APK is not proven signed.' }
if ($ExpectedPackage -and $package -ne $ExpectedPackage) { $blockers += "Package mismatch: expected $ExpectedPackage." }
if ($ExpectedCertificateSha256) {
    $normalExpected = ($ExpectedCertificateSha256 -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
    $normalActual = ($cert -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
    if (!$cert -or $normalActual -ne $normalExpected) { $blockers += 'Certificate SHA-256 mismatch.' }
}
if ($RequireRelease -and $debuggable) { $blockers += 'A debuggable APK cannot be installed as a physical Release.' }
if (!$package) { $blockers += 'Package name is missing from APK metadata.' }
$status = if ($blockers.Count -eq 0) { 'PASS' } else { 'FAIL' }
$result = [ordered]@{
    status=$status; apk_path=$resolvedApk; package_name=$package; version_code=$versionCode; version_name=$versionName
    debuggable=$debuggable; signed=($sign.exit_code -eq 0); certificate_sha256=$cert; sha256=$hash
    sdk_root=$sdk; build_tools=$buildTools; aapt2_exit_code=$aapt.exit_code; apksigner_exit_code=$sign.exit_code
    blockers=$blockers; security=@('Only public APK metadata and certificate fingerprints were read; no keystore material was accessed.')
}
if ($JsonPath) { $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8 }
Read-JsonInput ([pscustomobject]$result) $(if ($status -eq 'PASS') { 0 } else { 1 })
