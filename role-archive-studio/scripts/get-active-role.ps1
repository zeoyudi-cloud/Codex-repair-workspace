param(
    [switch]$AsJson,
    [switch]$PromptOnly
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$profilesPath = Join-Path $dataRoot 'profiles.json'
$memoriesPath = Join-Path $dataRoot 'memories.json'
$statePath = Join-Path $dataRoot 'state.json'

function Initialize-Store {
    if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }
    if (-not (Test-Path $profilesPath)) { '[]' | Set-Content -Path $profilesPath -Encoding UTF8 }
    if (-not (Test-Path $memoriesPath)) { '[]' | Set-Content -Path $memoriesPath -Encoding UTF8 }
    if (-not (Test-Path $statePath)) { '{"activeProfileId":"","lastOpenedAt":"","updatedAt":""}' | Set-Content -Path $statePath -Encoding UTF8 }
}

function Read-JsonFile {
    param([string]$Path)
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw | ConvertFrom-Json
}

function Normalize-ObjectArray {
    param($Items)
    if ($null -eq $Items) { return @() }
    if ($Items.PSObject.Properties.Name -contains 'value') { return @($Items.value) }
    return @($Items)
}

function Build-Prompt {
    param($Profile, [array]$MemoryEntries)
    if (-not $Profile) { return '' }

    $memories = @()
    if ($Profile.memories) { $memories = @($Profile.memories | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
    foreach ($entry in @($MemoryEntries)) {
        if ($entry -and -not [string]::IsNullOrWhiteSpace([string]$entry.text)) { $memories += [string]$entry.text }
    }
    $memories = @($memories | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

    $rules = @()
    if ($Profile.rules) { $rules = @($Profile.rules | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }

    $memoryFocus = if ([string]::IsNullOrWhiteSpace([string]$Profile.memoryFocus)) {
        'Keep only stable long-term information: preferences, collaboration style, and confirmed facts. Do not store role-card setup, one-off dev process, or temporary test details.'
    } else {
        [string]$Profile.memoryFocus
    }

    $lines = @(
        "Active role: $($Profile.name)"
        "Role title: $($Profile.title)"
        "Role summary: $($Profile.summary)"
        "Personality: $($Profile.personality)"
        "Voice style: $($Profile.voice)"
        "Memory focus: $memoryFocus"
        'Remember these details:'
    )

    if ($memories.Count -eq 0) { $lines += '- none' } else { $lines += ($memories | ForEach-Object { "- $_" }) }
    $lines += 'Collaboration rules:'
    if ($rules.Count -eq 0) { $lines += '- none' } else { $lines += ($rules | ForEach-Object { "- $_" }) }
    if (-not [string]::IsNullOrWhiteSpace($Profile.notes)) { $lines += "Notes: $($Profile.notes)" }
    return ($lines -join [Environment]::NewLine)
}

Initialize-Store
$profiles = @(Normalize-ObjectArray (Read-JsonFile -Path $profilesPath))
$memoryEntries = @(Normalize-ObjectArray (Read-JsonFile -Path $memoriesPath))
$state = Read-JsonFile -Path $statePath
$active = $profiles | Where-Object { $_.id -eq $state.activeProfileId } | Select-Object -First 1
$activeMemories = @($memoryEntries | Where-Object { $_.profileId -eq $state.activeProfileId })

if ($PromptOnly) { Build-Prompt -Profile $active -MemoryEntries $activeMemories; exit 0 }
if ($AsJson) {
    [PSCustomObject]@{ dataRoot = $dataRoot; activeProfile = $active; memoryEntries = $activeMemories; prompt = Build-Prompt -Profile $active -MemoryEntries $activeMemories } | ConvertTo-Json -Depth 6
    exit 0
}
if (-not $active) { Write-Output "No active role profile is set. Data root: $dataRoot"; exit 0 }
Write-Output "Active role: $($active.name)"
Write-Output "Data root: $dataRoot"
Write-Output ''
Write-Output (Build-Prompt -Profile $active -MemoryEntries $activeMemories)