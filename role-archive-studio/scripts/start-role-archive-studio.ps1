param(
    [int]$Port = 48678,
    [switch]$NoBrowser,
    [int]$RequestLimit = 0
)

$serverScript = Join-Path $PSScriptRoot 'role_archive_server.ps1'

if (-not (Test-Path $serverScript)) {
    throw "Server script not found: $serverScript"
}

$arguments = @(
    '-ExecutionPolicy', 'Bypass',
    '-File', $serverScript,
    '-Port', $Port,
    '-RequestLimit', $RequestLimit
)

if ($NoBrowser) {
    $arguments += '-NoBrowser'
}

& powershell @arguments
