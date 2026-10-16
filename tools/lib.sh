# shellcheck shell=bash disable=SC2034  # variables here are used by the scripts that source it
# Shared helpers for tools/setup.sh and tools/godot. Source it; don't run it.
# Finds a Godot >= GODOT_MIN and stores the command in the GODOT_CMD array.

HTZ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HTZ_TOOLS="$HTZ_ROOT/.tools" # hidden, so Godot doesn't import it; gitignored
# shellcheck source=versions.env
. "$HTZ_ROOT/tools/versions.env"

GODOT_CMD=()

# Prints the "major.minor.patch" Godot reports, or nothing.
godot_version() {
	"$@" --headless --version 2>/dev/null | grep -Eo '^[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1
}

# True if version $1 >= GODOT_MIN.
version_ok() {
	[ -n "$1" ] || return 1
	local have_major have_minor need_major need_minor
	have_major="${1%%.*}"; have_minor="${1#*.}"; have_minor="${have_minor%%.*}"
	need_major="${GODOT_MIN%%.*}"; need_minor="${GODOT_MIN#*.}"
	[ "$have_major" -gt "$need_major" ] || { [ "$have_major" -eq "$need_major" ] && [ "$have_minor" -ge "$need_minor" ]; }
}

# Prints candidate Godot commands, one per line, best first.
# A line is either an executable path or "flatpak:<app id>".
godot_candidates() {
	[ -n "${GODOT:-}" ] && echo "$GODOT"
	[ -f "$HTZ_TOOLS/godot-path" ] && cat "$HTZ_TOOLS/godot-path"
	echo "$HTZ_TOOLS/godot-nix/bin/godot"
	echo "$HTZ_TOOLS/Godot.app/Contents/MacOS/Godot"
	echo "$HTZ_TOOLS/Godot_v${GODOT_VERSION}-stable_linux.$(godot_linux_arch 2>/dev/null)"
	local n
	for n in godot godot4 "godot$GODOT_MIN" godot-4; do command -v "$n" 2>/dev/null || true; done
	echo "/Applications/Godot.app/Contents/MacOS/Godot"
	echo "$HOME/Applications/Godot.app/Contents/MacOS/Godot"
	if command -v flatpak >/dev/null 2>&1 && flatpak info org.godotengine.Godot >/dev/null 2>&1; then
		echo "flatpak:org.godotengine.Godot"
	fi
}

# Sets GODOT_CMD from one candidate line. Returns 1 if it isn't runnable.
godot_cmd_from() {
	case "$1" in
		flatpak:*) GODOT_CMD=(flatpak run "${1#flatpak:}") ;;
		*) [ -x "$1" ] && [ ! -d "$1" ] || return 1; GODOT_CMD=("$1") ;;
	esac
}

# Finds the first Godot >= GODOT_MIN. Sets GODOT_CMD and GODOT_FOUND_VERSION.
# With $1 = "verbose", reports candidates that are too old.
find_godot() {
	local line ver
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		godot_cmd_from "$line" || continue
		ver="$(godot_version "${GODOT_CMD[@]}")"
		if version_ok "$ver"; then
			GODOT_FOUND_VERSION="$ver"
			return 0
		fi
		[ "${1:-}" = verbose ] && echo "  skipping ${GODOT_CMD[*]} (version ${ver:-unknown}, need $GODOT_MIN+)" >&2
	done < <(godot_candidates)
	GODOT_CMD=()
	return 1
}

godot_linux_arch() {
	case "$(uname -m)" in
		x86_64 | amd64) echo x86_64 ;;
		aarch64 | arm64) echo arm64 ;;
		i?86) echo x86_32 ;;
		armv7* | armv8l) echo arm32 ;;
		*) return 1 ;;
	esac
}

is_nixos() { [ -e /etc/NIXOS ]; }
is_musl() { ls /lib/ld-musl-* >/dev/null 2>&1; }
