class_name DB
## All the tuning in one place: survivors, weapons, infected, difficulty and the campaign.

const SURVIVORS := [
	{"name": "Gus", "skin": Color(0.78, 0.6, 0.45), "shirt": Color(0.36, 0.4, 0.24), "pants": Color(0.25, 0.22, 0.2), "hat": "cap", "hat_color": Color(0.55, 0.15, 0.12), "ui": Color(0.55, 0.85, 0.4)},
	{"name": "Rosa", "skin": Color(0.62, 0.45, 0.34), "shirt": Color(0.85, 0.45, 0.6), "pants": Color(0.82, 0.42, 0.58), "hat": "ponytail", "hat_color": Color(0.15, 0.1, 0.08), "ui": Color(0.95, 0.55, 0.75)},
	{"name": "Dex", "skin": Color(0.9, 0.75, 0.62), "shirt": Color(0.14, 0.13, 0.13), "pants": Color(0.2, 0.25, 0.4), "hat": "bandana", "hat_color": Color(0.75, 0.12, 0.12), "ui": Color(0.95, 0.6, 0.25)},
	{"name": "Mei", "skin": Color(0.95, 0.82, 0.68), "shirt": Color(0.25, 0.5, 0.75), "pants": Color(0.18, 0.18, 0.22), "hat": "beanie", "hat_color": Color(0.95, 0.85, 0.3), "ui": Color(0.45, 0.75, 1.0)},
]

## slot: primary / secondary / throwable / medkit / pills
## Guns: dmg per pellet, rof = seconds between shots, spread in degrees, pierce = commons a bullet passes through.
const WEAPONS := {
	"pistol": {"name": "Pistol", "slot": "secondary", "kind": "gun", "dmg": 36.0, "pellets": 1, "rof": 0.14, "auto": false, "mag": 15, "reserve": -1, "spread": 1.2, "reload": 1.4, "pierce": 1, "sound": "pistol"},
	"dual_pistols": {"name": "Dual Pistols", "slot": "secondary", "kind": "gun", "dmg": 36.0, "pellets": 1, "rof": 0.09, "auto": false, "mag": 30, "reserve": -1, "spread": 1.8, "reload": 2.0, "pierce": 1, "sound": "pistol"},
	"bat": {"name": "Baseball Bat", "slot": "secondary", "kind": "melee", "dmg": 160.0, "rof": 0.65, "range": 2.3, "arc": 70.0, "sound": "swing"},
	"axe": {"name": "Fire Axe", "slot": "secondary", "kind": "melee", "dmg": 240.0, "rof": 0.8, "range": 2.4, "arc": 60.0, "sound": "swing"},
	"machete": {"name": "Machete", "slot": "secondary", "kind": "melee", "dmg": 200.0, "rof": 0.55, "range": 2.1, "arc": 75.0, "sound": "swing"},
	"smg": {"name": "SMG", "slot": "primary", "kind": "gun", "tier": 1, "dmg": 20.0, "pellets": 1, "rof": 0.065, "auto": true, "mag": 50, "reserve": 650, "spread": 2.4, "reload": 2.1, "pierce": 1, "sound": "smg"},
	"pump_shotgun": {"name": "Pump Shotgun", "slot": "primary", "kind": "gun", "tier": 1, "dmg": 25.0, "pellets": 10, "rof": 0.85, "auto": false, "mag": 8, "reserve": 56, "spread": 5.5, "reload": 2.6, "pierce": 1, "sound": "shotgun"},
	"rifle": {"name": "Assault Rifle", "slot": "primary", "kind": "gun", "tier": 2, "dmg": 33.0, "pellets": 1, "rof": 0.0875, "auto": true, "mag": 50, "reserve": 360, "spread": 1.5, "reload": 2.3, "pierce": 2, "sound": "rifle"},
	## The Megamart's reduced-to-clear assault rifle: huge damage for pennies, but it misfires and
	## passes its use-by date 5 minutes after you pick it up (the timer keeps running in your bag).
	"reduced_rifle": {"name": "Reduced Rifle", "slot": "primary", "kind": "gun", "tier": 3, "dmg": 130.0, "pellets": 1, "rof": 0.075, "auto": true, "mag": 60, "reserve": 300, "spread": 1.1, "reload": 2.0, "pierce": 5, "sound": "rifle", "price": 27, "expires": 300.0, "misfire": 0.08, "base_model": "rifle"},
	"auto_shotgun": {"name": "Auto Shotgun", "slot": "primary", "kind": "gun", "tier": 2, "dmg": 23.0, "pellets": 11, "rof": 0.3, "auto": true, "mag": 10, "reserve": 90, "spread": 6.0, "reload": 3.0, "pierce": 1, "sound": "shotgun"},
	"hunting_rifle": {"name": "Hunting Rifle", "slot": "primary", "kind": "gun", "tier": 2, "dmg": 90.0, "pellets": 1, "rof": 0.25, "auto": false, "mag": 15, "reserve": 150, "spread": 0.3, "reload": 3.0, "pierce": 5, "sound": "sniper"},
	"pipe_bomb": {"name": "Pipe Bomb", "slot": "throwable", "kind": "throw"},
	"molotov": {"name": "Molotov", "slot": "throwable", "kind": "throw"},
	"bile_jar": {"name": "Bile Jar", "slot": "throwable", "kind": "throw"},
	"medkit": {"name": "First Aid Kit", "slot": "medkit", "kind": "heal"},
	"pills": {"name": "Pain Pills", "slot": "pills", "kind": "heal"},
}
const SLOTS := ["primary", "secondary", "throwable", "medkit", "pills"]

## hp, run speed (m/s), dmg = per hit at Normal (scaled by difficulty for commons).
const INFECTED := {
	"common": {"name": "Infected", "hp": 50.0, "speed": 6.2, "dmg": 2.0, "size": 1.0},
	"boomer": {"name": "Boomer", "hp": 50.0, "speed": 3.6, "dmg": 4.0, "size": 1.15, "special": true},
	"hunter": {"name": "Hunter", "hp": 250.0, "speed": 7.0, "dmg": 10.0, "size": 1.0, "special": true},
	"smoker": {"name": "Smoker", "hp": 250.0, "speed": 4.6, "dmg": 8.0, "size": 1.15, "special": true},
	"spitter": {"name": "Spitter", "hp": 100.0, "speed": 5.0, "dmg": 4.0, "size": 1.05, "special": true},
	"tank": {"name": "Tank", "hp": 4000.0, "speed": 5.6, "dmg": 24.0, "size": 1.9, "special": true, "boss": true},
	"witch": {"name": "Witch", "hp": 1000.0, "speed": 9.5, "dmg": 100.0, "size": 0.95, "boss": true},
}
const SPECIALS := ["boomer", "hunter", "smoker", "spitter"]

const DIFFICULTIES := [
	{"name": "Easy", "common_dmg": 1.0, "special_dmg": 0.6, "ff": 0.0, "tank_hp": 3000.0, "horde": 0.7, "special_every": 50.0, "max_specials": 2, "witch_incaps": true},
	{"name": "Normal", "common_dmg": 2.0, "special_dmg": 1.0, "ff": 0.1, "tank_hp": 4000.0, "horde": 1.0, "special_every": 35.0, "max_specials": 3, "witch_incaps": true},
	{"name": "Advanced", "common_dmg": 5.0, "special_dmg": 1.5, "ff": 0.5, "tank_hp": 6000.0, "horde": 1.25, "special_every": 28.0, "max_specials": 3, "witch_incaps": false},
	{"name": "Expert", "common_dmg": 20.0, "special_dmg": 2.0, "ff": 1.0, "tank_hp": 8000.0, "horde": 1.5, "special_every": 22.0, "max_specials": 4, "witch_incaps": false},
]

const MAX_HP := 100.0
const INCAP_HP := 300.0
const REVIVE_TIME := 5.0
const HEAL_TIME := 5.0
const REVIVED_HP := 30.0
const MAX_INCAPS := 2  # The third one kills you.
const TEMP_DECAY := 0.27  # temp health lost per second
const RESPAWN_HP := 50.0

## The campaign. Each chapter is a run of segments that MapGen lays out end to end along +Z.
## Layout seeds are fixed so a chapter is the same map every time; what spawns in it isn't.
const CAMPAIGN_NAME := "Dead Low Tide"
const CHAPTERS := [
	{
		"name": "Main Street", "seed": 1101,
		"segments": ["saferoom_start", "street", "alley", "street", "park", "alley", "street_alarm", "saferoom_end"],
		"start_weapons": ["smg", "smg", "pump_shotgun", "pump_shotgun"],
		"tank": true, "witch": true,
		"sky": Color(0.24,0.50,0.62), "fog": Color(0.57,0.68,0.60),
	},
	{
		"name": "The Warehouse", "seed": 2202,
		"segments": ["saferoom_start", "alley", "warehouse", "warehouse_gate", "yard", "warehouse", "saferoom_end"],
		"start_weapons": ["rifle", "auto_shotgun", "hunting_rifle", "smg"],
		"tank": true, "witch": true,
		"sky": Color(0.06, 0.05, 0.09), "fog": Color(0.09, 0.08, 0.11),
	},
	{
		"name": "The Docks (Finale)", "seed": 3303,
		"segments": ["saferoom_start", "street", "containers", "docks_finale"],
		"start_weapons": ["rifle", "auto_shotgun", "rifle", "auto_shotgun"],
		"tank": false, "witch": false, "finale": true,
		"sky": Color(0.08, 0.06, 0.12), "fog": Color(0.1, 0.09, 0.14),
	},
]

## Finale stages after the radio call. "wait" = seconds of quiet, "horde" = n waves, "tank" = n tanks.
const FINALE := [
	{"kind": "horde", "count": 2}, {"kind": "wait", "time": 12.0},
	{"kind": "tank", "count": 1}, {"kind": "wait", "time": 10.0},
	{"kind": "horde", "count": 3}, {"kind": "tank", "count": 1},
	{"kind": "rescue"},
]

const MAX_COMMONS := 36


static func difficulty(i: int) -> Dictionary:
	return DIFFICULTIES[clampi(i, 0, DIFFICULTIES.size() - 1)]


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, {})


# Semi-real platforms. These are game tuning values, not manufacturer specifications.
const GUN_PROFILES := {
	"pistol": {"model": "M9 SERVICE", "caliber": "9×19 mm", "recoil": 0.012, "recovery": 7.0, "range": 35.0, "zoom": 1.35},
	"dual_pistols": {"model": "M9 / AKIMBO", "caliber": "9×19 mm", "recoil": 0.016, "recovery": 6.0, "range": 30.0, "zoom": 1.2},
	"smg": {"model": "MP5 COMPACT", "caliber": "9×19 mm", "recoil": 0.009, "recovery": 8.5, "range": 30.0, "zoom": 1.4},
	"pump_shotgun": {"model": "M590 BREACHER", "caliber": "12 gauge", "recoil": 0.055, "recovery": 5.0, "range": 16.0, "zoom": 1.3},
	"rifle": {"model": "AR-15 PATROL", "caliber": "5.56×45 mm", "recoil": 0.016, "recovery": 7.5, "range": 60.0, "zoom": 1.5},
	"reduced_rifle": {"model": "AR-15 MARKDOWN", "caliber": "5.56×45 mm (best before: soon)", "recoil": 0.02, "recovery": 7.5, "range": 70.0, "zoom": 1.5},
	"auto_shotgun": {"model": "M4 TACTICAL", "caliber": "12 gauge", "recoil": 0.042, "recovery": 5.5, "range": 18.0, "zoom": 1.3},
	"hunting_rifle": {"model": "M14 SCOUT", "caliber": "7.62×51 mm", "recoil": 0.038, "recovery": 6.5, "range": 90.0, "zoom": 3.0},
}
const UPGRADES := {
	"power": {"name": "MATCH AMMUNITION", "detail": "+20% damage per tier", "cost": 180, "max": 3},
	"magazine": {"name": "EXTENDED MAGAZINE", "detail": "+25% capacity per tier · reload to fill", "cost": 140, "max": 3},
	"handling": {"name": "TUNED ACTION", "detail": "Less recoil, tighter spread, faster reload", "cost": 160, "max": 3},
	"optic": {"name": "PRECISION OPTIC", "detail": "Magnified aim, tighter aimed grouping", "cost": 220, "max": 1},
}


static func gun_stats(id: String, upgrades := {}) -> Dictionary:
	var w := weapon(id).duplicate(true)
	if not GUN_PROFILES.has(id):
		return w
	w.merge(GUN_PROFILES[id], true)
	var power := clampi(int(upgrades.get("power", 0)), 0, 3)
	var magazine := clampi(int(upgrades.get("magazine", 0)), 0, 3)
	var handling := clampi(int(upgrades.get("handling", 0)), 0, 3)
	w.dmg *= 1.0 + power * 0.2
	w.mag = ceili(float(w.mag) * (1.0 + magazine * 0.25))
	w.reload *= pow(0.88, handling)
	w.spread *= pow(0.85, handling)
	w.recoil *= pow(0.8, handling)
	w.recovery *= 1.0 + handling * 0.15
	w.optic = int(upgrades.get("optic", 0)) > 0
	if w.optic:
		w.zoom = 4.0 if id == "hunting_rifle" else 2.0
	return w


static func upgrade_cost(kind: String, tier: int) -> int:
	return int(UPGRADES[kind].cost) * (tier + 1) if UPGRADES.has(kind) else 0
