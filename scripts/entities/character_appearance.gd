class_name CharacterAppearance
extends RefCounted
## Every selection builds visible geometry on the existing animation rig.
const SHIRTS := [Color("66775c"),Color("c9c5a3"),Color("ab663d"),Color("536f87"),Color("c3a653"),Color("854e58"),Color("d1a27e"),Color("586b69")]
const PANTS := [Color("354d65"),Color("545f43"),Color("a18a62"),Color("3c3e47"),Color("627988"),Color("70553c"),Color("706146"),Color("394d44")]
const SHOES := [Color("67432e"),Color("d4c6a1"),Color("9e4e37"),Color("493b29"),Color("4c747c"),Color("a49371"),Color("485846"),Color("24262a")]
const JACKETS := [Color("66775c"),Color("455c75"),Color("645a40"),Color("c9a044"),Color("302f30"),Color("857261"),Color("3d5948"),Color("625c3e")]

static func sleeve_colour(look: Dictionary) -> Color:
	var outfit: int=look.get("outfits",0)
	if outfit>0:
		if outfit==5: return JACKETS[4]
		if outfit==6: return JACKETS[7]
		return [Color.WHITE,Color("4b646b"),Color("ece5cc"),Color("e1dfc1"),Color("dc8b32"),Color("353438"),Color("52734b"),Color("d7bd48")][outfit]
	return JACKETS[look.jackets] if look.jackets>0 else SHIRTS[look.tshirts]

static func build(model: Node3D, raw: Dictionary) -> void:
	var look := CosmeticCatalog.normalise(raw,0,true)
	var skin: Color=CosmeticCatalog.SKINS[look.skin]
	var shirt: Color=SHIRTS[look.tshirts]
	var pants: Color=PANTS[look.trousers]
	var shoes: Color=SHOES[look.shoes]
	var outfit: int=look.outfits
	if outfit>0:
		shirt=[Color.WHITE,Color("4b646b"),Color("ece5cc"),Color("e1dfc1"),Color("dc8b32"),Color("353438"),Color("52734b"),Color("d7bd48")][outfit]
		pants=shirt.darkened(0.25)
		shoes=SHOES[[0,3,7,5,3,7,6,3][outfit]]
	model.kind="survivor"
	model._body(skin,shirt,skin if look.trousers==2 and outfit==0 else pants,Vector3(0.62,0.7,0.38),1.0,1.0)
	_face(model,look,skin)
	if outfit!=7: _hair(model,look.hair,CosmeticCatalog.COLOURS[look.hair_colour])
	_clothes(model,look,shirt,pants,shoes)
	_accessories(model,look)
	model.set_meta("appearance",look.duplicate())

static func _face(m: Node3D, look: Dictionary, skin: Color) -> void:
	var eye: int=look.eyes
	var widths := [0.17,0.19,0.20,0.18,0.16,0.18,0.20,0.18]
	var heights := [0.20,0.13,0.22,0.11,0.18,0.15,0.09,0.21]
	var iris: Color=[Color("25464c"),Color("756132"),Color("3d6255"),Color("584a3e"),Color("407b7c"),Color("6b574b"),Color("3b4a35"),Color("637eab")][eye]
	for side in [-1,1]:
		var tilt: float = side*([0.08,0.16,0.0,-0.08,0.22,-0.22,0.02,0.04][eye])
		m._eye(Vector3(side*0.125,0.335,0.225),Vector3(widths[eye],heights[eye],0.13),iris,tilt)
		var brow: int=look.brows
		var hair: Color=CosmeticCatalog.COLOURS[look.hair_colour].darkened(0.12)
		var brow_node := Node3D.new()
		brow_node.name="Brow%d"%side
		m.head.add_child(brow_node)
		var y: float=0.455+([0,0,0.025,0,0.045,-0.015,0.015,0][brow])
		var slope: float=[-0.01,0,0.05,-0.02,0.07,-0.07,0.01,0.03][brow]
		var thickness: float=[0.025,0.020,0.021,0.040,0.027,0.033,0.012,0.023][brow]
		ArtShapes.link(brow_node,Vector3(side*0.055,y,0.25),Vector3(side*0.195,y+slope,0.21),thickness,hair)
		if brow==2 or brow==4: ArtShapes.link(brow_node,Vector3(side*0.195,y+slope,0.21),Vector3(side*0.235,y+slope-0.035,0.18),thickness,hair)
		if brow==7: ArtShapes.link(brow_node,Vector3(side*0.22,y+0.02,0.2),Vector3(side*0.25,y+0.035,0.18),0.018,hair)
	var nose: int=look.nose
	var sizes := [Vector3(0.17,0.15,0.21),Vector3(0.12,0.23,0.19),Vector3(0.23,0.15,0.22),Vector3(0.12,0.25,0.29),Vector3(0.16,0.12,0.25),Vector3(0.10,0.12,0.15),Vector3(0.23,0.20,0.23),Vector3(0.13,0.22,0.34)]
	var nasal := ArtShapes.oval(m.head,sizes[nose],skin.lightened(0.05),Vector3(0,0.23,0.31),Vector3(-20 if nose==4 else (15 if nose==3 else -5),0,0))
	nasal.name="Nose"
	ArtShapes.nostrils(nasal,Vector3(0.023,0.015,0.014),skin.darkened(0.5))
	var mouth: int=look.mouth
	var lips := Node3D.new()
	lips.name="MouthStyle"
	m.head.add_child(lips)
	var width: float=[0.18,0.17,0.25,0.20,0.24,0.18,0.13,0.23][mouth]
	var height: float=[0.035,0.022,0.09,0.04,0.08,0.016,0.055,0.13][mouth]
	ArtShapes.oval(lips,Vector3(width,height,0.045),Color("63392e"),Vector3(0,0.09,0.26),Vector3(0,0,14 if mouth==3 else 0))
	if mouth in [2,4,7]:
		ArtShapes.oval(lips,Vector3(width*0.8,height*0.36,0.02),Color("ede2bf"),Vector3(0,0.10,0.286))
		if mouth==4: ArtShapes.oval(lips,Vector3(0.025,0.035,0.012),Color("63392e"),Vector3(0.01,0.10,0.30))
	if mouth==0:
		for side in [-1,1]: ArtShapes.link(lips,Vector3(side*0.075,0.09,0.27),Vector3(side*0.11,0.12,0.26),0.012,Color("63392e"))
	if mouth==6: ArtShapes.oval(lips,Vector3(0.11,0.04,0.03),skin.darkened(0.14),Vector3(0,0.067,0.29))
	_beard(m,0 if look.outfits==7 else look.facial_hair,CosmeticCatalog.COLOURS[look.hair_colour])

static func _hair(m: Node3D, style: int, color: Color) -> void:
	var root := Node3D.new()
	root.name="HairStyle"
	m.head.add_child(root)
	ArtShapes.oval(root,Vector3(0.65,0.22 if style==0 else 0.28,0.55),color,Vector3(0,0.56,-0.025))
	match style:
		1,4:
			for index in (4 if style==1 else 6):
				ArtShapes.oval(root,Vector3(0.20,0.12,0.27),color.lightened(index*0.015),Vector3(-0.20+index*0.075,0.51+index*0.012,0.17),Vector3(-10,0,-25 if style==1 else 20))
		2:
			for index in 14:
				var angle := index*TAU/14
				ArtShapes.oval(root,Vector3(0.23,0.24,0.22),color.lightened((index%3)*0.035),Vector3(cos(angle)*0.25,0.55+sin(index*2.4)*0.045,sin(angle)*0.20))
		3:
			for index in 7:
				ArtShapes.loft(root,[Vector4(0,0.055,0.065,0),Vector4(0.19,0.028,0.04,0),Vector4(0.30,0.002,0.002,0)],color,Vector3(0,0.55,-0.22+index*0.065),16)
		5:
			ArtShapes.oval(root,Vector3(0.66,0.63,0.20),color,Vector3(0,0.29,-0.23))
			for side in [-1,1]: ArtShapes.oval(root,Vector3(0.17,0.54,0.39),color,Vector3(side*0.29,0.30,-0.01))
		6:
			ArtShapes.link(root,Vector3(0,0.48,-0.25),Vector3(0,0.05,-0.48),0.11,color)
			ArtShapes.oval(root,Vector3(0.25,0.15,0.18),Color("b17642"),Vector3(0,0.40,-0.29))
		7:
			for side in [-1,1]:
				for index in 7:
					ArtShapes.oval(root,Vector3(0.12,0.11,0.13),color.lightened((index%2)*0.05),Vector3(side*(0.27+sin(index)*0.02),0.42-index*0.065,-0.12))

static func _beard(m: Node3D, style: int, color: Color) -> void:
	var root := Node3D.new()
	root.name="FacialHair"
	m.head.add_child(root)
	if style==0: return
	if style==1:
		for index in 18:
			var x := -0.20+(index%6)*0.08
			ArtShapes.oval(root,Vector3(0.023,0.027,0.012),color,Vector3(x,0.015+(index/6)*0.033,0.23+0.025*(1-absf(x)*3)))
	elif style in [2,7]:
		for side in [-1,1]:
			ArtShapes.oval(root,Vector3(0.13,0.05,0.05),color,Vector3(side*0.052,0.14,0.29),Vector3(0,0,side*12))
			if style==7: ArtShapes.link(root,Vector3(side*0.10,0.14,0.28),Vector3(side*0.19,0.19,0.25),0.022,color)
	elif style==3:
		ArtShapes.oval(root,Vector3(0.12,0.14,0.10),color,Vector3(0,0.005,0.23))
		ArtShapes.oval(root,Vector3(0.18,0.04,0.045),color,Vector3(0,0.14,0.28))
	elif style==6:
		for side in [-1,1]: ArtShapes.oval(root,Vector3(0.13,0.27,0.12),color,Vector3(side*0.25,0.16,0.14))
	else:
		ArtShapes.oval(root,Vector3(0.44,0.20 if style==4 else 0.34,0.19),color,Vector3(0,-0.015 if style==4 else -0.08,0.19))
		for side in [-1,1]: ArtShapes.oval(root,Vector3(0.13,0.25,0.12),color,Vector3(side*0.23,0.14,0.16))

static func _clothes(m: Node3D, look: Dictionary, shirt: Color, pants: Color, shoes: Color) -> void:
	if look.outfits>0:
		look=look.duplicate()
		look.tshirts=0
		look.trousers=0
		look.shoes=[0,3,7,5,3,7,6,3][look.outfits]
	var details := Node3D.new()
	details.name="ClothesDetails"
	m.torso.add_child(details)
	var tee: int=look.tshirts
	if tee==1 or look.outfits==3:
		for index in 5: ArtShapes.oval(details,Vector3(0.62,0.035,0.42),Color("354e69"),Vector3(0,0.15+index*0.085,0))
	elif tee==2: ArtShapes.oval(details,Vector3(0.62,0.18,0.43),shirt.lightened(0.2),Vector3(0,0.35,0))
	elif tee in [3,4]: ArtShapes.oval(details,Vector3(0.25,0.08,0.24),Color("ddd7be"),Vector3(0,0.69,0))
	elif tee in [5,6]:
		ArtShapes.oval(details,Vector3(0.13 if tee==5 else 0.24,0.13,0.025),Color("e1bd67"),Vector3(-0.13 if tee==5 else 0,0.43,0.22))
	elif tee==7: ArtShapes.oval(details,Vector3(0.61,0.18,0.39),shirt,Vector3(0,-0.04,0))
	for leg in [m.leg_l,m.leg_r]:
		# Recolour and shape the existing boot meshes without disturbing the joints.
		for child in leg.get_children():
			if child is MeshInstance3D and child.position.y < -0.55:
				child.material_override=Build.mat(shoes if child.position.y>-0.75 else shoes.darkened(0.45))
				if look.shoes in [1,4,5]: child.scale.y*=0.7
				elif look.shoes in [2,6]: child.scale.y*=1.15
		if look.trousers==2 and look.outfits==0:
			ArtShapes.link(leg,Vector3(0,-0.04,0),Vector3(0,-0.35,0),0.135,pants)
		if look.trousers in [1,4,5,7]:
			ArtShapes.oval(leg,Vector3(0.15,0.18,0.05),pants.lightened(0.13),Vector3(0.075,-0.35,0.13))
		elif look.trousers==3:
			ArtShapes.oval(leg,Vector3(0.25,0.09,0.28),pants.darkened(0.18),Vector3(0,-0.57,0.02))
		elif look.trousers==6:
			for index in 5: ArtShapes.link(leg,Vector3(-0.08+index*0.04,-0.1,0.14),Vector3(-0.08+index*0.04,-0.58,0.14),0.006,pants.lightened(0.10))
	var jacket: int=look.jackets
	if look.outfits>0: jacket=4 if look.outfits==5 else (7 if look.outfits==6 else 0)
	if jacket>0:
		var color: Color=JACKETS[jacket]
		ArtShapes.oval(details,Vector3(0.66,0.64,0.17),color,Vector3(0,0.33,-0.19))
		for side in [-1,1]:
			ArtShapes.loft(details,[Vector4(-0.04,0.14,0.07,0),Vector4(0.2,0.14,0.09,0),Vector4(0.55,0.16,0.06,0),Vector4(0.67,0.07,0.02,0)],color,Vector3(side*0.18,0,0.18))
			ArtShapes.oval(details,Vector3(0.16,0.12,0.03),color.lightened(0.12),Vector3(side*0.18,0.29,0.275))
		for arm in [m.arm_l,m.arm_r]: ArtShapes.link(arm,Vector3(0,-0.02,0),Vector3(0,-0.49,0.03),0.112,color)
		if jacket in [3,6,7]: ArtShapes.oval(details,Vector3(0.68,0.28,0.44),color,Vector3(0,-0.07,0))
		if jacket in [5,6]: ArtShapes.oval(details,Vector3(0.40,0.28,0.20),color,Vector3(0,0.67,-0.23))
	var outfit: int=look.outfits
	if outfit in [1,2,4,6,7]:
		ArtShapes.link(details,Vector3(0,0.07,0.23),Vector3(0,0.64,0.23),0.012,Color("c4b78f"))
		for side in [-1,1]: ArtShapes.oval(details,Vector3(0.16,0.16,0.04),shirt.darkened(0.15),Vector3(side*0.17,0.45,0.22))
	if outfit==2:
		Build.box(details,Vector3(0.18,0.055,0.04),Color("b9513c"),Vector3(0,0.47,0.26))
		Build.box(details,Vector3(0.055,0.18,0.04),Color("b9513c"),Vector3(0,0.47,0.26))
	if outfit==4:
		for y in [0.15,0.5]: ArtShapes.oval(details,Vector3(0.65,0.055,0.44),Color("e5e4bd"),Vector3(0,y,0))
	if outfit==7:
		ArtShapes.oval(m.head,Vector3(0.74,0.77,0.57),shirt,Vector3(0,0.30,-0.10))
		ArtShapes.oval(m.head,Vector3(0.58,0.36,0.12),Color("344d4d"),Vector3(0,0.34,0.27))
		ArtShapes.oval(m.head,Vector3(0.43,0.29,0.28),Color("485b4d"),Vector3(0,0.13,0.34))
		for side in [-1,1]: ArtShapes.oval(m.head,Vector3(0.13,0.14,0.08),Color("263d37"),Vector3(side*0.16,0.10,0.46))
		for arm in [m.arm_l,m.arm_r]: ArtShapes.link(arm,Vector3.ZERO,Vector3(0,-0.5,0.02),0.12,shirt)

static func _ring(parent: Node3D, radius: float, thickness: float, color: Color, pos: Vector3, scale := Vector3.ONE) -> Node3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius=radius-thickness
	mesh.outer_radius=radius+thickness
	mesh.rings=16
	mesh.ring_segments=12
	var node := Build.mesh(parent,mesh,color,pos,Vector3(90,0,0))
	node.scale=scale
	return node

static func _accessories(m: Node3D, look: Dictionary) -> void:
	var metal := Color("b99c55")
	var index: int=look.earrings
	if index>0:
		for side in [-1,1]:
			if index==3 and side==1: continue
			var point := Vector3(side*0.35,0.22,0.06)
			if index in [2,4,7]:
				_ring(m.head,0.062 if index!=7 else 0.08,0.012,metal if index==4 else Color("b9c2c2"),point+Vector3(0,-0.04,0),Vector3(0.8,1,1))
				if index==4: _ring(m.head,0.035,0.009,metal,point+Vector3(0,-0.12,0))
			else: ArtShapes.oval(m.head,Vector3(0.055,0.11 if index==3 else 0.055,0.055),Color("5caaa0") if index==5 else metal,point)
			if index==6: _ring(m.head,0.055,0.015,Color("b7c5c3"),point+Vector3(0,0.10,0),Vector3(0.6,1,1))
	index=look.glasses
	if index>0:
		var color := Color("3d302b") if index%2==0 else metal
		for side in [-1,1]:
			var point := Vector3(side*0.128,0.34,0.33)
			if index in [2,4,7]:
				for dy in [-0.08,0.08]: Build.box(m.head,Vector3(0.22,0.025,0.03),color,point+Vector3(0,dy,0))
				for dx in [-0.11,0.11]: Build.box(m.head,Vector3(0.022,0.16,0.03),color,point+Vector3(dx,0,0))
			else: _ring(m.head,0.10 if index!=5 else 0.075,0.012,color,point,Vector3(1,0.85 if index==3 else 1,1))
			ArtShapes.link(m.head,point+Vector3(side*0.10,0,0),Vector3(side*0.32,0.35,-0.03),0.012,color)
			if index in [3,4,6]: ArtShapes.oval(m.head,Vector3(0.19,0.135,0.025),Color("233638"),point)
		ArtShapes.link(m.head,Vector3(-0.03,0.34,0.34),Vector3(0.03,0.34,0.34),0.012,color)
		if index==7: Build.box(m.head,Vector3(0.06,0.04,0.05),Color("ddd6b9"),Vector3(0.02,0.34,0.35),Vector3(0,0,20))
	index=look.watches
	if index>0:
		ArtShapes.oval(m.arm_l,Vector3(0.23,0.07,0.23),SHOES[index],Vector3(0,-0.54,0.03))
		Build.box(m.arm_l,Vector3(0.11,0.11 if index%2 else 0.075,0.04),metal if index==3 else Color("b6bfbd"),Vector3(0,-0.54,0.16))
		Build.box(m.arm_l,Vector3(0.075,0.055,0.012),Color("496559") if index%2==0 else Color("d5ceb8"),Vector3(0,-0.54,0.185))
		ArtShapes.link(m.arm_l,Vector3(0,-0.54,0.195),Vector3(0.025,-0.52,0.195),0.005,Color("333a35"))
	index=look.necklaces
	if index>0:
		for step in 18:
			var a := PI*step/18.0
			var b := PI*(step+1)/18.0
			var from := Vector3(cos(a)*0.22,0.64-sin(a)*0.25,0.23)
			var to := Vector3(cos(b)*0.22,0.64-sin(b)*0.25,0.23)
			if index==5: ArtShapes.oval(m.torso,Vector3.ONE*0.045,Color("845938"),from)
			else: ArtShapes.link(m.torso,from,to,0.013 if index==7 else 0.007,metal if index%2 else Color("b5bfbc"))
		if index in [1,3,4,6]:
			ArtShapes.oval(m.torso,Vector3(0.10,0.15 if index==1 else 0.09,0.03),Color("4c9b8b") if index==3 else metal,Vector3(0,0.34,0.25))
			if index==6: ArtShapes.link(m.torso,Vector3(-0.07,0.32,0.25),Vector3(0.07,0.32,0.25),0.018,metal)
