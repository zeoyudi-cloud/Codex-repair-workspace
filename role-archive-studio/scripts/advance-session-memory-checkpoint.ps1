param(
    [Parameter(Mandatory = $true)]
    [string]$SessionId,
    [string]$ProfileId,
    [string]$CursorAt,
    [string]$SummarySource = 'manual-summary',
    [switch]$AsJson
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$sessionsPath = Join-Path $dataRoot 'sessions.json'
function Initialize-Store { if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }; if (-not (Test-Path $sessionsPath)) { '[]' | Set-Content -Path $sessionsPath -Encoding UTF8 } }
function Read-JsonFile { param([string]$Path) $raw = Get-Content -Raw -Path $Path -Encoding UTF8; if ([string]::IsNullOrWhiteSpace($raw)) { return $null }; return ($raw | ConvertFrom-Json) }
function Normalize-ObjectArray { param($Items) if ($null -eq $Items) { return @() }; if ($Items -is [System.Array]) { return @($Items) }; if ($Items.PSObject.Properties.Name -contains 'value') { return @($Items.value) }; return @($Items) }
function Normalize-HashtableLike { param($Value) $result = @{}; if ($null -eq $Value) { return $result }; foreach ($prop in $Value.PSObject.Properties) { $result[$prop.Name] = [string]$prop.Value }; return $result }
function Save-Sessions { param([array]$Sessions) (ConvertTo-Json -InputObject ([object[]]@($Sessions)) -Depth 10) | Set-Content -Path $sessionsPath -Encoding UTF8 }
Initialize-Store
$sessions = @(Normalize-ObjectArray (Read-JsonFile -Path $sessionsPath))
$session = $sessions | Where-Object { [string]$_.id -eq $SessionId } | Select-Object -First 1
if (-not $session) { throw 'Session not found.' }
$resolvedProfileId = if ([string]::IsNullOrWhiteSpace($ProfileId)) { [string]$session.profileId } else { $ProfileId }
$now = (Get-Date).ToString('s')
$cursor = if ([string]::IsNullOrWhiteSpace($CursorAt)) { $now } else { $CursorAt }
$cursors = Normalize-HashtableLike $session.memoryCursors
$cursors[[string]$resolvedProfileId] = $cursor
$runtimeSummaries = Normalize-HashtableLike $session.runtimeSummaries
$updated = [PSCustomObject]@{ id=[string]$session.id; title=[string]$session.title; profileId=[string]$session.profileId; roleBoundAt=[string]$session.roleBoundAt; memoryCursors=$cursors; lastSummaryAt=$now; lastSummarySource=$SummarySource; runtimeSummaries=$runtimeSummaries; runtimeUpdatedAt=[string]$session.runtimeUpdatedAt; createdAt=[string]$session.createdAt; updatedAt=$now; lastUsedAt=$now }
$sessions = @($sessions | Where-Object { [string]$_.id -ne $SessionId }) + $updated
Save-Sessions -Sessions $sessions
if ($AsJson) { $updated | ConvertTo-Json -Depth 6; exit 0 }
Write-Output ("Advanced memory cursor for session/profile: {0} / {1}" -f $SessionId, $resolvedProfileId)