param(
    [Parameter(Mandatory = $true)]
    [string]$SessionId,
    [string]$ProfileId,
    [string]$CursorAt,
    [string]$SummarySource = 'manual-summary',
    [switch]$AsJson
)

& "$PSScriptRoot\advance-session-memory-checkpoint.ps1" -SessionId $SessionId -ProfileId $ProfileId -CursorAt $CursorAt -SummarySource $SummarySource -AsJson:$AsJson