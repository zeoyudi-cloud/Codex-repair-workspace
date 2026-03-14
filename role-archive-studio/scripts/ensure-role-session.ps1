param(
    [string]$SessionId,
    [string]$Title,
    [switch]$AsJson
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$sessionsPath = Join-Path $dataRoot 'sessions.json'

function Initialize-Store {
    if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }
    if (-not (Test-Path $sessionsPath)) { '[]' | Set-Content -Path $sessionsPath -Encoding UTF8 }
}
function Read-JsonFile { param([string]$Path) $raw = Get-Content -Raw -Path $Path -Encoding UTF8; if ([string]::IsNullOrWhiteSpace($raw)) { return $null }; return ($raw | ConvertFrom-Json) }
function Normalize-ObjectArray { param($Items) if ($null -eq $Items) { return @() }; if ($Items -is [System.Array]) { return @($Items) }; if ($Items.PSObject.Properties.Name -contains 'value') { return @($Items.value) }; return @($Items) }
function Normalize-HashtableLike {
    param($Value)
    $result = @{}
    if ($null -eq $Value) { return $result }
    foreach ($prop in $Value.PSObject.Properties) { $result[$prop.Name] = [string]$prop.Value }
    return $result
}
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

Initialize-Store
$sessions = @(Normalize-ObjectArray (Read-JsonFile -Path $sessionsPath) | ForEach-Object { Normalize-Session $_ })
$resolvedSessionId = if ([string]::IsNullOrWhiteSpace($SessionId)) { 'session-' + [guid]::NewGuid().ToString('N').Substring(0, 12) } else { $SessionId }
$now = (Get-Date).ToString('s')
$existing = $sessions | Where-Object { [string]$_.id -eq $resolvedSessionId } | Select-Object -First 1
if ($existing) {
    $updated = [PSCustomObject]@{
        id = [string]$existing.id
        title = if ([string]::IsNullOrWhiteSpace($Title)) { [string]$existing.title } else { $Title }
        profileId = [string]$existing.profileId
        roleBoundAt = [string]$existing.roleBoundAt
        memoryCursors = $existing.memoryCursors
        lastSummaryAt = [string]$existing.lastSummaryAt
        lastSummarySource = [string]$existing.lastSummarySource
        runtimeSummaries = $existing.runtimeSummaries
        runtimeUpdatedAt = [string]$existing.runtimeUpdatedAt
        createdAt = [string]$existing.createdAt
        updatedAt = $now
        lastUsedAt = $now
    }
    $sessions = @($sessions | Where-Object { [string]$_.id -ne $resolvedSessionId }) + $updated
    Save-Sessions -Sessions $sessions
    $result = $updated
} else {
    $created = [PSCustomObject]@{
        id = $resolvedSessionId
        title = if ([string]::IsNullOrWhiteSpace($Title)) { '' } else { $Title }
        profileId = ''
        roleBoundAt = ''
        memoryCursors = @{}
        lastSummaryAt = ''
        lastSummarySource = ''
        runtimeSummaries = @{}
        runtimeUpdatedAt = ''
        createdAt = $now
        updatedAt = $now
        lastUsedAt = $now
    }
    $sessions = @($sessions) + $created
    Save-Sessions -Sessions $sessions
    $result = $created
}
if ($AsJson) { $result | ConvertTo-Json -Depth 6; exit 0 }
Write-Output ("Session ready: {0}" -f $result.id)