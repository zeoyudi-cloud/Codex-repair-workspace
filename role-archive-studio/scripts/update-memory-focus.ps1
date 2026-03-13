param(
    [Parameter(Mandatory = $true)]
    [string]$Text,
    [string]$ProfileId
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$profilesPath = Join-Path $dataRoot 'profiles.json'
$statePath = Join-Path $dataRoot 'state.json'

function Initialize-Store {
    if (-not (Test-Path $dataRoot)) {
        New-Item -ItemType Directory -Path $dataRoot | Out-Null
    }

    if (-not (Test-Path $profilesPath)) {
        '[]' | Set-Content -Path $profilesPath -Encoding UTF8
    }

    if (-not (Test-Path $statePath)) {
        '{"activeProfileId":"","lastOpenedAt":"","updatedAt":""}' | Set-Content -Path $statePath -Encoding UTF8
    }
}

function Read-JsonFile {
    param([string]$Path)

    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return $raw | ConvertFrom-Json
}

function Normalize-StringArray {
    param($Value)

    $items = @()
    foreach ($entry in @($Value)) {
        if ($null -eq $entry) {
            continue
        }

        $text = [string]$entry
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $items += $text.Trim()
        }
    }

    return $items
}

Initialize-Store

$state = Read-JsonFile -Path $statePath
$resolvedProfileId = if ([string]::IsNullOrWhiteSpace($ProfileId)) { [string]$state.activeProfileId } else { $ProfileId }
if ([string]::IsNullOrWhiteSpace($resolvedProfileId)) {
    throw 'No active profile is set, and no -ProfileId was provided.'
}

$profiles = @((Read-JsonFile -Path $profilesPath))
$existing = $profiles | Where-Object { $_.id -eq $resolvedProfileId } | Select-Object -First 1
if (-not $existing) {
    throw 'Profile not found.'
}

$updated = [PSCustomObject]@{
    id = [string]$existing.id
    name = [string]$existing.name
    title = [string]$existing.title
    summary = [string]$existing.summary
    personality = [string]$existing.personality
    voice = [string]$existing.voice
    memories = Normalize-StringArray -Value $existing.memories
    rules = Normalize-StringArray -Value $existing.rules
    notes = [string]$existing.notes
    memoryFocus = $Text.Trim()
    memoryFocusConfirmedAt = (Get-Date).ToString('s')
    createdAt = [string]$existing.createdAt
    updatedAt = (Get-Date).ToString('s')
}

$profiles = @($profiles | Where-Object { $_.id -ne $resolvedProfileId }) + $updated
$json = ConvertTo-Json -InputObject ([object[]]@($profiles)) -Depth 10`nSet-Content -Path $profilesPath -Value $json -Encoding UTF8
$updated | ConvertTo-Json -Depth 6