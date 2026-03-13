param(
    [int]$Port = 48678,
    [switch]$NoBrowser,
    [int]$RequestLimit = 0
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
$webRoot = Join-Path $skillRoot 'assets/web'
$dataRoot = Join-Path $HOME '.codex/role-archive-studio-data'
$profilesPath = Join-Path $dataRoot 'profiles.json'
$memoriesPath = Join-Path $dataRoot 'memories.json'
$settingsPath = Join-Path $dataRoot 'settings.json'
$statePath = Join-Path $dataRoot 'state.json'

function Get-DefaultSettings {
    [PSCustomObject]@{
        memoryMode = 'manual'
        sessionSummaryLimit = 3
        defaultMemoryFocus = '只记录稳定偏好、重要已确认事实和关键工作边界；不把角色卡设定、某次具体开发过程或临时测试细节写进长期记忆。'
        memoryFilterSummary = '优先保留稳定偏好、合作方式和关键已确认事实；不把角色卡设定、一次性开发过程和临时测试细节写入长期记忆。'
        updatedAt = ''
    }
}
function Initialize-Store {
    if (-not (Test-Path $dataRoot)) { New-Item -ItemType Directory -Path $dataRoot | Out-Null }
    if (-not (Test-Path $profilesPath)) { '[]' | Set-Content -Path $profilesPath -Encoding UTF8 }
    if (-not (Test-Path $memoriesPath)) { '[]' | Set-Content -Path $memoriesPath -Encoding UTF8 }
    if (-not (Test-Path $settingsPath)) { (Get-DefaultSettings | ConvertTo-Json -Depth 6) | Set-Content -Path $settingsPath -Encoding UTF8 }
    if (-not (Test-Path $statePath)) { '{"activeProfileId":"","lastOpenedAt":"","updatedAt":""}' | Set-Content -Path $statePath -Encoding UTF8 }
}
function Read-JsonFile { param([string]$Path) $raw = Get-Content -Raw -Path $Path -Encoding UTF8; if ([string]::IsNullOrWhiteSpace($raw)) { return $null }; $raw | ConvertFrom-Json }
function Normalize-ObjectArray { param($Items) if ($null -eq $Items) { return @() }; if ($Items -is [System.Array]) { return @($Items) }; if ($Items.PSObject.Properties.Name -contains 'value') { return @($Items.value) }; return @($Items) }
function Flatten-MemoryItems { param($Items) $result = @(); foreach ($item in @(Normalize-ObjectArray $Items)) { if ($null -eq $item) { continue }; if ($item.PSObject.Properties.Name -contains 'value') { $result += Flatten-MemoryItems -Items $item.value; continue }; if ($item.PSObject.Properties.Name -contains 'id' -and $item.PSObject.Properties.Name -contains 'text') { $result += $item } }; $result }
function Normalize-StringArray { param($Value) $items = @(); foreach ($entry in @($Value)) { if ($null -eq $entry) { continue }; $text = [string]$entry; if (-not [string]::IsNullOrWhiteSpace($text)) { $items += $text.Trim() } }; $items }
function Normalize-Profile { param($Profile) if ($null -eq $Profile) { return $null }; [PSCustomObject]@{ id=[string]$Profile.id; name=[string]$Profile.name; title=[string]$Profile.title; summary=[string]$Profile.summary; personality=[string]$Profile.personality; voice=[string]$Profile.voice; memories=@(Normalize-StringArray $Profile.memories); rules=@(Normalize-StringArray $Profile.rules); notes=[string]$Profile.notes; memoryFocus=[string]$Profile.memoryFocus; memoryFocusConfirmedAt=[string]$Profile.memoryFocusConfirmedAt; createdAt=[string]$Profile.createdAt; updatedAt=[string]$Profile.updatedAt } }
function Read-Profiles { @(Normalize-ObjectArray (Read-JsonFile -Path $profilesPath) | ForEach-Object { Normalize-Profile $_ }) }
function Save-Profiles { param([array]$Profiles) (ConvertTo-Json -InputObject ([object[]]@($Profiles)) -Depth 10) | Set-Content -Path $profilesPath -Encoding UTF8 }
function Read-Memories { @(Flatten-MemoryItems (Read-JsonFile -Path $memoriesPath)) }
function Save-Memories { param([array]$Memories) (ConvertTo-Json -InputObject ([object[]]@($Memories)) -Depth 10) | Set-Content -Path $memoriesPath -Encoding UTF8 }
function Read-Settings { $defaults = Get-DefaultSettings; $settings = Read-JsonFile -Path $settingsPath; if ($null -eq $settings) { return $defaults }; [PSCustomObject]@{ memoryMode = if ([string]::IsNullOrWhiteSpace([string]$settings.memoryMode)) { $defaults.memoryMode } else { [string]$settings.memoryMode }; sessionSummaryLimit = if ($settings.sessionSummaryLimit) { [int]$settings.sessionSummaryLimit } else { $defaults.sessionSummaryLimit }; defaultMemoryFocus = if ([string]::IsNullOrWhiteSpace([string]$settings.defaultMemoryFocus)) { $defaults.defaultMemoryFocus } else { [string]$settings.defaultMemoryFocus }; memoryFilterSummary = if ([string]::IsNullOrWhiteSpace([string]$settings.memoryFilterSummary)) { $defaults.memoryFilterSummary } else { [string]$settings.memoryFilterSummary }; updatedAt = [string]$settings.updatedAt } }
function Save-Settings { param($Settings) ($Settings | ConvertTo-Json -Depth 10) | Set-Content -Path $settingsPath -Encoding UTF8 }
function Read-State { $state = Read-JsonFile -Path $statePath; if ($null -eq $state) { [PSCustomObject]@{ activeProfileId=''; lastOpenedAt=''; updatedAt='' } } else { $state } }
function Save-State { param($State) ($State | ConvertTo-Json -Depth 10) | Set-Content -Path $statePath -Encoding UTF8 }
function Get-MemoriesForProfile { param([string]$ProfileId) if ([string]::IsNullOrWhiteSpace($ProfileId)) { return @() }; @(Read-Memories | Where-Object { $_.profileId -eq $ProfileId } | Sort-Object createdAt -Descending) }
function Build-Prompt { param($Profile, [array]$MemoryEntries) if (-not $Profile) { return '' }; $memories = @(); if ($Profile.memories) { $memories += @($Profile.memories | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }; foreach ($entry in @($MemoryEntries)) { if ($entry -and -not [string]::IsNullOrWhiteSpace([string]$entry.text)) { $memories += [string]$entry.text } }; $memories = @($memories | Select-Object -Unique); $rules = @(); if ($Profile.rules) { $rules += @($Profile.rules | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }; $memoryFocus = if ([string]::IsNullOrWhiteSpace([string]$Profile.memoryFocus)) { (Read-Settings).defaultMemoryFocus } else { [string]$Profile.memoryFocus }; $lines = @("Active role: $($Profile.name)","Role title: $($Profile.title)","Role summary: $($Profile.summary)","Personality: $($Profile.personality)","Voice style: $($Profile.voice)","Memory focus: $memoryFocus",'Remember these details:'); if ($memories.Count -eq 0) { $lines += '- none' } else { $lines += ($memories | ForEach-Object { "- $_" }) }; $lines += 'Collaboration rules:'; if ($rules.Count -eq 0) { $lines += '- none' } else { $lines += ($rules | ForEach-Object { "- $_" }) }; if (-not [string]::IsNullOrWhiteSpace($Profile.notes)) { $lines += "Notes: $($Profile.notes)" }; ($lines -join [Environment]::NewLine) }
function Read-BodyJson { param($Request) $encoding = [System.Text.Encoding]::UTF8; if ($Request.ContentEncoding -and $Request.ContentEncoding.WebName -and $Request.ContentEncoding.WebName -ne 'iso-8859-1') { $encoding = $Request.ContentEncoding }; $reader = New-Object System.IO.StreamReader($Request.InputStream, $encoding); try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }; if ([string]::IsNullOrWhiteSpace($body)) { return $null }; $body | ConvertFrom-Json }
function Send-Json { param($Response, $Payload, [int]$StatusCode = 200) $json = $Payload | ConvertTo-Json -Depth 10; $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $Response.StatusCode = $StatusCode; $Response.ContentType = 'application/json; charset=utf-8'; $Response.ContentLength64 = $buffer.Length; $Response.OutputStream.Write($buffer, 0, $buffer.Length); $Response.OutputStream.Close() }
function Send-Text { param($Response, [string]$Text, [string]$ContentType = 'text/plain; charset=utf-8', [int]$StatusCode = 200) $buffer = [System.Text.Encoding]::UTF8.GetBytes($Text); $Response.StatusCode = $StatusCode; $Response.ContentType = $ContentType; $Response.ContentLength64 = $buffer.Length; $Response.OutputStream.Write($buffer, 0, $buffer.Length); $Response.OutputStream.Close() }
function Send-File { param($Response, [string]$FilePath) if (-not (Test-Path $FilePath)) { Send-Text -Response $Response -Text 'Not Found' -StatusCode 404; return }; $extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant(); $contentType = switch ($extension) { '.html' { 'text/html; charset=utf-8' } '.css' { 'text/css; charset=utf-8' } '.js' { 'application/javascript; charset=utf-8' } '.json' { 'application/json; charset=utf-8' } default { 'application/octet-stream' } }; $bytes = [System.IO.File]::ReadAllBytes($FilePath); $Response.StatusCode = 200; $Response.ContentType = $contentType; $Response.ContentLength64 = $bytes.Length; $Response.OutputStream.Write($bytes, 0, $bytes.Length); $Response.OutputStream.Close() }
Initialize-Store
$state = Read-State
$state.lastOpenedAt = (Get-Date).ToString('s')
$state.updatedAt = (Get-Date).ToString('s')
Save-State -State $state
$listener = [System.Net.HttpListener]::new()
$prefix = "http://127.0.0.1:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
if (-not $NoBrowser) { Start-Process $prefix | Out-Null }
$handled = 0
try {
while ($listener.IsListening) {
if ($RequestLimit -gt 0 -and $handled -ge $RequestLimit) { break }
$context = $listener.GetContext(); $request = $context.Request; $response = $context.Response; $path = $request.Url.AbsolutePath; $method = $request.HttpMethod.ToUpperInvariant()
try {
if ($method -eq 'GET' -and $path -eq '/api/bootstrap') { $profiles = Read-Profiles; $state = Read-State; $active = $profiles | Where-Object { $_.id -eq $state.activeProfileId } | Select-Object -First 1; $activeMemories = Get-MemoriesForProfile -ProfileId $state.activeProfileId; Send-Json -Response $response -Payload @{ profiles = $profiles; memories = Read-Memories; settings = Read-Settings; state = $state; activeProfile = $active; activeMemories = $activeMemories; dataRoot = $dataRoot; skillRoot = $skillRoot; activePrompt = Build-Prompt -Profile $active -MemoryEntries $activeMemories } }
elseif ($method -eq 'POST' -and $path -eq '/api/profiles') { $body = Read-BodyJson -Request $request; $profiles = Read-Profiles; $now = (Get-Date).ToString('s'); $item = [PSCustomObject]@{ id = if ([string]::IsNullOrWhiteSpace($body.id)) { [guid]::NewGuid().ToString('N') } else { [string]$body.id }; name = [string]$body.name; title = [string]$body.title; summary = [string]$body.summary; personality = [string]$body.personality; voice = [string]$body.voice; memories = @(Normalize-StringArray $body.memories); rules = @(Normalize-StringArray $body.rules); notes = [string]$body.notes; memoryFocus = [string]$body.memoryFocus; memoryFocusConfirmedAt = [string]$body.memoryFocusConfirmedAt; createdAt = if ([string]::IsNullOrWhiteSpace($body.createdAt)) { $now } else { [string]$body.createdAt }; updatedAt = $now }; if ($profiles | Where-Object { $_.id -eq $item.id }) { $profiles = @($profiles | Where-Object { $_.id -ne $item.id }) + $item } else { $profiles += $item }; Save-Profiles -Profiles $profiles; Send-Json -Response $response -Payload $item -StatusCode 201 }
elseif ($method -eq 'PUT' -and $path -match '^/api/profiles/([^/]+)$') { $profileId = $Matches[1]; $body = Read-BodyJson -Request $request; $profiles = Read-Profiles; $existing = $profiles | Where-Object { $_.id -eq $profileId } | Select-Object -First 1; if (-not $existing) { Send-Json -Response $response -Payload @{ error = 'Profile not found.' } -StatusCode 404 } else { $updated = [PSCustomObject]@{ id = $existing.id; name = [string]$body.name; title = [string]$body.title; summary = [string]$body.summary; personality = [string]$body.personality; voice = [string]$body.voice; memories = @(Normalize-StringArray $body.memories); rules = @(Normalize-StringArray $body.rules); notes = [string]$body.notes; memoryFocus = [string]$body.memoryFocus; memoryFocusConfirmedAt = if ([string]::IsNullOrWhiteSpace([string]$body.memoryFocusConfirmedAt)) { [string]$existing.memoryFocusConfirmedAt } else { [string]$body.memoryFocusConfirmedAt }; createdAt = [string]$existing.createdAt; updatedAt = (Get-Date).ToString('s') }; $profiles = @($profiles | Where-Object { $_.id -ne $profileId }) + $updated; Save-Profiles -Profiles $profiles; Send-Json -Response $response -Payload $updated } }
elseif ($method -eq 'DELETE' -and $path -match '^/api/profiles/([^/]+)$') { $profileId = $Matches[1]; $profiles = @((Read-Profiles) | Where-Object { $_.id -ne $profileId }); Save-Profiles -Profiles $profiles; $state = Read-State; if ($state.activeProfileId -eq $profileId) { $state.activeProfileId = ''; $state.updatedAt = (Get-Date).ToString('s'); Save-State -State $state }; Send-Json -Response $response -Payload @{ ok = $true } }
elseif ($method -eq 'POST' -and $path -eq '/api/activate') { $body = Read-BodyJson -Request $request; $profiles = Read-Profiles; $existing = $profiles | Where-Object { $_.id -eq [string]$body.id } | Select-Object -First 1; if (-not $existing) { Send-Json -Response $response -Payload @{ error = 'Profile not found.' } -StatusCode 404 } else { $state = Read-State; $state.activeProfileId = [string]$body.id; $state.updatedAt = (Get-Date).ToString('s'); Save-State -State $state; Send-Json -Response $response -Payload @{ ok = $true; activeProfile = $existing; prompt = Build-Prompt -Profile $existing -MemoryEntries (Get-MemoriesForProfile -ProfileId $existing.id) } } }
elseif ($method -eq 'POST' -and $path -eq '/api/memories') { $body = Read-BodyJson -Request $request; $memories = Read-Memories; $now = Get-Date; $eventAt = if ([string]::IsNullOrWhiteSpace([string]$body.eventAt)) { $now.ToString('yyyy-MM-ddTHH:mm') } else { [string]$body.eventAt }; $entry = [PSCustomObject]@{ id = [guid]::NewGuid().ToString('N'); profileId = [string]$body.profileId; text = [string]$body.text; source = if ([string]::IsNullOrWhiteSpace([string]$body.source)) { 'manual' } else { [string]$body.source }; pinned = [bool]$body.pinned; eventAt = $eventAt; createdAt = $now.ToString('s'); updatedAt = $now.ToString('s') }; if ([string]::IsNullOrWhiteSpace($entry.text)) { Send-Json -Response $response -Payload @{ error = 'Memory text is required.' } -StatusCode 400 } else { $memories += $entry; Save-Memories -Memories $memories; Send-Json -Response $response -Payload $entry -StatusCode 201 } }
elseif ($method -eq 'DELETE' -and $path -match '^/api/memories/([^/]+)$') { $memoryId = $Matches[1]; $memories = @((Read-Memories) | Where-Object { $_.id -ne $memoryId }); Save-Memories -Memories $memories; Send-Json -Response $response -Payload @{ ok = $true } }
elseif ($method -eq 'PUT' -and $path -eq '/api/settings') { $body = Read-BodyJson -Request $request; $mode = [string]$body.memoryMode; if ($mode -notin @('manual', 'confirm', 'session-summary')) { Send-Json -Response $response -Payload @{ error = 'Unsupported memory mode.' } -StatusCode 400 } else { $existing = Read-Settings; $settings = [PSCustomObject]@{ memoryMode = $mode; sessionSummaryLimit = if ($body.sessionSummaryLimit) { [int]$body.sessionSummaryLimit } else { 3 }; defaultMemoryFocus = [string]$existing.defaultMemoryFocus; memoryFilterSummary = [string]$existing.memoryFilterSummary; updatedAt = (Get-Date).ToString('s') }; Save-Settings -Settings $settings; Send-Json -Response $response -Payload $settings } }
else { $relativePath = if ($path -eq '/') { 'index.html' } else { $path.TrimStart('/') }; $relativePath = $relativePath -replace '/', '\'; $fullPath = [System.IO.Path]::GetFullPath((Join-Path $webRoot $relativePath)); $allowedRoot = [System.IO.Path]::GetFullPath($webRoot); if (-not $fullPath.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) { Send-Text -Response $response -Text 'Forbidden' -StatusCode 403 } else { Send-File -Response $response -FilePath $fullPath } }
} catch { Send-Json -Response $response -Payload @{ error = $_.Exception.Message; path = $path } -StatusCode 500 }
$handled += 1
}
} finally { if ($listener.IsListening) { $listener.Stop() }; $listener.Close() }
