param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [ValidateSet("public", "private")]
    [string]$Visibility = "public"
)

$ErrorActionPreference = "Stop"

function Clear-ProxyEnv {
    foreach ($name in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy", "GIT_HTTP_PROXY", "GIT_HTTPS_PROXY")) {
        Set-Item -Path "Env:$name" -Value "" -ErrorAction SilentlyContinue
    }
}

function Require-CommandPath {
    param(
        [string]$Path,
        [string]$InstallId
    )
    if (-not (Test-Path $Path)) {
        winget install --id $InstallId -e --source winget --accept-package-agreements --accept-source-agreements
    }
    if (-not (Test-Path $Path)) {
        throw "Missing required tool: $Path"
    }
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
        [string]$RepoName
    )

    $token = (& $gh auth token).Trim()
    $headers = @{
        Authorization = "Bearer $token"
        Accept        = "application/vnd.github+json"
        "User-Agent"  = "github-repo-upload-minimal"
    }

    $files = Get-ChildItem $Dir -Recurse -File
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Dir.Length).TrimStart('\').Replace('\', '/')
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $content = [Convert]::ToBase64String($bytes)
        $bodyObject = @{
            message = "Update $relative"
            content = $content
            branch  = "main"
        }

        $uri = "https://api.github.com/repos/$RepoName/contents/$relative"
        try {
            $existing = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            $bodyObject.sha = $existing.sha
        } catch {
        }

        $body = $bodyObject | ConvertTo-Json
        Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $body -ContentType "application/json" | Out-Null
        Write-Host "Uploaded $relative"
    }
}

Clear-ProxyEnv

$git = "C:\Program Files\Git\cmd\git.exe"
$gh = "C:\Program Files\GitHub CLI\gh.exe"

Require-CommandPath -Path $git -InstallId "Git.Git"
Require-CommandPath -Path $gh -InstallId "GitHub.cli"

if (-not (Test-Path $SourceDir)) {
    throw "Source directory not found: $SourceDir"
}

try {
    & $gh auth status | Out-Null
} catch {
    & $gh auth login --hostname github.com --web --git-protocol https
}

Ensure-GitRepo -Dir $SourceDir
Ensure-RepoExists -RepoName $Repo -VisibilityName $Visibility -Dir $SourceDir

try {
    & $git -C $SourceDir remote remove origin 2>$null
} catch {
}
& $git -C $SourceDir remote add origin "https://github.com/$Repo.git"

try {
    $token = (& $gh auth token).Trim()
    & $git -C $SourceDir -c credential.helper= -c core.askPass= -c http.https://github.com/.extraheader="AUTHORIZATION: bearer $token" push -u origin main
} catch {
    Upload-WithApi -Dir $SourceDir -RepoName $Repo
}

Write-Host "Repository ready: https://github.com/$Repo"
