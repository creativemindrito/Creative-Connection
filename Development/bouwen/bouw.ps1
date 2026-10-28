# Builds and checks the exes.
param(
  [string]$Root = '',
  [switch]$Starter,
  [string]$SetupOut = '',
  [switch]$Check,
  [string]$Setup = ''
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression

if (-not $Root) { $Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
if (-not $Starter -and -not $SetupOut) { $Check = $true }
$src = Join-Path $Root 'Development\bouwen'
$starterName = 'Creative Connection.exe'
$setupName = 'Creative Connection Setup.exe'
$fixedTime = New-Object DateTimeOffset 2026, 1, 1, 0, 0, 0, ([TimeSpan]::Zero)

function Stop-Build([string]$text) { Write-Output "STOP: $text"; exit 2 }

function Get-Compiler {
  foreach ($dir in 'Framework64', 'Framework') {
    $csc = Join-Path $env:WINDIR "Microsoft.NET\$dir\v4.0.30319\csc.exe"
    if (Test-Path -LiteralPath $csc) { return $csc }
  }
  Stop-Build 'the C# compiler of .NET Framework 4 was not found.'
}

function Get-Offset([byte[]]$bytes, [int]$sections, [int]$count, [uint32]$rva) {
  for ($i = 0; $i -lt $count; $i++) {
    $at = $sections + 40 * $i
    $va = [BitConverter]::ToUInt32($bytes, $at + 12)
    $size = [Math]::Max([BitConverter]::ToUInt32($bytes, $at + 8), [BitConverter]::ToUInt32($bytes, $at + 16))
    if ($rva -ge $va -and $rva -lt $va + $size) { return [int]([BitConverter]::ToUInt32($bytes, $at + 20) + $rva - $va) }
  }
  throw 'address outside the file'
}

# Removes build time, random ID.
function Set-Stable([string]$file) {
  $bytes = [IO.File]::ReadAllBytes($file)
  $pe = [BitConverter]::ToInt32($bytes, 0x3C)
  $count = [BitConverter]::ToUInt16($bytes, $pe + 6)
  $optional = $pe + 24
  $sections = $optional + [BitConverter]::ToUInt16($bytes, $pe + 20)
  $dirs = if ([BitConverter]::ToUInt16($bytes, $optional) -eq 0x20B) { $optional + 112 } else { $optional + 96 }
  [Array]::Clear($bytes, $pe + 8, 4)
  $cli = Get-Offset $bytes $sections $count ([BitConverter]::ToUInt32($bytes, $dirs + 14 * 8))
  $meta = Get-Offset $bytes $sections $count ([BitConverter]::ToUInt32($bytes, $cli + 8))
  if ([BitConverter]::ToUInt32($bytes, $meta) -ne 0x424A5342) { throw 'no .NET metadata found' }
  $at = $meta + 16 + [BitConverter]::ToInt32($bytes, $meta + 12)
  $streams = [BitConverter]::ToUInt16($bytes, $at + 2)
  $at += 4
  $guidAt = -1; $guidSize = 0
  for ($s = 0; $s -lt $streams; $s++) {
    $offset = [BitConverter]::ToInt32($bytes, $at); $size = [BitConverter]::ToInt32($bytes, $at + 4)
    $end = [Array]::IndexOf($bytes, [byte]0, $at + 8)
    $name = [Text.Encoding]::ASCII.GetString($bytes, $at + 8, $end - $at - 8)
    if ($name -eq '#GUID') { $guidAt = $meta + $offset; $guidSize = $size }
    $at = $end + 1
    while (($at - $meta) % 4) { $at++ }
  }
  if ($guidAt -lt 0) { throw 'no #GUID heap found' }
  [Array]::Clear($bytes, $guidAt, $guidSize)
  $sha = [Security.Cryptography.SHA256]::Create()
  $seed = $sha.ComputeHash($bytes)
  for ($g = 0; $g -lt $guidSize; $g += 16) {
    $part = $sha.ComputeHash([byte[]]($seed + [BitConverter]::GetBytes($g)))
    [Array]::Copy($part, 0, $bytes, $guidAt + $g, [Math]::Min(16, $guidSize - $g))
  }
  $sha.Dispose()
  [IO.File]::WriteAllBytes($file, $bytes)
}

function Invoke-Compiler([string]$work, [string[]]$arguments) {
  $rsp = Join-Path $work 'build.rsp'
  [IO.File]::WriteAllLines($rsp, [string[]]$arguments, (New-Object Text.UTF8Encoding $false))
  $said = & (Get-Compiler) /nologo /noconfig "@$rsp" 2>&1
  if ($LASTEXITCODE -ne 0) { Stop-Build ("the compiler failed:`n" + ($said -join "`n")) }
}

function Q([string]$text) { '"' + $text + '"' }

function New-Starter([string]$work) {
  $out = Join-Path $work $starterName
  Invoke-Compiler $work @(
    '/target:winexe', '/platform:anycpu', '/optimize+', '/debug-',
    '/r:System.dll', '/r:System.Windows.Forms.dll',
    (Q ('/win32icon:' + (Join-Path $Root 'Development\iconen\logo.ico'))),
    (Q ('/out:' + $out)),
    (Q (Join-Path $src 'starter.cs'))
  )
  Set-Stable $out
  return $out
}

# Files that never go in.
function Test-Skip([string]$rel) {
  if ($rel -match '^\.git(\\|$)' -or $rel -in '.gitignore', '.gitattributes') { return $true }
  if ($rel -in 'Development\logboek.txt', 'Development\namen.json', 'Development\namen.kapot.json', 'Development\namen.json.tmp') { return $true }
  if ($rel -like 'Development\archief\*') { return $true }
  if ($rel -like 'Turn on\*' -and $rel -ne 'Turn on\README.txt') { return $true }
  return $rel -like '*.exe' -and $rel -ne $starterName
}

function Get-PayloadFiles {
  $all = Get-ChildItem -LiteralPath $Root -Recurse -File -Force
  $list = foreach ($f in $all) {
    $rel = $f.FullName.Substring($Root.Length + 1)
    if (-not (Test-Skip $rel)) { $rel }
  }
  [string[]]$sorted = @($list)
  [Array]::Sort($sorted, [StringComparer]::Ordinal)
  return $sorted
}

function New-Payload([string]$zipFile) {
  $files = Get-PayloadFiles
  if (-not ($files -contains $starterName)) { Stop-Build "$starterName is missing in $Root. Build it first with -Starter." }
  $stream = [IO.File]::Open($zipFile, 'CreateNew')
  $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)
  foreach ($rel in $files) {
    $entry = $zip.CreateEntry($rel.Replace('\', '/'), [IO.Compression.CompressionLevel]::NoCompression)
    $entry.LastWriteTime = $fixedTime
    $to = $entry.Open()
    $data = [IO.File]::ReadAllBytes((Join-Path $Root $rel))
    $to.Write($data, 0, $data.Length)
    $to.Dispose()
  }
  $zip.Dispose(); $stream.Dispose()
  return $files.Count
}

function New-Setup([string]$work) {
  $zipFile = Join-Path $work 'payload.zip'
  $count = New-Payload $zipFile
  $out = Join-Path $work $setupName
  Invoke-Compiler $work @(
    '/target:winexe', '/platform:anycpu', '/optimize+', '/debug-',
    '/r:System.dll', '/r:System.Drawing.dll', '/r:System.Windows.Forms.dll', '/r:System.IO.Compression.dll',
    (Q ('/win32icon:' + (Join-Path $Root 'Development\iconen\logo.ico'))),
    (Q ('/win32manifest:' + (Join-Path $src 'setup.manifest'))),
    (Q ('/resource:' + $zipFile + ',payload.zip')),
    (Q ('/resource:' + (Join-Path $Root 'Development\iconen\logo.png') + ',logo.png')),
    (Q ('/resource:' + (Join-Path $Root 'Development\iconen\logo.ico') + ',logo.ico')),
    (Q ('/out:' + $out)),
    (Q (Join-Path $src 'installatie.cs'))
  )
  Set-Stable $out
  return @{ File = $out; Count = $count }
}

function Get-Hash([string]$file) { (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() }

function Compare-Payload([string]$setupFile) {
  $assembly = [Reflection.Assembly]::ReflectionOnlyLoad([IO.File]::ReadAllBytes($setupFile))
  $stream = $assembly.GetManifestResourceStream('payload.zip')
  if (-not $stream) { return @('the setup has no payload') }
  $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Read)
  $inside = @{}
  foreach ($entry in $zip.Entries) {
    $read = $entry.Open(); $copy = New-Object IO.MemoryStream; $read.CopyTo($copy); $read.Dispose()
    $sha = [Security.Cryptography.SHA256]::Create()
    $inside[$entry.FullName.Replace('/', '\')] = [BitConverter]::ToString($sha.ComputeHash($copy.ToArray())).Replace('-', '').ToLowerInvariant()
    $sha.Dispose()
  }
  $zip.Dispose()
  $folder = @{}
  foreach ($rel in Get-PayloadFiles) { $folder[$rel] = Get-Hash (Join-Path $Root $rel) }
  $problems = foreach ($key in @($inside.Keys + $folder.Keys | Sort-Object -Unique)) {
    if (-not $folder.ContainsKey($key)) { "only in the setup: $key" }
    elseif (-not $inside.ContainsKey($key)) { "only in this folder: $key" }
    elseif ($inside[$key] -ne $folder[$key]) { "different: $key" }
  }
  return @($problems)
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('cc-bouw-' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $work)
try {
  if (-not (Test-Path -LiteralPath (Join-Path $Root 'Creative Connection.ps1'))) { Stop-Build "no Creative Connection.ps1 in $Root" }
  if ($Starter) {
    $made = New-Starter $work
    Copy-Item -LiteralPath $made -Destination (Join-Path $Root $starterName) -Force
    Write-Output ("Built: $starterName  sha256 " + (Get-Hash (Join-Path $Root $starterName)))
  }
  if ($SetupOut) {
    $SetupOut = [IO.Path]::GetFullPath($SetupOut)
    if ($SetupOut.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { Stop-Build 'put the setup outside the app folder.' }
    $made = New-Setup $work
    Copy-Item -LiteralPath $made.File -Destination $SetupOut -Force
    Write-Output ("Built: $(Split-Path $SetupOut -Leaf)  $($made.Count) files  sha256 " + (Get-Hash $SetupOut))
  }
  if ($Check) {
    $bad = 0
    $have = Join-Path $Root $starterName
    if (-not (Test-Path -LiteralPath $have)) { Write-Output "MISSING  $starterName"; $bad++ }
    else {
      $again = Get-Hash (New-Starter $work)
      if ($again -eq (Get-Hash $have)) { Write-Output "SAME     $starterName is built from Development\bouwen\starter.cs  sha256 $again" }
      else { Write-Output "DIFFERENT  $starterName does not match a fresh build of starter.cs"; $bad++ }
    }
    if ($Setup) {
      $Setup = [IO.Path]::GetFullPath($Setup)
      $problems = Compare-Payload $Setup
      if ($problems.Count -eq 0) { Write-Output "SAME     every file inside the setup equals the file in this folder" }
      else { $problems | ForEach-Object { Write-Output "DIFFERENT  $_" }; $bad++ }
      $sub = Join-Path $work 'setup'
      [void](New-Item -ItemType Directory -Path $sub)
      $again = Get-Hash (New-Setup $sub).File
      if ($again -eq (Get-Hash $Setup)) { Write-Output "SAME     $(Split-Path $Setup -Leaf) is built from installatie.cs and this folder  sha256 $again" }
      else { Write-Output "DIFFERENT  the setup does not match a fresh build, byte for byte"; $bad++ }
    }
    if ($bad) { Write-Output "RESULT: DIFFERENT ($bad)"; exit 1 }
    Write-Output 'RESULT: SAME'
  }
} finally {
  if ($work.StartsWith([IO.Path]::GetTempPath()) -and $work -like '*cc-bouw-*') { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
exit 0
