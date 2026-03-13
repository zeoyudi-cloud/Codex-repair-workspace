param(
    [switch]$DiagnoseOnly
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=== $Title ==="
}

function Get-CodexConfigPath {
    return Join-Path $env:USERPROFILE ".codex\config.toml"
}

function Get-NativeCodexExe {
    $roots = @(
        (Join-Path $env:USERPROFILE ".vscode\extensions"),
        (Join-Path $env:USERPROFILE ".cursor\extensions")
    )

    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        $match = Get-ChildItem $root -Recurse -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and $_.Name -eq "codex.exe" } |
            Select-Object -First 1 -ExpandProperty FullName
        if ($match) { return $match }
    }

    return $null
}

function Test-SandboxCommand {
    try {
        $output = & codex.cmd sandbox windows cmd /c echo skill_sandbox_ok 2>&1
        return ($output -join "`n")
    } catch {
        return $_.Exception.Message
    }
}

Write-Section "BASIC"
$cmd = $null
try { $cmd = Get-Command codex -ErrorAction Stop } catch {}
$nativeExe = Get-NativeCodexExe
$configPath = Get-CodexConfigPath

Write-Host "CurrentUser: $env:USERNAME"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "codex command: $($cmd.Definition)"
Write-Host "native codex.exe: $nativeExe"
Write-Host "config.toml: $configPath"

Write-Section "EXECUTION POLICY"
$policyList = Get-ExecutionPolicy -List
$policyList | Format-Table -AutoSize

if (-not $DiagnoseOnly) {
    $currentUserPolicy = (Get-ExecutionPolicy -Scope CurrentUser)
    if ($currentUserPolicy -ne "RemoteSigned") {
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
        Write-Host "Updated CurrentUser execution policy to RemoteSigned"
    } else {
        Write-Host "CurrentUser execution policy already RemoteSigned"
    }
}

Write-Section "CONFIG TOML"
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw
    Write-Host $config

    if (-not $DiagnoseOnly) {
        if ($config -match '(?ms)^\[windows\]\s*sandbox = "elevated"') {
            $updated = $config -replace '(?ms)(^\[windows\]\s*sandbox = )"elevated"', '$1"unelevated"'
            Set-Content -Path $configPath -Value $updated -Encoding UTF8
            Write-Host "Updated [windows].sandbox from elevated to unelevated"
        } elseif ($config -notmatch '(?ms)^\[windows\]') {
            Add-Content -Path $configPath -Value "`r`n[windows]`r`nsandbox = `"unelevated`"`r`n" -Encoding UTF8
            Write-Host "Added [windows] sandbox = unelevated"
        } else {
            Write-Host "Windows sandbox config already present and not elevated"
        }
    }
} else {
    Write-Host "Config file not found"
}

Write-Section "COMMAND CHECKS"
try {
    & codex --version
} catch {
    Write-Host "codex --version failed: $($_.Exception.Message)"
}

try {
    & codex.cmd --version
} catch {
    Write-Host "codex.cmd --version failed: $($_.Exception.Message)"
}

if ($nativeExe) {
    try {
        & $nativeExe --version
    } catch {
        Write-Host "native codex.exe --version failed: $($_.Exception.Message)"
    }
}

Write-Section "RUNNER CHECK"
if ($nativeExe) {
    $runnerExe = Join-Path (Split-Path $nativeExe -Parent) "codex-command-runner.exe"
    if (Test-Path $runnerExe) {
        try {
            & $runnerExe
        } catch {
            Write-Host "runner output: $($_.Exception.Message)"
        }
    } else {
        Write-Host "runner not found next to native codex.exe"
    }
}

Write-Section "SANDBOX TEST"
$sandboxResult = Test-SandboxCommand
Write-Host $sandboxResult

Write-Section "DONE"
if ($DiagnoseOnly) {
    Write-Host "Diagnose only mode: no fixes were applied."
} else {
    Write-Host "Fix mode completed."
}
