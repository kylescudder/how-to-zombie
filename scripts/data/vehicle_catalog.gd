class_name VehicleCatalog
extends RefCounted
## Every drivable or parkable vehicle: twelve body types of ten models. A model overrides its type's base,
## which overrides DEFAULTS. Lengths are metres; cowl, peak, back, foot and the axles run from the nose.
const DEFAULTS := {
	"len": 4.2, "wid": 1.8, "ride": 0.26, "r": 0.33, "tw": 0.22, "ax_f": 0.82, "ax_r": 3.4,
	"nose": 0.72, "belt": 0.95, "tail": 0.95, "cowl": 1.4, "peak": 1.95, "back": 3.0, "foot": 3.6,
	"roof": 1.42, "crown": 0.03, "tuck": 0.8, "pillars": [2.55], "pillar_width": 0.07, "glass_to": 99.0,
	"rear_glass": true, "step": false, "doors": [], "handles": true, "rub": "black", "front": "slats",
	"grille_w": 0.62, "lamp": "rect", "tail_lamp": "rect", "bumper": "black", "rim": "steel", "dual": false,
	"axles": [], "exhaust": true, "fit": [], "wear": 0, "paint": Color(0.74,0.34,0.16),
}

const STREET_MODELS := ["hatch_01","hatch_04","hatch_07","saloon_01","saloon_08","saloon_06","estate_01","estate_05"]
## One car waits at each island's camp, in island order.
const CAMP_MODELS := ["estate_03","offroad_01","pickup_02","hatch_02","van_02"]
const POLICE_MODEL := "service_01"
const PICKS := ["hatch_02","saloon_02","estate_03","muscle_01","offroad_01","pickup_02","van_02","camper_01","service_03","truck_02","bus_01","rig_01"]

const TYPES := [
	{"id": "hatch", "label": "Hatchback", "base": {"len": 3.9, "ax_f": 0.72, "ax_r": 3.25, "nose": 0.7, "belt": 0.93, "tail": 0.98, "cowl": 1.12, "peak": 1.72, "back": 3.3, "foot": 3.72, "roof": 1.46, "pillars": [2.4], "tail_lamp": "tall"}, "models": [
		{"name": "City Runabout", "paint": Color(0.27,0.47,0.56), "front": "slot", "lamp": "slim"},
		{"name": "Tin Box 900", "paint": Color(0.84,0.48,0.13), "len": 3.6, "ax_r": 3.0, "cowl": 1.0, "peak": 1.42, "back": 3.1, "foot": 3.45, "roof": 1.5, "tuck": 0.88, "lamp": "square", "front": "bars", "bumper": "chrome", "tail_lamp": "rect", "pillars": [2.25]},
		{"name": "Hot Hatch GTi", "paint": Color(0.72,0.1,0.1), "ride": 0.2, "r": 0.34, "tw": 0.26, "roof": 1.38, "front": "mesh", "lamp": "slim", "rim": "star", "fit": ["lip","splitter","hood_stripe"], "paint2": Color(0.08,0.08,0.09)},
		{"name": "Three-Door Rally", "paint": Color(0.92,0.9,0.84), "ride": 0.32, "r": 0.36, "tw": 0.28, "lamp": "round", "front": "mesh", "rim": "deep", "rim_paint": Color(0.92,0.92,0.92), "fit": ["rally","band","lip"], "paint2": Color(0.1,0.28,0.6), "flare": Color(0.1,0.1,0.11), "bumper": "none"},
		{"name": "Pensioner's Special", "paint": Color(0.62,0.72,0.6), "len": 3.7, "ax_r": 3.08, "foot": 3.55, "back": 3.1, "cowl": 1.08, "front": "slats", "lamp": "round", "bumper": "chrome", "tail_lamp": "small", "rub": "chrome", "paint2": Color(0.9,0.87,0.78), "roof_paint": Color(0.9,0.87,0.78)},
		{"name": "Five-Door Family", "paint": Color(0.56,0.58,0.6), "len": 4.15, "ax_r": 3.45, "back": 3.55, "foot": 3.98, "pillars": [2.3,3.2], "fit": ["rails"], "lamp": "slim", "front": "split"},
		{"name": "Rust Bucket", "paint": Color(0.33,0.42,0.3), "lamp": "square", "front": "slats", "bumper": "none", "wear": 2, "tuck": 0.86, "rim": "steel"},
		{"name": "Tall Micro", "paint": Color(0.86,0.72,0.2), "len": 3.3, "ax_f": 0.56, "ax_r": 2.8, "cowl": 0.8, "peak": 1.2, "back": 2.95, "foot": 3.2, "roof": 1.66, "tuck": 0.9, "belt": 1.0, "nose": 0.8, "tail": 1.0, "pillars": [2.05], "front": "flat", "lamp": "round", "rim": "steel", "roof_paint": Color(0.93,0.91,0.83)},
		{"name": "Soft-Roof Cabby", "paint": Color(0.14,0.3,0.26), "roof_paint": Color(0.11,0.11,0.12), "rear_glass": true, "lamp": "round", "front": "chrome", "bumper": "chrome", "rub": "chrome", "tuck": 0.76, "roof": 1.38, "exhaust": false},
		{"name": "Scavenged Hatch", "paint": Color(0.52,0.2,0.14), "ride": 0.36, "r": 0.38, "tw": 0.28, "wear": 2, "front": "mesh", "lamp": "square", "bumper": "steel", "flare": Color(0.09,0.09,0.1), "fit": ["rack","luggage","bull","mesh"]},
	]},
	{"id": "saloon", "label": "Saloon", "base": {"len": 4.4, "ax_f": 0.85, "ax_r": 3.55, "nose": 0.7, "belt": 0.92, "tail": 0.95, "cowl": 1.38, "peak": 1.98, "back": 3.0, "foot": 3.55, "roof": 1.42, "pillars": [2.5]}, "models": [
		{"name": "Commuter Four", "paint": Color(0.42,0.46,0.5), "lamp": "rect", "front": "slot"},
		{"name": "Old Reliable", "paint": Color(0.16,0.27,0.46), "lamp": "quad", "front": "chrome", "bumper": "chrome", "rub": "chrome", "tuck": 0.84, "roof": 1.46, "tail_lamp": "rect", "doors": [1.48,2.5,3.1]},
		{"name": "Executive V8", "paint": Color(0.08,0.09,0.11), "len": 4.8, "ax_r": 3.95, "cowl": 1.6, "peak": 2.2, "back": 3.3, "foot": 3.9, "tail": 0.98, "front": "chrome", "lamp": "slim", "bumper": "body", "rim": "star", "rub": "chrome", "pillars": [2.75], "tail_lamp": "bar"},
		{"name": "Sports Saloon", "paint": Color(0.1,0.32,0.62), "ride": 0.2, "tw": 0.26, "roof": 1.36, "lamp": "slim", "front": "mesh", "rim": "star", "fit": ["spoiler","splitter","hood_vents"], "tail_lamp": "bar"},
		{"name": "Minicab", "paint": Color(0.93,0.74,0.13), "lamp": "rect", "front": "split", "fit": ["taxi","checker"], "paint2": Color(0.08,0.08,0.09), "bumper": "body"},
		{"name": "Fleet Special", "paint": Color(0.86,0.86,0.84), "lamp": "square", "front": "bars", "roof": 1.46, "tuck": 0.84, "rim": "steel", "bumper": "black", "wear": 1},
		{"name": "Landau", "paint": Color(0.33,0.08,0.12), "len": 4.9, "ax_r": 4.0, "cowl": 1.72, "peak": 2.25, "back": 3.2, "foot": 3.9, "belt": 0.94, "nose": 0.76, "tuck": 0.86, "roof": 1.46, "lamp": "quad", "front": "chrome", "bumper": "chrome", "rub": "chrome", "fit": ["vinyl"], "pillars": [2.78], "tail_lamp": "tall"},
		{"name": "Fastback Four", "paint": Color(0.17,0.42,0.34), "back": 2.8, "foot": 4.0, "tail": 0.97, "roof": 1.38, "lamp": "slim", "front": "split", "tail_lamp": "bar", "rim": "star"},
		{"name": "Writer-Off", "paint": Color(0.45,0.4,0.31), "front": "slats", "lamp": "square", "wear": 2, "bumper": "none", "exhaust": false},
		{"name": "Boarded Saloon", "paint": Color(0.3,0.31,0.26), "ride": 0.32, "r": 0.36, "wear": 2, "lamp": "square", "front": "mesh", "bumper": "steel", "fit": ["boards","spikes","rack"]},
	]},
	{"id": "estate", "label": "Estate", "base": {"len": 4.5, "ax_f": 0.85, "ax_r": 3.6, "nose": 0.72, "belt": 0.94, "tail": 0.96, "cowl": 1.34, "peak": 1.92, "back": 4.08, "foot": 4.34, "roof": 1.46, "pillars": [2.45,3.45], "tail_lamp": "tall", "tuck": 0.84}, "models": [
		{"name": "Family Wagon", "paint": Color(0.66,0.62,0.52), "lamp": "rect", "front": "slot", "fit": ["rails"]},
		{"name": "Timber Tourer", "paint": Color(0.85,0.79,0.62), "lamp": "round", "front": "chrome", "bumper": "chrome", "fit": ["wood","rack"], "tail_lamp": "round", "roof_paint": Color(0.85,0.79,0.62)},
		{"name": "Long-Roof Swede", "paint": Color(0.64,0.3,0.14), "len": 4.75, "ax_r": 3.8, "back": 4.42, "foot": 4.62, "peak": 1.82, "tuck": 0.9, "roof": 1.5, "lamp": "square", "front": "bars", "bumper": "black", "pillars": [2.4,3.5], "fit": ["rack"]},
		{"name": "Shooting Brake", "paint": Color(0.14,0.25,0.2), "ride": 0.22, "belt": 0.88, "roof": 1.32, "cowl": 1.55, "peak": 2.15, "back": 3.95, "foot": 4.3, "lamp": "slim", "front": "chrome", "rim": "star", "tuck": 0.78, "pillars": [2.65]},
		{"name": "School-Run Diesel", "paint": Color(0.5,0.62,0.68), "lamp": "rect", "front": "split", "wear": 1, "fit": ["rails","luggage"]},
		{"name": "Fast Wagon RS", "paint": Color(0.86,0.72,0.24), "ride": 0.2, "tw": 0.26, "lamp": "slim", "front": "mesh", "rim": "star", "fit": ["lip","splitter","hood_vents"], "tail_lamp": "bar"},
		{"name": "Hearse", "paint": Color(0.05,0.05,0.06), "len": 5.5, "ax_r": 4.3, "cowl": 1.55, "peak": 2.1, "back": 5.05, "foot": 5.3, "roof": 1.62, "belt": 0.96, "tuck": 0.92, "front": "chrome", "bumper": "chrome", "lamp": "quad", "rub": "chrome", "glass_to": 4.95, "pillars": [2.7,3.8], "doors": [1.65,2.7,3.75]},
		{"name": "Lifted Country", "paint": Color(0.2,0.36,0.3), "ride": 0.38, "r": 0.39, "tw": 0.27, "lamp": "round", "front": "bars", "flare": Color(0.1,0.1,0.11), "bumper": "steel", "fit": ["rack","bull"], "paint2": Color(0.75,0.71,0.58)},
		{"name": "Surf Wagon", "paint": Color(0.33,0.64,0.66), "lamp": "round", "front": "slats", "bumper": "chrome", "roof_paint": Color(0.93,0.9,0.8), "fit": ["rack","low_band"], "paint2": Color(0.93,0.9,0.8), "wear": 1},
		{"name": "Salvage Wagon", "paint": Color(0.36,0.3,0.25), "ride": 0.34, "r": 0.37, "wear": 2, "front": "mesh", "lamp": "square", "bumper": "steel", "fit": ["boards","rack","luggage","jerry"]},
	]},
	{"id": "muscle", "label": "Muscle & Sports", "base": {"len": 4.5, "wid": 1.86, "ride": 0.22, "r": 0.35, "tw": 0.3, "ax_f": 0.95, "ax_r": 3.62, "nose": 0.66, "belt": 0.84, "tail": 0.92, "cowl": 1.75, "peak": 2.32, "back": 2.95, "foot": 3.8, "roof": 1.24, "crown": 0.02, "tuck": 0.78, "pillars": [], "grille_w": 0.74, "tail_lamp": "bar", "rim": "deep"}, "models": [
		{"name": "Interceptor 440", "paint": Color(0.8,0.3,0.06), "front": "split", "lamp": "quad", "bumper": "chrome", "fit": ["stripes","scoop"], "paint2": Color(0.05,0.05,0.06)},
		{"name": "Blacktop GT", "paint": Color(0.06,0.07,0.08), "front": "mesh", "lamp": "hooded", "fit": ["blower","side_pipes"], "bumper": "none"},
		{"name": "Pony Fastback", "paint": Color(0.17,0.4,0.27), "len": 4.3, "ax_r": 3.46, "cowl": 1.62, "peak": 2.15, "back": 2.65, "foot": 3.95, "front": "mesh", "lamp": "round", "bumper": "chrome", "fit": ["lip"], "rim": "star"},
		{"name": "Wedge Turbo", "paint": Color(0.85,0.82,0.14), "len": 4.2, "wid": 1.88, "ride": 0.17, "r": 0.31, "nose": 0.6, "belt": 0.8, "tail": 0.94, "cowl": 1.55, "peak": 2.25, "back": 2.65, "foot": 3.6, "roof": 1.12, "tuck": 0.74, "ax_f": 0.82, "ax_r": 3.32, "front": "slot", "lamp": "slim", "rim": "star", "fit": ["spoiler","splitter"], "bumper": "none"},
		{"name": "Vinyl Roof Cruiser", "paint": Color(0.1,0.16,0.42), "len": 4.8, "ax_r": 3.82, "cowl": 1.9, "peak": 2.42, "back": 3.1, "foot": 3.9, "front": "chrome", "lamp": "quad", "bumper": "chrome", "rub": "chrome", "fit": ["vinyl"]},
		{"name": "Roadster 2.0", "paint": Color(0.7,0.1,0.1), "len": 3.95, "wid": 1.72, "tw": 0.24, "ax_f": 0.8, "ax_r": 3.1, "cowl": 1.68, "peak": 1.98, "back": 2.45, "foot": 2.68, "roof": 1.14, "belt": 0.86, "tail": 0.86, "nose": 0.62, "front": "slats", "lamp": "round", "bumper": "chrome", "roof_paint": Color(0.1,0.1,0.11), "fit": ["hood_stripe"], "paint2": Color(0.92,0.9,0.85), "tail_lamp": "round"},
		{"name": "Drag Street", "paint": Color(0.5,0.09,0.42), "ride": 0.28, "fit": ["blower","hood_vents"], "front": "mesh", "lamp": "quad", "flare": Color(0.08,0.08,0.09), "bumper": "none", "rim": "star"},
		{"name": "Le Mans Replica", "paint": Color(0.84,0.84,0.82), "ride": 0.17, "r": 0.31, "nose": 0.58, "belt": 0.78, "tail": 0.9, "roof": 1.08, "cowl": 1.6, "peak": 2.15, "back": 2.8, "foot": 3.75, "tuck": 0.72, "front": "slot", "lamp": "hooded", "fit": ["stripes","spoiler","splitter"], "paint2": Color(0.08,0.24,0.56), "bumper": "none", "rim": "star"},
		{"name": "Barn Find", "paint": Color(0.34,0.38,0.33), "wear": 2, "front": "split", "lamp": "quad", "bumper": "none", "rim": "steel", "exhaust": false},
		{"name": "Road Warrior", "paint": Color(0.1,0.1,0.11), "ride": 0.28, "r": 0.38, "wear": 1, "flare": Color(0.08,0.08,0.09), "front": "bars", "lamp": "hooded", "fit": ["ram","blower","side_pipes","spikes"], "bumper": "none"},
	]},
	{"id": "offroad", "label": "4x4 & SUV", "base": {"len": 4.3, "wid": 1.86, "ride": 0.46, "r": 0.44, "tw": 0.32, "ax_f": 0.8, "ax_r": 3.42, "nose": 0.98, "belt": 1.18, "tail": 1.18, "cowl": 1.1, "peak": 1.42, "back": 3.85, "foot": 4.2, "roof": 1.84, "crown": 0.02, "tuck": 0.88, "pillars": [2.25,3.1], "front": "bars", "lamp": "round", "tail_lamp": "small", "bumper": "steel", "rim": "steel", "flare": Color(0.09,0.09,0.1), "rub": "none"}, "models": [
		{"name": "Land Mule 110", "paint": Color(0.3,0.38,0.3), "roof_paint": Color(0.88,0.86,0.76), "fit": ["rack","spare","snorkel"], "wear": 1},
		{"name": "Short Wheelbase", "paint": Color(0.14,0.28,0.36), "len": 3.7, "ax_r": 2.92, "back": 3.3, "foot": 3.6, "pillars": [2.1], "fit": ["spare"], "roof_paint": Color(0.92,0.9,0.82)},
		{"name": "Mud Plugger", "paint": Color(0.66,0.14,0.1), "r": 0.5, "ride": 0.56, "tw": 0.4, "fit": ["roof_spare","rack","winch","snorkel"], "wear": 1, "belt": 1.26, "nose": 1.08, "tail": 1.26, "roof": 1.92},
		{"name": "Soft Top", "paint": Color(0.75,0.68,0.42), "roof_paint": Color(0.3,0.3,0.24), "len": 3.9, "ax_r": 3.1, "back": 3.55, "foot": 3.8, "pillars": [2.2], "pillar_width": 0.1, "fit": ["spare","jerry"]},
		{"name": "Square Wagon", "paint": Color(0.62,0.6,0.56), "len": 4.8, "ax_r": 3.75, "back": 4.4, "foot": 4.68, "cowl": 1.25, "peak": 1.55, "roof": 1.9, "tuck": 0.93, "front": "chrome", "lamp": "square", "pillars": [2.35,3.4], "fit": ["rails"], "rim": "star"},
		{"name": "Suburban Tank", "paint": Color(0.08,0.09,0.1), "len": 5.2, "wid": 1.98, "ax_f": 0.9, "ax_r": 4.15, "cowl": 1.35, "peak": 1.72, "back": 4.85, "foot": 5.08, "front": "chrome", "lamp": "rect", "bumper": "chrome", "rim": "star", "pillars": [2.5,3.6], "rub": "chrome", "fit": ["rails","steps"]},
		{"name": "School-Gate SUV", "paint": Color(0.82,0.82,0.8), "ride": 0.34, "r": 0.39, "nose": 0.86, "belt": 1.06, "tail": 1.06, "roof": 1.68, "tuck": 0.82, "cowl": 1.25, "peak": 1.8, "back": 3.75, "foot": 4.15, "front": "split", "lamp": "slim", "bumper": "black", "rim": "star", "tail_lamp": "tall", "fit": ["rails"]},
		{"name": "Expedition", "paint": Color(0.82,0.74,0.56), "fit": ["rack","tent","snorkel","winch","jerry","spare"], "paint2": Color(0.32,0.5,0.34), "wear": 1, "bumper": "steel"},
		{"name": "Forestry Ranger", "paint": Color(0.18,0.33,0.2), "fit": ["rack","beacon","band"], "paint2": Color(0.93,0.87,0.3)},
		{"name": "Zombie Hunter", "paint": Color(0.2,0.21,0.17), "r": 0.5, "ride": 0.56, "tw": 0.4, "belt": 1.26, "nose": 1.08, "tail": 1.26, "roof": 1.92, "wear": 2, "front": "mesh", "fit": ["bull","rack","rally","mesh","cage","spare","jerry"]},
	]},
	{"id": "pickup", "label": "Pickup", "base": {"len": 5.1, "wid": 1.88, "ride": 0.42, "r": 0.41, "tw": 0.3, "ax_f": 0.85, "ax_r": 4.0, "nose": 0.96, "belt": 1.14, "tail": 1.14, "cowl": 1.25, "peak": 1.62, "back": 2.55, "foot": 2.64, "roof": 1.75, "tuck": 0.88, "pillars": [2.12], "doors": [1.32,2.12,2.5], "tail_lamp": "tall", "bumper": "chrome", "fit": ["bed"], "rub": "none"}, "models": [
		{"name": "Work Single", "paint": Color(0.84,0.84,0.82), "front": "bars", "lamp": "square", "fit": ["bed","load"], "wear": 1},
		{"name": "Farm Hand", "paint": Color(0.17,0.33,0.5), "front": "chrome", "lamp": "round", "fit": ["bed","band","tow"], "paint2": Color(0.9,0.87,0.78)},
		{"name": "Crew Cab", "paint": Color(0.1,0.11,0.12), "len": 5.5, "ax_r": 4.25, "back": 3.1, "foot": 3.18, "pillars": [2.2,2.65], "doors": [1.32,2.2,3.0], "front": "chrome", "lamp": "rect", "bumper": "black", "rim": "star", "fit": ["bed","steps"]},
		{"name": "Compact Ute", "paint": Color(0.86,0.5,0.14), "len": 4.45, "wid": 1.74, "ride": 0.28, "r": 0.34, "tw": 0.24, "ax_f": 0.75, "ax_r": 3.55, "nose": 0.72, "belt": 0.94, "tail": 0.94, "cowl": 1.25, "peak": 1.75, "back": 2.45, "foot": 2.55, "roof": 1.46, "tuck": 0.84, "front": "slats", "lamp": "rect", "bumper": "black", "fit": ["bed"], "doors": [1.3,2.45], "pillars": []},
		{"name": "Stepside Classic", "paint": Color(0.33,0.56,0.54), "len": 4.9, "ax_r": 3.82, "belt": 1.1, "nose": 1.0, "tail": 1.1, "front": "bars", "lamp": "round", "tail_lamp": "round", "rim": "steel", "rim_paint": Color(0.88,0.84,0.72), "fit": ["bed","steps"], "flare": Color(0.33,0.56,0.54)},
		{"name": "Canopy Tradesman", "paint": Color(0.58,0.6,0.62), "front": "split", "lamp": "rect", "bumper": "black", "fit": ["bed","canopy","ladder"]},
		{"name": "Tarp Hauler", "paint": Color(0.36,0.4,0.28), "front": "bars", "lamp": "round", "bumper": "steel", "fit": ["bed","tarp"], "wear": 1},
		{"name": "Monster Lift", "paint": Color(0.75,0.1,0.08), "r": 0.6, "ride": 0.74, "tw": 0.42, "nose": 1.3, "belt": 1.48, "tail": 1.48, "roof": 2.08, "flare": Color(0.08,0.08,0.09), "front": "chrome", "lamp": "square", "bumper": "steel", "rim": "deep", "track": 0.1, "fit": ["bed","rally","bull"]},
		{"name": "Tow Rig", "paint": Color(0.9,0.72,0.14), "front": "chrome", "lamp": "rect", "bumper": "steel", "fit": ["bed","crane","redbar"], "wear": 1, "exhaust": false},
		{"name": "Technical", "paint": Color(0.55,0.5,0.36), "wear": 2, "front": "mesh", "lamp": "round", "bumper": "steel", "fit": ["bed","roll","sandbags","jerry","bull"], "exhaust": false},
	]},
	{"id": "van", "label": "Panel Van", "base": {"len": 5.0, "wid": 1.95, "ride": 0.3, "r": 0.35, "tw": 0.24, "ax_f": 0.82, "ax_r": 3.95, "nose": 0.92, "belt": 1.2, "tail": 1.2, "cowl": 0.5, "peak": 1.1, "back": 4.85, "foot": 4.94, "roof": 2.2, "crown": 0.02, "tuck": 0.93, "pillars": [], "glass_to": 1.72, "rear_glass": false, "doors": [0.72,1.78,3.0], "front": "slats", "bumper": "body", "tail_lamp": "tall", "rub": "black"}, "models": [
		{"name": "Tradesman LWB", "paint": Color(0.86,0.86,0.84), "lamp": "rect", "fit": ["rack","ladder"]},
		{"name": "Parcel Runner", "paint": Color(0.24,0.42,0.52), "len": 4.5, "ax_r": 3.5, "lamp": "rect", "front": "split", "fit": ["band"], "paint2": Color(0.92,0.75,0.2), "wear": 1},
		{"name": "Bread Van", "paint": Color(0.82,0.72,0.44), "len": 4.4, "ax_f": 0.64, "ax_r": 3.5, "wid": 2.05, "cowl": 0.12, "peak": 0.42, "roof": 2.42, "tuck": 0.98, "belt": 1.34, "nose": 1.3, "tail": 1.34, "lamp": "round", "front": "flat", "bumper": "chrome", "glass_to": 1.2, "doors": [0.44,1.2], "fit": ["low_band"], "paint2": Color(0.62,0.17,0.12)},
		{"name": "Ice Cream Van", "paint": Color(0.93,0.82,0.86), "len": 4.8, "ax_r": 3.7, "lamp": "round", "front": "slats", "bumper": "chrome", "fit": ["checker","awning"], "paint2": Color(0.28,0.56,0.64)},
		{"name": "Sprinter High Roof", "paint": Color(0.14,0.16,0.2), "len": 5.9, "ax_r": 4.5, "back": 5.72, "foot": 5.84, "roof": 2.56, "lamp": "slim", "front": "split", "doors": [0.72,1.78,3.4], "bumper": "black"},
		{"name": "Micro Kei Van", "paint": Color(0.54,0.72,0.74), "len": 3.4, "wid": 1.5, "r": 0.28, "tw": 0.18, "ride": 0.24, "ax_f": 0.5, "ax_r": 2.8, "cowl": 0.12, "peak": 0.38, "back": 3.28, "foot": 3.36, "belt": 1.08, "nose": 1.02, "tail": 1.08, "roof": 1.92, "tuck": 0.95, "lamp": "square", "front": "flat", "glass_to": 1.05, "doors": [0.32,1.1], "bumper": "black", "exhaust": false},
		{"name": "Dog Catcher", "paint": Color(0.72,0.7,0.62), "lamp": "square", "front": "bars", "bumper": "black", "wear": 1, "fit": ["beacon","band"], "paint2": Color(0.12,0.26,0.4)},
		{"name": "Blacked-Out Unmarked", "paint": Color(0.05,0.055,0.06), "lamp": "slim", "front": "mesh", "bumper": "black", "rim": "star"},
		{"name": "Courier Beater", "paint": Color(0.46,0.14,0.12), "wear": 2, "bumper": "none", "lamp": "square", "front": "slats"},
		{"name": "Fortified Van", "paint": Color(0.26,0.28,0.25), "wear": 2, "ride": 0.38, "r": 0.4, "tw": 0.28, "lamp": "square", "front": "mesh", "bumper": "steel", "fit": ["plates","mesh","rack","bull"]},
	]},
	{"id": "camper", "label": "Minibus & Camper", "base": {"len": 5.2, "wid": 1.98, "ride": 0.3, "r": 0.35, "tw": 0.24, "ax_f": 0.72, "ax_r": 4.1, "nose": 0.92, "belt": 1.22, "tail": 1.22, "cowl": 0.36, "peak": 0.88, "back": 5.0, "foot": 5.1, "roof": 2.16, "crown": 0.02, "tuck": 0.9, "pillars": [1.75,2.75,3.75], "doors": [0.65,1.75,2.75], "front": "flat", "bumper": "chrome", "tail_lamp": "tall", "rub": "none", "lamp": "round"}, "models": [
		{"name": "Split-Screen Wanderer", "paint": Color(0.26,0.55,0.52), "roof_paint": Color(0.92,0.89,0.8), "fit": ["low_band","rack","poptop"], "paint2": Color(0.92,0.89,0.8)},
		{"name": "Pop-Top Tourer", "paint": Color(0.84,0.46,0.14), "roof_paint": Color(0.92,0.89,0.8), "fit": ["poptop"], "paint2": Color(0.92,0.89,0.8)},
		{"name": "Airport Shuttle", "paint": Color(0.86,0.86,0.84), "len": 5.9, "ax_r": 4.6, "back": 5.72, "foot": 5.82, "pillars": [1.75,2.65,3.55,4.45], "front": "split", "lamp": "rect", "bumper": "black", "fit": ["band","hightop"], "paint2": Color(0.14,0.36,0.6)},
		{"name": "Church Minibus", "paint": Color(0.92,0.9,0.82), "len": 5.7, "ax_r": 4.45, "back": 5.5, "foot": 5.6, "pillars": [1.8,2.75,3.7,4.65], "front": "slats", "lamp": "rect", "bumper": "black", "fit": ["low_band","rack"], "paint2": Color(0.56,0.16,0.14), "wear": 1},
		{"name": "Hotel Courtesy", "paint": Color(0.12,0.2,0.18), "front": "chrome", "lamp": "square", "fit": ["rails","cab_stripe"], "paint2": Color(0.78,0.66,0.34)},
		{"name": "Motorhome Lite", "paint": Color(0.88,0.84,0.74), "len": 6.1, "ax_r": 4.5, "back": 5.9, "foot": 6.0, "roof": 2.3, "cowl": 0.5, "peak": 1.05, "glass_to": 4.8, "pillars": [1.95,3.4], "front": "slats", "lamp": "rect", "fit": ["hightop","low_band","ac","ladder"], "paint2": Color(0.6,0.42,0.2), "bumper": "black"},
		{"name": "Hippie Bus", "paint": Color(0.55,0.28,0.6), "wear": 1, "roof_paint": Color(0.9,0.76,0.2), "fit": ["rack","luggage","low_band"], "paint2": Color(0.28,0.64,0.5)},
		{"name": "Crew Bus", "paint": Color(0.92,0.62,0.12), "front": "bars", "lamp": "square", "fit": ["beacon","rack"], "bumper": "black", "wear": 1},
		{"name": "Rooftop Stayer", "paint": Color(0.4,0.48,0.42), "ride": 0.38, "r": 0.4, "tw": 0.28, "fit": ["rack","tent","jerry","spare"], "paint2": Color(0.86,0.5,0.2), "flare": Color(0.08,0.08,0.09), "bumper": "steel", "wear": 1},
		{"name": "Safe-Room Camper", "paint": Color(0.5,0.47,0.4), "wear": 2, "ride": 0.38, "r": 0.4, "tw": 0.28, "bumper": "steel", "fit": ["boards","mesh","rack","luggage","bull"]},
	]},
	{"id": "service", "label": "Emergency & Service", "base": {"len": 4.5, "ax_f": 0.85, "ax_r": 3.6, "nose": 0.72, "belt": 0.94, "tail": 0.97, "cowl": 1.38, "peak": 1.96, "back": 3.05, "foot": 3.62, "roof": 1.44, "pillars": [2.5], "bumper": "black", "front": "slot"}, "models": [
		{"name": "Police Saloon", "paint": Color(0.92,0.92,0.92), "fit": ["lightbar","checker"], "paint2": Color(0.1,0.17,0.4), "lamp": "rect"},
		{"name": "Police Estate", "paint": Color(0.92,0.92,0.92), "back": 4.08, "foot": 4.34, "pillars": [2.45,3.45], "fit": ["lightbar","band"], "paint2": Color(0.12,0.3,0.68), "lamp": "slim", "tail_lamp": "tall"},
		{"name": "Riot Wagon", "paint": Color(0.1,0.13,0.25), "len": 5.2, "wid": 2.04, "ride": 0.34, "r": 0.38, "tw": 0.26, "ax_f": 0.82, "ax_r": 4.1, "nose": 0.95, "belt": 1.24, "tail": 1.24, "cowl": 0.45, "peak": 1.05, "back": 5.05, "foot": 5.12, "roof": 2.26, "crown": 0.01, "tuck": 0.94, "pillars": [], "glass_to": 1.72, "rear_glass": false, "doors": [0.72,1.78,3.2], "front": "mesh", "lamp": "square", "bumper": "steel", "fit": ["lightbar","mesh","band"], "paint2": Color(0.86,0.76,0.2)},
		{"name": "Paramedic Van", "paint": Color(0.92,0.9,0.42), "len": 5.3, "wid": 2.0, "ride": 0.32, "r": 0.36, "ax_f": 0.8, "ax_r": 4.15, "nose": 0.92, "belt": 1.22, "tail": 1.22, "cowl": 0.5, "peak": 1.08, "back": 5.15, "foot": 5.22, "roof": 2.34, "crown": 0.01, "tuck": 0.95, "pillars": [], "glass_to": 1.72, "rear_glass": false, "doors": [0.72,1.78], "front": "split", "lamp": "rect", "fit": ["lightbar","checker","hightop"], "paint2": Color(0.14,0.5,0.32), "tail_lamp": "tall"},
		{"name": "Box Ambulance", "paint": Color(0.92,0.92,0.9), "len": 5.9, "wid": 2.1, "ride": 0.36, "r": 0.4, "tw": 0.26, "ax_f": 0.85, "ax_r": 4.4, "nose": 0.98, "belt": 1.2, "tail": 1.2, "step": true, "cowl": 0.95, "peak": 1.2, "back": 2.05, "foot": 2.12, "roof": 2.0, "tuck": 0.92, "pillars": [], "doors": [1.1,2.05], "front": "bars", "lamp": "square", "fit": ["redbar","cross","band"], "paint2": Color(0.75,0.13,0.1), "box": {"a": 2.14, "b": 5.88, "top": 2.8, "ribs": 2, "color": Color(0.92,0.92,0.9)}},
		{"name": "Fire Engine", "paint": Color(0.76,0.11,0.08), "len": 7.0, "wid": 2.4, "ride": 0.52, "r": 0.5, "tw": 0.34, "ax_f": 1.2, "ax_r": 5.3, "nose": 1.2, "belt": 1.58, "tail": 1.58, "cowl": 0.14, "peak": 0.44, "back": 2.65, "foot": 2.72, "roof": 2.7, "crown": 0.01, "tuck": 0.96, "pillars": [1.55], "doors": [0.3,1.55,2.5], "front": "chrome", "lamp": "square", "bumper": "chrome", "dual": true, "rim": "truck", "fit": ["redbar","band","pump","hose","ladder"], "pump_t": 2.75, "paint2": Color(0.93,0.84,0.34), "tail_lamp": "small"},
		{"name": "Mountain Rescue", "paint": Color(0.86,0.3,0.06), "wid": 1.86, "ride": 0.46, "r": 0.44, "tw": 0.32, "ax_f": 0.8, "ax_r": 3.42, "len": 4.4, "nose": 0.98, "belt": 1.18, "tail": 1.18, "cowl": 1.1, "peak": 1.42, "back": 3.9, "foot": 4.25, "roof": 1.84, "tuck": 0.88, "pillars": [2.25,3.1], "front": "bars", "lamp": "round", "bumper": "steel", "flare": Color(0.08,0.08,0.09), "fit": ["redbar","rack","winch","band"], "paint2": Color(0.92,0.92,0.9), "rub": "none", "tail_lamp": "small"},
		{"name": "Army Jeep Patrol", "paint": Color(0.27,0.31,0.2), "len": 3.8, "wid": 1.8, "ride": 0.46, "r": 0.42, "tw": 0.3, "ax_f": 0.72, "ax_r": 3.02, "nose": 1.02, "belt": 1.12, "tail": 1.12, "cowl": 1.25, "peak": 1.36, "back": 3.4, "foot": 3.7, "roof": 1.78, "tuck": 0.92, "pillars": [2.2], "front": "bars", "lamp": "round", "bumper": "steel", "rub": "none", "fit": ["spare","jerry"], "roof_paint": Color(0.33,0.33,0.24), "tail_lamp": "small", "wear": 1},
		{"name": "Bin Lorry Pickup", "paint": Color(0.9,0.62,0.1), "len": 5.1, "wid": 1.88, "ride": 0.42, "r": 0.41, "tw": 0.3, "ax_r": 4.0, "nose": 0.96, "belt": 1.14, "tail": 1.14, "cowl": 1.25, "peak": 1.62, "back": 2.55, "foot": 2.64, "roof": 1.75, "tuck": 0.88, "pillars": [2.12], "doors": [1.32,2.12], "front": "bars", "lamp": "square", "fit": ["bed","drums","beacon"], "bumper": "steel", "wear": 1},
		{"name": "Hazmat Response", "paint": Color(0.86,0.8,0.14), "len": 5.2, "wid": 2.04, "ride": 0.34, "r": 0.38, "tw": 0.26, "ax_f": 0.82, "ax_r": 4.1, "nose": 0.95, "belt": 1.24, "tail": 1.24, "cowl": 0.45, "peak": 1.05, "back": 5.05, "foot": 5.12, "roof": 2.26, "crown": 0.01, "tuck": 0.94, "pillars": [], "glass_to": 1.72, "rear_glass": false, "doors": [0.72,1.78,3.2], "front": "bars", "lamp": "square", "bumper": "steel", "fit": ["redbar","chevrons","rack"], "paint2": Color(0.1,0.1,0.11), "wear": 1},
	]},
	{"id": "truck", "label": "Lorry & Truck", "base": {"len": 7.5, "wid": 2.4, "ride": 0.62, "r": 0.52, "tw": 0.3, "ax_f": 1.05, "ax_r": 5.6, "nose": 1.3, "belt": 1.72, "tail": 1.14, "step": true, "cowl": 0.2, "peak": 0.55, "back": 1.8, "foot": 1.86, "roof": 2.8, "crown": 0.01, "tuck": 0.92, "pillars": [], "doors": [0.3,1.72], "dual": true, "rim": "truck", "front": "slats", "lamp": "square", "bumper": "steel", "tail_lamp": "small", "rub": "none", "grille_w": 0.74, "exhaust": false, "box": {"a": 1.92, "b": 7.46, "top": 3.3, "color": Color(0.84,0.82,0.76)}}, "models": [
		{"name": "Removals Luton", "paint": Color(0.72,0.14,0.1), "wear": 1, "box": {"a": 1.92, "b": 7.46, "top": 3.4, "color": Color(0.74,0.16,0.11)}},
		{"name": "Shutter Box", "paint": Color(0.86,0.86,0.84), "box": {"a": 1.92, "b": 7.46, "top": 3.3, "shutter": true, "color": Color(0.86,0.86,0.84)}, "fit": ["visor"]},
		{"name": "Fridge Truck", "paint": Color(0.14,0.3,0.46), "len": 6.8, "ax_r": 5.0, "box": {"a": 1.92, "b": 6.76, "top": 3.25, "ribs": 3, "color": Color(0.92,0.92,0.9)}, "fit": ["visor","exhaust_stack"]},
		{"name": "Flatbed", "paint": Color(0.84,0.56,0.1), "box": {"a": 1.92, "b": 7.46, "top": 1.3, "ribs": 10, "color": Color(0.32,0.25,0.18)}, "fit": ["exhaust_stack"]},
		{"name": "Tipper", "paint": Color(0.58,0.62,0.2), "len": 6.6, "ax_r": 4.8, "box": {"a": 1.92, "b": 6.56, "top": 2.5, "ribs": 5, "color": Color(0.34,0.35,0.34)}, "wear": 2, "fit": ["visor"]},
		{"name": "Fuel Bowser", "paint": Color(0.12,0.12,0.14), "fit": ["tank","exhaust_stack"], "tank_paint": Color(0.82,0.82,0.8), "wear": 1, "box": {"a": 1.92, "b": 7.46, "top": 1.3, "ribs": 10, "color": Color(0.14,0.14,0.15)}},
		{"name": "Army Canvas", "paint": Color(0.27,0.32,0.21), "front": "bars", "lamp": "round", "ride": 0.72, "r": 0.58, "tw": 0.36, "dual": false, "fit": ["visor"], "box": {"a": 1.92, "b": 7.46, "top": 3.1, "ribs": 5, "color": Color(0.36,0.37,0.25)}},
		{"name": "Bonneted Tractor", "paint": Color(0.1,0.3,0.34), "len": 7.2, "ax_f": 1.1, "ax_r": 5.5, "cowl": 1.9, "peak": 2.2, "back": 3.1, "foot": 3.2, "nose": 1.52, "pillars": [], "doors": [2.0,3.05], "front": "chrome", "lamp": "round", "fit": ["exhaust_stack","visor"], "box": {"a": 3.3, "b": 7.15, "top": 3.25, "color": Color(0.82,0.8,0.74)}},
		{"name": "Tree Surgeon Crane", "paint": Color(0.9,0.62,0.1), "len": 6.6, "ax_r": 5.0, "box": {"a": 1.92, "b": 6.56, "top": 1.32, "ribs": 8, "color": Color(0.24,0.24,0.24)}, "fit": ["crane","beacon"], "wear": 1},
		{"name": "Survivor Hauler", "paint": Color(0.3,0.32,0.28), "wear": 2, "front": "mesh", "fit": ["mesh","plates","ram","spikes"], "box": {"a": 1.92, "b": 7.46, "top": 3.2, "ribs": 12, "color": Color(0.42,0.4,0.34)}},
	]},
	{"id": "bus", "label": "Bus & Coach", "base": {"len": 10.0, "wid": 2.5, "ride": 0.38, "r": 0.5, "tw": 0.3, "ax_f": 2.0, "ax_r": 7.4, "nose": 1.14, "belt": 1.5, "tail": 1.5, "cowl": 0.16, "peak": 0.34, "back": 9.84, "foot": 9.92, "roof": 3.0, "crown": 0.02, "tuck": 0.96, "pillars": [2.5,3.7,4.9,6.1,7.3,8.5], "doors": [8.8], "handles": false, "rub": "none", "front": "flat", "lamp": "rect", "bumper": "body", "tail_lamp": "tall", "rim": "truck", "exhaust": false, "grille_w": 0.7, "fit": ["door_bus","destination"]}, "models": [
		{"name": "Route 12 Single Deck", "paint": Color(0.76,0.14,0.1), "fit": ["door_bus","destination","band"], "paint2": Color(0.92,0.86,0.68)},
		{"name": "Yellow School Bus", "paint": Color(0.94,0.68,0.08), "len": 9.4, "ax_f": 1.05, "ax_r": 6.7, "cowl": 1.2, "peak": 1.42, "nose": 1.3, "belt": 1.52, "back": 9.26, "foot": 9.34, "roof": 2.95, "tuck": 0.94, "pillars": [2.4,3.3,4.2,5.1,6.0,6.9,7.8,8.7], "front": "bars", "lamp": "round", "bumper": "steel", "fit": ["band","stop_arm"], "paint2": Color(0.08,0.08,0.09)},
		{"name": "Luxury Coach", "paint": Color(0.92,0.9,0.86), "len": 11.5, "ax_r": 8.2, "roof": 3.34, "belt": 1.72, "nose": 1.3, "tail": 1.72, "back": 11.32, "foot": 11.42, "pillars": [2.6,4.1,5.6,7.1,8.6,10.1], "fit": ["door_bus","destination","low_band","ac"], "paint2": Color(0.14,0.3,0.54)},
		{"name": "Airport Transfer", "paint": Color(0.14,0.46,0.5), "len": 8.2, "ax_f": 1.7, "ax_r": 6.2, "back": 8.04, "foot": 8.12, "pillars": [2.5,3.7,4.9,6.1,7.2], "fit": ["door_bus","destination","ac"]},
		{"name": "Tour Rider", "paint": Color(0.06,0.06,0.07), "len": 11.0, "ax_r": 7.9, "belt": 1.84, "nose": 1.3, "tail": 1.84, "roof": 3.4, "back": 10.84, "foot": 10.92, "pillars": [2.6,4.1,5.6,7.1,8.6], "fit": ["door_bus","destination","cab_stripe","ac"], "paint2": Color(0.56,0.46,0.22)},
		{"name": "Community Shuttle", "paint": Color(0.2,0.44,0.26), "len": 7.2, "wid": 2.3, "r": 0.44, "ride": 0.34, "ax_f": 1.3, "ax_r": 5.4, "back": 7.04, "foot": 7.12, "roof": 2.8, "pillars": [2.4,3.4,4.4,5.4,6.3], "fit": ["door_bus","destination","low_band"], "paint2": Color(0.9,0.86,0.68), "lamp": "square"},
		{"name": "Prison Transfer", "paint": Color(0.52,0.56,0.54), "lamp": "square", "front": "bars", "bumper": "steel", "fit": ["door_bus","mesh","cab_stripe"], "paint2": Color(0.12,0.12,0.14), "wear": 1},
		{"name": "Army Personnel", "paint": Color(0.27,0.32,0.21), "bumper": "steel", "fit": ["door_bus","rack"], "lamp": "square", "wear": 1},
		{"name": "Rusted Terminus", "paint": Color(0.3,0.42,0.42), "wear": 2, "bumper": "none", "fit": ["door_bus","low_band"], "paint2": Color(0.73,0.68,0.52)},
		{"name": "Rolling Stronghold", "paint": Color(0.28,0.3,0.27), "wear": 2, "bumper": "steel", "lamp": "square", "fit": ["plates","mesh","ram","rack","spikes"]},
	]},
	{"id": "rig", "label": "Scavenger War Rig", "base": {"len": 5.1, "wid": 1.98, "ride": 0.5, "r": 0.48, "tw": 0.36, "ax_f": 0.88, "ax_r": 4.05, "nose": 1.04, "belt": 1.22, "tail": 1.22, "cowl": 1.25, "peak": 1.6, "back": 2.55, "foot": 2.64, "roof": 1.84, "tuck": 0.9, "pillars": [2.1], "doors": [1.32,2.1], "front": "mesh", "lamp": "square", "bumper": "steel", "rim": "steel", "flare": Color(0.08,0.08,0.09), "rub": "none", "tail_lamp": "small", "wear": 2, "exhaust": false, "plate_paint": Color(0.34,0.36,0.34)}, "models": [
		{"name": "Plough Pickup", "paint": Color(0.5,0.26,0.16), "fit": ["bed","plough","mesh","roll","sandbags","jerry"]},
		{"name": "Ram Wagon", "paint": Color(0.27,0.3,0.26), "back": 4.65, "foot": 4.92, "pillars": [2.25,3.3], "doors": [1.32,2.25,3.3], "fit": ["ram","plates","windscreen_slit","rack","spare"]},
		{"name": "Bone Shaker", "paint": Color(0.14,0.14,0.15), "len": 4.4, "ax_r": 3.5, "back": 3.95, "foot": 4.25, "pillars": [2.25,3.1], "fit": ["ram","spikes","cage","rally"], "paint2": Color(0.68,0.16,0.1)},
		{"name": "Gatecrasher", "paint": Color(0.62,0.48,0.14), "fit": ["bed","plough","plates","roll","drums"], "plate_paint": Color(0.5,0.3,0.14)},
		{"name": "Scrap Hound", "paint": Color(0.36,0.34,0.3), "len": 4.0, "ax_r": 3.15, "back": 3.55, "foot": 3.85, "fit": ["bull","boards","rack","luggage","jerry"], "pillars": [2.15], "doors": [1.32,2.15]},
		{"name": "Sand Rail", "paint": Color(0.8,0.54,0.2), "len": 4.0, "ride": 0.54, "r": 0.5, "tw": 0.4, "ax_f": 0.8, "ax_r": 3.25, "nose": 1.08, "belt": 1.16, "tail": 1.16, "cowl": 1.3, "peak": 1.45, "back": 2.8, "foot": 3.3, "roof": 1.7, "tuck": 0.8, "pillars": [], "doors": [1.4,2.8], "pillar_width": 0.1, "front": "bars", "fit": ["cage","rally"], "cage_at": [1.6,2.2,2.8], "wear": 1},
		{"name": "Steel Coffin", "paint": Color(0.22,0.24,0.24), "len": 5.3, "wid": 2.06, "ax_f": 0.82, "ax_r": 4.25, "cowl": 0.5, "peak": 1.05, "back": 5.12, "foot": 5.2, "roof": 2.26, "crown": 0.01, "tuck": 0.94, "pillars": [], "glass_to": 1.72, "rear_glass": false, "doors": [0.72,1.78,3.2], "fit": ["plates","windscreen_slit","ram","rack","spikes"], "belt": 1.3, "tail": 1.3, "nose": 1.08},
		{"name": "Fuel Runner", "paint": Color(0.42,0.2,0.12), "fit": ["bed","tank","mesh","bull"], "tank_paint": Color(0.36,0.32,0.26), "len": 5.6, "ax_r": 4.45},
		{"name": "Half-Plated Bus", "paint": Color(0.36,0.42,0.36), "len": 7.4, "wid": 2.4, "ride": 0.56, "r": 0.56, "tw": 0.36, "ax_f": 1.45, "ax_r": 5.6, "cowl": 0.2, "peak": 0.42, "nose": 1.2, "belt": 1.6, "tail": 1.6, "back": 7.24, "foot": 7.32, "roof": 2.96, "crown": 0.02, "tuck": 0.96, "pillars": [2.2,3.2,4.2,5.2,6.2], "doors": [1.0], "handles": false, "fit": ["plates","mesh","ram","rack","spikes"]},
		{"name": "Last Light", "paint": Color(0.12,0.13,0.13), "r": 0.56, "ride": 0.62, "belt": 1.3, "nose": 1.12, "tail": 1.3, "roof": 1.96, "fit": ["bed","roll","plates","ram","rally","sandbags","mesh"], "plate_paint": Color(0.24,0.25,0.25)},
	]},
]

static func find(id: String) -> Dictionary:
	var parts := id.rsplit("_",true,1)
	for kind: Dictionary in TYPES:
		if kind.id == parts[0]:
			var data: Dictionary = DEFAULTS.duplicate()
			data.merge(kind.base,true)
			data.merge(kind.models[int(parts[1])-1],true)
			data.id = id
			data.type = kind.label
			return data
	push_error("Unknown vehicle %s" % id)
	return {}

static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for kind: Dictionary in TYPES:
		for index in kind.models.size():
			out.append("%s_%02d" % [kind.id,index+1])
	return out
