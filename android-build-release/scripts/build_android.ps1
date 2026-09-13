[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [ValidateSet('Auto','Gradle','Flutter','ReactNative')][string]$Framework = 'Auto',
    [ValidateSet('Debug','Release')][string]$Variant = 'Release',
    [string]$SigningPropertiesFile,
    [string]$EvidenceDirectory,
    [switch]$SkipTests,
    [string[]]$GradleTask,
    [string[]]$GradleArg = @(),
    [string[]]$FlutterArg = @(),
    [string]$JsonPath
)

. (Join-Path $PSScriptRoot 'common.ps1')

try { $resolved = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path } catch { $resolved = $ProjectPath }
if (!$EvidenceDirectory) { $EvidenceDirectory = Join-Path $env:TEMP ("android-app-delivery\" + [guid]::NewGuid().ToString('N')) }
New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null

$detectRaw = @(& (Join-Path $PSScriptRoot 'detect_android_project.ps1') -ProjectPath $resolved -Framework $Framework 2>$null)
$detect = $null
try { $detect = ($detectRaw -join [Environment]::NewLine) | ConvertFrom-Json } catch { }
if (!$detect -or $detect.status -ne 'PASS') {
    $result = [ordered]@{ status='BLOCKED'; project_root=$resolved; framework=$null; variant=$Variant; commands=@(); artifacts=@(); tests=@(); blockers=@('Project detection did not return PASS.'); evidence_directory=$EvidenceDirectory }
    if ($JsonPath) { $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8 }
    Read-JsonInput ([pscustomobject]$result) 1
}
$selected = $detect.primary_framework
$commands = @()
$tests = @()
$blockers = @()
$logs = @()

function Run-Step {
    param([string]$Name, [string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory, [bool]$Required = $true, [switch]$RecordCommand)
    $safeName = ($Name -replace '[^A-Za-z0-9_.-]', '_')
    $log = Join-Path $EvidenceDirectory ($safeName + '.log')
    $run = Invoke-CapturedTool -FilePath $FilePath -Arguments $Arguments -WorkingDirectory $WorkingDirectory -LogPath $log
    $record = [pscustomobject]@{ name=$Name; required=$Required; exit_code=$run.exit_code; status=if ($run.exit_code -eq 0) { 'PASS' } elseif ($Required) { 'FAIL' } else { 'PARTIAL' }; log_path=$run.log_path }
    $script:logs += $log
    return $record
}

if ($selected -eq 'Flutter') {
    $flutter = Get-CommandPath 'flutter'
    if (!$flutter) { $blockers += 'Flutter SDK is not available.' }
    else {
        if (!$SkipTests) {
            $commands += Run-Step 'flutter_pub_get' $flutter @('pub','get') $resolved $true -RecordCommand
            $tests += Run-Step 'flutter_analyze' $flutter @('analyze') $resolved $true
            $tests += Run-Step 'flutter_test' $flutter @('test') $resolved $true
        } else { $tests += [pscustomobject]@{ name='flutter_tests'; status='NOT_PERFORMED'; reason='SkipTests was explicitly supplied.' } }
        $buildArgs = @('build','apk')
        if ($Variant -eq 'Release') { $buildArgs += '--release' } else { $buildArgs += '--debug' }
        $buildArgs += $FlutterArg
        $commands += Run-Step ("flutter_build_" + $Variant.ToLowerInvariant()) $flutter $buildArgs $resolved $true -RecordCommand
    }
} else {
    $gradleRoot = if ($selected -eq 'Gradle') { $resolved } else { Join-Path $resolved 'android' }
    if ($selected -eq 'ReactNative' -and !$SkipTests) {
        $packageJson = Join-Path $resolved 'package.json'
        $hasTestScript = $false
        try {
            $package = Get-Content -LiteralPath $packageJson -Raw -ErrorAction Stop | ConvertFrom-Json
            $hasTestScript = ($package.PSObject.Properties.Name -contains 'scripts' -and $package.scripts -and $package.scripts.PSObject.Properties.Name -contains 'test')
        } catch { $hasTestScript = $false }
        if ($hasTestScript) {
            $managerName = if (Test-Path -LiteralPath (Join-Path $resolved 'pnpm-lock.yaml')) { 'pnpm' } elseif (Test-Path -LiteralPath (Join-Path $resolved 'yarn.lock')) { 'yarn' } else { 'npm' }
            $manager = Get-CommandPath $managerName
            if ($manager) {
                $tests += Run-Step ("react_native_" + $managerName + '_test') $manager @('run','test','--','--runInBand','--watch=false') $resolved $true
            } else { $blockers += "React Native test script exists but $managerName was not found." }
        } else {
            $tests += [pscustomobject]@{ name='react_native_tests'; status='NOT_PERFORMED'; reason='No package.json test script was declared.' }
        }
    }
    $wrapper = Join-Path $gradleRoot 'gradlew.bat'
    if (!(Test-Path -LiteralPath $wrapper -PathType Leaf)) {
        $blockers += "Gradle wrapper was not found at $wrapper."
    } else {
        if (!$SkipTests) {
            $testTasks = if ($GradleTask) { @($GradleTask) } else { @(':app:testDebugUnitTest', ':app:testReleaseUnitTest', ':app:lintDebug', ':app:lintRelease') }
            foreach ($task in $testTasks) { $tests += Run-Step ("gradle_" + ($task -replace '[:/]','_')) $wrapper (@($task) + $GradleArg) $gradleRoot $true }
        } else { $tests += [pscustomobject]@{ name='gradle_tests_lint'; status='NOT_PERFORMED'; reason='SkipTests was explicitly supplied.' } }
        $assemble = if ($Variant -eq 'Release') { ':app:assembleRelease' } else { ':app:assembleDebug' }
        $commands += Run-Step ("gradle_" + $Variant.ToLowerInvariant()) $wrapper (@($assemble) + $GradleArg) $gradleRoot $true -RecordCommand
        if ($Variant -eq 'Debug') {
            $commands += Run-Step 'gradle_debug_android_test' $wrapper (@(':app:assembleDebugAndroidTest') + $GradleArg) $gradleRoot $false -RecordCommand
        }
    }
}

$apkCandidates = @()
foreach ($root in @(
    (Join-Path $resolved 'app\build\outputs\apk'),
    (Join-Path $resolved 'android\app\build\outputs\apk'),
    (Join-Path $resolved 'build\app\outputs\flutter-apk')
)) {
    if (Test-Path -LiteralPath $root -PathType Container) {
        $apkCandidates += Get-ChildItem -LiteralPath $root -Recurse -Filter '*.apk' -File -ErrorAction SilentlyContinue
    }
}
$apkCandidates = @($apkCandidates | Sort-Object LastWriteTime -Descending -Unique)
$failedRequired = @($commands + $tests | Where-Object { ($_.PSObject.Properties.Name -contains 'required') -and $_.required -and $_.status -eq 'FAIL' })
$status = if ($blockers.Count -gt 0) { 'BLOCKED' } elseif ($failedRequired.Count -gt 0) { 'FAIL' } elseif ($apkCandidates.Count -eq 0) { 'FAIL' } elseif (@($tests | Where-Object { $_.status -eq 'NOT_PERFORMED' }).Count -gt 0) { 'PARTIAL' } else { 'PASS' }

$result = [ordered]@{
    status = $status
    project_root = $resolved
    framework = $selected
    variant = $Variant
    signing_properties_supplied = [bool]($SigningPropertiesFile -and (Test-Path -LiteralPath $SigningPropertiesFile -PathType Leaf))
    evidence_directory = $EvidenceDirectory
    tests = @($tests)
    commands = @($commands)
    logs = @($logs)
    artifacts = @($apkCandidates | ForEach-Object { [pscustomobject]@{ path=$_.FullName; bytes=$_.Length; last_write_time=$_.LastWriteTime.ToString('o') } })
    blockers = @($blockers)
    security = @('Signing properties are accepted by path only; file contents are never read or printed.', 'No clean, reset, uninstall, or package-data deletion command was run.')
}
if ($JsonPath) { $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8 }
Read-JsonInput ([pscustomobject]$result) $(if ($status -eq 'PASS' -or $status -eq 'PARTIAL') { 0 } else { 1 })
