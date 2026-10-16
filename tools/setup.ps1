# One-step setup for Windows: makes sure Godot 4.7+ is available, then installs the GodotSteam
# plugin and imports the project. Run tools\setup.cmd (it bypasses the script execution policy).
#
#   tools\setup.cmd [-Manager NAME] [-Yes] [-Force]
#   -Manager  how to get Godot if it isn't already installed:
#             auto (default: winget, then scoop, then choco, then download), winget, scoop, choco,
#             download (official build into .tools\, no admin needed), or none
#   -Yes      don't ask before running the package manager
#   -Force    reinstall GodotSteam and ignore any Godot that's already installed
[CmdletBinding()]
param(
	[ValidateSet('auto', 'winget', 'scoop', 'choco', 'download', 'none')]
	[string]$Manager = 'auto',
	[switch]$Yes,
	[switch]$Force
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # Invoke-WebRequest is very slow with the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

. (Join-Path $PSScriptRoot 'lib.ps1')

function Say([string]$m) { Write-Host "==> $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "warning: $m" -ForegroundColor Yellow }

function Confirm-Step([string]$question) {
	if ($Yes) { return $true }
	if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) { return $false }
	$reply = Read-Host "$question [Y/n]"
	return -not ($reply -match '^[nN]')
}

function Save-GodotPath([string]$path) {
	New-Item -ItemType Directory -Force -Path $HtzTools | Out-Null
	Set-Content -Path (Join-Path $HtzTools 'godot-path') -Value $path -Encoding ASCII
}

function Get-File([string]$url, [string]$dest) {
	Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

function Update-SessionPath {
	$machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
	$user = [Environment]::GetEnvironmentVariable('Path', 'User')
	$env:Path = "$machine;$user"
}

function Install-Download {
	$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'windows_arm64' } else { 'win64' }
	$file = "Godot_v$($HtzVersions.GODOT_VERSION)-stable_$arch.exe.zip"
	$base = "https://github.com/godotengine/godot/releases/download/$($HtzVersions.GODOT_VERSION)-stable"
	$tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
	New-Item -ItemType Directory -Path $tmp | Out-Null
	try {
		Say "Downloading $file"
		$zip = Join-Path $tmp $file
		Get-File "$base/$file" $zip
		$sums = Join-Path $tmp 'sums.txt'
		Get-File "$base/SHA512-SUMS.txt" $sums
		$line = Get-Content $sums | Where-Object { $_ -match "\s$([regex]::Escape($file))$" } | Select-Object -First 1
		$got = (Get-FileHash -Algorithm SHA512 -Path $zip).Hash.ToLower()
		if (-not $line) { Warn "couldn't verify the checksum (not listed in SHA512-SUMS.txt)" }
		elseif ($line.Split(' ')[0] -ne $got) { throw "checksum mismatch for $file" }
		Expand-Archive -Path $zip -DestinationPath $tmp -Force
		New-Item -ItemType Directory -Force -Path $HtzTools | Out-Null
		Get-ChildItem -Path $tmp -Filter 'Godot_v*.exe' | ForEach-Object {
			Copy-Item $_.FullName -Destination $HtzTools -Force
		}
		$exe = Join-Path $HtzTools ($file -replace '\.zip$', '')
		if (-not (Test-Path $exe)) { throw "unexpected archive layout in $file" }
		Save-GodotPath $exe
	}
	finally {
		Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
	}
}

function Install-With([string]$name) {
	# Package managers write to stderr and return their own exit codes; don't treat that as fatal.
	$ErrorActionPreference = 'Continue'
	switch ($name) {
		'download' { Install-Download; return $true }
		'winget' {
			if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Warn 'winget not found'; return $false }
			if (-not (Confirm-Step "Run 'winget install GodotEngine.GodotEngine'?")) { return $false }
			winget install --id GodotEngine.GodotEngine --exact --accept-source-agreements --accept-package-agreements | Out-Host
		}
		'scoop' {
			if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { Warn 'scoop not found'; return $false }
			if (-not (Confirm-Step "Run 'scoop install extras/godot'?")) { return $false }
			scoop bucket add extras *> $null
			scoop install extras/godot | Out-Host
		}
		'choco' {
			if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { Warn 'choco not found'; return $false }
			if (-not (Confirm-Step "Run 'choco install godot' (needs an admin shell)?")) { return $false }
			choco install godot -y | Out-Host
		}
		'none' { return $false }
	}
	Update-SessionPath
	return $LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE
}

function Initialize-Godot {
	if (-not $Force) {
		$found = Find-Godot -Verbose
		if ($found) {
			Say "Using Godot $($found.Version): $($found.Path)"
			Save-GodotPath $found.Path
			return
		}
	}
	Remove-Item (Join-Path $HtzTools 'godot-path') -ErrorAction SilentlyContinue
	$managers = if ($Manager -eq 'auto') { @('winget', 'scoop', 'choco', 'download') } else { @($Manager) }
	foreach ($m in $managers) {
		Say "Getting Godot $($HtzVersions.GODOT_MIN)+ with $m"
		$ok = $false
		try { $ok = Install-With $m } catch { Warn "${m}: $($_.Exception.Message)" }
		if (-not $ok) { Warn "${m}: skipped or failed"; continue }
		$found = Find-Godot -Verbose
		if ($found) {
			Say "Using Godot $($found.Version): $($found.Path)"
			Save-GodotPath $found.Path
			return
		}
		Warn "$m didn't provide Godot $($HtzVersions.GODOT_MIN)+"
	}
	throw "couldn't get Godot $($HtzVersions.GODOT_MIN)+. Install it yourself and re-run, or set GODOT=C:\path\to\godot.exe"
}

function Initialize-GodotSteam {
	$version = $HtzVersions.GODOTSTEAM_VERSION
	$addon = Join-Path $HtzRoot 'addons/godotsteam'
	$marker = Join-Path $addon '.version'
	if (-not $Force -and (Test-Path $marker) -and ((Get-Content $marker -Raw).Trim() -eq $version)) {
		Say "GodotSteam $version already installed"
		return
	}
	$file = "godotsteam-$($version.TrimStart('v') -replace '-gde$', '')-gdextension-plugin-4.4.zip"
	$url = "https://codeberg.org/godotsteam/godotsteam/releases/download/$version/$file"
	$tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
	New-Item -ItemType Directory -Path $tmp | Out-Null
	try {
		Say "Downloading GodotSteam $version"
		Get-File $url (Join-Path $tmp 'gs.zip')
		Expand-Archive -Path (Join-Path $tmp 'gs.zip') -DestinationPath (Join-Path $tmp 'out') -Force
		$src = Join-Path $tmp 'out/addons/godotsteam'
		if (-not (Test-Path (Join-Path $src 'godotsteam.gdextension'))) { throw 'unexpected GodotSteam archive layout' }
		Remove-Item -Recurse -Force $addon -ErrorAction SilentlyContinue
		New-Item -ItemType Directory -Force -Path (Join-Path $HtzRoot 'addons') | Out-Null
		Copy-Item -Recurse $src $addon
		Set-Content -Path $marker -Value $version -Encoding ASCII
		Say "GodotSteam $version installed to addons\godotsteam"
	}
	finally {
		Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
	}
}

Initialize-Godot
Initialize-GodotSteam
Say 'Importing the project (first run only takes a moment)'
$godot = Find-Godot
& $godot.Console --headless --path $HtzRoot --import *> $null
if ($LASTEXITCODE -ne 0) { Warn 'import step failed; the editor will import on first open' }
Say 'Done. Play with: tools\godot.cmd    Editor: tools\godot.cmd -e'
