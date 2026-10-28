# Practice device. Sends nothing.
[CmdletBinding(PositionalBinding = $false)]
param([switch]$Controleer)
# Pretend address, house number 123.
$PracticeIp = '192.0.2.123'
# Practice result. See Help.
$PracticeCode = 12
$PracticeName = 'Practice device'
$Words = @{ 0 = 'sent'; 1 = 'failed'; 10 = 'already-on'; 11 = 'not-found'; 12 = 'test' }
$Code = if ($Words.ContainsKey([int]$PracticeCode)) { [int]$PracticeCode } else { 12 }
$Result = $Words[$Code]
$LogFile = if ($PSScriptRoot) { Join-Path $PSScriptRoot '..\Development\logboek.txt' } else { $null }
function Write-LogLine([string]$Word) {
  if ($Controleer -or $env:CREATIVE_CONNECTION -eq 'app' -or -not $LogFile) { return }
  try {
    if (-not (Test-Path -LiteralPath (Split-Path -Path $LogFile -Parent))) { return }
    $line = (@((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Word, $PracticeName, $PSCommandPath, 'direct') -join "`t") + "`r`n"
    $bytes = (New-Object Text.UTF8Encoding $false).GetBytes($line)
    try { $stream = New-Object IO.FileStream($LogFile, [IO.FileMode]::Append, [Security.AccessControl.FileSystemRights]::AppendData, [IO.FileShare]::ReadWrite, 4096, [IO.FileOptions]::None) }
    catch { $stream = New-Object IO.FileStream($LogFile, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite) }
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
  } catch { }
}
if ($Controleer) {
  "Check: $PracticeName would end with exit code $Code ($Result). Nothing was turned on and nothing was sent."
  exit 0
}
"$PracticeName ran. Result: $Result. Nothing was turned on and nothing was sent."
Write-LogLine $Result
exit $Code
