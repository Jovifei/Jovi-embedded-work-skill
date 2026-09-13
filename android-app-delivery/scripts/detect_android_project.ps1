[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [ValidateSet('Auto','Gradle','Flutter','ReactNative')][string]$Framework = 'Auto',
    [string]$JsonPath
)

. (Join-Path $PSScriptRoot 'common.ps1')

function Get-FirstMatch {
    param([string[]]$Paths, [string]$Pattern)
    foreach ($path in $Paths) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $match = Select-String -LiteralPath $path -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) { return $match.Line }
    }
    return $null
}

$resolved = $null
try { $resolved = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path } catch { }
if (!$resolved -or !(Test-Path -LiteralPath $resolved -PathType Container)) {
    Read-JsonInput ([pscustomobject]@{ status='FAIL'; project_root=$ProjectPath; unsupported_reason='Project path does not exist or is not a directory.'; frameworks=@() }) 2
}

$git = Get-GitBaseline -ProjectPath $resolved
$pubspec = Join-Path $resolved 'pubspec.yaml'
$packageJson = Join-Path $resolved 'package.json'
$androidDir = Join-Path $resolved 'android'
$gradleFiles = @(
    (Join-Path $resolved 'settings.gradle'),
    (Join-Path $resolved 'settings.gradle.kts'),
    (Join-Path $resolved 'build.gradle'),
    (Join-Path $resolved 'build.gradle.kts'),
    (Join-Path $resolved 'gradlew.bat'),
    (Join-Path $resolved 'android\settings.gradle'),
    (Join-Path $resolved 'android\settings.gradle.kts'),
    (Join-Path $resolved 'android\build.gradle'),
    (Join-Path $resolved 'android\build.gradle.kts'),
    (Join-Path $resolved 'android\gradlew.bat')
)

$isFlutter = (Test-Path -LiteralPath $pubspec -PathType Leaf) -and (Test-Path -LiteralPath $androidDir -PathType Container)
$isReactNative = $false
if ((Test-Path -LiteralPath $packageJson -PathType Leaf) -and (Test-Path -LiteralPath $androidDir -PathType Container)) {
    try {
        $package = Get-Content -LiteralPath $packageJson -Raw -ErrorAction Stop | ConvertFrom-Json
        $allDeps = @()
        if ($package.PSObject.Properties.Name -contains 'dependencies' -and $package.dependencies) { $allDeps += $package.dependencies.PSObject.Properties.Name }
        if ($package.PSObject.Properties.Name -contains 'devDependencies' -and $package.devDependencies) { $allDeps += $package.devDependencies.PSObject.Properties.Name }
        $isReactNative = $allDeps -contains 'react-native'
    } catch { $isReactNative = $false }
}
$isGradle = $false
foreach ($file in $gradleFiles) { if (Test-Path -LiteralPath $file -PathType Leaf) { $isGradle = $true; break } }
if ($isFlutter -or $isReactNative) { $isGradle = $true }

$detected = @()
if ($isFlutter) { $detected += 'Flutter' }
if ($isReactNative) { $detected += 'ReactNative' }
if ($isGradle -and !$isFlutter -and !$isReactNative) { $detected += 'Gradle' }

$primary = $null
$status = 'PASS'
$reason = $null
if ($Framework -ne 'Auto') {
    $mapped = if ($Framework -eq 'ReactNative') { 'ReactNative' } else { $Framework }
    if ($detected -contains $mapped) { $primary = $mapped } else { $status = 'BLOCKED'; $reason = "Requested framework '$Framework' was not detected." }
} elseif ($detected.Count -eq 1) {
    $primary = $detected[0]
} elseif ($detected.Count -eq 0) {
    $status = 'BLOCKED'; $reason = 'No supported Gradle, Flutter, or React Native Android project was detected.'
} else {
    $status = 'BLOCKED'; $reason = 'Multiple supported frameworks were detected; pass -Framework explicitly.'
}

$gradleRoot = $resolved
if ($primary -eq 'Flutter' -or $primary -eq 'ReactNative') { $gradleRoot = $androidDir }
$gradleAppFiles = @(
    (Join-Path $gradleRoot 'app\build.gradle'),
    (Join-Path $gradleRoot 'app\build.gradle.kts'),
    (Join-Path $gradleRoot 'build.gradle'),
    (Join-Path $gradleRoot 'build.gradle.kts')
)
$applicationId = $null
$packageSource = $null
$line = Get-FirstMatch -Paths $gradleAppFiles -Pattern 'applicationId\s*[= ]\s*["'']([^"'']+)["'']'
if ($line -and $line -match 'applicationId\s*[= ]\s*["'']([^"'']+)["'']') { $applicationId = $Matches[1]; $packageSource = 'gradle applicationId' }
if (!$applicationId) {
    $line = Get-FirstMatch -Paths $gradleAppFiles -Pattern 'namespace\s*[= ]\s*["'']([^"'']+)["'']'
    if ($line -and $line -match 'namespace\s*[= ]\s*["'']([^"'']+)["'']') { $applicationId = $Matches[1]; $packageSource = 'gradle namespace' }
}

$result = [ordered]@{
    status = $status
    project_root = $resolved
    primary_framework = $primary
    frameworks = @($detected)
    gradle_root = if ($isGradle) { $gradleRoot } else { $null }
    flutter_root = if ($isFlutter) { $resolved } else { $null }
    react_native_root = if ($isReactNative) { $resolved } else { $null }
    application_id = $applicationId
    package_source = $packageSource
    git = $git
    unsupported_reason = $reason
    inputs_required = if ($status -eq 'BLOCKED') { @('framework', 'application id', 'signing identity when building Release') } else { @() }
}
if ($JsonPath) { $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8 }
Read-JsonInput ([pscustomobject]$result) $(if ($status -eq 'PASS') { 0 } else { 1 })
