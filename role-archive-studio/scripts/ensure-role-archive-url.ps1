param(
    [int]$Port = 48678,
    [switch]$ForceRestart
)

$launcher = Join-Path $PSScriptRoot 'start-role-archive-studio.ps1'
$url = "http://127.0.0.1:$Port/"
$apiUrl = "${url}api/bootstrap"

function Test-RoleArchiveServer {
    param([string]$BootstrapUrl)
    try {
        Invoke-RestMethod -Uri $BootstrapUrl -TimeoutSec 2 | Out-Null
        return $true
    } catch {
        return $false
    }
}

if ($ForceRestart) {
    Get-CimInstance Win32_Process |
        Where-Object { $_.CommandLine -like '*role_archive_server.ps1*' -or $_.CommandLine -like '*start-role-archive-studio.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}

if (-not (Test-RoleArchiveServer -BootstrapUrl $apiUrl)) {
    Start-Process powershell -WindowStyle Hidden -ArgumentList '-ExecutionPolicy', 'Bypass', '-File', $launcher, '-NoBrowser', '-Port', $Port | Out-Null
    $ready = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-RoleArchiveServer -BootstrapUrl $apiUrl) {
            $ready = $true
            break
        }
    }
    if (-not $ready) { throw "Role Archive Studio did not become ready at $url" }
}

Write-Output $url
