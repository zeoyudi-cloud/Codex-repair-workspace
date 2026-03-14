param(
    [string]$Id,
    [string]$Name,
    [int]$Index = 0,
    [string]$SessionId,
    [switch]$AsJson,
    [switch]$PromptOnly
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$profilesPath = Join-Path $dataRoot 'profiles.json'
$memoriesPath = Join-Path $dataRoot 'memories.json'
$statePath = Join-Path $dataRoot 'state.json'
$sessionsPath = Join-Path $dataRoot 'sessions.json'

function Initialize-Store {
    if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }
    if (-not (Test-Path $profilesPath)) { '[]' | Set-Content -Path $profilesPath -Encoding UTF8 }
    if (-not (Test-Path $memoriesPath)) { '[]' | Set-Content -Path $memoriesPath -Encoding UTF8 }
    if (-not (Test-Path $statePath)) { '{"activeProfileId":"","lastOpenedAt":"","updatedAt":""}' | Set-Content -Path $statePath -Encoding UTF8 }
    if (-not (Test-Path $sessionsPath)) { '[]' | Set-Content -Path $sessionsPath -Encoding UTF8 }
}
function Read-JsonFile { param([string]$Path) $raw = Get-Content -Raw -Path $Path -Encoding UTF8; if ([string]::IsNullOrWhiteSpace($raw)) { return $null }; return ($raw | ConvertFrom-Json) }
function Normalize-ObjectArray { param($Items) if ($null -eq $Items) { return @() }; if ($Items -is [System.Array]) { return @($Items) }; if ($Items.PSObject.Properties.Name -contains 'value') { return @($Items.value) }; return @($Items) }
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
function Save-Sessions { param([array]$Sessions) (ConvertTo-Json -InputObject ([object[]]@($Sessions)) -Depth 10) | Set-Content -Path $sessionsPath -Encoding UTF8 }
function Build-RuntimeSummary {
    param($Profile)
    if (-not $Profile) { return '' }
    $lines = @(
        "Role identity: $($Profile.name)",
        "Stay in this role's tone and priorities for the current chat.",
        "Primary job: $($Profile.summary)",
        "Personality cue: $($Profile.personality)",
        "Voice cue: $($Profile.voice)",
        "Memory focus: $($Profile.memoryFocus)"
    )
    if (-not [string]::IsNullOrWhiteSpace([string]$Profile.notes)) { $lines += "Note: $($Profile.notes)" }
    return ($lines -join [Environment]::NewLine)
}
function Build-Prompt {
    param($Profile, [array]$MemoryEntries, [string]$RuntimeSummary)
    if (-not $Profile) { return '' }
    $memories = @()
    if ($Profile.memories) { $memories += @($Profile.memories | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
    foreach ($entry in @($MemoryEntries)) { if ($entry -and -not [string]::IsNullOrWhiteSpace([string]$entry.text)) { $memories += [string]$entry.text } }
    $memories = @($memories | Select-Object -Unique)
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
$profiles = @(Normalize-ObjectArray (Read-JsonFile -Path $profilesPath) | Sort-Object updatedAt -Descending)
$memories = @(Normalize-ObjectArray (Read-JsonFile -Path $memoriesPath))
if ($profiles.Count -eq 0) { throw 'No role profiles found.' }
$match = $null
if (-not [string]::IsNullOrWhiteSpace($Id)) { $match = $profiles | Where-Object { [string]$_.id -eq $Id } | Select-Object -First 1 }
elseif ($Index -gt 0) { $match = $profiles | Select-Object -Index ($Index - 1) }
elseif (-not [string]::IsNullOrWhiteSpace($Name)) {
    $exact = @($profiles | Where-Object { [string]$_.name -eq $Name })
    if ($exact.Count -eq 1) { $match = $exact[0] } else {
        $like = @($profiles | Where-Object { [string]$_.name -like "*$Name*" })
        if ($like.Count -eq 1) { $match = $like[0] }
        elseif ($like.Count -gt 1) { throw 'Multiple roles matched the provided name. Please use -Id or an exact role name.' }
    }
}
if (-not $match) { throw 'Role not found.' }
$now = (Get-Date).ToString('s')
$runtimeSummary = Build-RuntimeSummary -Profile $match
if ([string]::IsNullOrWhiteSpace($SessionId)) {
    $state = Read-JsonFile -Path $statePath
    if ($null -eq $state) { $state = [PSCustomObject]@{ activeProfileId=''; lastOpenedAt=''; updatedAt='' } }
    $state.activeProfileId = [string]$match.id
    $state.updatedAt = $now
    $state.lastOpenedAt = $now
    ($state | ConvertTo-Json -Depth 6) | Set-Content -Path $statePath -Encoding UTF8
} else {
    $sessions = @(Normalize-ObjectArray (Read-JsonFile -Path $sessionsPath) | ForEach-Object { Normalize-Session $_ })
    $existing = $sessions | Where-Object { [string]$_.id -eq $SessionId } | Select-Object -First 1
    if ($existing) {
        $cursors = $existing.memoryCursors
        $summaries = $existing.runtimeSummaries
        $summaries[[string]$match.id] = $runtimeSummary
        $updated = [PSCustomObject]@{
            id = [string]$existing.id
            title = [string]$existing.title
            profileId = [string]$match.id
            roleBoundAt = $now
            memoryCursors = $cursors
            lastSummaryAt = [string]$existing.lastSummaryAt
            lastSummarySource = [string]$existing.lastSummarySource
            runtimeSummaries = $summaries
            runtimeUpdatedAt = $now
            createdAt = [string]$existing.createdAt
            updatedAt = $now
            lastUsedAt = $now
        }
        $sessions = @($sessions | Where-Object { [string]$_.id -ne $SessionId }) + $updated
    } else {
        $updated = [PSCustomObject]@{
            id = $SessionId
            title = ''
            profileId = [string]$match.id
            roleBoundAt = $now
            memoryCursors = @{}
            lastSummaryAt = ''
            lastSummarySource = ''
            runtimeSummaries = @{ ([string]$match.id) = $runtimeSummary }
            runtimeUpdatedAt = $now
            createdAt = $now
            updatedAt = $now
            lastUsedAt = $now
        }
        $sessions = @($sessions) + $updated
    }
    Save-Sessions -Sessions $sessions
}
$activeMemories = @($memories | Where-Object { $_.profileId -eq $match.id })
$prompt = Build-Prompt -Profile $match -MemoryEntries $activeMemories -RuntimeSummary $runtimeSummary
if ($PromptOnly) { Write-Output $prompt; exit 0 }
if ($AsJson) { [PSCustomObject]@{ sessionId = $SessionId; activeProfile = $match; runtimeSummary = $runtimeSummary; memoryEntries = $activeMemories; prompt = $prompt } | ConvertTo-Json -Depth 6; exit 0 }
Write-Output ("Active role set: {0}" -f $match.name)