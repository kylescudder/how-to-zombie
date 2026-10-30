class_name StreetPockets
extends RefCounted
## Small playable lots replace filler masses; all solid geometry stays inside the lot.
const NAMES := ["Neighbourhood market", "Community garden", "Evacuation aid station", "Service yard"]

static func kind(block: Vector2i, district: String) -> int:
	var value := posmod(block.x*73 + block.y*37, 17)
	if value > 3: return -1
	if district == "industrial": return 3 if value%2==0 else 2
	return value

static func build(city: BareaCity, block: Vector2i, variant: int) -> void:
	var center := city.block_center(block)
	var ow := city.ow
	var root := city.root
	var palette := [Color(0.65,0.40,0.26),Color(0.34,0.49,0.28),Color(0.66,0.68,0.57),Color(0.40,0.43,0.45)]
	city._tile("pocket_floor%d"%variant,palette[variant],center+Vector3.UP*0.08,Vector3(44,0.05,44))
	# A rear service building gives every pocket shelter, a backdrop and a clear entrance.
	city._mass(variant,Vector3(38,5,8),center+Vector3(0,2.5,-17),true)
	city._tile("pocket_door",Color(0.23,0.29,0.27),center+Vector3(0,1.5,-12.9),Vector3(2.2,3,0.12))
	for x in [-10,10]:
		city._tile("pocket_glass",Color(0.19,0.35,0.36),center+Vector3(x,2.2,-12.9),Vector3(6,2,0.12))
	city._tile("pocket_lintel",Color(0.86,0.78,0.57),center+Vector3(0,4.6,-12.8),Vector3(37,0.35,0.15))
	var sign := city._sign(NAMES[variant].to_upper(),center+Vector3(0,5.8,-12.8),0,100,Color(0.96,0.89,0.66))
	sign.visibility_range_end=130
	sign.pixel_size=0.015
	for side in [-1,1]:
		var pos := center+Vector3(side*15,0,4)
		match variant:
			0:
				# Open stalls with striped canopies, overturned crates and produce.
				for z in [-5,7]:
					var stall := pos+Vector3(0,0,z)
					city._wall(Vector3(4,1,2),Color(0.47,0.32,0.20),stall+Vector3.UP*0.5)
					for x in [-2,2]:
						for dz in [-1,1]: city._tile("stall_post",Color(0.34,0.29,0.22),stall+Vector3(x,1.4,dz),Vector3(0.13,2.8,0.13))
					for stripe in 8:
						city._tile("stall%d"%(stripe%2),Color(0.75,0.29,0.19) if stripe%2==0 else Color(0.90,0.81,0.56),stall+Vector3(-2+stripe*0.5,2.8,0),Vector3(0.5,0.15,3.5))
					for x in [-1,0,1]:
						city._tile("produce",Color(0.62,0.71,0.24),stall+Vector3(x,1.2,0),Vector3(0.65,0.4,1))
			1:
				for z in [-5,7]:
					city._wall(Vector3(6,0.6,4),Color(0.48,0.34,0.22),pos+Vector3(0,0.3,z))
					StreetArt.tree(root,pos+Vector3(0,0.6,z),2.0)
			2:
				city._wall(Vector3(6,1,3),Color(0.55,0.59,0.46),pos+Vector3.UP*0.5)
				for x in [-3.6,3.6]:
					for z in [-4,4]: city._tile("aid_post",Color(0.37,0.42,0.34),pos+Vector3(x,1.65,z),Vector3(0.14,3.3,0.14))
				city._tile("aid_roof",Color(0.75,0.75,0.59),pos+Vector3.UP*3.3,Vector3(8,0.2,9))
				city._tile("aid_cross",Color(0.72,0.23,0.17),pos+Vector3(0,3.42,0),Vector3(1.5,0.04,4))
				city._tile("aid_cross",Color(0.72,0.23,0.17),pos+Vector3(0,3.42,0),Vector3(4,0.04,1.5))
			3:
				city._wall(Vector3(5,3,9),Color(0.65,0.44,0.21),pos+Vector3.UP*1.5)
				for z in [-3,0,3]: city._tile("yard_ribs",Color(0.43,0.34,0.22),pos+Vector3(2.55,1.5,z),Vector3(0.1,3,0.12))
	var loot := center+Vector3(0,0.2,-8)
	if posmod(block.x+block.y,3)==0: ow.markers.caches.append({"pos":loot,"dir":Vector3.RIGHT,"items":["medkit"] if variant==2 else ["pills"]})
	ow.markers.street_pockets.append({"kind":variant,"name":NAMES[variant],"pos":center,"entry":center+Vector3(0,0,21),"loot":loot})
