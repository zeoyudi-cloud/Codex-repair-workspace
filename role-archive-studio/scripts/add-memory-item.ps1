param(
    [Parameter(Mandatory = $true)]
    [string]$Text,
    [string]$Source = 'manual',
    [switch]$Pinned,
    [string]$ProfileId,
    [string]$EventAt
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$memoriesPath = Join-Path $dataRoot 'memories.json'
$statePath = Join-Path $dataRoot 'state.json'

function Initialize-Store {
    if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }
    if (-not (Test-Path $memoriesPath)) { '[]' | Set-Content -Path $memoriesPath -Encoding UTF8 }
    if (-not (Test-Path $statePath)) { '{"activeProfileId":"","lastOpenedAt":"","updatedAt":""}' | Set-Content -Path $statePath -Encoding UTF8 }
}

function Read-JsonFile {
    param([string]$Path)
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $raw | ConvertFrom-Json
}

function Flatten-MemoryItems {
    param($Items)
    $result = @()
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        if ($item.PSObject.Properties.Name -contains 'value') {
            $result += Flatten-MemoryItems -Items $item.value
            continue
        }
        if ($item.PSObject.Properties.Name -contains 'id' -and $item.PSObject.Properties.Name -contains 'text') {
            $result += $item
        }
    }
    $result
}

Initialize-Store
$state = Read-JsonFile -Path $statePath
$resolvedProfileId = if ([string]::IsNullOrWhiteSpace($ProfileId)) { [string]$state.activeProfileId } else { $ProfileId }
if ([string]::IsNullOrWhiteSpace($resolvedProfileId)) { throw 'No active profile is set, and no -ProfileId was provided.' }

$memories = @(Flatten-MemoryItems -Items (Read-JsonFile -Path $memoriesPath))
$now = Get-Date
$entry = [PSCustomObject]@{
    id = [guid]::NewGuid().ToString('N')
    profileId = $resolvedProfileId
    text = $Text.Trim()
    source = $Source
    pinned = [bool]$Pinned
    eventAt = if ([string]::IsNullOrWhiteSpace($EventAt)) { $now.ToString('yyyy-MM-ddTHH:mm') } else { $EventAt }
    createdAt = $now.ToString('s')
    updatedAt = $now.ToString('s')
}
if ([string]::IsNullOrWhiteSpace($entry.text)) { throw 'Memory text is required.' }
(ConvertTo-Json -InputObject ([object[]]@($memories + $entry)) -Depth 10) | Set-Content -Path $memoriesPath -Encoding UTF8
$entry | ConvertTo-Json -Depth 6
