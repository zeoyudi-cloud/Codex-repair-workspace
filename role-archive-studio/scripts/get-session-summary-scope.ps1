param(
    [Parameter(Mandatory = $true)]
    [string]$SessionId,
    [string]$ProfileId,
    [switch]$AsJson
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$profilesPath = Join-Path $dataRoot 'profiles.json'
$sessionsPath = Join-Path $dataRoot 'sessions.json'

function Initialize-Store {
    if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }
    if (-not (Test-Path $profilesPath)) { '[]' | Set-Content -Path $profilesPath -Encoding UTF8 }
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

Initialize-Store
$profiles = @(Normalize-ObjectArray (Read-JsonFile -Path $profilesPath))
$sessions = @(Normalize-ObjectArray (Read-JsonFile -Path $sessionsPath) | ForEach-Object { Normalize-Session $_ })
$session = $sessions | Where-Object { [string]$_.id -eq $SessionId } | Select-Object -First 1
if (-not $session) { throw 'Session not found.' }
$resolvedProfileId = if ([string]::IsNullOrWhiteSpace($ProfileId)) { [string]$session.profileId } else { $ProfileId }
if ([string]::IsNullOrWhiteSpace($resolvedProfileId)) { throw 'No role bound to this session.' }
$profile = $profiles | Where-Object { [string]$_.id -eq $resolvedProfileId } | Select-Object -First 1
if (-not $profile) { throw 'Profile not found.' }
$cursors = $session.memoryCursors
$cursor = if ($cursors.ContainsKey([string]$resolvedProfileId)) { [string]$cursors[[string]$resolvedProfileId] } else { '' }
$scope = [PSCustomObject]@{
    sessionId = $SessionId
    profileId = $resolvedProfileId
    roleName = [string]$profile.name
    memoryCursorAt = $cursor
    runtimeSummary = if ($session.runtimeSummaries.ContainsKey([string]$resolvedProfileId)) { [string]$session.runtimeSummaries[[string]$resolvedProfileId] } else { '' }
    instruction = if ([string]::IsNullOrWhiteSpace($cursor)) { 'Summarize only the new content from this chat for the currently bound role. Do not repeat old stored memories unless they were materially changed.' } else { "Summarize only the content from this chat that happened after $cursor for the currently bound role. Do not repeat memories that were already summarized before that point." }
}
if ($AsJson) { $scope | ConvertTo-Json -Depth 6; exit 0 }
$scope | Format-List | Out-String