class_name CosmeticCatalog
extends RefCounted
const OPTIONS := {
	"hair": ["Crop","Side part","Curls","Mohawk","Pixie","Bob","Ponytail","Braids"],
	"hair_colour": ["Ink black","Espresso","Chestnut","Auburn","Honey blonde","Silver","Sea teal","Lavender"],
	"brows": ["Natural","Straight","Arched","Heavy","Quizzical","Slanted","Fine","Split"],
	"eyes": ["Wide awake","Almond","Round","Sleepy","Upturned","Downturned","Narrow","Bright"],
	"nose": ["Button","Straight","Broad","Hooked","Upturned","Petite","Round","Long"],
	"mouth": ["Easy smile","Straight","Toothy grin","Crooked smile","Gap tooth","Thin lips","Pout","Open smile"],
	"facial_hair": ["Clean shaven","Stubble","Moustache","Goatee","Short beard","Full beard","Sideburns","Handlebar"],
	"skin": ["Warm tan","Porcelain","Peach","Olive","Bronze","Umber","Deep brown","Ebony"],
	"earrings": ["None","Brass studs","Silver hoops","Single drop","Double hoops","Sea glass","Ear cuffs","Long drops"],
	"glasses": ["None","Round wire","Square frames","Aviators","Wraparound","Tiny readers","Sunshades","Patched frames"],
	"watches": ["None","Field watch","Digital","Gold dress","Diver","Leather strap","Sport band","Compass watch"],
	"necklaces": ["None","Dog tags","Fine chain","Sea glass pendant","Lucky coin","Wooden beads","Anchor charm","Heavy chain"],
	"tshirts": ["Camp tee","Breton stripes","Two tone","Ringer tee","Baseball tee","Patch tee","Sun print","Longline"],
	"trousers": ["Blue jeans","Cargo pants","Utility shorts","Joggers","Patched denim","Work trousers","Corduroy","Expedition pants"],
	"shoes": ["Camp boots","Canvas trainers","High tops","Work boots","Running shoes","Deck shoes","Trail boots","Polished boots"],
	"jackets": ["None","Denim jacket","Bomber","Raincoat","Leather jacket","Hoodie","Parka","Field coat"],
	"outfits": ["Separate pieces","Mechanic","Paramedic","Sailor","Road crew","Biker","Ranger","Hazmat"],
}
const FACE := ["hair","hair_colour","brows","eyes","nose","mouth","facial_hair","skin"]
const COLOURS := [Color("201e22"),Color("3c2821"),Color("714329"),Color("a3472e"),Color("d4b16b"),Color("b7bdc3"),Color("347e7c"),Color("8a6ca3")]
const SKINS := [Color("bf9673"),Color("edcdb4"),Color("dea988"),Color("b39a6b"),Color("a2764f"),Color("805638"),Color("62432f"),Color("41302b")]
const THRESHOLDS := [0,50,100,200,350,550,800,1200]

static func defaults() -> Dictionary:
	var look := {}
	for part in OPTIONS: look[part]=0
	return look

static func requirement(part: String, index: int) -> int:
	if part in FACE: return 0
	return THRESHOLDS[clampi(index,0,7)] * (3 if part=="outfits" else (2 if part=="jackets" else 1))

static func unlocked(part: String, index: int, xp: int) -> bool:
	return OPTIONS.has(part) and index>=0 and index<8 and xp>=requirement(part,index)

static func normalise(raw: Dictionary, xp := 0, preview := false) -> Dictionary:
	var look := defaults()
	for part in look:
		var value: Variant=raw.get(part,0)
		if not (value is int or value is float) or not is_finite(float(value)): continue
		var index := clampi(int(value),0,7)
		if preview or unlocked(part,index,xp): look[part]=index
	return look
