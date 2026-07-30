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
    return $relative -notmatch '(^|[\\/])(?:\.git|node_modules|vendor|build|dist|output|objects|packages)([\\/]|$)'
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
        $destination = Join-Path $mirrorRoot ($relative -replace '/', '\')
        $copied += [pscustomobject]@{ relative_path = $relative; source = $source; destination = $destination; sha256 = Get-CMHash $source }
    }

    $manifest = @(
        "# $id - 工程文档镜像",
        '',
        '<!-- codex-memory:auto:start -->',
        '## 同步说明',
        '- 本目录保存工程 docs/、根目录 README.md 和 GUIDE.md 的 Markdown 原文副本。',
        '- 原工程仍是编辑源；此处用于离线检索和跨会话知识加载。同步只新增或更新当前文档，不删除已有副本。',
        '',
        '## 已复制'
    )
    if ($copied.Count) {
        foreach ($item in $copied) { $manifest += "- ``$($item.relative_path)`` - SHA-256: ``$($item.sha256)``" }
    } else {
        $manifest += '- 无可复制的 Markdown 文档。'
    }
    $manifest += ''
    $manifest += '## 已跳过'
    if ($skipped.Count) {
        foreach ($item in $skipped) { $manifest += "- ``$($item.relative_path)`` - $($item.reason)" }
    } else {
        $manifest += '- 无。'
    }
    $manifest += '<!-- codex-memory:auto:end -->'
    $manifestPath = Join-Path $mirrorRoot '00-同步清单.md'

    if ($DryRun -or -not $Apply) {
        (Get-CMResult -Status 'DRY_RUN' -Message 'Project documentation mirror validated; no copies were written.' -Data @{ project_id = $id; mirror_root = $mirrorRoot; manifest_path = $manifestPath; copy_count = $copied.Count; skip_count = $skipped.Count; copied = $copied; skipped = $skipped }) | ConvertTo-Json -Depth 8
        exit 0
    }

    $lock = Enter-CMLock -Name ('document-mirror-' + $id)
    try {
        foreach ($item in $copied) { Write-CMAtomicBytes -Path $item.destination -Bytes ([System.IO.File]::ReadAllBytes($item.source)) }
        Write-CMAtomicText -Path $manifestPath -Content ($manifest -join "`r`n")
    } finally {
        $lock.Dispose()
    }
    (Get-CMResult -Status 'PASS' -Message 'Project documentation mirror synchronized.' -Data @{ project_id = $id; mirror_root = $mirrorRoot; manifest_path = $manifestPath; copy_count = $copied.Count; skip_count = $skipped.Count; copied = $copied; skipped = $skipped }) | ConvertTo-Json -Depth 8
} catch {
    (Get-CMResult -Status 'BLOCKED' -Message $_.Exception.Message -Data $null) | ConvertTo-Json -Depth 6
    exit 1
}
