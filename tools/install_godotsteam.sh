#!/usr/bin/env bash
# Downloads the GodotSteam GDExtension (includes SteamMultiplayerPeer) into addons/.
set -euo pipefail
VERSION="${1:-v4.23-gde}"
FILE="godotsteam-${VERSION#v}"
FILE="${FILE%-gde}-gdextension-plugin-4.4.zip"
URL="https://codeberg.org/godotsteam/godotsteam/releases/download/${VERSION}/${FILE}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
echo "Downloading $URL"
curl -fL -o "$TMP/gs.zip" "$URL"
unzip -q -o "$TMP/gs.zip" -d "$TMP/out"
rm -rf "$ROOT/addons/godotsteam"
mkdir -p "$ROOT/addons"
cp -R "$TMP/out/addons/godotsteam" "$ROOT/addons/godotsteam"
rm -rf "$TMP"
echo "GodotSteam installed to addons/godotsteam"
