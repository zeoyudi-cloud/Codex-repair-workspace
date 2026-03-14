param(
    [Parameter(Mandatory = $true)]
    [string]$Text,
    [string]$Source = 'manual',
    [switch]$Pinned,
    [string]$ProfileId,
    [string]$EventAt,
    [string]$SessionId
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$memoriesPath = Join-Path $dataRoot 'memories.json'
$statePath = Join-Path $dataRoot 'state.json'
$sessionsPath = Join-Path $dataRoot 'sessions.json'

function Initialize-Store {
    if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }
    if (-not (Test-Path $memoriesPath)) { '[]' | Set-Content -Path $memoriesPath -Encoding UTF8 }
    if (-not (Test-Path $statePath)) { '{"activeProfileId":"","lastOpenedAt":"","updatedAt":""}' | Set-Content -Path $statePath -Encoding UTF8 }
    if (-not (Test-Path $sessionsPath)) { '[]' | Set-Content -Path $sessionsPath -Encoding UTF8 }
}

function Read-JsonFile {
    param([string]$Path)
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
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

function Normalize-ObjectArray {
    param($Items)
    if ($null -eq $Items) { return @() }
    if ($Items -is [System.Array]) { return @($Items) }
    if ($Items.PSObject.Properties.Name -contains 'value') { return @($Items.value) }
    return @($Items)
}

Initialize-Store
$state = Read-JsonFile -Path $statePath
$sessions = @(Normalize-ObjectArray (Read-JsonFile -Path $sessionsPath))
$resolvedProfileId = if (-not [string]::IsNullOrWhiteSpace($ProfileId)) { $ProfileId } elseif (-not [string]::IsNullOrWhiteSpace($SessionId)) { [string](($sessions | Where-Object { [string]$_.id -eq $SessionId } | Select-Object -First 1).profileId) } else { [string]$state.activeProfileId }
if ([string]::IsNullOrWhiteSpace($resolvedProfileId)) { throw 'No active profile is set for this scope.' }
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