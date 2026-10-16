# Shared helpers for tools\setup.ps1 and tools\godot.ps1. Dot-source it; don't run it.

$HtzRoot = Split-Path -Parent $PSScriptRoot
$HtzTools = Join-Path $HtzRoot '.tools' # hidden from Godot's importer by the leading dot; gitignored

$HtzVersions = @{}
foreach ($line in Get-Content (Join-Path $PSScriptRoot 'versions.env')) {
	if ($line -match '^\s*([A-Z_]+)=(.*)$') { $HtzVersions[$Matches[1]] = $Matches[2].Trim() }
}

# The *_console.exe next to a Godot exe prints to the terminal; fall back to the exe itself.
function Get-GodotConsole([string]$exe) {
	$console = $exe -replace '(_console)?\.exe$', '_console.exe'
	if (Test-Path $console) { return $console }
	return $exe
}

function Get-GodotVersion([string]$exe) {
	try {
		$out = & (Get-GodotConsole $exe) --headless --version 2>$null | Out-String
		if ($out -match '(?m)^(\d+)\.(\d+)(\.\d+)?') { return $Matches[0] }
	}
	catch { }
	return $null
}

function Test-GodotVersion([string]$version) {
	if (-not $version) { return $false }
	$have = $version.Split('.')
	$need = $HtzVersions.GODOT_MIN.Split('.')
	if ([int]$have[0] -ne [int]$need[0]) { return [int]$have[0] -gt [int]$need[0] }
	return [int]$have[1] -ge [int]$need[1]
}

function Get-GodotCandidates {
	if ($env:GODOT) { $env:GODOT }
	$recorded = Join-Path $HtzTools 'godot-path'
	if (Test-Path $recorded) { (Get-Content $recorded -Raw).Trim() }
	Get-ChildItem -Path $HtzTools -Filter 'Godot_v*.exe' -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -notmatch '_console\.exe$' } | ForEach-Object { $_.FullName }
	foreach ($name in 'godot', 'godot4') {
		Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object { $_.Source }
	}
	$globs = @(
		"$env:LOCALAPPDATA\Microsoft\WinGet\Links\godot*.exe",
		"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v*.exe",
		"$env:USERPROFILE\scoop\apps\godot\current\*.exe",
		"$env:ChocolateyInstall\lib\godot\tools\*.exe",
		"$env:ProgramFiles\Godot*\*.exe"
	)
	foreach ($glob in $globs) {
		Get-ChildItem -Path $glob -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -notmatch '_console\.exe$' } | ForEach-Object { $_.FullName }
	}
}

# Returns @{ Path; Console; Version } for the first Godot >= GODOT_MIN, or $null.
function Find-Godot([switch]$Verbose) {
	foreach ($exe in Get-GodotCandidates) {
		if (-not $exe -or -not (Test-Path $exe -PathType Leaf)) { continue }
		$version = Get-GodotVersion $exe
		if (Test-GodotVersion $version) {
			return @{ Path = $exe; Console = (Get-GodotConsole $exe); Version = $version }
		}
		if ($Verbose) { Write-Host "  skipping $exe (version $(if ($version) { $version } else { 'unknown' }), need $($HtzVersions.GODOT_MIN)+)" }
	}
	return $null
}
