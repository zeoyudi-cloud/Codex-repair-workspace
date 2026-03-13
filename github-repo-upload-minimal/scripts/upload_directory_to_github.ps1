param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [ValidateSet("public", "private")]
    [string]$Visibility = "public",

    [string]$RepoSubdir = "",

    [ValidateSet('auto', 'report', 'off')]
    [string]$SanitizeMode = 'auto'
)

$ErrorActionPreference = "Stop"

function Clear-ProxyEnv {
    foreach ($name in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy", "GIT_HTTP_PROXY", "GIT_HTTPS_PROXY")) {
        Set-Item -Path "Env:$name" -Value "" -ErrorAction SilentlyContinue
    }
}

function Get-WingetPath {
    $candidates = @(
        'winget.exe',
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe')
    )
    foreach ($candidate in $candidates) {
        try {
            if ($candidate -eq 'winget.exe') {
                $null = Get-Command winget.exe -ErrorAction Stop
                return 'winget.exe'
            }
            if (Test-Path $candidate) { return $candidate }
        } catch {}
    }
    throw 'winget is not available on this system.'
}

function Require-CommandPath {
    param(
        [string]$Path,
        [string]$InstallId
    )
    if (-not (Test-Path $Path)) {
        $winget = Get-WingetPath
        & $winget install --id $InstallId -e --source winget --accept-package-agreements --accept-source-agreements
    }
    if (-not (Test-Path $Path)) {
        throw "Missing required tool: $Path"
    }
}

function Normalize-RepoSubdir {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return ($Value.Trim() -replace '^[\\/]+', '' -replace '[\\/]+$', '' -replace '\\', '/')
}

function Get-TextLikeExtensions {
    @('.md', '.txt', '.ps1', '.psm1', '.json', '.yaml', '.yml', '.html', '.css', '.js', '.ts', '.tsx', '.jsx')
}

function Is-TextLikeFile {
    param([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    return (Get-TextLikeExtensions) -contains $ext
}

function Get-FileText {
    param([string]$Path)
    try {
        return [System.IO.File]::ReadAllText($Path)
    } catch {
        return ''
    }
}

function Get-SensitiveFindings {
    param([string]$Dir)
    $patterns = @(
        [PSCustomObject]@{ Id='win-user-path'; Regex='[A-Za-z]:\\Users\\[^\\\r\n]+(?:\\[^\r\n`"''<>|]+)*'; Message='Windows 用户目录绝对路径' },
        [PSCustomObject]@{ Id='unix-user-path'; Regex='/(Users|home)/[^/\s]+(?:/[^\s`"''<>|]+)*'; Message='Unix 用户目录绝对路径' },
        [PSCustomObject]@{ Id='codex-data-abs'; Regex='[A-Za-z]:\\Users\\[^\\\r\n]+\\\.codex\\[^\r\n`"''<>|]*'; Message='绝对 .codex 本地目录路径' }
    )
    $findings = @()
    $files = Get-ChildItem -Path $Dir -Recurse -File
    foreach ($file in $files) {
        if (-not (Is-TextLikeFile -Path $file.FullName)) { continue }
        $text = Get-FileText -Path $file.FullName
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        foreach ($pattern in $patterns) {
            $matches = [System.Text.RegularExpressions.Regex]::Matches($text, $pattern.Regex)
            foreach ($match in $matches) {
                $findings += [PSCustomObject]@{
                    Path = $file.FullName
                    Rule = $pattern.Id
                    Message = $pattern.Message
                    Snippet = $match.Value
                }
            }
        }
    }
    return $findings
}

function Sanitize-AbsolutePaths {
    param([string]$Dir)
    $files = Get-ChildItem -Path $Dir -Recurse -File
    $changed = @()
    foreach ($file in $files) {
        if (-not (Is-TextLikeFile -Path $file.FullName)) { continue }
        $text = Get-FileText -Path $file.FullName
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $updated = $text
        $updated = [System.Text.RegularExpressions.Regex]::Replace($updated, '[A-Za-z]:\\Users\\[^\\\r\n]+\\\.codex\\skills\\', '$HOME/.codex/skills/')
        $updated = [System.Text.RegularExpressions.Regex]::Replace($updated, '[A-Za-z]:\\Users\\[^\\\r\n]+\\\.codex\\', '$HOME/.codex/')
        $updated = [System.Text.RegularExpressions.Regex]::Replace($updated, '/Users/[^/\s]+/\.codex/', '$HOME/.codex/')
        $updated = [System.Text.RegularExpressions.Regex]::Replace($updated, '/home/[^/\s]+/\.codex/', '$HOME/.codex/')
        if ($updated -ne $text) {
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($file.FullName, $updated, $utf8NoBom)
            $changed += $file.FullName
        }
    }
    return $changed
}

function Invoke-SanitizePreflight {
    param(
        [string]$Dir,
        [string]$Mode
    )
    if ($Mode -eq 'off') {
        Write-Host 'Sanitize preflight: skipped.'
        return
    }

    $initial = @(Get-SensitiveFindings -Dir $Dir)
    if ($initial.Count -eq 0) {
        Write-Host 'Sanitize preflight: no high-risk absolute paths found.'
        return
    }

    Write-Host "Sanitize preflight: found $($initial.Count) high-risk item(s)."
    if ($Mode -eq 'report') {
        $initial | Select-Object -First 20 | ForEach-Object { Write-Host ("[{0}] {1} -> {2}" -f $_.Rule, $_.Path, $_.Snippet) }
        throw 'Sensitive path scan found issues. Resolve them or rerun with -SanitizeMode auto after review.'
    }

    $changed = @(Sanitize-AbsolutePaths -Dir $Dir)
    if ($changed.Count -gt 0) {
        Write-Host "Sanitize preflight: auto-generalized $($changed.Count) file(s)."
    }

    $remaining = @(Get-SensitiveFindings -Dir $Dir)
    if ($remaining.Count -gt 0) {
        $remaining | Select-Object -First 20 | ForEach-Object { Write-Host ("[{0}] {1} -> {2}" -f $_.Rule, $_.Path, $_.Snippet) }
        throw 'Sensitive path scan still found unresolved issues after auto-sanitize.'
    }

    Write-Host 'Sanitize preflight: passed.'
}

function Ensure-GitRepo {
    param([string]$Dir)
    & $git -C $Dir init | Out-Null
    & $git -C $Dir config user.name "github-uploader"
    & $git -C $Dir config user.email "github-uploader@users.noreply.github.com"
    & $git -C $Dir branch -M main
    & $git -C $Dir add .
    $status = & $git -C $Dir status --short
    if ($status) {
        & $git -C $Dir commit -m "Upload via github-repo-upload-minimal" | Out-Null
    }
}

function Ensure-RepoExists {
    param(
        [string]$RepoName,
        [string]$VisibilityName,
        [string]$Dir
    )
    try {
        & $gh repo view $RepoName | Out-Null
    } catch {
        & $gh repo create $RepoName "--$VisibilityName" --source $Dir --remote origin | Out-Null
    }
}

function Upload-WithApi {
    param(
        [string]$Dir,
        [string]$RepoName,
        [string]$TargetSubdir
    )

    $token = (& $gh auth token).Trim()
    $headers = @{
        Authorization = "Bearer $token"
        Accept        = "application/vnd.github+json"
        "User-Agent"  = "github-repo-upload-minimal"
    }

    $prefix = Normalize-RepoSubdir -Value $TargetSubdir
    $files = Get-ChildItem $Dir -Recurse -File
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Dir.Length).TrimStart('\\').Replace('\\', '/')
        $targetPath = if ([string]::IsNullOrWhiteSpace($prefix)) { $relative } else { "$prefix/$relative" }
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $content = [Convert]::ToBase64String($bytes)
        $bodyObject = @{
            message = "Update $targetPath"
            content = $content
            branch  = "main"
        }

        $uri = "https://api.github.com/repos/$RepoName/contents/$targetPath"
        try {
            $existing = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            $bodyObject.sha = $existing.sha
        } catch {}

        $body = $bodyObject | ConvertTo-Json
        Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $body -ContentType "application/json" | Out-Null
        Write-Host "Uploaded $targetPath"
    }
}

Clear-ProxyEnv

$git = "C:\Program Files\Git\cmd\git.exe"
$gh = "C:\Program Files\GitHub CLI\gh.exe"
$RepoSubdir = Normalize-RepoSubdir -Value $RepoSubdir

Require-CommandPath -Path $git -InstallId "Git.Git"
Require-CommandPath -Path $gh -InstallId "GitHub.cli"

if (-not (Test-Path $SourceDir)) {
    throw "Source directory not found: $SourceDir"
}

Invoke-SanitizePreflight -Dir $SourceDir -Mode $SanitizeMode

try {
    & $gh auth status | Out-Null
} catch {
    & $gh auth login --hostname github.com --web --git-protocol https
}

Ensure-RepoExists -RepoName $Repo -VisibilityName $Visibility -Dir $SourceDir

if (-not [string]::IsNullOrWhiteSpace($RepoSubdir)) {
    Upload-WithApi -Dir $SourceDir -RepoName $Repo -TargetSubdir $RepoSubdir
    Write-Host "Repository ready: https://github.com/$Repo/tree/main/$RepoSubdir"
    exit 0
}

Ensure-GitRepo -Dir $SourceDir

try {
    & $git -C $SourceDir remote remove origin 2>$null
} catch {}
& $git -C $SourceDir remote add origin "https://github.com/$Repo.git"

try {
    $token = (& $gh auth token).Trim()
    & $git -C $SourceDir -c credential.helper= -c core.askPass= -c http.https://github.com/.extraheader="AUTHORIZATION: bearer $token" push -u origin main
} catch {
    Upload-WithApi -Dir $SourceDir -RepoName $Repo -TargetSubdir ''
}

Write-Host "Repository ready: https://github.com/$Repo"
