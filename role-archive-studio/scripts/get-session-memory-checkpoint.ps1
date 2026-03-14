param(
    [Parameter(Mandatory = $true)]
    [string]$SessionId,
    [string]$ProfileId,
    [switch]$AsJson
)

$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$sessionsPath = Join-Path $dataRoot 'sessions.json'
function Initialize-Store { if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }; if (-not (Test-Path $sessionsPath)) { '[]' | Set-Content -Path $sessionsPath -Encoding UTF8 } }
function Read-JsonFile { param([string]$Path) $raw = Get-Content -Raw -Path $Path -Encoding UTF8; if ([string]::IsNullOrWhiteSpace($raw)) { return $null }; return ($raw | ConvertFrom-Json) }
function Normalize-ObjectArray { param($Items) if ($null -eq $Items) { return @() }; if ($Items -is [System.Array]) { return @($Items) }; if ($Items.PSObject.Properties.Name -contains 'value') { return @($Items.value) }; return @($Items) }
function Normalize-HashtableLike { param($Value) $result = @{}; if ($null -eq $Value) { return $result }; foreach ($prop in $Value.PSObject.Properties) { $result[$prop.Name] = [string]$prop.Value }; return $result }
Initialize-Store
$sessions = @(Normalize-ObjectArray (Read-JsonFile -Path $sessionsPath))
$session = $sessions | Where-Object { [string]$_.id -eq $SessionId } | Select-Object -First 1
if (-not $session) { throw 'Session not found.' }
$resolvedProfileId = if ([string]::IsNullOrWhiteSpace($ProfileId)) { [string]$session.profileId } else { $ProfileId }
$cursors = Normalize-HashtableLike $session.memoryCursors
$result = [PSCustomObject]@{ sessionId = $SessionId; profileId = $resolvedProfileId; memoryCursorAt = if ($cursors.ContainsKey([string]$resolvedProfileId)) { [string]$cursors[[string]$resolvedProfileId] } else { '' }; lastSummaryAt = [string]$session.lastSummaryAt; lastSummarySource = [string]$session.lastSummarySource }
if ($AsJson) { $result | ConvertTo-Json -Depth 6; exit 0 }
$result | Format-List | Out-String