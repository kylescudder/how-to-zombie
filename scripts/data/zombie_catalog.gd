class_name ZombieCatalog
extends RefCounted
## Every infected look: twelve types of ten models. A model overrides its type's base, which overrides DEFAULTS.
## The first six types are common infected and spawn mixed together; the rest dress one special each.
## Sizes are metres, matching the rig CharacterModel animates: w, d and th size the torso, height scales the body.
const DEFAULTS := {
	"skin": "moss", "w": 0.6, "d": 0.36, "th": 0.7, "height": 1.0, "legs": 1.0, "arms": 1.0, "belly": 0.0,
	"neck": 0.0, "head_scale": 1.0, "head_y": 0.0, "head_z": 0.0,
	"head": "round", "eyes": "mismatch", "pupil": Color(0.24,0.075,0.025), "jaw": "slack", "teeth": 4, "nose": "bulb", "ears": 2,
	"hair": "tufts", "hair_color": Color(0.19,0.22,0.11), "hat": "", "hat_color": Color(0.55,0.13,0.1),
	"top": "tee", "pattern": "", "shirt": Color(0.35,0.3,0.25), "inner": Color(0.86,0.84,0.76), "trim": Color(0.92,0.9,0.82),
	"sleeves": "short", "crop": false, "legwear": "trousers", "pants": Color(0.2,0.22,0.3), "shoes": "boots",
	"shoe": Color(0.23,0.12,0.075), "socks": Color(0,0,0,0), "fit": [], "wear": 1,
}

## Infected skin, by name so models read easily.
const SKINS := {
	"moss": Color(0.53,0.62,0.43), "sage": Color(0.62,0.68,0.56), "ash": Color(0.63,0.64,0.61), "lilac": Color(0.63,0.57,0.68),
	"sallow": Color(0.71,0.69,0.47), "teal": Color(0.46,0.62,0.6), "bruise": Color(0.52,0.5,0.6), "olive": Color(0.5,0.54,0.33),
	"rot": Color(0.58,0.52,0.4), "chalk": Color(0.9,0.9,0.86), "clay": Color(0.66,0.52,0.48), "bile": Color(0.66,0.66,0.4),
}

## Which types each infected kind draws from. Commons mix all six common types.
const KINDS := {
	"common": ["towns","workers","uniforms","sporty","elders","outdoors"],
	"boomer": ["boomer"], "hunter": ["hunter"], "smoker": ["smoker"], "spitter": ["spitter"], "tank": ["tank"], "witch": ["witch"],
}
## Ten looks worth seeing first, one per line of the lineup.
const PICKS := ["towns_05","workers_02","uniforms_09","sporty_05","elders_01","outdoors_01","boomer_07","hunter_01","smoker_01","spitter_04","tank_01","witch_06"]

const TYPES := [
	{"id": "towns", "label": "Townsfolk", "kind": "common", "base": {}, "models": [
		{"name": "Weekend Dad", "skin": "sage", "top": "polo", "shirt": Color(0.2,0.55,0.55), "pants": Color(0.66,0.58,0.42), "shoes": "sneakers", "shoe": Color(0.85,0.85,0.82), "hair": "comb", "hair_color": Color(0.3,0.22,0.14), "belly": 0.16, "fit": ["watch"]},
		{"name": "Hoodie Teen", "skin": "moss", "top": "hoodie", "shirt": Color(0.75,0.16,0.14), "sleeves": "long", "pants": Color(0.22,0.32,0.55), "shoes": "sneakers", "shoe": Color(0.15,0.15,0.17), "hair": "fringe", "hair_color": Color(0.12,0.1,0.08), "w": 0.54, "height": 1.04, "eyes": "squint", "fit": ["headphones"]},
		{"name": "Shopper Mum", "skin": "lilac", "top": "cardigan", "shirt": Color(0.6,0.42,0.68), "inner": Color(0.92,0.9,0.85), "sleeves": "long", "legwear": "skirt", "pants": Color(0.18,0.2,0.35), "shoes": "flats", "shoe": Color(0.5,0.12,0.15), "hair": "bun", "hair_color": Color(0.45,0.25,0.12), "w": 0.54, "nose": "pointy", "fit": ["satchel"]},
		{"name": "Office Temp", "skin": "ash", "top": "shirt", "shirt": Color(0.66,0.78,0.9), "trim": Color(0.75,0.1,0.1), "sleeves": "long", "pants": Color(0.32,0.33,0.36), "shoes": "smart", "shoe": Color(0.08,0.08,0.09), "hair": "comb", "hair_color": Color(0.16,0.12,0.1), "jaw": "under", "fit": ["tie","lanyard"]},
		{"name": "Sunburnt Tourist", "skin": "clay", "top": "shirt", "pattern": "spots", "shirt": Color(0.95,0.5,0.2), "trim": Color(0.98,0.85,0.3), "legwear": "shorts", "pants": Color(0.82,0.75,0.58), "shoes": "sandals", "socks": Color(0.95,0.95,0.92), "hair": "bald", "hat": "bucket", "hat_color": Color(0.9,0.88,0.75), "belly": 0.24, "fit": ["camera","shades"]},
		{"name": "Pizza Courier", "skin": "sallow", "top": "tee", "shirt": Color(0.82,0.18,0.12), "trim": Color(0.98,0.9,0.75), "pattern": "bands", "legwear": "shorts", "pants": Color(0.14,0.14,0.16), "shoes": "sneakers", "shoe": Color(0.9,0.9,0.86), "hat": "cap_back", "hat_color": Color(0.82,0.18,0.12), "hair": "buzz", "eyes": "pop", "fit": ["satchel"]},
		{"name": "Barista", "skin": "teal", "top": "apron", "shirt": Color(0.12,0.12,0.13), "inner": Color(0.16,0.42,0.26), "pants": Color(0.12,0.12,0.13), "shoes": "sneakers", "shoe": Color(0.12,0.12,0.13), "hair": "ponytail", "hair_color": Color(0.55,0.2,0.32), "w": 0.54, "fit": ["nametag","glasses"]},
		{"name": "Librarian", "skin": "bruise", "top": "cardigan", "shirt": Color(0.78,0.6,0.18), "inner": Color(0.9,0.86,0.76), "sleeves": "long", "legwear": "skirt", "pants": Color(0.4,0.26,0.16), "shoes": "flats", "shoe": Color(0.3,0.18,0.1), "hair": "bun", "hair_color": Color(0.7,0.7,0.68), "height": 0.95, "eyes": "wide", "jaw": "grin", "fit": ["glasses","pearls"]},
		{"name": "Night Owl", "skin": "sage", "top": "shirt", "pattern": "stripes", "shirt": Color(0.55,0.68,0.88), "trim": Color(0.92,0.92,0.95), "sleeves": "long", "pants": Color(0.55,0.68,0.88), "shoes": "slippers", "shoe": Color(0.35,0.28,0.24), "hair": "spiky", "hair_color": Color(0.4,0.28,0.16), "belly": 0.1, "jaw": "gape", "wear": 0},
		{"name": "Student", "skin": "olive", "top": "tee", "shirt": Color(0.2,0.2,0.24), "trim": Color(0.9,0.75,0.2), "pattern": "chest", "legwear": "torn", "pants": Color(0.28,0.36,0.58), "shoes": "sneakers", "shoe": Color(0.75,0.15,0.15), "hat": "beanie", "hat_color": Color(0.85,0.55,0.15), "hair": "fringe", "hair_color": Color(0.12,0.1,0.08), "height": 1.06, "w": 0.55, "fit": ["backpack"]},
	]},
	{"id": "workers", "label": "Workers", "kind": "common", "base": {"shoes": "boots", "wear": 2}, "models": [
		{"name": "Site Builder", "skin": "rot", "top": "vest", "pattern": "bands", "shirt": Color(0.98,0.55,0.08), "inner": Color(0.55,0.55,0.52), "trim": Color(0.82,0.85,0.86,0.5), "pants": Color(0.28,0.36,0.55), "hat": "hard_hat", "hat_color": Color(0.98,0.8,0.1), "hair": "bald", "belly": 0.18, "w": 0.64, "fit": ["toolbelt"]},
		{"name": "Road Crew", "skin": "moss", "top": "vest", "pattern": "bands", "shirt": Color(0.86,0.95,0.15), "inner": Color(0.98,0.45,0.1), "trim": Color(0.82,0.85,0.86,0.5), "pants": Color(0.18,0.2,0.24), "hat": "cone", "hat_color": Color(0.98,0.42,0.08), "hair": "bald", "eyes": "wide", "jaw": "gape"},
		{"name": "Grease Monkey", "skin": "ash", "top": "jumpsuit", "shirt": Color(0.24,0.33,0.5), "pants": Color(0.24,0.33,0.5), "sleeves": "rolled", "hat": "cap", "hat_color": Color(0.78,0.12,0.1), "hair": "buzz", "hair_color": Color(0.1,0.08,0.06), "wear": 3, "fit": ["nametag","gloves"]},
		{"name": "Line Cook", "skin": "sallow", "top": "chef", "shirt": Color(0.95,0.94,0.9), "trim": Color(0.15,0.15,0.17), "sleeves": "long", "pants": Color(0.2,0.2,0.22), "shoes": "smart", "shoe": Color(0.1,0.1,0.1), "hat": "chef", "hat_color": Color(0.97,0.97,0.95), "hair": "bald", "eyes": "pop", "fit": ["cleaver"]},
		{"name": "Butcher", "skin": "clay", "top": "apron", "pattern": "stripes", "shirt": Color(0.75,0.22,0.22), "trim": Color(0.92,0.9,0.86), "inner": Color(0.94,0.93,0.9), "pants": Color(0.25,0.25,0.27), "shoes": "wellies", "shoe": Color(0.95,0.95,0.92), "hat": "flat_cap", "hat_color": Color(0.92,0.9,0.86), "hair": "bald", "belly": 0.28, "w": 0.66, "wear": 3, "fit": ["moustache"]},
		{"name": "Janitor", "skin": "bruise", "top": "jumpsuit", "shirt": Color(0.42,0.5,0.55), "pants": Color(0.42,0.5,0.55), "sleeves": "long", "hair": "comb", "hair_color": Color(0.6,0.6,0.58), "height": 0.96, "jaw": "under", "fit": ["nametag","keys","gloves"]},
		{"name": "Farmer", "skin": "olive", "top": "overalls", "pattern": "check", "shirt": Color(0.75,0.15,0.12), "trim": Color(0.95,0.85,0.75), "pants": Color(0.3,0.42,0.62), "shoes": "wellies", "shoe": Color(0.2,0.38,0.2), "hat": "straw", "hat_color": Color(0.88,0.75,0.42), "hair": "tufts", "hair_color": Color(0.6,0.5,0.3), "fit": ["beard"]},
		{"name": "Lumberjack", "skin": "rot", "top": "shirt", "pattern": "check", "shirt": Color(0.78,0.12,0.1), "trim": Color(0.1,0.1,0.11), "sleeves": "rolled", "pants": Color(0.25,0.3,0.48), "hat": "beanie", "hat_color": Color(0.85,0.65,0.15), "hair": "buzz", "hair_color": Color(0.3,0.15,0.06), "w": 0.68, "height": 1.07, "belly": 0.1, "fit": ["beard","braces"]},
		{"name": "Delivery Driver", "skin": "teal", "top": "polo", "shirt": Color(0.42,0.28,0.16), "trim": Color(0.95,0.75,0.2), "legwear": "shorts", "pants": Color(0.42,0.28,0.16), "shoes": "sneakers", "shoe": Color(0.22,0.18,0.14), "socks": Color(0.42,0.28,0.16), "hat": "cap", "hat_color": Color(0.42,0.28,0.16), "hair": "buzz", "nose": "broken", "fit": ["satchel"]},
		{"name": "Bin Crew", "skin": "sage", "top": "jacket", "pattern": "bands", "shirt": Color(0.2,0.55,0.25), "inner": Color(0.28,0.3,0.32), "trim": Color(0.82,0.85,0.86,0.5), "sleeves": "long", "pants": Color(0.2,0.55,0.25), "hair": "mohawk", "hair_color": Color(0.15,0.12,0.1), "ears": 1, "fit": ["gloves"]},
	]},
	{"id": "uniforms", "label": "Uniforms", "kind": "common", "base": {"shoes": "smart", "shoe": Color(0.08,0.08,0.09), "sleeves": "long"}, "models": [
		{"name": "Beat Cop", "skin": "ash", "top": "shirt", "shirt": Color(0.55,0.68,0.85), "trim": Color(0.12,0.15,0.3), "pants": Color(0.12,0.15,0.3), "hat": "police", "hat_color": Color(0.12,0.15,0.3), "hair": "buzz", "belly": 0.12, "fit": ["tie","badge","radio"]},
		{"name": "Firefighter", "skin": "rot", "top": "coat", "pattern": "bands", "shirt": Color(0.74,0.62,0.36), "inner": Color(0.25,0.22,0.18), "trim": Color(0.92,0.86,0.2), "pants": Color(0.74,0.62,0.36), "shoes": "wellies", "shoe": Color(0.1,0.1,0.1), "hat": "fire", "hat_color": Color(0.82,0.12,0.08), "hair": "bald", "w": 0.66, "fit": ["gloves"]},
		{"name": "Ward Nurse", "skin": "lilac", "top": "scrubs", "shirt": Color(0.9,0.55,0.66), "sleeves": "short", "pants": Color(0.9,0.55,0.66), "shoes": "sneakers", "shoe": Color(0.95,0.95,0.95), "hat": "nurse", "hat_color": Color(0.97,0.97,0.95), "hair": "bun", "hair_color": Color(0.85,0.7,0.35), "w": 0.54, "fit": ["stethoscope","nametag"]},
		{"name": "Surgeon", "skin": "sage", "top": "scrubs", "shirt": Color(0.3,0.6,0.58), "sleeves": "short", "pants": Color(0.3,0.6,0.58), "shoes": "sneakers", "shoe": Color(0.95,0.95,0.95), "hat": "surgical", "hat_color": Color(0.3,0.6,0.58), "hair": "bald", "wear": 3, "eyes": "wide", "fit": ["mask","gloves_blue"]},
		{"name": "Paramedic", "skin": "teal", "top": "jumpsuit", "pattern": "bands", "shirt": Color(0.22,0.42,0.3), "trim": Color(0.88,0.95,0.2), "pants": Color(0.22,0.42,0.3), "shoes": "boots", "shoe": Color(0.1,0.1,0.1), "hair": "ponytail", "hair_color": Color(0.2,0.12,0.08), "fit": ["radio","gloves_blue"]},
		{"name": "Security Guard", "skin": "moss", "top": "shirt", "shirt": Color(0.92,0.92,0.9), "trim": Color(0.08,0.08,0.09), "sleeves": "short", "pants": Color(0.08,0.08,0.09), "hat": "police", "hat_color": Color(0.08,0.08,0.09), "hair": "buzz", "belly": 0.3, "w": 0.66, "jaw": "under", "fit": ["tie","badge","radio"]},
		{"name": "Soldier", "skin": "olive", "top": "jacket", "pattern": "camo", "shirt": Color(0.4,0.44,0.26), "inner": Color(0.3,0.32,0.2), "trim": Color(0.28,0.22,0.14), "pants": Color(0.4,0.44,0.26), "shoes": "boots", "shoe": Color(0.15,0.12,0.08), "hat": "helmet", "hat_color": Color(0.36,0.4,0.24), "hair": "bald", "fit": ["backpack"]},
		{"name": "Mail Carrier", "skin": "sallow", "top": "shirt", "shirt": Color(0.6,0.7,0.82), "trim": Color(0.75,0.12,0.12), "sleeves": "short", "legwear": "shorts", "pants": Color(0.15,0.2,0.38), "socks": Color(0.15,0.2,0.38), "shoes": "smart", "hat": "cap", "hat_color": Color(0.15,0.2,0.38), "hair": "comb", "hair_color": Color(0.45,0.3,0.15), "fit": ["satchel","badge"]},
		{"name": "Prisoner", "skin": "bruise", "top": "jumpsuit", "shirt": Color(0.98,0.48,0.12), "pants": Color(0.98,0.48,0.12), "sleeves": "short", "shoes": "sneakers", "shoe": Color(0.92,0.92,0.92), "hair": "buzz", "hair_color": Color(0.1,0.1,0.1), "eyes": "squint", "jaw": "grin", "fit": ["cuffs"]},
		{"name": "Bellhop", "skin": "chalk", "top": "chef", "shirt": Color(0.72,0.1,0.12), "trim": Color(0.95,0.78,0.25), "pants": Color(0.12,0.12,0.14), "hat": "pillbox", "hat_color": Color(0.72,0.1,0.12), "hair": "comb", "hair_color": Color(0.1,0.1,0.1), "height": 0.94, "w": 0.52, "fit": ["bowtie","gloves_white"]},
	]},
	{"id": "sporty", "label": "Sporty", "kind": "common", "base": {"shoes": "sneakers", "sleeves": "none", "wear": 1}, "models": [
		{"name": "Morning Jogger", "skin": "sage", "top": "tank", "shirt": Color(0.95,0.3,0.55), "legwear": "shorts", "pants": Color(0.12,0.12,0.14), "shoe": Color(0.3,0.75,0.9), "hat": "headband", "hat_color": Color(0.3,0.75,0.9), "hair": "ponytail", "hair_color": Color(0.85,0.7,0.35), "w": 0.52, "height": 1.04, "fit": ["watch","bib"]},
		{"name": "Footballer", "skin": "moss", "top": "tee", "pattern": "stripes", "shirt": Color(0.85,0.12,0.12), "trim": Color(0.95,0.95,0.95), "sleeves": "short", "legwear": "shorts", "pants": Color(0.95,0.95,0.95), "socks": Color(0.85,0.12,0.12), "shoes": "studs", "shoe": Color(0.1,0.1,0.1), "hair": "buzz", "hair_color": Color(0.15,0.1,0.06), "eyes": "pop"},
		{"name": "Gym Bro", "skin": "clay", "top": "tank", "shirt": Color(0.55,0.56,0.58), "legwear": "trousers", "pants": Color(0.3,0.3,0.33), "shoe": Color(0.95,0.95,0.95), "hair": "buzz", "hair_color": Color(0.1,0.08,0.06), "w": 0.76, "arms": 1.15, "d": 0.4, "jaw": "under", "fit": ["watch","headphones"]},
		{"name": "Cyclist", "skin": "teal", "top": "tee", "pattern": "panel", "shirt": Color(0.98,0.85,0.15), "trim": Color(0.12,0.3,0.7), "sleeves": "short", "legwear": "shorts", "pants": Color(0.1,0.1,0.12), "shoe": Color(0.98,0.85,0.15), "hat": "helmet_bike", "hat_color": Color(0.12,0.3,0.7), "hair": "bald", "w": 0.54, "fit": ["shades"]},
		{"name": "Boxer", "skin": "rot", "top": "bare", "legwear": "shorts", "pants": Color(0.82,0.12,0.12), "shoes": "boots", "shoe": Color(0.82,0.12,0.12), "hair": "buzz", "hair_color": Color(0.1,0.08,0.06), "w": 0.68, "nose": "broken", "eyes": "squint", "wear": 2, "fit": ["boxing_gloves","belt_gold"]},
		{"name": "Cheerleader", "skin": "lilac", "top": "tank", "pattern": "bands", "shirt": Color(0.2,0.3,0.75), "trim": Color(0.98,0.85,0.2), "legwear": "skirt", "pants": Color(0.2,0.3,0.75), "socks": Color(0.95,0.95,0.95), "shoe": Color(0.95,0.95,0.95), "hair": "ponytail", "hair_color": Color(0.95,0.8,0.4), "w": 0.5, "jaw": "grin", "fit": ["bow"]},
		{"name": "Skater", "skin": "sallow", "top": "tee", "pattern": "chest", "shirt": Color(0.3,0.62,0.4), "trim": Color(0.95,0.9,0.8), "sleeves": "short", "legwear": "shorts", "pants": Color(0.55,0.5,0.4), "socks": Color(0.95,0.95,0.95), "shoe": Color(0.15,0.15,0.17), "hat": "cap_back", "hat_color": Color(0.15,0.15,0.17), "hair": "mullet", "hair_color": Color(0.65,0.5,0.2), "fit": ["knee_pads"]},
		{"name": "Golfer", "skin": "ash", "top": "polo", "pattern": "check", "shirt": Color(0.95,0.75,0.8), "trim": Color(0.75,0.85,0.95), "sleeves": "short", "pants": Color(0.95,0.92,0.82), "shoes": "smart", "shoe": Color(0.95,0.95,0.92), "hat": "flat_cap", "hat_color": Color(0.35,0.45,0.3), "hair": "bald", "belly": 0.2, "fit": ["glove_one","moustache"]},
		{"name": "Tennis Ace", "skin": "bruise", "top": "polo", "shirt": Color(0.97,0.97,0.95), "trim": Color(0.2,0.55,0.3), "sleeves": "short", "legwear": "shorts", "pants": Color(0.97,0.97,0.95), "socks": Color(0.97,0.97,0.95), "shoe": Color(0.97,0.97,0.95), "hat": "headband", "hat_color": Color(0.2,0.55,0.3), "hair": "afro", "hair_color": Color(0.2,0.12,0.06), "fit": ["watch"]},
		{"name": "Lifeguard", "skin": "olive", "top": "tank", "shirt": Color(0.88,0.15,0.12), "trim": Color(0.97,0.97,0.95), "legwear": "shorts", "pants": Color(0.88,0.15,0.12), "shoes": "bare", "hair": "mullet", "hair_color": Color(0.95,0.85,0.5), "nose": "zinc", "w": 0.66, "fit": ["whistle"]},
	]},
	{"id": "elders", "label": "Old Timers", "kind": "common", "base": {"height": 0.95, "sleeves": "long", "wear": 1}, "models": [
		{"name": "Curler Granny", "skin": "lilac", "top": "coat", "pattern": "spots", "shirt": Color(0.95,0.62,0.72), "inner": Color(0.95,0.9,0.92), "trim": Color(0.98,0.85,0.88), "legwear": "bare", "shoes": "slippers", "shoe": Color(0.95,0.62,0.72), "hair": "curlers", "hair_color": Color(0.75,0.75,0.78), "hat_color": Color(0.4,0.65,0.9), "eyes": "wide", "teeth": 2, "fit": ["glasses"]},
		{"name": "Flat Cap Grandad", "skin": "ash", "top": "cardigan", "shirt": Color(0.48,0.36,0.24), "inner": Color(0.85,0.85,0.8), "pants": Color(0.38,0.38,0.4), "shoes": "smart", "shoe": Color(0.35,0.2,0.1), "hat": "flat_cap", "hat_color": Color(0.42,0.4,0.32), "hair": "bald", "teeth": 1, "nose": "pointy", "fit": ["moustache"]},
		{"name": "Bingo Nan", "skin": "bruise", "top": "dress", "pattern": "spots", "shirt": Color(0.5,0.28,0.6), "trim": Color(0.95,0.85,0.3), "legwear": "bare", "shoes": "flats", "shoe": Color(0.15,0.12,0.12), "hair": "bun", "hair_color": Color(0.92,0.92,0.94), "belly": 0.18, "w": 0.62, "jaw": "grin", "fit": ["pearls","satchel","glasses"]},
		{"name": "Bowls Champion", "skin": "sage", "top": "polo", "shirt": Color(0.97,0.97,0.95), "trim": Color(0.2,0.4,0.25), "pants": Color(0.97,0.97,0.95), "shoes": "smart", "shoe": Color(0.6,0.4,0.2), "hat": "bucket", "hat_color": Color(0.97,0.97,0.95), "hair": "comb", "hair_color": Color(0.92,0.92,0.94), "fit": ["badge"]},
		{"name": "Retired Colonel", "skin": "clay", "top": "suit", "shirt": Color(0.12,0.16,0.32), "inner": Color(0.92,0.92,0.9), "trim": Color(0.55,0.12,0.15), "pants": Color(0.55,0.52,0.45), "shoes": "smart", "shoe": Color(0.1,0.08,0.07), "hair": "comb", "hair_color": Color(0.92,0.92,0.94), "eyes": "squint", "fit": ["moustache","tie","medals"]},
		{"name": "Garden Gran", "skin": "moss", "top": "apron", "pattern": "spots", "shirt": Color(0.55,0.7,0.85), "inner": Color(0.95,0.85,0.55), "trim": Color(0.9,0.4,0.45), "legwear": "skirt", "pants": Color(0.4,0.3,0.25), "shoes": "wellies", "shoe": Color(0.2,0.45,0.25), "hat": "straw", "hat_color": Color(0.9,0.8,0.5), "hair": "bun", "hair_color": Color(0.75,0.75,0.78), "fit": ["gloves_garden"]},
		{"name": "Socks and Sandals", "skin": "sallow", "top": "shirt", "pattern": "check", "shirt": Color(0.72,0.82,0.62), "trim": Color(0.92,0.92,0.82), "sleeves": "short", "legwear": "shorts", "pants": Color(0.75,0.68,0.5), "shoes": "sandals", "socks": Color(0.97,0.97,0.95), "hair": "bald", "belly": 0.3, "eyes": "wide", "fit": ["glasses","camera"]},
		{"name": "Grumpy Neighbour", "skin": "rot", "top": "tank", "shirt": Color(0.92,0.9,0.82), "pants": Color(0.4,0.3,0.2), "shoes": "slippers", "shoe": Color(0.3,0.22,0.18), "sleeves": "none", "hair": "comb", "hair_color": Color(0.6,0.6,0.6), "belly": 0.38, "w": 0.66, "wear": 2, "jaw": "under", "fit": ["moustache"]},
		{"name": "Ageing Rocker", "skin": "teal", "top": "jacket", "shirt": Color(0.1,0.1,0.11), "inner": Color(0.45,0.45,0.48), "trim": Color(0.7,0.7,0.72), "pants": Color(0.12,0.12,0.14), "shoes": "boots", "shoe": Color(0.08,0.08,0.08), "hair": "long", "hair_color": Color(0.75,0.75,0.78), "height": 1.0, "fit": ["shades","beard","studs"]},
		{"name": "Knitting Nana", "skin": "chalk", "top": "cardigan", "pattern": "check", "shirt": Color(0.35,0.55,0.38), "inner": Color(0.85,0.75,0.55), "trim": Color(0.82,0.72,0.35), "legwear": "skirt", "pants": Color(0.3,0.25,0.35), "shoes": "flats", "shoe": Color(0.3,0.2,0.15), "hat": "bobble", "hat_color": Color(0.8,0.2,0.25), "hair": "bald", "height": 0.9, "teeth": 1, "fit": ["scarf","glasses"]},
	]},
	{"id": "outdoors", "label": "Outdoors", "kind": "common", "base": {"shoes": "boots", "wear": 1}, "models": [
		{"name": "Weekend Angler", "skin": "moss", "top": "vest", "shirt": Color(0.55,0.55,0.38), "inner": Color(0.4,0.55,0.7), "sleeves": "long", "pants": Color(0.32,0.36,0.24), "shoes": "wellies", "shoe": Color(0.22,0.3,0.18), "hat": "bucket", "hat_color": Color(0.6,0.58,0.42), "hair": "tufts", "fit": ["pockets","rod"]},
		{"name": "Fly Fisher", "skin": "sage", "top": "overalls", "pattern": "check", "shirt": Color(0.3,0.42,0.62), "trim": Color(0.85,0.85,0.8), "pants": Color(0.3,0.38,0.26), "shoes": "wellies", "shoe": Color(0.3,0.38,0.26), "hat": "cap", "hat_color": Color(0.55,0.5,0.35), "hair": "buzz", "jaw": "gape", "fit": ["fish","beard"]},
		{"name": "Hiker", "skin": "olive", "top": "jacket", "shirt": Color(0.85,0.25,0.15), "inner": Color(0.25,0.28,0.3), "sleeves": "long", "legwear": "shorts", "pants": Color(0.4,0.36,0.3), "socks": Color(0.85,0.8,0.7), "hat": "beanie", "hat_color": Color(0.2,0.45,0.6), "hair": "buzz", "fit": ["backpack_big"]},
		{"name": "Camp Counsellor", "skin": "teal", "top": "tee", "pattern": "chest", "shirt": Color(0.25,0.55,0.3), "trim": Color(0.98,0.92,0.75), "legwear": "shorts", "pants": Color(0.75,0.65,0.45), "socks": Color(0.95,0.95,0.92), "hat": "", "hair": "fringe", "hair_color": Color(0.7,0.35,0.12), "fit": ["neckerchief","whistle"]},
		{"name": "Birdwatcher", "skin": "lilac", "top": "vest", "shirt": Color(0.62,0.58,0.42), "inner": Color(0.85,0.82,0.72), "sleeves": "long", "pants": Color(0.45,0.42,0.32), "hat": "bush", "hat_color": Color(0.5,0.42,0.28), "hair": "comb", "hair_color": Color(0.6,0.6,0.6), "eyes": "wide", "fit": ["binoculars","pockets"]},
		{"name": "Surfer", "skin": "sallow", "top": "jumpsuit", "pattern": "panel", "shirt": Color(0.1,0.1,0.12), "trim": Color(0.15,0.6,0.85), "sleeves": "long", "pants": Color(0.1,0.1,0.12), "shoes": "bare", "hair": "long", "hair_color": Color(0.95,0.85,0.45), "jaw": "grin", "fit": ["shades"]},
		{"name": "Gamekeeper", "skin": "rot", "top": "coat", "pattern": "check", "shirt": Color(0.45,0.38,0.24), "inner": Color(0.3,0.35,0.24), "trim": Color(0.55,0.48,0.3), "pants": Color(0.4,0.34,0.22), "shoes": "wellies", "shoe": Color(0.18,0.22,0.15), "hat": "flat_cap", "hat_color": Color(0.45,0.38,0.24), "hair": "bald", "fit": ["moustache"]},
		{"name": "Beach Bum", "skin": "clay", "top": "jacket", "pattern": "spots", "shirt": Color(0.2,0.72,0.75), "inner": Color(0, 0, 0, 0), "trim": Color(0.98,0.9,0.35), "legwear": "shorts", "pants": Color(0.95,0.5,0.2), "shoes": "sandals", "hair": "spiky", "hair_color": Color(0.95,0.85,0.5), "belly": 0.2, "fit": ["shades"]},
		{"name": "Scout Leader", "skin": "ash", "top": "shirt", "shirt": Color(0.72,0.65,0.42), "trim": Color(0.55,0.42,0.22), "sleeves": "short", "legwear": "shorts", "pants": Color(0.4,0.36,0.24), "socks": Color(0.35,0.42,0.25), "hat": "bush", "hat_color": Color(0.6,0.45,0.25), "hair": "bald", "belly": 0.15, "fit": ["neckerchief","patches"]},
		{"name": "Ice Fisher", "skin": "bruise", "top": "coat", "shirt": Color(0.95,0.5,0.12), "inner": Color(0.2,0.22,0.3), "trim": Color(0.92,0.92,0.92), "sleeves": "long", "pants": Color(0.2,0.22,0.3), "shoes": "wellies", "shoe": Color(0.1,0.1,0.12), "hat": "trapper", "hat_color": Color(0.35,0.25,0.18), "hair": "bald", "w": 0.66, "fit": ["scarf","fish"]},
	]},
	{"id": "boomer", "label": "Boomer", "kind": "boomer", "base": {"skin": "bile", "w": 1.1, "th": 0.8, "d": 0.8, "belly": 0.45, "head_scale": 0.92, "crop": true, "hair": "bald", "fit": ["boils"], "wear": 2, "jaw": "gape"}, "models": [
		{"name": "Bloater", "top": "tee", "shirt": Color(0.78,0.65,0.3), "pants": Color(0.3,0.28,0.25)},
		{"name": "Bowling League", "top": "shirt", "pattern": "panel", "shirt": Color(0.92,0.86,0.7), "trim": Color(0.55,0.12,0.15), "pants": Color(0.2,0.2,0.22), "shoes": "smart", "shoe": Color(0.6,0.15,0.15), "hair": "comb", "hair_color": Color(0.1,0.08,0.06)},
		{"name": "Vest and Braces", "top": "tank", "shirt": Color(0.9,0.88,0.78), "pants": Color(0.35,0.3,0.25), "sleeves": "none", "fit": ["boils","braces"]},
		{"name": "Fry Cook", "top": "apron", "shirt": Color(0.95,0.93,0.88), "inner": Color(0.95,0.75,0.2), "pants": Color(0.2,0.2,0.22), "hat": "paper", "hat_color": Color(0.95,0.93,0.88), "fit": ["boils","nametag"]},
		{"name": "Couch Potato", "top": "coat", "pattern": "check", "shirt": Color(0.6,0.15,0.18), "inner": Color(0.85,0.8,0.7), "trim": Color(0.2,0.35,0.25), "legwear": "bare", "shoes": "slippers", "shoe": Color(0.35,0.28,0.22), "sleeves": "long"},
		{"name": "Biker", "top": "jacket", "shirt": Color(0.12,0.12,0.13), "inner": Color(0, 0, 0, 0), "sleeves": "none", "pants": Color(0.18,0.22,0.35), "hat": "bandana", "hat_color": Color(0.15,0.2,0.55), "fit": ["boils","beard","studs"]},
		{"name": "Mall Santa", "top": "coat", "pattern": "bands", "shirt": Color(0.8,0.1,0.1), "inner": Color(0.8,0.1,0.1), "trim": Color(0.97,0.97,0.95), "sleeves": "long", "pants": Color(0.8,0.1,0.1), "shoe": Color(0.08,0.08,0.08), "hat": "santa", "hat_color": Color(0.8,0.1,0.1), "crop": false, "fit": ["boils","beard_white","belt_black"]},
		{"name": "Luau Uncle", "top": "shirt", "pattern": "spots", "shirt": Color(0.15,0.55,0.6), "trim": Color(0.98,0.55,0.35), "legwear": "shorts", "pants": Color(0.85,0.82,0.7), "shoes": "sandals", "fit": ["boils","shades"]},
		{"name": "Basement Gamer", "top": "hoodie", "shirt": Color(0.35,0.2,0.45), "sleeves": "long", "pants": Color(0.25,0.25,0.28), "shoes": "slippers", "shoe": Color(0.3,0.3,0.35), "hair": "fringe", "hair_color": Color(0.12,0.1,0.08), "fit": ["boils","headphones","glasses"]},
		{"name": "Long-Haul Trucker", "top": "shirt", "pattern": "check", "shirt": Color(0.3,0.38,0.6), "trim": Color(0.12,0.12,0.14), "pants": Color(0.25,0.32,0.5), "hat": "cap", "hat_color": Color(0.95,0.95,0.92), "fit": ["boils","moustache"]},
	]},
	{"id": "hunter", "label": "Hunter", "kind": "hunter", "base": {"skin": "ash", "w": 0.58, "top": "hoodie", "sleeves": "long", "hat": "hood", "shoes": "sneakers", "hair": "bald", "eyes": "glare", "pupil": Color(0.95,0.25,0.12), "fit": ["claws","tape"], "wear": 2}, "models": [
		{"name": "Charcoal Hood", "shirt": Color(0.18,0.2,0.24), "pants": Color(0.15,0.15,0.18), "shoe": Color(0.3,0.3,0.32)},
		{"name": "Navy Track", "shirt": Color(0.12,0.16,0.35), "trim": Color(0.92,0.92,0.92), "pattern": "panel", "pants": Color(0.12,0.16,0.35), "shoe": Color(0.92,0.92,0.92), "fit": ["claws","tape","leg_stripes"]},
		{"name": "Black Ops", "shirt": Color(0.07,0.07,0.08), "pants": Color(0.1,0.1,0.11), "shoes": "boots", "shoe": Color(0.05,0.05,0.05)},
		{"name": "Olive Drab", "shirt": Color(0.3,0.33,0.2), "pants": Color(0.22,0.22,0.18), "shoes": "boots", "shoe": Color(0.25,0.18,0.1), "skin": "olive"},
		{"name": "Maroon Hood", "shirt": Color(0.42,0.1,0.14), "pants": Color(0.18,0.18,0.2), "shoe": Color(0.85,0.85,0.85)},
		{"name": "Grey Marl", "shirt": Color(0.5,0.5,0.52), "pants": Color(0.4,0.4,0.42), "shoe": Color(0.15,0.15,0.17), "skin": "bruise"},
		{"name": "Camo Hood", "shirt": Color(0.36,0.4,0.24), "pattern": "camo", "trim": Color(0.25,0.2,0.12), "pants": Color(0.25,0.24,0.2), "shoes": "boots", "shoe": Color(0.2,0.15,0.1)},
		{"name": "Red Zip", "shirt": Color(0.72,0.12,0.1), "pants": Color(0.12,0.12,0.14), "shoe": Color(0.12,0.12,0.14), "fit": ["claws","tape","zip"]},
		{"name": "Purple Track", "shirt": Color(0.32,0.18,0.48), "trim": Color(0.95,0.85,0.25), "pattern": "panel", "pants": Color(0.32,0.18,0.48), "shoe": Color(0.95,0.95,0.95), "skin": "teal", "fit": ["claws","tape","leg_stripes"]},
		{"name": "Barefoot Stalker", "shirt": Color(0.24,0.3,0.32), "pants": Color(0.2,0.2,0.22), "legwear": "torn", "shoes": "bare", "skin": "sage", "wear": 3},
	]},
	{"id": "smoker", "label": "Smoker", "kind": "smoker", "base": {"skin": "rot", "w": 0.5, "th": 0.85, "d": 0.32, "height": 1.25, "legs": 1.2, "hair": "comb", "hair_color": Color(0.25,0.22,0.18), "sleeves": "long", "fit": ["tumours"], "wear": 2, "teeth": 3, "jaw": "slack"}, "models": [
		{"name": "Trench Coat", "top": "coat", "shirt": Color(0.55,0.45,0.3), "inner": Color(0.3,0.3,0.32), "pants": Color(0.3,0.28,0.25), "shoes": "smart", "shoe": Color(0.15,0.1,0.08), "hat": "fedora", "hat_color": Color(0.3,0.26,0.2)},
		{"name": "Flannel Wreck", "top": "shirt", "pattern": "check", "shirt": Color(0.4,0.35,0.3), "trim": Color(0.6,0.25,0.18), "pants": Color(0.25,0.22,0.2)},
		{"name": "Undertaker", "top": "suit", "shirt": Color(0.1,0.1,0.11), "inner": Color(0.85,0.85,0.82), "trim": Color(0.1,0.1,0.11), "pants": Color(0.1,0.1,0.11), "shoes": "smart", "shoe": Color(0.05,0.05,0.05), "hat": "top_hat", "hat_color": Color(0.08,0.08,0.09), "fit": ["tumours","tie"]},
		{"name": "Chain Cardigan", "top": "cardigan", "shirt": Color(0.45,0.4,0.32), "inner": Color(0.75,0.7,0.6), "pants": Color(0.3,0.28,0.28), "shoes": "slippers", "shoe": Color(0.35,0.3,0.25), "skin": "ash"},
		{"name": "Night Porter", "top": "chef", "shirt": Color(0.35,0.12,0.12), "trim": Color(0.8,0.65,0.3), "pants": Color(0.12,0.12,0.14), "shoes": "smart", "hat": "pillbox", "hat_color": Color(0.35,0.12,0.12)},
		{"name": "Overall Lanky", "top": "overalls", "shirt": Color(0.6,0.55,0.48), "pants": Color(0.25,0.32,0.45), "hair": "tufts", "fit": ["tumours","braces"]},
		{"name": "Tracksuit Wheeze", "top": "jumpsuit", "pattern": "panel", "shirt": Color(0.2,0.42,0.3), "trim": Color(0.92,0.92,0.92), "pants": Color(0.2,0.42,0.3), "shoes": "sneakers", "shoe": Color(0.9,0.9,0.9), "fit": ["tumours","leg_stripes"]},
		{"name": "Shift Manager", "top": "shirt", "shirt": Color(0.85,0.82,0.7), "trim": Color(0.3,0.35,0.55), "pants": Color(0.25,0.25,0.28), "shoes": "smart", "fit": ["tumours","tie","lanyard"]},
		{"name": "Hivis Smoker", "top": "vest", "pattern": "bands", "shirt": Color(0.95,0.6,0.1), "inner": Color(0.4,0.38,0.35), "trim": Color(0.82,0.85,0.86,0.5), "pants": Color(0.2,0.2,0.24), "hat": "beanie", "hat_color": Color(0.2,0.2,0.22)},
		{"name": "Hospital Gown", "top": "dress", "pattern": "spots", "shirt": Color(0.68,0.8,0.82), "trim": Color(0.45,0.6,0.7), "legwear": "bare", "shoes": "bare", "hair": "bald", "skin": "sage", "fit": ["tumours","bandage"]},
	]},
	{"id": "spitter", "label": "Spitter", "kind": "spitter", "base": {"skin": "olive", "w": 0.5, "d": 0.32, "height": 1.05, "neck": 0.3, "hair": "long", "hair_color": Color(0.2,0.18,0.12), "jaw": "gape", "fit": ["acid"], "wear": 2}, "models": [
		{"name": "Acid Mouth", "top": "tank", "shirt": Color(0.3,0.35,0.2), "pants": Color(0.2,0.22,0.15), "sleeves": "none"},
		{"name": "Prom Night", "top": "dress", "shirt": Color(0.55,0.2,0.55), "legwear": "bare", "shoes": "flats", "shoe": Color(0.55,0.2,0.55), "hair_color": Color(0.85,0.7,0.3), "fit": ["acid","pearls"]},
		{"name": "Ward Escapee", "top": "dress", "pattern": "spots", "shirt": Color(0.75,0.85,0.88), "trim": Color(0.45,0.6,0.7), "legwear": "bare", "shoes": "bare", "hair": "bald", "fit": ["acid","bandage"]},
		{"name": "Band Tee", "top": "tee", "pattern": "chest", "shirt": Color(0.1,0.1,0.12), "trim": Color(0.85,0.2,0.15), "legwear": "torn", "pants": Color(0.2,0.25,0.4), "shoes": "sneakers", "shoe": Color(0.1,0.1,0.1), "hair": "mohawk", "hair_color": Color(0.3,0.8,0.25)},
		{"name": "Office Spit", "top": "shirt", "shirt": Color(0.9,0.88,0.82), "trim": Color(0.2,0.5,0.3), "legwear": "skirt", "pants": Color(0.25,0.25,0.28), "shoes": "flats", "shoe": Color(0.1,0.1,0.1), "sleeves": "long", "fit": ["acid","lanyard"]},
		{"name": "Swamp Bride", "top": "dress", "shirt": Color(0.88,0.86,0.75), "legwear": "bare", "shoes": "bare", "hat": "veil", "hat_color": Color(0.92,0.92,0.88), "wear": 3},
		{"name": "Yoga Drip", "top": "tank", "pattern": "panel", "shirt": Color(0.35,0.65,0.6), "trim": Color(0.2,0.3,0.4), "pants": Color(0.2,0.3,0.4), "shoes": "sneakers", "shoe": Color(0.92,0.92,0.92), "hair": "ponytail", "hair_color": Color(0.12,0.1,0.08)},
		{"name": "Cardigan Drool", "top": "cardigan", "shirt": Color(0.55,0.5,0.38), "inner": Color(0.3,0.38,0.25), "sleeves": "long", "legwear": "skirt", "pants": Color(0.3,0.25,0.22), "shoes": "slippers", "shoe": Color(0.5,0.4,0.35), "hair": "bun", "hair_color": Color(0.6,0.6,0.58)},
		{"name": "Hivis Spitter", "top": "vest", "pattern": "bands", "shirt": Color(0.85,0.95,0.15), "inner": Color(0.25,0.25,0.28), "trim": Color(0.82,0.85,0.86,0.5), "pants": Color(0.2,0.22,0.26), "hair": "buzz"},
		{"name": "Nightdress", "top": "dress", "pattern": "stripes", "shirt": Color(0.75,0.68,0.85), "trim": Color(0.9,0.85,0.92), "legwear": "bare", "shoes": "slippers", "shoe": Color(0.75,0.68,0.85), "hair": "curlers", "hair_color": Color(0.45,0.3,0.15), "hat_color": Color(0.95,0.5,0.6)},
	]},
	{"id": "tank", "label": "Tank", "kind": "tank", "base": {"skin": "clay", "w": 1.5, "th": 0.9, "d": 0.9, "legs": 0.9, "arms": 2.0, "head_scale": 0.78, "head_y": -0.04, "head_z": 0.25, "top": "bare", "sleeves": "none", "hair": "bald", "shoes": "bare", "legwear": "torn", "jaw": "under", "teeth": 3, "eyes": "squint", "fit": ["lumps"], "wear": 2}, "models": [
		{"name": "Brute", "pants": Color(0.22,0.2,0.25)},
		{"name": "Torn Denim", "pants": Color(0.25,0.35,0.55), "fit": ["lumps","belt_black"]},
		{"name": "Overall Hulk", "top": "overalls", "shirt": Color(0, 0, 0, 0), "pants": Color(0.3,0.38,0.55), "legwear": "trousers", "shoes": "boots", "shoe": Color(0.2,0.15,0.1)},
		{"name": "Chain Gang", "pants": Color(0.95,0.5,0.15), "fit": ["lumps","cuffs","chain"]},
		{"name": "Wrestler", "legwear": "shorts", "pants": Color(0.75,0.12,0.15), "shoes": "boots", "shoe": Color(0.75,0.12,0.15), "fit": ["lumps","belt_gold"]},
		{"name": "Camo Hulk", "pants": Color(0.36,0.4,0.24), "fit": ["lumps","dog_tags"]},
		{"name": "Scrap Plated", "pants": Color(0.25,0.24,0.22), "skin": "ash", "fit": ["lumps","plates"]},
		{"name": "Lumberhulk", "top": "shirt", "pattern": "check", "shirt": Color(0.75,0.14,0.1), "trim": Color(0.1,0.1,0.1), "pants": Color(0.3,0.32,0.45), "skin": "rot", "fit": ["lumps","shreds"]},
		{"name": "Stitched Giant", "pants": Color(0.35,0.3,0.25), "skin": "sage", "fit": ["lumps","stitches"]},
		{"name": "Pale Mountain", "pants": Color(0.15,0.15,0.17), "skin": "bruise", "hair": "mohawk", "hair_color": Color(0.1,0.1,0.1)},
	]},
	{"id": "witch", "label": "Witch", "kind": "witch", "base": {"skin": "chalk", "w": 0.44, "d": 0.28, "top": "dress", "shirt": Color(0.75,0.72,0.7), "legwear": "bare", "shoes": "bare", "hair": "long", "hair_color": Color(0.95,0.95,0.92), "eyes": "glare", "pupil": Color(1.0,0.75,0.45), "jaw": "slack", "teeth": 2, "fit": ["claws_long"], "wear": 1}, "models": [
		{"name": "Weeping Witch"},
		{"name": "Black Mourning", "shirt": Color(0.1,0.1,0.12), "hair_color": Color(0.12,0.12,0.14)},
		{"name": "Red Slip", "shirt": Color(0.55,0.08,0.1), "hair_color": Color(0.75,0.25,0.12)},
		{"name": "Ash Gown", "shirt": Color(0.45,0.45,0.48), "hair_color": Color(0.6,0.6,0.62), "skin": "ash"},
		{"name": "Nightgown", "pattern": "spots", "shirt": Color(0.85,0.8,0.88), "trim": Color(0.6,0.55,0.75), "shoes": "slippers", "shoe": Color(0.85,0.8,0.88)},
		{"name": "Jilted Bride", "shirt": Color(0.96,0.95,0.9), "hat": "veil", "hat_color": Color(0.96,0.96,0.92), "fit": ["claws_long","pearls"], "wear": 2},
		{"name": "Ballerina", "top": "tank", "shirt": Color(0.95,0.75,0.8), "legwear": "tutu", "pants": Color(0.95,0.75,0.8), "shoes": "flats", "shoe": Color(0.95,0.75,0.8), "hair": "bun", "hair_color": Color(0.3,0.2,0.12)},
		{"name": "Schoolgirl", "top": "shirt", "shirt": Color(0.95,0.95,0.92), "trim": Color(0.55,0.1,0.12), "legwear": "skirt", "pants": Color(0.15,0.18,0.35), "socks": Color(0.95,0.95,0.92), "shoes": "flats", "shoe": Color(0.08,0.08,0.08), "hair_color": Color(0.1,0.08,0.06), "fit": ["claws_long","tie"]},
		{"name": "Bog Witch", "shirt": Color(0.35,0.4,0.28), "hair_color": Color(0.3,0.38,0.22), "skin": "moss", "wear": 3},
		{"name": "Ghost Lace", "pattern": "stripes", "shirt": Color(0.88,0.9,0.95), "trim": Color(0.72,0.78,0.9), "hair_color": Color(0.85,0.88,0.95), "skin": "lilac"},
	]},
]

static func ids() -> Array[String]:
	var out: Array[String] = []
	for kind: Dictionary in TYPES:
		for i in kind.models.size():
			out.append("%s_%02d" % [kind.id,i+1])
	return out

## The merged entry for a model id like "towns_03", or {} when there is none.
static func find(id: String) -> Dictionary:
	var cut := id.rfind("_")
	if cut < 0: return {}
	var type_id := id.left(cut)
	var index := id.substr(cut+1).to_int()-1
	for kind: Dictionary in TYPES:
		if kind.id != type_id or index < 0 or index >= kind.models.size(): continue
		var data := DEFAULTS.duplicate(true)
		data.merge(kind.base,true)
		data.merge(kind.models[index],true)
		data.id = id
		data.type = kind.label
		data.kind = kind.kind
		return data
	return {}

## The look an infected of this kind wears, chosen by its spawn seed so every peer agrees.
static func pick(kind: String, seed_v: int) -> String:
	var types: Array = KINDS.get(kind,KINDS.common)
	var pool: Array[String] = []
	for id in ids():
		if id.left(id.rfind("_")) in types: pool.append(id)
	return pool[posmod(hash(seed_v ^ 0x7a3b1e),pool.size())]
