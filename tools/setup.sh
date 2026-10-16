#!/usr/bin/env bash
# One-step setup for macOS, Linux (and WSL): makes sure Godot 4.7+ is available, then installs
# the GodotSteam plugin and imports the project. Windows: use tools\setup.cmd instead.
#
# Usage: tools/setup.sh [--manager NAME] [--yes] [--force]
#   --manager  how to get Godot if it isn't already installed:
#              auto (default), nix, brew, port, pacman, dnf, zypper, apk, xbps, flatpak,
#              download (official build into .tools/, no root needed), or none
#   --yes      don't ask before running the package manager (it may use sudo)
#   --force    reinstall GodotSteam and ignore any Godot that's already installed
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

MANAGER=auto
YES=0
FORCE=0
while [ $# -gt 0 ]; do
	case "$1" in
		--manager) MANAGER="${2:?--manager needs a value}"; shift 2 ;;
		--manager=*) MANAGER="${1#*=}"; shift ;;
		-y | --yes) YES=1; shift ;;
		--force) FORCE=1; shift ;;
		-h | --help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
	esac
done

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

confirm() {
	[ "$YES" = 1 ] && return 0
	[ -t 0 ] || return 1
	printf '%s [Y/n] ' "$1"
	local reply
	read -r reply
	case "$reply" in [nN]*) return 1 ;; *) return 0 ;; esac
}

sudo_cmd() {
	if [ "$(id -u)" = 0 ]; then "$@"
	elif have sudo; then sudo "$@"
	elif have doas; then doas "$@"
	else die "need root for: $*"; fi
}

record_godot() {
	mkdir -p "$HTZ_TOOLS"
	printf '%s\n' "$1" > "$HTZ_TOOLS/godot-path"
}

fetch() { # url dest
	if have curl; then curl -fL --retry 3 --progress-bar -o "$2" "$1"
	elif have wget; then wget -q --show-progress -O "$2" "$1"
	else die "need curl or wget"; fi
}

extract() { # zip dir
	mkdir -p "$2"
	if have unzip; then unzip -q -o "$1" -d "$2"
	elif have bsdtar; then bsdtar -xf "$1" -C "$2"
	elif have python3; then python3 -I -m zipfile -e "$1" "$2"
	elif command -v nix >/dev/null 2>&1; then nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#unzip -c unzip -q -o "$1" -d "$2"
	else die "need unzip, bsdtar or python3"; fi
}

sha512_of() {
	if have sha512sum; then sha512sum "$1" | cut -d' ' -f1
	elif have shasum; then shasum -a 512 "$1" | cut -d' ' -f1
	elif have openssl; then openssl dgst -sha512 -r "$1" | cut -d' ' -f1
	fi
}

# Installs the official Godot build into .tools/ and verifies its checksum.
install_download() {
	local os file url base tmp want got
	os="$(uname -s)"
	case "$os" in
		Darwin) file="Godot_v${GODOT_VERSION}-stable_macos.universal.zip" ;;
		Linux)
			is_nixos && die "the official Linux build can't run on NixOS; use --manager nix (or 'nix develop')"
			is_musl && die "the official Linux build needs glibc; on musl distros (Alpine, Void musl) use flatpak"
			file="Godot_v${GODOT_VERSION}-stable_linux.$(godot_linux_arch)" || die "unsupported CPU: $(uname -m)"
			file="$file.zip" ;;
		*) die "no official Godot download for $os; install Godot $GODOT_MIN+ yourself and set GODOT=/path/to/godot" ;;
	esac
	base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
	url="$base/$file"
	tmp="$(mktemp -d)"
	say "Downloading $file"
	fetch "$url" "$tmp/$file"
	fetch "$base/SHA512-SUMS.txt" "$tmp/sums" 2>/dev/null || true
	want="$(grep " $file\$" "$tmp/sums" 2>/dev/null | cut -d' ' -f1)"
	got="$(sha512_of "$tmp/$file")"
	if [ -z "$got" ] || [ -z "$want" ]; then
		warn "couldn't verify the checksum (no sha512 tool or SHA512-SUMS.txt)"
	elif [ "$want" != "$got" ]; then
		rm -rf "$tmp"
		die "checksum mismatch for $file"
	fi
	extract "$tmp/$file" "$tmp/out"
	mkdir -p "$HTZ_TOOLS"
	if [ "$os" = Darwin ]; then
		rm -rf "$HTZ_TOOLS/Godot.app"
		mv "$tmp/out/Godot.app" "$HTZ_TOOLS/Godot.app"
		xattr -dr com.apple.quarantine "$HTZ_TOOLS/Godot.app" 2>/dev/null || true
		record_godot "$HTZ_TOOLS/Godot.app/Contents/MacOS/Godot"
	else
		local bin="${file%.zip}"
		mv "$tmp/out/$bin" "$HTZ_TOOLS/$bin"
		chmod +x "$HTZ_TOOLS/$bin"
		record_godot "$HTZ_TOOLS/$bin"
	fi
	rm -rf "$tmp"
}

# Builds the Godot pinned by flake.nix and links it at .tools/godot-nix.
install_nix() {
	have nix || die "nix isn't installed (https://nixos.org/download)"
	mkdir -p "$HTZ_TOOLS"
	say "Building Godot from flake.nix (nixpkgs godot_4_7)"
	(cd "$HTZ_ROOT" && nix --extra-experimental-features 'nix-command flakes' \
		build .#godot --out-link "$HTZ_TOOLS/godot-nix")
	record_godot "$HTZ_TOOLS/godot-nix/bin/godot"
}

install_flatpak() {
	have flatpak || die "flatpak isn't installed"
	flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	flatpak install --user -y flathub org.godotengine.Godot
	# The sandbox needs to reach the Steam client's IPC files in your home directory.
	flatpak override --user --filesystem=home org.godotengine.Godot || true
	record_godot "flatpak:org.godotengine.Godot"
}

# Runs one package manager. Returns non-zero if the user declined.
install_with() {
	case "$1" in
		nix) install_nix ;;
		download) install_download ;;
		flatpak) confirm "Install Godot from Flathub (per-user)?" || return 1; install_flatpak ;;
		brew) confirm "Run 'brew install --cask godot'?" || return 1; brew install --cask godot ;;
		port) confirm "Run 'sudo port install godot'?" || return 1; sudo_cmd port install godot ;;
		pacman) confirm "Run 'sudo pacman -S godot'?" || return 1; sudo_cmd pacman -S --needed --noconfirm godot ;;
		dnf) confirm "Run 'sudo dnf install godot'?" || return 1; sudo_cmd dnf install -y godot ;;
		zypper) confirm "Run 'sudo zypper install godot'?" || return 1; sudo_cmd zypper --non-interactive install godot ;;
		apk) confirm "Run 'sudo apk add godot'?" || return 1; sudo_cmd apk add godot ;;
		xbps) confirm "Run 'sudo xbps-install godot'?" || return 1; sudo_cmd xbps-install -Sy godot ;;
		none) return 1 ;;
		*) die "unknown manager '$1' (see --help)" ;;
	esac
}

# Picks managers to try, in order. Native packages are only used where they're usually current;
# the version is checked afterwards either way, falling back to the official download.
auto_managers() {
	local id="" like=""
	if [ -r /etc/os-release ]; then
		id="$(. /etc/os-release && echo "${ID:-}")"
		like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
	fi
	if is_nixos; then echo nix; return; fi
	have nix && echo nix
	if is_musl; then
		have apk && echo apk
		have xbps-install && echo xbps
		echo flatpak
		return
	fi
	case "$(uname -s)" in
		Darwin)
			have brew && echo brew
			echo download
			return ;;
	esac
	case " $id $like " in
		*" steamos "*) ;; # read-only root: skip pacman
		*" arch "*) have pacman && echo pacman ;;
		*" opensuse-tumbleweed "* | *" suse "* | *" opensuse "*) have zypper && echo zypper ;;
		*" fedora "*) have dnf && echo dnf ;;
		*" void "*) have xbps-install && echo xbps ;;
	esac
	# Debian, Ubuntu, Mint, Pop!_OS, SteamOS etc. only package old Godot, so use the official build.
	echo download
	if have flatpak; then echo flatpak; fi
}

ensure_godot() {
	if [ "$FORCE" = 0 ] && find_godot verbose; then
		say "Using Godot $GODOT_FOUND_VERSION: ${GODOT_CMD[*]}"
		record_godot "$( [ "${GODOT_CMD[0]}" = flatpak ] && echo "flatpak:${GODOT_CMD[2]}" || echo "${GODOT_CMD[0]}")"
		return
	fi
	local managers m
	if [ "$MANAGER" = auto ]; then managers="$(auto_managers)"; else managers="$MANAGER"; fi
	rm -f "$HTZ_TOOLS/godot-path"
	for m in $managers; do
		say "Getting Godot $GODOT_MIN+ with $m"
		if ! (install_with "$m"); then
			warn "$m: skipped or failed"
			continue
		fi
		if find_godot verbose; then
			say "Using Godot $GODOT_FOUND_VERSION: ${GODOT_CMD[*]}"
			return
		fi
		warn "$m didn't provide Godot $GODOT_MIN+"
	done
	die "couldn't get Godot $GODOT_MIN+. Install it yourself and re-run, or set GODOT=/path/to/godot"
}

ensure_godotsteam() {
	local current=""
	[ -f "$HTZ_ROOT/addons/godotsteam/.version" ] && current="$(cat "$HTZ_ROOT/addons/godotsteam/.version")"
	if [ "$FORCE" = 0 ] && [ "$current" = "$GODOTSTEAM_VERSION" ]; then
		say "GodotSteam $GODOTSTEAM_VERSION already installed"
		return
	fi
	"$HTZ_ROOT/tools/install_godotsteam.sh" "$GODOTSTEAM_VERSION"
}

ensure_godot
ensure_godotsteam
say "Importing the project (first run only takes a moment)"
"$HTZ_ROOT/tools/godot" --headless --import >/dev/null 2>&1 || warn "import step failed; the editor will import on first open"
say "Done. Play with: tools/godot    Editor: tools/godot -e"
