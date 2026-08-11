[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [ValidateSet('home','company')][string]$Profile,
    [string]$ProjectId,
    [switch]$Apply,
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'common.ps1')

function Get-CMDocumentText {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $text = [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $text = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
    } else {
        try { $text = ([System.Text.UTF8Encoding]::new($false, $true)).GetString($bytes) }
        catch { $text = [System.Text.Encoding]::Default.GetString($bytes) }
    }
    return $text.TrimStart([char]0xFEFF)
}

function Test-CMProjectDocumentPath {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Path)
    $relative = $Path.Substring($Root.Length).TrimStart('\','/')
    if (Test-CMPlanLikePath -RelativePath $relative) { return $false }
    if ($relative -match '(^|[\\/])(?:\.git|node_modules|vendor|build|dist|output|objects|packages|superpowers|tasks|plans|specs)([\\/]|$)') { return $false }
    $fileName = [System.IO.Path]::GetFileName($relative)
    if ($fileName -match '^(?i:00-.*(?:\u9605|\u8BFB|\u6307|\u5F15|\u6A21|\u677F|\u540C|\u6B65|template|guide|manifest|sync).*)\.md$') { return $false }
    return $true
}

function Test-CMInMappedChild {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Path, $Mappings)
    foreach ($mapping in @($Mappings)) {
        if ($null -eq $mapping) { continue }
        $propertyNames = @($mapping.PSObject.Properties | ForEach-Object { $_.Name })
        $component = if ($propertyNames -contains 'component') { [string]$mapping.component } else { 'main' }
        if ($component -eq 'main' -or $propertyNames -notcontains 'source_root') { continue }
        $mappedRoot = [string]$mapping.source_root
        if ([string]::IsNullOrWhiteSpace($mappedRoot) -or -not [System.IO.Path]::IsPathRooted($mappedRoot)) { continue }
        if ((Test-CMSamePath -Left $Root -Right $mappedRoot)) { continue }
        if ((Test-CMPathWithin -Root $Root -Candidate $mappedRoot) -and (Test-CMPathWithin -Root $mappedRoot -Candidate $Path)) { return $true }
    }
    return $false
}

try {
    $configArgs = @{ RequireMemoryRoot = $true }
    if ($Profile) { $configArgs.Profile = $Profile }
    $config = & (Join-Path $PSScriptRoot 'resolve-config.ps1') @configArgs | ConvertFrom-Json
    if ($config.status -ne 'PASS') { throw $config.message }
    if (-not [bool]$config.data.policy.allow_document_mirror) { throw 'Active profile does not permit project document mirrors.' }

    $projectArgs = @{ ProjectRoot = $ProjectRoot }
    if ($ProjectId) { $projectArgs.ProjectId = $ProjectId }
    $project = & (Join-Path $PSScriptRoot 'discover-project.ps1') @projectArgs | ConvertFrom-Json
    if ($project.status -ne 'PASS') { throw $project.message }

    $root = (Resolve-Path -LiteralPath ([string]$project.data.project_root)).Path.TrimEnd('\')
    $id = ConvertTo-CMSafeId ([string]$project.data.memory_id)
    $mirrorRoot = Join-Path (Get-CMProjectMemoryPath -MemoryRoot ([string]$config.data.memory_root) -ProjectId $id) '05-工程文档'
    $mirrorPrefix = if ($project.data.mirror_prefix) { ConvertTo-CMSafeId ([string]$project.data.mirror_prefix) } else { $null }
    $allowedExtensions = @($config.data.policy.source_extensions | ForEach-Object { [string]$_ })
    $paths = @()
    $paths += @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -in @('README.md','GUIDE.md') -and $_.Extension.ToLowerInvariant() -in $allowedExtensions -and (Test-CMProjectDocumentPath -Root $root -Path $_.FullName)
    })
    $docsRoot = [string]$project.data.docs_root
    $documentRoots = @()
    if (Test-Path -LiteralPath $docsRoot -PathType Container) { $documentRoots += (Get-Item -LiteralPath $docsRoot) }
    $documentRoots += @(Get-ChildItem -LiteralPath $root -Recurse -Directory -Filter 'docs' -ErrorAction SilentlyContinue | Where-Object {
        Test-CMProjectDocumentPath -Root $root -Path $_.FullName
    })
    foreach ($documentRoot in $documentRoots) {
        $paths += @(Get-ChildItem -LiteralPath $documentRoot.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension.ToLowerInvariant() -in $allowedExtensions -and (Test-CMProjectDocumentPath -Root $root -Path $_.FullName)
        })
    }

    $paths = @($paths | Where-Object { -not (Test-CMInMappedChild -Root $root -Path $_.FullName -Mappings $config.data.project_mappings) })

    $seen = @{}
    $copied = @()
    $skipped = @()
    foreach ($file in $paths) {
        $source = $file.FullName
        $key = (Get-CMCanonicalPath $source).ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $relative = $source.Substring($root.Length).TrimStart('\','/')
        if (-not (Test-CMSafeRelativePath $relative)) { throw "Project document path is unsafe: $relative" }
        $text = Get-CMDocumentText -Path $source
        if (Test-CMSensitiveText $text) {
            $skipped += [pscustomobject]@{ relative_path = $relative; reason = 'sensitive_content' }
            continue
        }
        $destinationRelative = if ($mirrorPrefix) { Join-Path $mirrorPrefix $relative } else { $relative }
        if (-not (Test-CMSafeRelativePath $destinationRelative)) { throw "Project document destination path is unsafe: $destinationRelative" }
        $destination = Join-Path $mirrorRoot ($destinationRelative -replace '/', '\')
        $copied += [pscustomobject]@{ relative_path = $relative; destination_relative_path = $destinationRelative; source = $source; destination = $destination; sha256 = Get-CMHash $source }
    }
    $component = if ($project.data.component) { [string]$project.data.component } else { 'main' }
    $statePath = Get-CMDocumentStatePath -ProjectId $id -Component $component
    $state = [ordered]@{ schema_version = 2; project_id = $id; mirror_prefix = $mirrorPrefix; updated_at = (Get-Date).ToUniversalTime().ToString('o'); copied = @($copied | ForEach-Object { @{ relative_path = $_.relative_path; destination_relative_path = $_.destination_relative_path; sha256 = $_.sha256 } }); skipped = @($skipped) }

    if ($DryRun -or -not $Apply) {
        (Get-CMResult -Status 'DRY_RUN' -Message 'Project documentation mirror validated; no copies were written.' -Data @{ project_id = $id; mirror_root = $mirrorRoot; manifest_path = $null; state_path = $statePath; copy_count = $copied.Count; skip_count = $skipped.Count; copied = $copied; skipped = $skipped }) | ConvertTo-Json -Depth 8
        exit 0
    }

    $lock = Enter-CMLock -Name ('document-mirror-' + $id)
    $original = @{}
    try {
        foreach ($item in $copied) { $original[$item.destination] = Get-CMFileSnapshot -Path $item.destination }
        $original[$statePath] = Get-CMFileSnapshot -Path $statePath
        foreach ($item in $copied) { Write-CMAtomicBytes -Path $item.destination -Bytes ([System.IO.File]::ReadAllBytes($item.source)) }
        Write-CMAtomicJson -Path $statePath -Value $state
    } catch {
        foreach ($path in @($original.Keys)) {
            try { Restore-CMFileSnapshot -Path $path -Snapshot $original[$path] } catch { }
        }
        throw
    } finally {
        $lock.Dispose()
    }
    (Get-CMResult -Status 'PASS' -Message 'Project documentation mirror synchronized.' -Data @{ project_id = $id; mirror_root = $mirrorRoot; manifest_path = $null; state_path = $statePath; copy_count = $copied.Count; skip_count = $skipped.Count; copied = $copied; skipped = $skipped }) | ConvertTo-Json -Depth 8
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6
    exit 1
}
