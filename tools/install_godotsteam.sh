#!/usr/bin/env bash
# Downloads the GodotSteam GDExtension (includes SteamMultiplayerPeer) into addons/godotsteam.
# Usage: tools/install_godotsteam.sh [version]   (default: GODOTSTEAM_VERSION in tools/versions.env)
# Needs curl or wget, and unzip, bsdtar or python3.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=versions.env
. "$ROOT/tools/versions.env"
VERSION="${1:-$GODOTSTEAM_VERSION}"
FILE="godotsteam-${VERSION#v}"
FILE="${FILE%-gde}-gdextension-plugin-4.4.zip"
URL="https://codeberg.org/godotsteam/godotsteam/releases/download/${VERSION}/${FILE}"

fetch() { # url dest
	if command -v curl >/dev/null 2>&1; then curl -fL --retry 3 -o "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then wget -q --show-progress -O "$2" "$1"
	else echo "error: need curl or wget" >&2; exit 1; fi
}
extract() { # zip dir
	mkdir -p "$2"
	if command -v unzip >/dev/null 2>&1; then unzip -q -o "$1" -d "$2"
	elif command -v bsdtar >/dev/null 2>&1; then bsdtar -xf "$1" -C "$2"
	elif command -v python3 >/dev/null 2>&1; then python3 -I -m zipfile -e "$1" "$2"
	elif command -v nix >/dev/null 2>&1; then nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#unzip -c unzip -q -o "$1" -d "$2"
	else echo "error: need unzip, bsdtar or python3" >&2; exit 1; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading GodotSteam $VERSION"
fetch "$URL" "$TMP/gs.zip"
extract "$TMP/gs.zip" "$TMP/out"
[ -f "$TMP/out/addons/godotsteam/godotsteam.gdextension" ] || { echo "error: unexpected archive layout" >&2; exit 1; }
rm -rf "$ROOT/addons/godotsteam"
mkdir -p "$ROOT/addons"
cp -R "$TMP/out/addons/godotsteam" "$ROOT/addons/godotsteam"
echo "$VERSION" > "$ROOT/addons/godotsteam/.version"
echo "GodotSteam $VERSION installed to addons/godotsteam"
