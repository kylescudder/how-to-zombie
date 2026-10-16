class_name DB
## Static game data: weapons, rods, zombies, islands, quests and hats.
## Tweak numbers here to rebalance the game.

const WATER_LEVEL := 0.0

# kind: "rod", "melee", "gun", "throw"
const WEAPONS := {
	"rod": {"name": "Rod", "kind": "rod", "price": 0},
	"fists": {"name": "Slappers", "kind": "melee", "price": 0, "damage": 6.0, "range": 2.2, "cooldown": 0.4, "knock": 7.0},
	"knife": {"name": "Rusty Knife", "kind": "melee", "price": 0, "damage": 20.0, "range": 2.3, "cooldown": 0.38, "knock": 2.0},
	"knuckles": {"name": "Brass Knuckles", "kind": "melee", "price": 150, "damage": 30.0, "range": 2.1, "cooldown": 0.32, "knock": 10.0},
	"bat": {"name": "Nail Bat", "kind": "melee", "price": 450, "damage": 45.0, "range": 2.7, "cooldown": 0.75, "knock": 24.0},
	"pistol": {"name": "Pea Shooter", "kind": "gun", "price": 300, "damage": 24.0, "cooldown": 0.28, "mag": 8, "reload": 1.1, "spread": 0.012, "pellets": 1, "knock": 2.5},
	"shotgun": {"name": "Boomstick", "kind": "gun", "price": 900, "damage": 13.0, "cooldown": 0.85, "mag": 4, "reload": 1.8, "spread": 0.085, "pellets": 8, "knock": 4.0},
	"smg": {"name": "Brrrt-9", "kind": "gun", "price": 1600, "damage": 11.0, "cooldown": 0.075, "mag": 30, "reload": 1.5, "spread": 0.035, "pellets": 1, "knock": 1.2},
	"harpoon": {"name": "Harpoon Gun", "kind": "gun", "price": 2600, "damage": 85.0, "cooldown": 1.3, "mag": 1, "reload": 1.2, "spread": 0.0, "pellets": 1, "knock": 30.0},
	"dynamite": {"name": "Dynamite", "kind": "throw", "price": 1200, "damage": 120.0, "cooldown": 2.5, "radius": 6.0, "knock": 26.0},
}

const WEAPON_ORDER := ["rod", "fists", "knife", "knuckles", "bat", "pistol", "shotgun", "smg", "harpoon", "dynamite"]
const STARTING_ITEMS := ["rod", "fists", "knife", "rod_1"]

# Rods: cast = throw distance, reel = reel speed, line = tension resistance, tier = biggest zombie tier you can hook.
const RODS := {
	"rod_1": {"name": "Stick & String", "price": 0, "cast": 1.0, "reel": 1.0, "line": 1.0, "tier": 1, "lure": 1.0, "color": Color(0.55, 0.38, 0.2)},
	"rod_2": {"name": "Fibreglass Fury", "price": 500, "cast": 1.3, "reel": 1.3, "line": 1.35, "tier": 2, "lure": 0.8, "color": Color(0.2, 0.6, 0.9)},
	"rod_3": {"name": "Carbon Deadliner", "price": 2200, "cast": 1.6, "reel": 1.7, "line": 1.8, "tier": 3, "lure": 0.65, "color": Color(0.15, 0.15, 0.17)},
	"rod_4": {"name": "The Golden Gaff", "price": 6500, "cast": 2.0, "reel": 2.2, "line": 2.5, "tier": 4, "lure": 0.5, "color": Color(1.0, 0.8, 0.2)},
}
const ROD_ORDER := ["rod_1", "rod_2", "rod_3", "rod_4"]

# fight = how hard it pulls on the line (0..1+)
const ZOMBIES := {
	"shambler": {"name": "Shambler", "tier": 1, "hp": 40.0, "speed": 1.7, "damage": 10.0, "value": 25, "fight": 0.35,
		"skin": Color(0.48, 0.66, 0.38), "shirt": Color(0.75, 0.3, 0.25), "pants": Color(0.25, 0.3, 0.5)},
	"drowned": {"name": "Drowned", "tier": 1, "hp": 32.0, "speed": 2.4, "damage": 8.0, "value": 32, "fight": 0.45,
		"skin": Color(0.45, 0.62, 0.68), "shirt": Color(0.9, 0.85, 0.7), "pants": Color(0.3, 0.25, 0.2)},
	"runner": {"name": "Runner", "tier": 2, "hp": 36.0, "speed": 4.6, "damage": 8.0, "value": 65, "fight": 0.6,
		"skin": Color(0.6, 0.7, 0.35), "shirt": Color(0.95, 0.85, 0.2), "pants": Color(0.15, 0.15, 0.2)},
	"bloater": {"name": "Bloater", "tier": 2, "hp": 60.0, "speed": 1.2, "damage": 12.0, "value": 85, "fight": 0.5, "explodes": true,
		"skin": Color(0.62, 0.72, 0.3), "shirt": Color(0.55, 0.75, 0.3), "pants": Color(0.4, 0.3, 0.25), "belly": 1.7},
	"diver": {"name": "Scuba Steve", "tier": 3, "hp": 95.0, "speed": 3.2, "damage": 14.0, "value": 160, "fight": 0.75,
		"skin": Color(0.4, 0.55, 0.45), "shirt": Color(0.1, 0.1, 0.12), "pants": Color(0.1, 0.1, 0.12), "hat": "goggles"},
	"brute": {"name": "Brute", "tier": 3, "hp": 230.0, "speed": 2.0, "damage": 28.0, "value": 240, "fight": 0.95, "scale": 1.6,
		"skin": Color(0.42, 0.55, 0.32), "shirt": Color(0.3, 0.3, 0.32), "pants": Color(0.35, 0.25, 0.15)},
	"golden": {"name": "Golden Boy", "tier": 1, "hp": 50.0, "speed": 5.2, "damage": 5.0, "value": 400, "fight": 0.9, "rare": true,
		"skin": Color(1.0, 0.82, 0.25), "shirt": Color(1.0, 0.9, 0.4), "pants": Color(0.9, 0.7, 0.2)},
	"mini": {"name": "Lil' Biter", "tier": 1, "hp": 14.0, "speed": 3.6, "damage": 5.0, "value": 8, "fight": 0.2, "scale": 0.6,
		"skin": Color(0.5, 0.7, 0.4), "shirt": Color(0.8, 0.4, 0.6), "pants": Color(0.3, 0.3, 0.5)},
	# Bosses
	"big_bloaty": {"name": "BIG BLOATY", "tier": 9, "hp": 1400.0, "speed": 1.6, "damage": 25.0, "value": 1500, "fight": 1.0, "scale": 3.0, "boss": true, "explodes": true,
		"skin": Color(0.6, 0.75, 0.28), "shirt": Color(0.4, 0.6, 0.85), "pants": Color(0.3, 0.3, 0.4), "belly": 2.0, "hat": "captain"},
	"grill_dad": {"name": "GRILL DAD", "tier": 9, "hp": 2800.0, "speed": 2.6, "damage": 30.0, "value": 4000, "fight": 1.0, "scale": 2.6, "boss": true,
		"skin": Color(0.55, 0.68, 0.38), "shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.75, 0.6, 0.4), "hat": "chef", "belly": 1.4},
	"mall_santa": {"name": "MALL SANTA", "tier": 9, "hp": 5000.0, "speed": 2.2, "damage": 35.0, "value": 10000, "fight": 1.0, "scale": 3.2, "boss": true,
		"skin": Color(0.6, 0.7, 0.45), "shirt": Color(0.85, 0.1, 0.12), "pants": Color(0.85, 0.1, 0.12), "hat": "santa", "belly": 1.6},
}

const ISLANDS := [
	{
		"name": "Bait & Tackle Pier",
		"boss": "big_bloaty", "bait_price": 200,
		"table": {"shambler": 60, "drowned": 35, "runner": 6, "bloater": 4, "golden": 2},
		"sky_top": Color(0.35, 0.6, 0.95), "sky_horizon": Color(0.95, 0.75, 0.6), "water": Color(0.15, 0.45, 0.5), "fog": Color(0.85, 0.75, 0.7),
		"quests": [
			{"id": "catch", "goal": 3, "text": "Reel in %d zombies"},
			{"id": "sell", "goal": 150, "text": "Sell $%d of zombie"},
			{"id": "combo", "goal": 1, "text": "Score a x2 kill (trick shot!)"},
			{"id": "bait", "goal": 1, "text": "Buy Boss Bait from Doc"},
			{"id": "boss", "goal": 1, "text": "Pour the chum & kill BIG BLOATY"},
		],
	},
	{
		"name": "Cul-de-Sac Reef",
		"boss": "grill_dad", "bait_price": 900,
		"table": {"shambler": 30, "drowned": 25, "runner": 30, "bloater": 15, "diver": 6, "brute": 3, "golden": 2},
		"sky_top": Color(0.45, 0.5, 0.85), "sky_horizon": Color(1.0, 0.6, 0.45), "water": Color(0.2, 0.4, 0.35), "fog": Color(0.9, 0.65, 0.55),
		"quests": [
			{"id": "catch", "goal": 8, "text": "Reel in %d zombies"},
			{"id": "headshot", "goal": 3, "text": "Land %d headshot kills"},
			{"id": "airborne", "goal": 1, "text": "AIR MAIL: kill one mid-air"},
			{"id": "bait", "goal": 1, "text": "Buy Boss Bait from Doc"},
			{"id": "boss", "goal": 1, "text": "Pour the chum & kill GRILL DAD"},
		],
	},
	{
		"name": "Mega-Mall Atoll",
		"boss": "mall_santa", "bait_price": 2800,
		"table": {"runner": 25, "bloater": 20, "diver": 25, "brute": 18, "shambler": 10, "golden": 3},
		"sky_top": Color(0.25, 0.2, 0.5), "sky_horizon": Color(0.95, 0.45, 0.55), "water": Color(0.15, 0.3, 0.4), "fog": Color(0.6, 0.4, 0.55),
		"quests": [
			{"id": "catch_tier3", "goal": 2, "text": "Reel in %d tier-3 zombies"},
			{"id": "sell", "goal": 3000, "text": "Sell $%d of zombie"},
			{"id": "slot", "goal": 1, "text": "Gamble a corpse at the Lucky Brain"},
			{"id": "bait", "goal": 1, "text": "Buy Boss Bait from Doc"},
			{"id": "boss", "goal": 1, "text": "Pour the chum & kill MALL SANTA"},
		],
	},
]

const HATS := ["none", "bucket", "cone", "viking", "crown", "propeller", "chef", "party", "pot", "santa"]
const HAT_NAMES := {
	"none": "No Hat", "bucket": "Bucket Hat", "cone": "Traffic Cone", "viking": "Viking Helm", "crown": "Crown",
	"propeller": "Propeller Cap", "chef": "Chef Hat", "party": "Party Hat", "pot": "Cooking Pot", "santa": "Santa Hat",
}

const PLAYER_COLORS := [Color(0.95, 0.45, 0.2), Color(0.25, 0.6, 0.95), Color(0.95, 0.8, 0.2), Color(0.75, 0.35, 0.9)]

# Kill style bonuses (added together, then +1). Shown as popups.
const BONUSES := {
	"headshot": {"text": "HEADSHOT", "value": 0.5},
	"airborne": {"text": "AIR MAIL", "value": 1.0},
	"explosion": {"text": "KABOOM", "value": 0.5},
	"slap": {"text": "SLAPPED TO DEATH", "value": 2.0},
	"melee": {"text": "UP CLOSE", "value": 0.2},
	"homerun": {"text": "HOME RUN", "value": 1.0},
	"longshot": {"text": "LONG SHOT", "value": 0.5},
	"multikill": {"text": "MULTI-KILL", "value": 0.5},
	"overkill": {"text": "OVERKILL", "value": 0.25},
	"water": {"text": "DROWNED TWICE", "value": 0.5},
	"chain": {"text": "CHAIN REACTION", "value": 0.75},
	"harpoon": {"text": "SKEWERED", "value": 0.5},
}


static func zombie_tier_ok(type: String, rod_id: String) -> bool:
	return ZOMBIES[type].tier <= RODS[rod_id].tier


static func roll_zombie(island: int, rod_id: String, rng: RandomNumberGenerator) -> String:
	var table: Dictionary = ISLANDS[island].table
	var total := 0
	for t in table:
		if zombie_tier_ok(t, rod_id):
			total += int(table[t])
	var r := rng.randi_range(1, max(total, 1))
	for t in table:
		if not zombie_tier_ok(t, rod_id):
			continue
		r -= int(table[t])
		if r <= 0:
			return t
	return "shambler"


static func format_money(v: int) -> String:
	var s := str(abs(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + "$" + s + out
