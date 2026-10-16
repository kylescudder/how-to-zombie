# Runs the project with the Godot that tools\setup.ps1 found. Use tools\godot.cmd from a terminal.
#   tools\godot.cmd                   play
#   tools\godot.cmd -e                open the editor
#   tools\godot.cmd -- --solo         launch straight into a mode (see README)
# Override the binary with $env:GODOT = 'C:\path\to\godot.exe'.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$godot = Find-Godot
if (-not $godot) {
	Write-Error "No Godot $($HtzVersions.GODOT_MIN)+ found. Run tools\setup.cmd first (or set GODOT)."
	exit 1
}
if (-not (Test-Path (Join-Path $HtzRoot 'addons/godotsteam/godotsteam.gdextension'))) {
	Write-Warning "GodotSteam isn't installed, so Steam features are off. Run tools\setup.cmd to add it."
}
# PowerShell drops a bare `--` from $args, but Godot needs it to separate game arguments
# (`-- --solo`). When started by godot.cmd, take the untouched arguments from the process instead.
$passArgs = $args
$argv = [Environment]::GetCommandLineArgs()
for ($i = 0; $i -lt $argv.Length - 1; $i++) {
	if ($argv[$i] -ieq '-File' -and (Resolve-Path $argv[$i + 1] -ErrorAction SilentlyContinue).Path -eq $PSCommandPath) {
		$passArgs = @($argv | Select-Object -Skip ($i + 2))
		break
	}
}
# The console build keeps output (tests, --headless) in this terminal.
& $godot.Console --path $HtzRoot @passArgs
exit $LASTEXITCODE
