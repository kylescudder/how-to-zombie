class_name DeathClips
extends RefCounted
## Every way an infected can die. A clip is a list of [seconds, ease, pose] keys; a pose only names
## the joints that change, the rest hold. Numbers are degrees, and one number means pitch.
##   root/hip/spine/head: + pitches forward, [pitch, yaw, roll]. root roll - tips towards +x.
##   al/ar/ll/lr: - swings the limb forward. al/ll z - and ar/lr z + spread it outwards.
##   el/er/kl/kr: how far the elbow or knee is bent.
##   move: [side, height, forward] metres. belly: torso swell, 1 is normal.
## cause: body, head, blast or fire. hit: where the blow came from, and "side" clips are authored
## falling towards +x and mirrored for the other side. Clips with "only" are that type's own.
## upright: the body is meant to end sitting or kneeling.

const CHANNELS := ["root", "hip", "spine", "head", "al", "ar", "ll", "lr", "el", "er", "kl", "kr", "move", "belly"]
const SWAPS := {"al": "ar", "ar": "al", "ll": "lr", "lr": "ll", "el": "er", "er": "el", "kl": "kr", "kr": "kl"}
const SPECIES_SHARE := 0.55  # How often a special dies in a way only it can.
const RECENT := 4            # A type won't repeat one of its last few deaths.
const WEIGHT := {"tank": 1.45, "boomer": 1.15, "witch": 0.9}

const CLIPS := {
	# --- Shot from the front: thrown backwards ---
	"back_flop": {"cause": "body", "hit": "front", "keys": [
		[0.14, "out", {"root": -9, "spine": -14, "head": -22, "al": [-55, 0, -45], "ar": [-40, 0, 50], "el": 30, "er": 15}],
		[0.62, "in", {"root": -90, "spine": -6, "head": -8, "al": [-100, 0, -70], "ar": [-120, 0, 60], "ll": -18, "lr": 8, "kl": 20}],
		[0.74, "out", {"root": -84, "al": [-125, 0, -70], "ar": [-140, 0, 60], "head": 8}],
		[0.92, "in", {"root": -90, "al": [-90, 0, -80], "ar": [-100, 0, 72], "head": -4, "ll": -12, "lr": 12, "kl": 12, "kr": 6}]]},
	"stagger_steps": {"cause": "body", "hit": "front", "keys": [
		[0.16, "out", {"root": -7, "spine": -20, "head": -18, "al": [-30, 0, -40], "ar": [-30, 0, 40], "ll": 18, "lr": -14, "kr": 18, "move": [0, 0, -0.25]}],
		[0.42, "io", {"root": -10, "spine": -10, "ll": -16, "lr": 20, "kl": 22, "kr": 0, "move": [0, 0, -0.55]}],
		[0.68, "io", {"root": -13, "spine": -22, "ll": 22, "lr": -12, "kl": 0, "kr": 28, "head": -26, "move": [0, 0, -0.85]}],
		[1.06, "in", {"root": -90, "spine": -4, "head": 4, "al": [-20, 0, -62], "ar": [-110, 0, 40], "er": 50, "ll": -22, "lr": 6, "kl": 30, "kr": 8, "move": [0, 0, -1.0]}],
		[1.2, "out", {"root": -86, "head": 12}],
		[1.34, "in", {"root": -90, "head": 2}]]},
	"arms_wide": {"cause": "body", "hit": "front", "keys": [
		[0.12, "out", {"root": -16, "spine": -24, "head": -30, "al": [-20, 0, -86], "ar": [-20, 0, 86], "move": [0, 0.04, -0.2]}],
		[0.5, "in", {"root": -92, "spine": -8, "head": -10, "al": [0, 0, -92], "ar": [0, 0, 92], "ll": -24, "lr": -6, "kl": 24, "move": [0, 0, -0.55]}],
		[0.62, "out", {"root": -85, "move": [0, 0, -0.62], "ll": -14, "kl": 12, "head": 6}],
		[0.8, "in", {"root": -90, "al": [-6, 0, -80], "ar": [6, 0, 76], "ll": -8, "lr": -4, "kl": 4, "head": -2, "move": [0, 0, -0.66]}]]},
	"chest_clutch": {"cause": "body", "hit": "front", "keys": [
		[0.2, "out", {"spine": 18, "head": 22, "al": [-62, 0, 44], "ar": [-58, 0, -44], "el": 96, "er": 104, "kl": 18, "kr": 12, "ll": -10, "lr": -6}],
		[0.62, "io", {"root": -6, "spine": 26, "kl": 88, "kr": 74, "ll": -42, "lr": -34, "head": 30}],
		[0.98, "in", {"root": -78, "spine": 32, "head": 14, "kl": 96, "kr": 62, "ll": -62, "lr": -44}],
		[1.14, "out", {"root": -71, "spine": 26}],
		[1.34, "in", {"root": -88, "spine": 8, "ar": [-38, 0, 8], "er": 80, "al": [-48, 0, 20], "kl": 70, "kr": 34, "ll": -44, "lr": -24}]]},
	"buckle_back": {"cause": "body", "hit": "front", "keys": [
		[0.14, "out", {"root": -4, "spine": -12, "head": -24, "al": [-12, 0, -30], "ar": [-12, 0, 30]}],
		[0.46, "in", {"hip": -6, "spine": -8, "kl": 120, "kr": 126, "ll": -66, "lr": -70, "head": -12, "al": [10, 0, -22], "ar": [14, 0, 22]}],
		[0.58, "out", {"spine": 2, "head": 8}],
		[0.98, "in", {"root": -88, "spine": -2, "head": -6, "ll": -46, "lr": -52, "kl": 128, "kr": 130, "al": [0, 0, -44], "ar": [-6, 0, 40]}],
		[1.14, "io", {"ll": -30, "kl": 90, "head": 0}]]},

	# --- Shot from behind: pitched forwards ---
	"faceplant": {"cause": "body", "hit": "back", "keys": [
		[0.14, "out", {"root": 8, "spine": -18, "head": -20, "al": [34, 0, -22], "ar": [40, 0, 22]}],
		[0.58, "in", {"root": 90, "spine": 2, "head": 14, "al": [-30, 0, -28], "ar": [12, 0, 22], "ll": 4, "lr": -14, "kr": 28}],
		[0.7, "out", {"root": 84, "head": -6, "kr": 12}],
		[0.86, "in", {"root": 90, "head": 6, "al": [-10, 0, -24], "ar": [20, 0, 16], "lr": -6, "kr": 8}]]},
	"knees_then_face": {"cause": "body", "hit": "back", "keys": [
		[0.16, "out", {"root": 4, "spine": -14, "head": -20, "al": [18, 0, -14], "ar": [18, 0, 14]}],
		[0.5, "in", {"ll": 6, "lr": 2, "kl": 92, "kr": 96, "spine": 8, "head": 6, "al": [4, 0, -8], "ar": [6, 0, 8]}],
		[0.66, "out", {"spine": -2, "head": -8, "kl": 88, "kr": 90}],
		[1.06, "in", {"root": 88, "spine": 0, "head": 16, "kl": 10, "kr": 24, "ll": 6, "lr": 0, "al": [-40, 0, -20], "ar": [-18, 0, 30], "el": 40}],
		[1.18, "out", {"root": 82}],
		[1.3, "in", {"root": 89}]]},
	"stumble_sprawl": {"cause": "body", "hit": "back", "keys": [
		[0.2, "out", {"root": 12, "spine": 12, "ll": -26, "lr": 16, "kr": 30, "al": [-46, 0, -18], "ar": [-30, 0, 20], "move": [0, 0, 0.35]}],
		[0.46, "io", {"root": 24, "ll": 18, "lr": -34, "kl": 34, "kr": 6, "al": [-78, 0, -30], "ar": [-70, 0, 26], "move": [0, 0, 0.8]}],
		[0.84, "in", {"root": 90, "spine": -12, "head": -18, "ll": 8, "lr": 14, "kl": 22, "kr": 30, "al": [-156, 0, -24], "ar": [-168, 0, 20], "move": [0, 0, 1.15]}],
		[0.98, "out", {"root": 85, "move": [0, 0, 1.25]}],
		[1.14, "in", {"root": 90, "head": 8, "kl": 8, "kr": 14, "move": [0, 0, 1.3]}]]},
	"reach_forward": {"cause": "body", "hit": "back", "keys": [
		[0.2, "out", {"root": 6, "spine": 6, "al": [-104, 0, 6], "ar": [-120, 0, -6], "head": -18, "lr": -14, "kr": 16}],
		[0.52, "io", {"root": 13, "spine": 16, "al": [-132, 0, 2], "ar": [-110, 0, 0], "kr": 34, "lr": -22}],
		[0.94, "in", {"root": 88, "spine": -4, "head": -8, "al": [-166, 0, -8], "ar": [-150, 0, 12], "kl": 14, "kr": 18, "lr": -6}],
		[1.08, "out", {"root": 84, "ar": [-140, 0, 18]}],
		[1.3, "io", {"root": 90, "al": [-172, 0, -10], "ar": [-160, 0, 20], "er": 22, "head": 4}]]},

	# --- Shot from the side: authored falling towards +x ---
	"spin_drop": {"cause": "body", "hit": "side", "keys": [
		[0.16, "out", {"root": [0, 90, 0], "spine": [0, 26, -14], "head": [0, 26, 0], "al": [-40, 0, -72], "ar": [10, 0, 58], "lr": -14, "kr": 18}],
		[0.42, "io", {"root": [8, 200, -18], "spine": [10, 12, -10], "al": [-20, 0, -80], "ar": [-30, 0, 80], "ll": 12, "kl": 26}],
		[0.78, "in", {"root": [90, 268, 0], "spine": 2, "head": [10, 40, 0], "al": [-60, 0, -40], "ar": [-14, 0, 34], "ll": -8, "lr": 6, "kr": 26}],
		[0.9, "out", {"root": [85, 268, 0]}],
		[1.04, "in", {"root": [90, 270, 0], "kr": 12}]]},
	"side_crumple": {"cause": "body", "hit": "side", "keys": [
		[0.14, "out", {"root": [0, 0, -7], "spine": [0, 0, 18], "head": [0, 0, 22], "ar": [-30, 0, 34], "er": 90, "al": [-24, 0, -36]}],
		[0.5, "in", {"root": [0, 0, -14], "spine": [14, 0, 24], "kl": 70, "kr": 104, "ll": -30, "lr": -56, "head": [20, 0, 24]}],
		[0.9, "in", {"root": [0, 12, -88], "spine": [18, 0, 6], "head": [4, 0, -18], "kl": 92, "kr": 110, "ll": -44, "lr": -62, "al": [-60, 0, -8], "ar": [-40, 0, 12]}],
		[1.02, "out", {"root": [0, 12, -84]}],
		[1.18, "in", {"root": [0, 12, -90], "head": [0, 0, -8]}]]},
	"shoulder_twist": {"cause": "body", "hit": "side", "keys": [
		[0.12, "out", {"spine": [0, 44, 0], "head": [0, 26, 0], "ar": [18, 0, 64], "al": [-82, 0, -26], "root": [0, 18, -4]}],
		[0.44, "io", {"root": [0, 56, -10], "spine": [8, 30, 0], "kl": 34, "ll": -16, "ar": [30, 0, 40], "er": 44}],
		[0.84, "in", {"root": [-90, 74, 0], "spine": [-8, 8, 0], "head": [0, 28, 0], "ar": [-20, 0, 78], "al": [-30, 0, -74], "ll": -10, "lr": 10, "kl": 24}],
		[0.96, "out", {"root": [-85, 74, 0]}],
		[1.12, "in", {"root": [-90, 76, 0], "kl": 8}]]},
	"sideways_stumble": {"cause": "body", "hit": "side", "keys": [
		[0.2, "out", {"root": [0, 0, -9], "ll": [4, 0, 10], "lr": [0, 0, 22], "spine": [0, 0, 14], "al": [-20, 0, -62], "ar": [-8, 0, 72], "move": [0.32, 0, 0]}],
		[0.44, "io", {"root": [0, 0, -5], "ll": [0, 0, 22], "lr": [0, 0, 4], "move": [0.62, 0, 0]}],
		[0.66, "io", {"root": [0, 0, -14], "ll": [0, 0, 6], "lr": [0, 0, 26], "kr": 22, "spine": [8, 0, 18], "move": [0.95, 0, 0]}],
		[1.04, "in", {"root": [0, 18, -90], "spine": [6, 0, 8], "ll": [-16, 0, 14], "lr": [-8, 0, 6], "kl": 16, "kr": 30, "ar": [-40, 0, 92], "al": [-10, 0, -40], "head": [0, 0, -14], "move": [1.05, 0, 0]}],
		[1.16, "out", {"root": [0, 18, -86]}],
		[1.3, "in", {"root": [0, 18, -90], "head": [0, 0, -4]}]]},

	# --- From anywhere ---
	"straight_down": {"cause": "body", "hit": "any", "keys": [
		[0.3, "in", {"kl": 148, "kr": 146, "ll": -74, "lr": -72, "spine": 8, "head": 28, "al": [8, 0, -8], "ar": [10, 0, 8]}],
		[0.42, "out", {"kl": 140, "kr": 138, "spine": 16, "head": 36}],
		[0.84, "in", {"root": [14, 0, 82], "spine": [20, 0, 0], "ll": -52, "lr": -38, "kl": 128, "kr": 96, "al": [-26, 0, -18], "ar": [12, 0, 20], "head": [10, 0, -10]}],
		[0.96, "out", {"root": [14, 0, 78]}],
		[1.1, "in", {"root": [14, 0, 86]}]]},
	"curl_up": {"cause": "body", "hit": "any", "keys": [
		[0.22, "out", {"spine": 26, "head": 22, "al": [-48, 0, 34], "ar": [-52, 0, -34], "el": 110, "er": 112, "kl": 20, "kr": 26}],
		[0.62, "io", {"spine": 36, "kl": 104, "kr": 112, "ll": -54, "lr": -60, "head": 32}],
		[1.08, "in", {"root": [0, 0, -86], "spine": 44, "head": 34, "ll": -86, "lr": -92, "kl": 124, "kr": 118, "al": [-82, 0, 26], "ar": [-90, 0, -16]}],
		[1.22, "out", {"root": [0, 0, -82]}],
		[1.42, "in", {"root": [0, 0, -88], "spine": 48, "head": 38}],
		[2.0, "io", {"kl": 112, "ll": -78}]]},
	"sit_slump": {"upright": true, "cause": "body", "hit": "any", "keys": [
		[0.2, "out", {"spine": -8, "head": -14, "kl": 26, "kr": 30}],
		[0.58, "in", {"ll": -86, "lr": -80, "kl": 34, "kr": 22, "spine": -12, "al": [18, 0, -26], "ar": [10, 0, 30], "el": 20, "head": 10}],
		[0.7, "out", {"spine": -2, "head": 24}],
		[1.12, "io", {"spine": 30, "head": 44, "ll": [-82, 0, -14], "lr": [-78, 0, 14], "kl": 16, "kr": 8, "al": [-12, 0, -8], "ar": [-14, 0, 8], "el": 18, "er": 22}],
		[1.6, "io", {"spine": [38, 0, 10], "head": [50, 0, 16], "ar": [-24, 0, 2]}]]},
	"kneel_tip": {"cause": "body", "hit": "any", "keys": [
		[0.42, "in", {"kl": 96, "kr": 92, "ll": 2, "lr": -2, "spine": 4, "head": 16, "al": [6, 0, -10], "ar": [6, 0, 10]}],
		[0.54, "out", {"spine": -8, "head": 4}],
		[1.0, "io", {"spine": [2, 0, 10], "head": [26, 0, 14], "root": [0, 0, -6]}],
		[1.42, "in", {"root": [6, 0, -88], "spine": [6, 0, 6], "ll": -14, "lr": -44, "kl": 84, "kr": 76, "al": [-30, 0, -20], "ar": [-44, 0, 34], "head": [10, 0, -6]}],
		[1.54, "out", {"root": [6, 0, -84]}],
		[1.68, "in", {"root": [6, 0, -90]}]]},
	"last_reach": {"cause": "body", "hit": "any", "keys": [
		[0.16, "out", {"root": -6, "spine": -10, "head": -18, "ar": [-18, 0, 30]}],
		[0.62, "in", {"root": -90, "ll": -12, "lr": -6, "kl": 28, "kr": 8, "al": [-10, 0, -40], "ar": [-70, 0, 44], "head": 0}],
		[0.72, "out", {"root": -86}],
		[0.86, "in", {"root": -90}],
		[1.34, "io", {"ar": [-96, 0, 8], "er": 12, "head": 18, "spine": 8}],
		[1.56, "in", {"ar": [-20, 0, 26], "er": 30, "head": 0, "spine": 0}],
		[1.68, "out", {"ar": [-30, 0, 26]}],
		[1.8, "in", {"ar": [-20, 0, 34], "head": [-2, 22, 0]}]]},
	"shudder_fall": {"cause": "body", "hit": "any", "keys": [
		[0.08, "out", {"spine": 10, "head": -18, "al": [-30, 0, -30], "ar": [-52, 0, 20]}],
		[0.16, "out", {"spine": -12, "head": 16, "al": [-72, 0, -10], "ar": [-14, 0, 44]}],
		[0.24, "out", {"spine": 12, "head": -14, "al": [-22, 0, -42], "ar": [-64, 0, 14]}],
		[0.32, "out", {"spine": -8, "head": 18, "al": [-60, 0, -12], "ar": [-20, 0, 40], "kl": 22}],
		[0.4, "out", {"spine": 14, "head": -8, "al": [-26, 0, -30], "ar": [-46, 0, 18], "kr": 30, "kl": 10}],
		[0.86, "in", {"root": [88, -14, 0], "spine": 2, "head": [12, 26, 0], "al": [-30, 0, -40], "ar": [10, 0, 26], "ll": -6, "kl": 26, "kr": 16}],
		[0.96, "out", {"root": [84, -14, 0]}],
		[1.08, "in", {"root": [90, -14, 0]}],
		[1.2, "out", {"ll": -14, "kl": 36}],
		[1.32, "in", {"ll": -6, "kl": 20}],
		[1.42, "out", {"al": [-40, 0, -46]}],
		[1.54, "in", {"al": [-30, 0, -40]}]]},

	# --- Headshots: everything switches off at once ---
	"head_snap": {"cause": "head", "hit": "front", "keys": [
		[0.07, "out", {"head": -50, "spine": -10, "root": -3}],
		[0.2, "out", {"head": -38, "kl": 24, "kr": 30, "al": [8, 0, -12], "ar": [8, 0, 12]}],
		[0.62, "in", {"root": -88, "head": -6, "spine": -6, "ll": -20, "lr": -8, "kl": 40, "kr": 24, "al": [-20, 0, -36], "ar": [-8, 0, 40]}],
		[0.72, "out", {"root": -83, "head": 10}],
		[0.86, "in", {"root": -90, "head": [-4, 18, 0]}]]},
	"rigid_drop": {"cause": "head", "hit": "any", "keys": [
		[0.09, "out", {"head": 24, "al": [-6, 0, -4], "ar": [-6, 0, 4]}],
		[0.62, "in", {"root": 90}],
		[0.68, "out", {"root": 87}],
		[0.76, "in", {"root": 90, "head": [12, 24, 0]}]]},
	"neck_whip": {"cause": "head", "hit": "side", "keys": [
		[0.06, "out", {"head": [0, 40, 48], "spine": [0, 14, 8]}],
		[0.22, "out", {"root": [0, 28, -5], "head": [18, 48, 40], "kr": 32, "kl": 12, "al": [4, 0, -20], "ar": [10, 0, 34]}],
		[0.66, "in", {"root": [88, 62, 0], "spine": 2, "head": [4, 34, 8], "kr": 24, "kl": 12, "ar": [20, 0, 40], "al": [-18, 0, -32]}],
		[0.76, "out", {"root": [84, 62, 0]}],
		[0.9, "in", {"root": [90, 62, 0]}]]},
	"hands_to_head": {"cause": "head", "hit": "any", "keys": [
		[0.22, "out", {"al": [-138, 0, 24], "ar": [-142, 0, -24], "el": 108, "er": 112, "head": 20, "spine": 14}],
		[0.56, "io", {"root": [0, 0, -4], "kl": 50, "kr": 62, "ll": -22, "lr": -30, "spine": 22}],
		[0.86, "in", {"kl": 112, "kr": 120, "ll": -50, "lr": -58, "spine": 28, "head": 26}],
		[1.26, "in", {"root": [84, 0, 20], "spine": 6, "head": 12, "ll": -6, "lr": -4, "kl": 36, "kr": 30, "al": [-126, 0, 10], "ar": [-110, 0, -10]}],
		[1.38, "out", {"root": [80, 0, 20]}],
		[1.5, "in", {"root": [86, 0, 22]}]]},

	# --- Pipe bombs and propane: light bodies only ---
	"launched_back": {"cause": "blast", "hit": "front", "light": true, "keys": [
		[0.1, "out", {"root": -24, "spine": -28, "head": -30, "al": [-120, 0, -50], "ar": [-110, 0, 54], "ll": -32, "lr": -44, "kl": 44, "kr": 28, "move": [0, 0.5, -0.5]}],
		[0.34, "out", {"root": -68, "spine": -18, "al": [-170, 0, -40], "ar": [-160, 0, 40], "ll": -22, "lr": 4, "move": [0, 1.0, -1.5]}],
		[0.78, "in", {"root": -100, "spine": -4, "al": [-130, 0, -60], "ar": [-150, 0, 40], "ll": -34, "lr": -12, "kl": 30, "kr": 12, "move": [0, 0, -3.0]}],
		[0.92, "out", {"root": -86, "move": [0, 0.22, -3.35], "ll": -46, "kl": 54}],
		[1.14, "in", {"root": -90, "al": [-80, 0, -74], "ar": [-110, 0, 68], "ll": -16, "lr": 6, "kl": 18, "kr": 6, "head": 2, "move": [0, 0, -3.65]}]]},
	"cartwheel": {"cause": "blast", "hit": "side", "light": true, "keys": [
		[0.12, "out", {"root": [0, 0, -70], "al": [-14, 0, -112], "ar": [-14, 0, 112], "ll": [0, 0, -30], "lr": [0, 0, 32], "move": [0.55, 0.65, 0]}],
		[0.44, "io", {"root": [0, 0, -220], "al": [0, 0, -124], "ar": [0, 0, 124], "ll": [0, 0, -38], "lr": [0, 0, 38], "move": [1.6, 1.15, 0]}],
		[0.78, "in", {"root": [0, 0, -360], "ll": [0, 0, -20], "lr": [0, 0, 22], "al": [-30, 0, -70], "move": [2.6, 0.25, 0]}],
		[1.12, "in", {"root": [0, 0, -450], "spine": 6, "ll": -10, "lr": 6, "kl": 22, "kr": 8, "al": [-70, 0, -30], "ar": [-30, 0, 60], "move": [3.1, 0, 0]}],
		[1.24, "out", {"root": [0, 0, -445], "move": [3.2, 0.06, 0]}],
		[1.38, "in", {"root": [0, 0, -450], "move": [3.25, 0, 0]}]]},
	"somersault": {"cause": "blast", "hit": "back", "light": true, "keys": [
		[0.12, "out", {"root": 58, "spine": 26, "head": 26, "ll": -30, "lr": -18, "kl": 60, "kr": 46, "al": [-66, 0, -30], "ar": [-74, 0, 30], "move": [0, 0.75, 0.55]}],
		[0.46, "io", {"root": 214, "spine": 44, "ll": -76, "lr": -66, "kl": 112, "kr": 104, "move": [0, 1.25, 1.65]}],
		[0.84, "in", {"root": 330, "spine": 22, "ll": -32, "lr": -16, "kl": 40, "kr": 32, "al": [-120, 0, -60], "ar": [-130, 0, 60], "move": [0, 0.2, 2.8]}],
		[1.08, "in", {"root": 450, "spine": 4, "head": 8, "ll": 4, "lr": -8, "kl": 14, "kr": 22, "al": [-170, 0, -26], "ar": [-160, 0, 22], "move": [0, 0, 3.35]}],
		[1.2, "out", {"root": 445, "move": [0, 0, 3.45]}],
		[1.34, "in", {"root": 450, "move": [0, 0, 3.5]}]]},

	# --- Burning ---
	"fire_flail": {"cause": "fire", "hit": "any", "keys": [
		[0.2, "out", {"root": [0, 40, 0], "spine": [-12, 0, 10], "head": -24, "al": [-156, 0, -40], "ar": [-100, 0, 44], "el": 40}],
		[0.42, "io", {"root": [0, -30, 0], "spine": [10, 0, -12], "head": 10, "al": [-96, 0, -44], "ar": [-164, 0, 36], "er": 56, "kl": 34, "lr": -26}],
		[0.64, "io", {"root": [0, 58, 0], "spine": [-6, 0, 14], "al": [-168, 0, -28], "ar": [-90, 0, 50], "kr": 40, "ll": -30, "lr": 4, "kl": 8, "head": -18}],
		[0.86, "io", {"root": [0, -8, 0], "spine": [14, 0, -10], "al": [-100, 0, -52], "ar": [-160, 0, 26], "kr": 12, "kl": 44, "lr": -24, "ll": 4}],
		[1.1, "io", {"root": [8, 46, 0], "spine": [10, 0, 10], "al": [-160, 0, -30], "ar": [-100, 0, 40], "kl": 64, "kr": 70, "ll": -30, "lr": -30}],
		[1.54, "in", {"root": [90, 62, 0], "spine": 2, "head": [10, 26, 0], "al": [-170, 0, -36], "ar": [-124, 0, 44], "kl": 28, "kr": 40, "ll": 0, "lr": -8}],
		[1.66, "out", {"root": [85, 62, 0]}],
		[1.82, "in", {"root": [90, 62, 0], "al": [-150, 0, -42]}]]},
	"fire_kneel": {"cause": "fire", "hit": "any", "keys": [
		[0.24, "out", {"spine": -10, "head": -38, "al": [-150, 0, 24], "ar": [-156, 0, -24], "el": 100, "er": 96}],
		[0.62, "in", {"kl": 94, "kr": 98, "head": -30, "spine": -16}],
		[0.76, "out", {"spine": -8}],
		[1.14, "io", {"spine": 30, "head": 26, "al": [-110, 0, 30], "ar": [-120, 0, -24], "el": 120, "er": 124}],
		[1.54, "in", {"root": 88, "spine": 4, "head": 14, "kl": 34, "kr": 40, "ll": 6, "lr": 4, "al": [-150, 0, 30], "ar": [-158, 0, -30]}],
		[1.66, "out", {"root": 84}],
		[1.8, "in", {"root": 90}]]},
	"fire_roll": {"cause": "fire", "hit": "any", "keys": [
		[0.3, "in", {"root": [40, 20, -40], "spine": 24, "kl": 60, "kr": 74, "ll": -30, "lr": -34, "al": [-110, 0, 30], "ar": [-120, 0, -30], "el": 110, "er": 110, "head": 22, "move": [0.1, 0, 0]}],
		[0.62, "in", {"root": [0, 0, -90], "spine": 36, "kl": 96, "kr": 104, "ll": -60, "lr": -64, "move": [0.45, 0, 0]}],
		[0.98, "io", {"root": [0, 0, -180], "spine": 30, "ll": -40, "lr": -60, "move": [0.95, 0, 0]}],
		[1.36, "io", {"root": [0, 0, -270], "spine": 34, "kl": 110, "kr": 86, "move": [1.4, 0, 0]}],
		[1.84, "in", {"root": [0, 0, -360], "spine": 20, "ll": -66, "lr": -18, "kl": 120, "kr": 44, "al": [-80, 0, 10], "ar": [-140, 0, -8], "move": [1.75, 0, 0]}],
		[2.0, "out", {"root": [-90, 0, -360], "spine": 8, "move": [1.8, 0, 0]}]]},

	# --- Boomer ---
	"boomer_pop": {"only": "boomer", "hit": "any", "keys": [
		[0.16, "out", {"belly": 1.28, "spine": -8, "head": -22, "al": [-28, 0, -58], "ar": [-28, 0, 58]}],
		[0.34, "io", {"belly": 1.5, "spine": -14, "head": -30, "al": [-40, 0, -74], "ar": [-44, 0, 74], "kl": 16, "kr": 14}],
		[0.42, "out", {"belly": 0.72, "spine": 12, "head": 18, "al": [10, 0, -30], "ar": [12, 0, 30]}],
		[0.84, "in", {"kl": 120, "kr": 118, "ll": -70, "lr": -66, "belly": 0.68, "spine": 18, "head": 34}],
		[1.26, "in", {"root": -88, "spine": 8, "ll": -38, "lr": -30, "kl": 80, "kr": 64, "belly": 0.66, "head": 10, "al": [-20, 0, -60], "ar": [-14, 0, 58]}],
		[1.4, "out", {"root": -83}],
		[1.54, "in", {"root": -90}]]},
	"boomer_belly_flop": {"only": "boomer", "hit": "back", "keys": [
		[0.2, "out", {"root": 8, "spine": -20, "head": -20, "al": [-60, 0, -60], "ar": [-60, 0, 60], "belly": 1.12}],
		[0.66, "in", {"root": 90, "spine": -10, "al": [-120, 0, -70], "ar": [-120, 0, 70], "ll": 10, "lr": 10, "kl": 44, "kr": 40, "move": [0, 0, 0.2]}],
		[0.8, "out", {"root": 80, "belly": 1.26, "kl": 22, "kr": 18}],
		[0.98, "in", {"root": 90, "belly": 0.9, "head": 10, "kl": 34, "kr": 30}],
		[1.14, "out", {"root": 87, "belly": 1.02}],
		[1.28, "in", {"root": 90, "belly": 0.94}]]},
	"boomer_wobble_sit": {"only": "boomer", "hit": "front", "keys": [
		[0.24, "out", {"root": [0, 0, 8], "spine": [-6, 0, -8], "al": [-14, 0, -50], "ar": [-14, 0, 50], "belly": 1.1}],
		[0.5, "io", {"root": [0, 0, -9], "spine": [-6, 0, 10]}],
		[0.76, "io", {"root": [0, 0, 7], "spine": [-8, 0, -8], "kl": 26, "kr": 30}],
		[1.12, "in", {"root": 0, "spine": -18, "ll": [-82, 0, -18], "lr": [-80, 0, 18], "kl": 14, "kr": 20, "head": 6, "belly": 1.02}],
		[1.24, "out", {"spine": -8, "belly": 1.14}],
		[1.7, "in", {"root": -72, "spine": 2, "head": 14, "ll": [-44, 0, -20], "lr": [-38, 0, 20], "al": [-14, 0, -58], "ar": [-8, 0, 58], "belly": 0.96}],
		[1.84, "out", {"root": -68}],
		[1.98, "in", {"root": -73}]]},
	"boomer_retch": {"only": "boomer", "hit": "any", "keys": [
		[0.22, "out", {"spine": 30, "head": 18, "al": [-26, 0, 44], "ar": [-26, 0, -44], "el": 96, "er": 96, "belly": 1.2}],
		[0.42, "io", {"spine": 16, "head": -18, "belly": 1.04}],
		[0.66, "out", {"spine": 40, "head": 26, "belly": 1.26, "kl": 24, "kr": 18}],
		[0.86, "io", {"spine": 22, "head": -12, "belly": 1.0}],
		[1.1, "out", {"spine": 46, "head": 30, "kl": 96, "kr": 88, "belly": 1.2}],
		[1.56, "in", {"root": 86, "spine": 4, "head": 16, "kl": 30, "kr": 24, "al": [-46, 0, 20], "ar": [-64, 0, -6], "belly": 0.82}],
		[1.68, "out", {"root": 81}],
		[1.84, "in", {"root": 89, "belly": 0.76}]]},
	"boomer_roll_over": {"only": "boomer", "hit": "side", "keys": [
		[0.3, "out", {"root": [0, 0, -14], "spine": [0, 0, 14], "ar": [-10, 0, 80], "al": [-20, 0, -54], "lr": [0, 0, 18], "belly": 1.1}],
		[0.76, "in", {"root": [0, 0, -92], "spine": [6, 0, 8], "ll": -14, "lr": -6, "kl": 30, "kr": 14, "al": [-60, 0, -40], "ar": [-40, 0, 90], "move": [0.3, 0, 0]}],
		[1.3, "io", {"root": [0, 0, -180], "spine": 0, "al": [-90, 0, -80], "ar": [-90, 0, 80], "ll": [0, 0, -18], "lr": [0, 0, 18], "kl": 12, "kr": 12, "move": [1.1, 0, 0]}],
		[1.42, "out", {"root": [0, 0, -176], "belly": 1.14}],
		[1.6, "in", {"root": [-90, 0, -360], "belly": 1.0, "head": -8, "move": [1.15, 0, 0]}]]},
	"boomer_blowback": {"only": "boomer", "hit": "front", "keys": [
		[0.1, "out", {"root": -12, "spine": -30, "head": -36, "belly": 1.4, "al": [-40, 0, -82], "ar": [-40, 0, 82]}],
		[0.2, "out", {"belly": 0.78, "move": [0, 0.4, -0.6], "root": -34, "ll": -30, "lr": -18, "kl": 36}],
		[0.68, "in", {"root": -92, "spine": -8, "head": -8, "belly": 0.7, "al": [-110, 0, -76], "ar": [-100, 0, 76], "ll": -30, "lr": -14, "kl": 28, "kr": 12, "move": [0, 0, -1.7]}],
		[0.82, "out", {"root": -84, "move": [0, 0.08, -1.9]}],
		[0.98, "in", {"root": -90, "belly": 0.68, "al": [-80, 0, -82], "ar": [-74, 0, 80], "head": 2, "move": [0, 0, -2.0]}]]},

	# --- Hunter ---
	"hunter_hood_snap": {"only": "hunter", "hit": "front", "keys": [
		[0.1, "out", {"head": -44, "spine": -24, "al": [-70, 0, -40], "ar": [-74, 0, 40], "kl": 70, "kr": 74, "ll": -44, "lr": -46}],
		[0.28, "out", {"kl": 110, "kr": 112, "ll": -68, "lr": -70, "spine": -18}],
		[0.68, "in", {"root": -90, "spine": 12, "head": 2, "ll": -82, "lr": -60, "kl": 118, "kr": 96, "al": [-80, 0, -50], "ar": [-130, 0, 30]}],
		[0.82, "out", {"root": -84}],
		[0.96, "in", {"root": -90}]]},
	"hunter_pounce_crash": {"only": "hunter", "hit": "back", "keys": [
		[0.16, "out", {"root": 34, "spine": -14, "head": -22, "al": [-154, 0, -24], "ar": [-160, 0, 24], "ll": 24, "lr": 8, "kl": 40, "kr": 30, "move": [0, 0.7, 0.7]}],
		[0.46, "in", {"root": 90, "spine": -10, "al": [-172, 0, -30], "ar": [-168, 0, 30], "ll": 8, "lr": -4, "kl": 12, "kr": 22, "move": [0, 0, 1.7]}],
		[0.8, "out", {"root": 92, "move": [0, 0, 2.5], "al": [-120, 0, -56], "ar": [-134, 0, 50], "kl": 42, "kr": 26, "spine": -16}],
		[1.0, "in", {"root": 90, "spine": 0, "head": 8, "kl": 22, "kr": 14, "move": [0, 0, 2.55]}]]},
	"hunter_crouch_collapse": {"only": "hunter", "hit": "any", "keys": [
		[0.2, "out", {"kl": 122, "kr": 118, "ll": -72, "lr": -66, "spine": 26, "head": -14, "al": [-86, 0, -26], "ar": [-80, 0, 26], "el": 30, "er": 30}],
		[0.5, "io", {"spine": 40, "head": 8, "al": [-40, 0, -14], "ar": [-30, 0, 18]}],
		[0.9, "in", {"root": [0, 0, -82], "spine": 44, "head": 12, "kl": 130, "kr": 110, "ll": -82, "lr": -64, "al": [-72, 0, 6], "ar": [-20, 0, 40]}],
		[1.04, "out", {"root": [0, 0, -78]}],
		[1.18, "in", {"root": [0, 0, -86]}]]},
	"hunter_claw_rake": {"only": "hunter", "hit": "any", "keys": [
		[0.16, "out", {"spine": 16, "al": [-150, 0, -30], "ar": [-30, 0, 30], "el": 30, "head": -12}],
		[0.34, "out", {"spine": [24, -20, 0], "al": [-30, 0, 18], "ar": [-156, 0, -6], "er": 34}],
		[0.54, "out", {"spine": [24, 20, 0], "al": [-154, 0, -6], "ar": [-40, 0, 24], "kl": 40, "kr": 26}],
		[0.96, "in", {"root": 90, "spine": 2, "head": 10, "al": [-170, 0, -14], "ar": [-110, 0, 24], "kl": 26, "kr": 12}],
		[1.1, "out", {"root": 85}],
		[1.26, "in", {"root": 90, "al": [-166, 0, -20]}],
		[1.6, "io", {"al": [-152, 0, -20], "el": 26, "head": 4}]]},
	"hunter_backflip_fail": {"only": "hunter", "hit": "front", "keys": [
		[0.14, "out", {"root": -46, "spine": -24, "kl": 90, "kr": 84, "ll": -60, "lr": -58, "move": [0, 0.9, -0.2]}],
		[0.42, "io", {"root": -150, "spine": 18, "head": 18, "kl": 124, "kr": 120, "ll": -92, "lr": -88, "al": [-90, 0, -40], "ar": [-96, 0, 40], "move": [0, 1.2, -0.9]}],
		[0.68, "in", {"root": -240, "spine": 10, "kl": 76, "kr": 60, "ll": -44, "lr": -30, "move": [0, 0.15, -1.6]}],
		[0.84, "out", {"root": -254, "move": [0, 0, -1.8], "al": [-150, 0, -30], "ar": [-160, 0, 30]}],
		[1.06, "in", {"root": -270, "spine": 2, "head": 12, "kl": 26, "kr": 18, "ll": -6, "lr": 0, "move": [0, 0, -1.95]}]]},
	"hunter_scrabble": {"only": "hunter", "hit": "back", "keys": [
		[0.3, "in", {"root": 78, "spine": 10, "head": -24, "al": [-140, 0, -28], "ar": [-90, 0, 24], "kl": 50, "kr": 30, "ll": -12}],
		[0.42, "out", {"root": 74}],
		[0.56, "in", {"root": 80, "al": [-100, 0, -30], "ar": [-156, 0, 20], "kl": 22, "kr": 54, "lr": -14, "ll": 2, "move": [0, 0, 0.14]}],
		[0.82, "io", {"al": [-158, 0, -22], "ar": [-100, 0, 26], "kl": 56, "kr": 24, "ll": -14, "lr": 0, "move": [0, 0, 0.32]}],
		[1.08, "io", {"al": [-110, 0, -26], "ar": [-150, 0, 18], "kl": 20, "kr": 38, "move": [0, 0, 0.42]}],
		[1.42, "in", {"root": 90, "spine": 0, "head": 12, "al": [-124, 0, -32], "ar": [-168, 0, 16], "kl": 12, "kr": 14}]]},

	# --- Smoker ---
	"smoker_choke": {"only": "smoker", "hit": "any", "keys": [
		[0.26, "out", {"al": [-118, 0, 34], "ar": [-122, 0, -34], "el": 132, "er": 128, "head": -28, "spine": -6}],
		[0.5, "io", {"spine": 10, "head": 14, "kl": 18}],
		[0.76, "io", {"spine": -8, "head": -30, "kl": 0, "kr": 22}],
		[1.0, "io", {"spine": 16, "head": 18, "kr": 34, "kl": 28}],
		[1.34, "in", {"kl": 104, "kr": 110, "spine": 26, "head": 24}],
		[1.74, "in", {"root": [0, 0, -86], "spine": 26, "head": 18, "ll": -24, "lr": -40, "kl": 90, "kr": 84}],
		[1.86, "out", {"root": [0, 0, -82]}],
		[2.02, "in", {"root": [0, 0, -90]}]]},
	"smoker_cough_fit": {"only": "smoker", "hit": "any", "keys": [
		[0.14, "out", {"spine": 32, "head": 26, "al": [-40, 0, 30], "ar": [-30, 0, -14], "el": 100}],
		[0.3, "io", {"spine": 12, "head": -8}],
		[0.44, "out", {"spine": 36, "head": 30}],
		[0.6, "io", {"spine": 14, "head": -6}],
		[0.74, "out", {"spine": 40, "head": 32, "kl": 44, "kr": 30}],
		[1.14, "io", {"root": [8, 0, 0], "spine": 50, "head": 18, "kl": 88, "kr": 76, "ll": -18, "lr": -14}],
		[1.56, "in", {"root": 90, "spine": 4, "head": 14, "kl": 18, "kr": 30, "ll": 0, "lr": -8, "al": [-140, 0, -24], "ar": [-30, 0, 24], "el": 30}],
		[1.68, "out", {"root": 85}],
		[1.82, "in", {"root": 90}]]},
	"smoker_long_topple": {"only": "smoker", "hit": "front", "keys": [
		[0.3, "io", {"root": -5, "spine": -12, "head": -20, "al": [-8, 0, -12], "ar": [-8, 0, 12]}],
		[0.62, "io", {"root": 6, "spine": -4, "head": -8}],
		[1.3, "in", {"root": -90, "spine": 0, "head": -6, "al": [-6, 0, -34], "ar": [-6, 0, 30], "ll": -6, "lr": 6}],
		[1.4, "out", {"root": -87, "head": 12}],
		[1.52, "in", {"root": -90, "head": 2, "al": [0, 0, -46], "ar": [0, 0, 42]}]]},
	"smoker_tongue_whip": {"only": "smoker", "hit": "side", "keys": [
		[0.1, "out", {"head": [-20, -40, -26], "spine": [0, -22, 0], "al": [-60, 0, -40], "ar": [-30, 0, 60]}],
		[0.3, "out", {"head": [10, 44, 26], "spine": [0, 26, 0], "root": [0, 30, 0]}],
		[0.5, "out", {"head": [-16, -32, -20], "spine": [0, -18, 0], "root": [0, -10, 0], "kl": 24}],
		[0.98, "in", {"root": [0, 40, -90], "spine": [8, 0, 0], "head": [0, 20, 0], "ar": [-90, 0, 80], "al": [-30, 0, -30], "kl": 36, "kr": 20, "ll": -22}],
		[1.1, "out", {"root": [0, 40, -86]}],
		[1.24, "in", {"root": [0, 40, -90]}]]},
	"smoker_kneel_wheeze": {"only": "smoker", "hit": "back", "keys": [
		[0.42, "in", {"kl": 98, "kr": 94, "spine": 10, "head": 22, "al": [-10, 0, 0], "ar": [-10, 0, 0]}],
		[0.8, "io", {"spine": 34, "head": 10, "al": [-58, 0, -6], "ar": [-60, 0, 6], "el": 40, "er": 42}],
		[1.14, "io", {"spine": 22, "head": -20}],
		[1.5, "io", {"spine": 40, "head": 20}],
		[1.96, "in", {"root": 88, "spine": 2, "head": 12, "kl": 28, "kr": 32, "al": [-160, 0, -16], "ar": [-140, 0, 24], "el": 10, "er": 30}],
		[2.08, "out", {"root": 82}],
		[2.22, "in", {"root": 90}]]},
	"smoker_spiral_down": {"only": "smoker", "hit": "any", "keys": [
		[0.4, "io", {"root": [0, 120, 0], "spine": [10, 16, 0], "kl": 28, "kr": 18, "al": [-50, 0, -70], "ar": [-10, 0, 70]}],
		[0.8, "io", {"root": [0, 260, 0], "spine": [18, 24, 0], "kl": 74, "kr": 62, "ll": -32, "lr": -30, "head": 20}],
		[1.2, "in", {"root": [0, 380, 0], "spine": [26, 20, 0], "kl": 128, "kr": 122, "ll": -74, "lr": -70, "head": 30}],
		[1.6, "in", {"root": [-88, 420, 0], "spine": 12, "ll": -44, "lr": -30, "kl": 96, "kr": 60, "al": [-30, 0, -80], "ar": [-30, 0, 80], "head": 0}],
		[1.72, "out", {"root": [-84, 420, 0]}],
		[1.86, "in", {"root": [-90, 420, 0]}]]},

	# --- Spitter ---
	"spitter_melt": {"upright": true, "only": "spitter", "hit": "any", "keys": [
		[0.4, "io", {"kl": 42, "kr": 48, "ll": -22, "lr": -24, "spine": 16, "head": 36, "al": [-12, 0, -14], "ar": [-12, 0, 14]}],
		[0.9, "io", {"kl": 104, "kr": 108, "ll": -56, "lr": -58, "spine": 30, "head": 48, "belly": 0.82, "al": [10, 0, -40], "ar": [10, 0, 40]}],
		[1.4, "io", {"kl": 148, "kr": 150, "ll": -78, "lr": -82, "spine": 52, "head": 54, "belly": 0.7, "al": [-30, 0, -50], "ar": [-30, 0, 50]}],
		[1.9, "io", {"root": [14, 0, 8], "spine": 66, "head": 50, "al": [-90, 0, -54], "ar": [-90, 0, 54], "belly": 0.62}]]},
	"spitter_neck_droop": {"only": "spitter", "hit": "any", "keys": [
		[0.24, "out", {"head": 64, "spine": 8, "al": [6, 0, -10], "ar": [6, 0, 10]}],
		[0.46, "io", {"head": 40}],
		[0.7, "in", {"head": 76, "spine": 16, "kl": 30, "kr": 24}],
		[1.14, "in", {"root": 74, "spine": 2, "kl": 40, "kr": 30, "al": [-20, 0, -26], "ar": [-14, 0, 26], "head": 60}],
		[1.28, "out", {"root": 70}],
		[1.42, "in", {"root": 86, "head": 34}]]},
	"spitter_acid_heave": {"only": "spitter", "hit": "front", "keys": [
		[0.22, "out", {"spine": -24, "head": -40, "belly": 1.2, "al": [10, 0, -40], "ar": [10, 0, 40]}],
		[0.44, "out", {"spine": 28, "head": 30, "belly": 0.8}],
		[0.66, "io", {"spine": -14, "head": -34, "belly": 1.16, "kl": 26}],
		[0.86, "out", {"spine": 34, "head": 36, "belly": 0.76, "kr": 30}],
		[1.3, "in", {"root": -88, "spine": 10, "ll": -24, "lr": -34, "kl": 54, "kr": 70, "head": 0, "al": [-30, 0, -60], "ar": [-20, 0, 56]}],
		[1.42, "out", {"root": -84}],
		[1.56, "in", {"root": -90}]]},
	"spitter_sink_spiral": {"only": "spitter", "hit": "side", "keys": [
		[0.3, "io", {"root": [0, 70, -4], "spine": [0, 24, 10], "kl": 22, "ar": [-20, 0, 70], "al": [-20, 0, -44]}],
		[0.7, "io", {"root": [0, 170, -8], "spine": [14, 22, 10], "kl": 88, "kr": 78, "ll": -40, "lr": -30, "head": 24}],
		[1.14, "in", {"root": [0, 250, -84], "spine": [26, 0, 6], "ll": -58, "lr": -30, "kl": 104, "kr": 66, "head": [10, 0, -10]}],
		[1.26, "out", {"root": [0, 250, -80]}],
		[1.4, "in", {"root": [0, 250, -88]}]]},
	"spitter_back_arch": {"only": "spitter", "hit": "front", "keys": [
		[0.2, "out", {"spine": -36, "head": -50, "al": [-20, 0, -74], "ar": [-20, 0, 74], "hip": 6}],
		[0.6, "in", {"root": -10, "kl": 92, "kr": 94, "ll": -18, "lr": -16, "spine": -46, "head": -48}],
		[1.04, "in", {"root": -50, "spine": -34, "kl": 120, "kr": 118, "ll": -6, "lr": 0, "head": -30}],
		[1.3, "in", {"root": -88, "spine": -10, "ll": -32, "lr": -26, "kl": 124, "kr": 112, "head": -6, "al": [0, 0, -96], "ar": [0, 0, 96]}],
		[1.44, "out", {"root": -84}],
		[1.58, "in", {"root": -90}]]},
	"spitter_sprawl": {"only": "spitter", "hit": "back", "keys": [
		[0.16, "out", {"root": 10, "spine": -18, "head": -28, "al": [10, 0, -44], "ar": [10, 0, 44]}],
		[0.64, "in", {"root": 90, "spine": 2, "al": [-100, 0, -40], "ar": [-40, 0, 70], "ll": [0, 0, -22], "lr": [-6, 0, 28], "kl": 6, "kr": 44, "head": [18, 0, 0], "move": [0, 0, 0.3]}],
		[0.76, "out", {"root": 84}],
		[0.9, "in", {"root": 90, "head": [28, 0, 18]}]]},

	# --- Tank ---
	"tank_tree_fall": {"only": "tank", "hit": "back", "keys": [
		[0.36, "io", {"root": -4, "spine": -16, "head": -26, "al": [-20, 0, -30], "ar": [-20, 0, 30]}],
		[0.72, "io", {"root": 8, "spine": -4, "lr": -16, "kr": 22, "head": -6}],
		[1.34, "in", {"root": 90, "spine": 0, "al": [-40, 0, -46], "ar": [-40, 0, 46], "lr": -4, "kr": 8, "head": 12}],
		[1.42, "out", {"root": 87, "head": -4}],
		[1.56, "in", {"root": 90, "head": 8, "al": [-34, 0, -56], "ar": [-34, 0, 56]}]]},
	"tank_knee_thud": {"only": "tank", "hit": "any", "keys": [
		[0.34, "out", {"spine": -8, "head": -24, "kl": 34, "ll": -20, "al": [-12, 0, -40], "ar": [-12, 0, 40]}],
		[0.62, "in", {"kl": 98, "ll": -4, "spine": 10, "head": 4, "kr": 40, "lr": -26}],
		[0.98, "io", {"ar": [-64, 0, 14], "er": 20, "spine": 18, "head": 18}],
		[1.3, "in", {"kr": 96, "lr": -2, "spine": 24, "head": 26, "ar": [-20, 0, 26]}],
		[1.82, "in", {"root": 90, "spine": 2, "kl": 26, "kr": 30, "al": [-64, 0, -40], "ar": [-60, 0, 40], "head": 14}],
		[1.9, "out", {"root": 87}],
		[2.02, "in", {"root": 90}]]},
	"tank_roar_back": {"only": "tank", "hit": "front", "keys": [
		[0.42, "out", {"spine": -26, "head": -44, "al": [-110, 0, -76], "ar": [-110, 0, 76], "el": 60, "er": 60, "belly": 1.08}],
		[0.84, "io", {"spine": -30, "head": -50, "al": [-130, 0, -70], "ar": [-130, 0, 70], "lr": 14, "ll": -10}],
		[1.5, "in", {"root": -90, "spine": -4, "head": -4, "al": [-80, 0, -86], "ar": [-80, 0, 86], "el": 16, "er": 16, "ll": -16, "lr": 6, "kl": 20, "belly": 1.0}],
		[1.58, "out", {"root": -87}],
		[1.7, "in", {"root": -90}]]},
	"tank_sit_thud": {"upright": true, "only": "tank", "hit": "front", "keys": [
		[0.3, "out", {"spine": -10, "head": -18, "kl": 18, "kr": 18}],
		[0.76, "in", {"ll": [-80, 0, -18], "lr": [-82, 0, 18], "kl": 8, "kr": 16, "spine": -10, "al": [10, 0, -30], "ar": [10, 0, 30]}],
		[0.84, "out", {"spine": -4, "head": 12}],
		[1.3, "io", {"spine": 26, "head": 30}],
		[1.8, "in", {"spine": 44, "head": 44, "al": [-20, 0, -14], "ar": [-20, 0, 14], "el": 14, "er": 14}]]},
	"tank_last_swing": {"only": "tank", "hit": "any", "keys": [
		[0.36, "out", {"spine": [0, 34, 0], "ar": [-120, 0, 60], "er": 70, "head": -10}],
		[0.62, "in", {"spine": [14, -46, 0], "ar": [-110, 0, -30], "er": 10, "root": [0, -20, 0], "lr": -20}],
		[0.84, "out", {"spine": [22, -60, 0], "root": [0, -34, 0], "kr": 30}],
		[1.42, "in", {"root": [88, -56, 0], "spine": [4, -10, 0], "ar": [-90, 0, 20], "al": [-30, 0, -50], "ll": 0, "lr": -8, "kr": 16, "er": 20}],
		[1.5, "out", {"root": [85, -56, 0]}],
		[1.62, "in", {"root": [90, -56, 0]}]]},
	"tank_fist_slam": {"only": "tank", "hit": "any", "keys": [
		[0.42, "io", {"spine": -14, "head": -30, "al": [-166, 0, -10], "ar": [-166, 0, 10], "el": 30, "er": 30, "kl": 16, "kr": 16}],
		[0.76, "in", {"spine": 52, "head": 10, "al": [-96, 0, 0], "ar": [-96, 0, 0], "el": 0, "er": 0, "kl": 92, "kr": 88}],
		[0.86, "out", {"spine": 46}],
		[1.3, "io", {"spine": 54, "head": 26, "al": [-74, 0, -14], "ar": [-74, 0, 14]}],
		[1.8, "in", {"root": 86, "spine": 8, "kl": 30, "kr": 40, "al": [-150, 0, -30], "ar": [-90, 0, 40], "head": 14}],
		[1.88, "out", {"root": 83}],
		[2.0, "in", {"root": 90}]]},

	# --- Witch ---
	"witch_shriek": {"only": "witch", "hit": "any", "keys": [
		[0.26, "out", {"spine": -30, "head": -56, "al": [-120, 0, -64], "ar": [-120, 0, 64], "el": 16, "er": 16}],
		[0.8, "io", {"spine": -34, "head": -62, "al": [-136, 0, -60], "ar": [-136, 0, 60]}],
		[1.08, "in", {"spine": 40, "head": 50, "al": [0, 0, -16], "ar": [0, 0, 16], "el": 0, "er": 0, "kl": 110, "kr": 116, "ll": -56, "lr": -60}],
		[1.54, "in", {"root": [0, 0, -88], "spine": 34, "head": 30, "kl": 124, "kr": 100, "ll": -74, "lr": -54, "al": [-60, 0, 0], "ar": [-30, 0, 30]}],
		[1.66, "out", {"root": [0, 0, -84]}],
		[1.8, "in", {"root": [0, 0, -90]}]]},
	"witch_weep_curl": {"only": "witch", "hit": "any", "keys": [
		[0.3, "out", {"al": [-136, 0, 30], "ar": [-140, 0, -30], "el": 120, "er": 124, "spine": 26, "head": 34}],
		[0.8, "io", {"kl": 134, "kr": 136, "ll": -74, "lr": -76, "spine": 40, "head": 38}],
		[1.1, "io", {"spine": 34}],
		[1.4, "io", {"spine": 44}],
		[1.9, "in", {"root": [0, 0, 88], "spine": 46, "head": 28, "ll": -96, "lr": -88, "kl": 126, "kr": 130}],
		[2.02, "out", {"root": [0, 0, 84]}],
		[2.16, "in", {"root": [0, 0, 90]}]]},
	"witch_claw_air": {"only": "witch", "hit": "front", "keys": [
		[0.14, "out", {"spine": -14, "head": -22, "al": [-150, 0, -30], "ar": [-90, 0, 30]}],
		[0.3, "out", {"al": [-70, 0, -18], "ar": [-160, 0, 24]}],
		[0.46, "out", {"al": [-160, 0, -24], "ar": [-70, 0, 18], "kr": 30}],
		[0.62, "out", {"al": [-80, 0, -18], "ar": [-156, 0, 22], "kl": 26, "kr": 14}],
		[1.06, "in", {"root": -90, "spine": -4, "ar": [-140, 0, 40], "al": [-50, 0, -60], "ll": -18, "lr": -6, "kl": 30, "kr": 10, "head": 2}],
		[1.16, "out", {"root": -85}],
		[1.3, "in", {"root": -90}],
		[1.7, "io", {"ar": [-100, 0, 54], "er": 26}]]},
	"witch_spin_faint": {"only": "witch", "hit": "side", "keys": [
		[0.3, "out", {"root": [0, 130, 0], "spine": [-10, 0, 0], "head": -24, "al": [-30, 0, -92], "ar": [-30, 0, 92]}],
		[0.62, "io", {"root": [0, 260, -4], "head": -10, "kl": 18, "al": [-10, 0, -80], "ar": [-10, 0, 80]}],
		[1.04, "in", {"root": [-90, 330, 0], "head": [0, 24, 0], "spine": -4, "al": [0, 0, -100], "ar": [-40, 0, 70], "ll": -8, "lr": -22, "kl": 8, "kr": 44}],
		[1.14, "out", {"root": [-86, 330, 0]}],
		[1.28, "in", {"root": [-90, 330, 0]}]]},
	"witch_sit_back": {"upright": true, "only": "witch", "hit": "back", "keys": [
		[0.3, "in", {"ll": -84, "lr": -86, "kl": 74, "kr": 82, "spine": 24, "head": 34, "al": [-80, 0, -6], "ar": [-80, 0, 6]}],
		[0.42, "out", {"spine": 16}],
		[1.0, "io", {"spine": 54, "head": 44, "al": [-120, 0, -14], "ar": [-120, 0, 14], "el": 20, "er": 20}],
		[1.5, "io", {"spine": 74, "head": 34, "al": [-164, 0, -14], "ar": [-170, 0, 14]}]]},
	"witch_crumple_bow": {"only": "witch", "hit": "back", "keys": [
		[0.16, "out", {"spine": -22, "head": -30, "al": [20, 0, -34], "ar": [20, 0, 34]}],
		[0.56, "in", {"spine": 60, "head": 40, "al": [-30, 0, -8], "ar": [-30, 0, 8], "kl": 34, "kr": 34}],
		[0.98, "in", {"root": 8, "spine": 72, "head": 40, "kl": 118, "kr": 118, "ll": -38, "lr": -40}],
		[1.42, "in", {"root": 88, "spine": 4, "head": 14, "kl": 26, "kr": 30, "ll": 0, "lr": 0, "al": [-170, 0, -16], "ar": [-166, 0, 16]}],
		[1.54, "out", {"root": 84}],
		[1.68, "in", {"root": 90}]]},
}

static var _compiled := {}
static var _ids: Array = []
static var _recent := {}


static func ids() -> Array:
	if _ids.is_empty():
		_ids = CLIPS.keys()
		_ids.sort()
	return _ids


## Everything a type can die from.
static func for_type(type: String) -> Array:
	return ids().filter(func(id): return _fits(CLIPS[id], type))


static func _fits(clip: Dictionary, type: String) -> bool:
	if clip.has("only"):
		return clip.only == type
	return type != "tank" or not clip.get("light", false)


## Packs a clip and whether it is mirrored into one number that replicates cheaply.
static func encode(id: String, mirror: bool) -> int:
	return ids().find(id) * 2 + int(mirror)


static func decode(code: int) -> Dictionary:
	return compiled(ids()[code >> 1], code & 1 == 1)


## type: infected type. kind: take_hit's kind. push: blow direction in the victim's space.
static func pick(type: String, kind: String, headshot: bool, push: Vector3, rng: RandomNumberGenerator) -> int:
	var cause := "body"
	if kind == "fire" or kind == "blast":
		cause = kind
	elif headshot:
		cause = "head"
	var hit := "any"
	if push.length() > 0.01:
		hit = "side" if absf(push.x) > absf(push.z) else ("front" if push.z < 0.0 else "back")
	var own: Array = []
	var shared: Array = []
	for id: String in for_type(type):
		var clip: Dictionary = CLIPS[id]
		var aimed: bool = hit == "any" or clip.hit == "any" or clip.hit == hit
		if clip.has("only"):
			if aimed:
				own.append(id)
		elif clip.cause == cause and aimed:
			shared.append(id)
	if shared.is_empty():
		shared = for_type(type).filter(func(id): return CLIPS[id].get("cause", "") == "body" and not CLIPS[id].has("only"))
	var pool := own if not own.is_empty() and rng.randf() < SPECIES_SHARE else shared
	var recent: Array = _recent.get_or_add(type, [])
	var fresh := pool.filter(func(id): return id not in recent)
	var id: String = (fresh if not fresh.is_empty() else pool)[rng.randi() % (fresh if not fresh.is_empty() else pool).size()]
	recent.append(id)
	if recent.size() > RECENT:
		recent.pop_front()
	var mirror := push.x < 0.0 if CLIPS[id].hit == "side" else rng.randf() < 0.5
	return encode(id, mirror)


## Turns a sparse authored clip into full keys of radians, ready to play.
static func compiled(id: String, mirror: bool) -> Dictionary:
	var name := id + ("~" if mirror else "")
	if _compiled.has(name):
		return _compiled[name]
	var clip: Dictionary = CLIPS[id]
	var pose := {}
	for channel: String in CHANNELS:
		pose[channel] = Vector3.ONE if channel == "belly" else Vector3.ZERO
	var keys: Array = []
	for key: Array in clip["keys"]:
		for channel: String in key[2]:
			pose[channel] = _channel(channel, key[2][channel])
		var values: Array = []
		for channel: String in CHANNELS:
			var value: Vector3 = pose[(SWAPS.get(channel, channel) if mirror else channel)]
			if mirror and channel != "belly":
				value = Vector3(-value.x, value.y, value.z) if channel == "move" else Vector3(value.x, -value.y, -value.z)
			values.append(value)
		keys.append({"t": float(key[0]), "ease": key[1], "pose": values})
	var result := {"id": id, "keys": keys, "dur": float(keys[-1].t)}
	_compiled[name] = result
	return result


static func _channel(channel: String, value: Variant) -> Vector3:
	var v := Vector3(value[0], value[1], value[2]) if value is Array else Vector3(float(value), 0, 0)
	if channel == "belly":
		return Vector3.ONE * v.x
	return v if channel == "move" else v * (PI / 180.0)


static func eased(style: String, t: float) -> float:
	match style:
		"in":
			return t * t
		"out":
			return 1.0 - (1.0 - t) * (1.0 - t)
	return t * t * (3.0 - 2.0 * t)
