[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [ValidateSet('Auto','Gradle','Flutter','ReactNative')][string]$Framework = 'Auto',
    [switch]$AutoInstallUserTools,
    [string]$JsonPath
)

. (Join-Path $PSScriptRoot 'common.ps1')

try { $resolved = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path } catch { $resolved = $ProjectPath }
$detectScript = Join-Path $PSScriptRoot 'detect_android_project.ps1'
$detect = & $detectScript -ProjectPath $resolved -Framework $Framework 2>$null | ConvertFrom-Json
$selected = $null
if ($detect -and $detect.PSObject.Properties.Name -contains 'primary_framework') { $selected = $detect.primary_framework }
if (!$selected) {
    $result = [ordered]@{
        status = 'BLOCKED'; project_root = $resolved; framework = $null; sdk_root = $null
        tools = @(); missing = @('supported framework'); install_plan = @('Provide a Gradle, Flutter, or React Native Android project and rerun.')
        auto_install_requested = [bool]$AutoInstallUserTools
    }
    if ($JsonPath) { $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8 }
    Read-JsonInput ([pscustomobject]$result) 1
}

$sdkRoot = Get-AndroidSdkRoot -ProjectPath $resolved
$toolRecords = @()
function Add-ToolRecord {
    param([string]$Name, [string]$Path, [string]$Version, [bool]$Required, [string]$InstallScope = 'existing')
    $state = if ($Path) { 'PASS' } elseif ($Required) { 'MISSING' } else { 'NOT_REQUIRED' }
    $script:toolRecords += [pscustomobject]@{ name=$Name; path=$Path; version=$Version; required=$Required; status=$state; install_scope=$InstallScope }
}

$java = Get-CommandPath 'java'
$javaVersion = $null
if ($java) {
    $r = Invoke-CapturedTool -FilePath $java -Arguments @('-version') -WorkingDirectory $resolved
    $javaVersion = (($r.output -join ' ') -replace '\s+', ' ').Trim()
}
$javaMajor = $null
if ($javaVersion -and $javaVersion -match 'version\s+["'']?(\d+)') { $javaMajor = [int]$Matches[1] }
Add-ToolRecord 'JDK' $java $javaVersion $true

$adb = $null
$adbVersion = $null
if ($sdkRoot -and (Test-Path (Join-Path $sdkRoot 'platform-tools\adb.exe'))) { $adb = Join-Path $sdkRoot 'platform-tools\adb.exe' }
if (!$adb) { $adb = Get-CommandPath 'adb' }
if ($adb) { $r = Invoke-CapturedTool -FilePath $adb -Arguments @('version') -WorkingDirectory $resolved; $adbVersion = (($r.output | Select-Object -First 1).Trim()) }
Add-ToolRecord 'Android platform-tools/adb' $adb $adbVersion $true

$buildTools = $null
$aapt2 = $null
$apksigner = $null
if ($sdkRoot) {
    $buildTools = Get-LatestBuildTools -SdkRoot $sdkRoot
    if ($buildTools) { $aapt2 = Join-Path $buildTools 'aapt2.exe'; $apksigner = Join-Path $buildTools 'apksigner.bat' }
}
Add-ToolRecord 'Android build-tools/aapt2' $(if ($aapt2 -and (Test-Path $aapt2)) { $aapt2 } else { $null }) $buildTools $true
Add-ToolRecord 'Android build-tools/apksigner' $(if ($apksigner -and (Test-Path $apksigner)) { $apksigner } else { $null }) $buildTools $true

$gradleWrapper = $null
if ($selected -eq 'Gradle') { $gradleWrapper = Join-Path $resolved 'gradlew.bat' }
if ($selected -eq 'ReactNative' -or $selected -eq 'Flutter') { $gradleWrapper = Join-Path $resolved 'android\gradlew.bat' }
if (!$gradleWrapper -or !(Test-Path $gradleWrapper)) { $gradleWrapper = $null }
Add-ToolRecord 'Gradle wrapper' $gradleWrapper $null $true

$flutter = Get-CommandPath 'flutter'
$flutterVersion = $null
if ($flutter -and $selected -eq 'Flutter') { $r = Invoke-CapturedTool -FilePath $flutter -Arguments @('--version', '--machine') -WorkingDirectory $resolved; $flutterVersion = (($r.output -join ' ') -replace '\s+', ' ').Trim() }
Add-ToolRecord 'Flutter SDK' $(if ($selected -eq 'Flutter') { $flutter } else { $null }) $flutterVersion ($selected -eq 'Flutter') 'user-space-or-manual'

$node = Get-CommandPath 'node'
$npm = Get-CommandPath 'npm'
$nodeVersion = $null
if ($node -and ($selected -eq 'ReactNative')) { $r = Invoke-CapturedTool -FilePath $node -Arguments @('--version') -WorkingDirectory $resolved; $nodeVersion = (($r.output | Select-Object -First 1).Trim()) }
Add-ToolRecord 'Node.js' $(if ($selected -eq 'ReactNative') { $node } else { $null }) $nodeVersion ($selected -eq 'ReactNative') 'user-space-or-manual'
Add-ToolRecord 'npm' $(if ($selected -eq 'ReactNative') { $npm } else { $null }) $null ($selected -eq 'ReactNative') 'user-space-or-manual'

$missing = @($toolRecords | Where-Object {
    $_.required -and ($_.status -eq 'MISSING' -or ($_.name -eq 'JDK' -and (!$javaMajor -or $javaMajor -lt 17)))
} | ForEach-Object { $_.name })
$installPlan = @()
foreach ($item in $toolRecords | Where-Object { $_.status -eq 'MISSING' }) {
    if ($item.install_scope -eq 'existing') { $installPlan += "Install or point to $($item.name) without administrator changes." }
    else { $installPlan += "Try a user-space $($item.name) installation only after confirming the package source; administrator/system scope pauses." }
}
if ($java -and $javaMajor -and $javaMajor -lt 17) { $installPlan += 'Select JDK 17 or newer; do not replace a system JDK without approval.' }

$result = [ordered]@{
    status = if ($missing.Count -eq 0) { 'PASS' } else { 'BLOCKED' }
    project_root = $resolved
    framework = $selected
    sdk_root = $sdkRoot
    java_major = $javaMajor
    tools = $toolRecords
    missing = $missing
    install_plan = $installPlan
    auto_install_requested = [bool]$AutoInstallUserTools
    security = @('No credentials, token, keystore password, or private key was read or printed.')
}
if ($JsonPath) { $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8 }
Read-JsonInput ([pscustomobject]$result) $(if ($missing.Count -eq 0) { 0 } else { 1 })
