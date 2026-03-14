param(
    [switch]$AsJson,
    [switch]$IncludeMemoryCount,
    [string]$SessionId
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$profilesPath = Join-Path $dataRoot 'profiles.json'
$memoriesPath = Join-Path $dataRoot 'memories.json'
$statePath = Join-Path $dataRoot 'state.json'
$sessionsPath = Join-Path $dataRoot 'sessions.json'

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

function Normalize-ObjectArray {
    param($Items)
    if ($null -eq $Items) { return @() }
    if ($Items -is [System.Array]) { return @($Items) }
    if ($Items.PSObject.Properties.Name -contains 'value') { return @($Items.value) }
    return @($Items)
}

$profiles = @(Normalize-ObjectArray (Read-JsonFile -Path $profilesPath))
$memories = @(Normalize-ObjectArray (Read-JsonFile -Path $memoriesPath))
$state = Read-JsonFile -Path $statePath
$sessions = @(Normalize-ObjectArray (Read-JsonFile -Path $sessionsPath))
$session = $null
$activeProfileId = if ($state) { [string]$state.activeProfileId } else { '' }
if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
    $session = $sessions | Where-Object { [string]$_.id -eq $SessionId } | Select-Object -First 1
    $activeProfileId = if ($session) { [string]$session.profileId } else { '' }
}
$items = @()
$index = 1
foreach ($profile in @($profiles | Sort-Object updatedAt -Descending)) {
    $items += [PSCustomObject]@{
        index = $index
        id = [string]$profile.id
        name = [string]$profile.name
        title = [string]$profile.title
        summary = [string]$profile.summary
        personality = [string]$profile.personality
        isActive = ([string]$profile.id -eq $activeProfileId)
        memoryCount = @($memories | Where-Object { $_.profileId -eq $profile.id }).Count
    }
    $index += 1
}

if ($AsJson) {
    [PSCustomObject]@{ sessionId = $SessionId; hasSession = ($null -ne $session); activeProfileId = $activeProfileId; profiles = $items } | ConvertTo-Json -Depth 6
    exit 0
}

if ($items.Count -eq 0) {
    Write-Output 'No roles found. Send new-role or role-workshop to open the UI.'
    exit 0
}

foreach ($item in $items) {
    $activeTag = if ($item.isActive) { '(CURRENT)' } else { '(AVAILABLE)' }
    $memoryPart = if ($IncludeMemoryCount) { " | memories: $($item.memoryCount)" } else { '' }
    Write-Output ("{0}. {1} {2} | personality: {3} | summary: {4}{5}" -f $item.index, $activeTag, $item.name, $item.personality, $item.summary, $memoryPart)
}
Write-Output ''
Write-Output 'Reply with role name, index, or id to switch. Send new-role or role-workshop to open the UI.'