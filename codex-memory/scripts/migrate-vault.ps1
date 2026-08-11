[CmdletBinding()]
param(
    [ValidateSet('home','company')][string]$Profile,
    [switch]$Apply,
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'common.ps1')

function Test-CMObsidianProcessFile {
    param([Parameter(Mandatory = $true)][string]$MemoryRoot, [Parameter(Mandatory = $true)][string]$Path)
    $relative = $Path.Substring($MemoryRoot.Length).TrimStart('\','/')
    $planName = '01-' + (-join ([int[]]@(0x603B,0x4F53,0x8BA1,0x5212) | ForEach-Object { [char]$_ })) + '.md'
    $manifestName = '00-' + (-join ([int[]]@(0x540C,0x6B65,0x6E05,0x5355) | ForEach-Object { [char]$_ })) + '.md'
    if ([System.IO.Path]::GetFileName($Path) -in @($planName, $manifestName)) { return $true }
    if ($relative -match '(^|[\\/])(?:superpowers[\\/]plans|superpowers[\\/]specs|tasks)([\\/]|$)') { return $true }
    if (Test-CMPlanLikePath -RelativePath $relative) { return $true }
    if ($relative -match '(^|[\\/])05-[^\\/]+([\\/]|$)' -and [System.IO.Path]::GetFileName($Path) -match '^(?i:00-.*(?:\u9605|\u8BFB|\u6307|\u5F15|\u6A21|\u677F|\u540C|\u6B65|template|guide|manifest|sync).*)\.md$') { return $true }
    return $false
}

try {
    $configArgs = @{ RequireMemoryRoot = $true }
    if ($Profile) { $configArgs.Profile = $Profile }
    $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') @configArgs | ConvertFrom-Json
    if ($config.status -ne 'PASS') { throw $config.message }
    $memoryRoot = (Resolve-Path -LiteralPath ([string]$config.data.memory_root)).Path.TrimEnd('\')
    $projectMemoryDirectory = '03-' + (-join ([int[]]@(0x9879,0x76EE,0x8BB0,0x5FC6) | ForEach-Object { [char]$_ }))
    $projectRoot = Join-Path $memoryRoot $projectMemoryDirectory
    $candidates = @()
    if (Test-Path -LiteralPath $projectRoot -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -File -ErrorAction SilentlyContinue) {
            if (Test-CMObsidianProcessFile -MemoryRoot $memoryRoot -Path $file.FullName) {
                if (-not (Test-CMPathWithin -Root $memoryRoot -Candidate $file.FullName)) { throw "Migration candidate escaped memory root: $($file.FullName)" }
                $candidates += [pscustomobject]@{ path = $file.FullName; relative_path = $file.FullName.Substring($memoryRoot.Length).TrimStart('\','/') }
            }
        }
    }
    $data = @{ memory_root = $memoryRoot; candidate_count = $candidates.Count; candidates = $candidates; action = 'move_to_recycle_bin' }
    if ($DryRun -or -not $Apply) {
        (Get-CMResult -Status 'DRY_RUN' -Message 'Vault process-file migration preview; no files were removed.' -Data $data) | ConvertTo-Json -Depth 10
        exit 0
    }
    Add-Type -AssemblyName Microsoft.VisualBasic
    foreach ($candidate in $candidates) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($candidate.path, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
    }
    (Get-CMResult -Status 'PASS' -Message 'Vault process files moved to the Windows Recycle Bin; source project files were untouched.' -Data $data) | ConvertTo-Json -Depth 10
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 8
    exit 1
}
