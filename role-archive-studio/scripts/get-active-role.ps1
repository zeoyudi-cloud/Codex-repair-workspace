param(
    [switch]$AsJson,
    [switch]$PromptOnly,
    [string]$SessionId
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$profilesPath = Join-Path $dataRoot 'profiles.json'
$memoriesPath = Join-Path $dataRoot 'memories.json'
$statePath = Join-Path $dataRoot 'state.json'
$sessionsPath = Join-Path $dataRoot 'sessions.json'

function Initialize-Store { if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }; if (-not (Test-Path $profilesPath)) { '[]' | Set-Content -Path $profilesPath -Encoding UTF8 }; if (-not (Test-Path $memoriesPath)) { '[]' | Set-Content -Path $memoriesPath -Encoding UTF8 }; if (-not (Test-Path $statePath)) { '{"activeProfileId":"","lastOpenedAt":"","updatedAt":""}' | Set-Content -Path $statePath -Encoding UTF8 }; if (-not (Test-Path $sessionsPath)) { '[]' | Set-Content -Path $sessionsPath -Encoding UTF8 } }
function Read-JsonFile { param([string]$Path) $raw = Get-Content -Raw -Path $Path -Encoding UTF8; if ([string]::IsNullOrWhiteSpace($raw)) { return $null }; return ($raw | ConvertFrom-Json) }
function Normalize-ObjectArray { param($Items) if ($null -eq $Items) { return @() }; if ($Items.PSObject.Properties.Name -contains 'value') { return @($Items.value) }; return @($Items) }
function Normalize-HashtableLike { param($Value) $result = @{}; if ($null -eq $Value) { return $result }; foreach ($prop in $Value.PSObject.Properties) { $result[$prop.Name] = [string]$prop.Value }; return $result }
function Normalize-Session {
    param($Session)
    if ($null -eq $Session) { return $null }
    [PSCustomObject]@{
        id = [string]$Session.id
        title = [string]$Session.title
        profileId = [string]$Session.profileId
        roleBoundAt = [string]$Session.roleBoundAt
        memoryCursors = Normalize-HashtableLike $Session.memoryCursors
        lastSummaryAt = [string]$Session.lastSummaryAt
        lastSummarySource = [string]$Session.lastSummarySource
        runtimeSummaries = Normalize-HashtableLike $Session.runtimeSummaries
        runtimeUpdatedAt = [string]$Session.runtimeUpdatedAt
        createdAt = [string]$Session.createdAt
        updatedAt = [string]$Session.updatedAt
        lastUsedAt = [string]$Session.lastUsedAt
    }
}
function Build-RuntimeSummary {
    param($Profile)
    if (-not $Profile) { return '' }
    $lines = @("Role: $($Profile.name)","Job: $($Profile.summary)","Tone: $($Profile.personality)","Voice: $($Profile.voice)","Focus: $($Profile.memoryFocus)")
    if (-not [string]::IsNullOrWhiteSpace([string]$Profile.notes)) { $lines += "Note: $($Profile.notes)" }
    return ($lines -join [Environment]::NewLine)
}
function Build-Prompt {
    param($Profile, [array]$MemoryEntries, [string]$RuntimeSummary)
    if (-not $Profile) { return '' }
    $memories = @(); if ($Profile.memories) { $memories += @($Profile.memories | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
    foreach ($entry in @($MemoryEntries)) { if ($entry -and -not [string]::IsNullOrWhiteSpace([string]$entry.text)) { $memories += [string]$entry.text } }
    $memories = @($memories | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $rules = @(); if ($Profile.rules) { $rules += @($Profile.rules | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
    $memoryFocus = if ([string]::IsNullOrWhiteSpace([string]$Profile.memoryFocus)) { 'Keep only stable long-term information.' } else { [string]$Profile.memoryFocus }
    $lines = @($RuntimeSummary,'',"Active role: $($Profile.name)","Role title: $($Profile.title)","Role summary: $($Profile.summary)","Personality: $($Profile.personality)","Voice style: $($Profile.voice)","Memory focus: $memoryFocus",'Remember these details:')
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
$sessions = @(Normalize-ObjectArray (Read-JsonFile -Path $sessionsPath) | ForEach-Object { Normalize-Session $_ })
$resolvedProfileId = [string]$state.activeProfileId
$session = $null
if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
    $session = $sessions | Where-Object { [string]$_.id -eq $SessionId } | Select-Object -First 1
    if (-not $session -or [string]::IsNullOrWhiteSpace([string]$session.profileId)) { throw 'No role bound to this session.' }
    $resolvedProfileId = [string]$session.profileId
}
if ([string]::IsNullOrWhiteSpace($resolvedProfileId)) { throw 'No active role is set.' }
$active = $profiles | Where-Object { $_.id -eq $resolvedProfileId } | Select-Object -First 1
if (-not $active) { throw 'Profile not found.' }
$activeMemories = @($memoryEntries | Where-Object { $_.profileId -eq $resolvedProfileId })
$runtimeSummary = if ($session -and $session.runtimeSummaries.ContainsKey([string]$resolvedProfileId) -and -not [string]::IsNullOrWhiteSpace([string]$session.runtimeSummaries[[string]$resolvedProfileId])) { [string]$session.runtimeSummaries[[string]$resolvedProfileId] } else { Build-RuntimeSummary -Profile $active }
$cursorAt = if ($session -and $session.memoryCursors.ContainsKey([string]$resolvedProfileId)) { [string]$session.memoryCursors[[string]$resolvedProfileId] } else { '' }
$prompt = Build-Prompt -Profile $active -MemoryEntries $activeMemories -RuntimeSummary $runtimeSummary
if ($PromptOnly) { Write-Output $prompt; exit 0 }
if ($AsJson) { [PSCustomObject]@{ sessionId = $SessionId; activeProfile = $active; runtimeSummary = $runtimeSummary; memoryCursorAt = $cursorAt; lastSummaryAt = if ($session) { [string]$session.lastSummaryAt } else { '' }; memoryEntries = $activeMemories; prompt = $prompt } | ConvertTo-Json -Depth 6; exit 0 }
Write-Output $prompt