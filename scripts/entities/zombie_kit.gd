class_name ZombieKit
extends RefCounted
## Faceted infected built from ZombieCatalog entries in VehicleKit's style: flat-shaded, vertex-coloured panels,
## painted face by face. Each body part bakes to one mesh that hangs on CharacterModel's rig, so the gait, the
## death clips and the hit capsule work as before. The face looks along +Z; every part is built in its own node's space.
const WET := Forge.GLASS
const METAL := Forge.CHROME
const GLOW := Forge.GLOW
const BONE := Color(0.9,0.84,0.6)
const GUM := Color(0.26,0.05,0.06)
const BLOOD := Color(0.34,0.06,0.05,0.5)  # Alpha under 1 lands on the wet layer.
const DARK := Color(0.07,0.07,0.08)
const STEEL := Color(0.62,0.64,0.66)
const GOLD := Color(0.92,0.7,0.22)
const PUS := Color(0.86,0.74,0.4)
const TUMOUR := Color(0.55,0.24,0.2)
const ACID := Color(0.55,1.0,0.22)
const PARTS := ["hips","torso","head","arm_l","fore_l","arm_r","fore_r","leg_l","shin_l","leg_r","shin_r"]

static var _rigs := {}
static var _materials: Array[Material] = []

var z: Dictionary
var f := {}  # Part name -> Forge.
var skin: Color
var shirt: Color
var inner: Color
var w: float
var d: float
var th: float
var belly: float
var arm_h: float
var arm_r: float
var leg_h: float
var leg_r: float
var shoulder: Vector3
var hip_x: float
var neck_top: Vector3
var torso_rings: Array[Vector4] = []
var eyes: Array = []

## Everything CharacterModel needs to hang this look on its rig. Every infected wearing it shares the meshes.
static func rig(id: String) -> Dictionary:
	if not _rigs.has(id):
		var kit := ZombieKit.new(ZombieCatalog.find(id))
		kit._assemble()
		_rigs[id] = kit._bake(_layer_materials())
	return _rigs[id]

static func _layer_materials() -> Array[Material]:
	if _materials.is_empty():
		for k in Forge.LAYERS:
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			_materials.append(m)
		var cloth: StandardMaterial3D = _materials[Forge.PAINT]
		cloth.roughness = 0.86
		Build._texture(cloth,"fabric",false)
		cloth.normal_scale = 0.3
		(_materials[WET] as StandardMaterial3D).roughness = 0.16
		(_materials[WET] as StandardMaterial3D).metallic_specular = 0.75
		(_materials[METAL] as StandardMaterial3D).roughness = 0.3
		(_materials[METAL] as StandardMaterial3D).metallic = 0.6
		var glow: StandardMaterial3D = _materials[GLOW]
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.8,1.8,1.8)
	return _materials

func _init(data: Dictionary) -> void:
	z = data
	for part: String in PARTS: f[part] = Forge.new()
	skin = ZombieCatalog.SKINS[z.skin] if z.skin is String else z.skin
	shirt = skin if Color(z.shirt).a == 0 else z.shirt
	inner = skin if Color(z.inner).a == 0 else z.inner
	var h: float = z.height
	w = z.w*0.5
	d = z.d*0.5
	th = z.th*h
	belly = z.belly
	leg_h = 0.8*z.legs*h
	leg_r = 0.26*0.49*clampf(sqrt(float(z.w)/0.6),0.92,1.5)
	arm_h = 0.66*h*(1.0+(z.arms-1.0)*0.3)
	arm_r = 0.2*z.arms*0.49
	shoulder = Vector3(w+0.05*z.arms,th*0.86,0)
	hip_x = w*0.48
	neck_top = Vector3(0,th+0.02+z.neck+z.head_y,z.head_z)

func has(fitting: String) -> bool:
	return z.fit.has(fitting)

func _bake(materials: Array[Material]) -> Dictionary:
	var meshes := {}
	for part: String in PARTS: meshes[part] = (f[part] as Forge).commit(materials)
	var baked := []
	for eye: Array in eyes: baked.append([eye[0],eye[1],(eye[2] as Forge).commit(materials)])
	return {"id": z.id, "skin": skin, "hip_h": leg_h, "head": neck_top, "head_scale": float(z.head_scale), "shoulder": shoulder,
		"hip_x": hip_x, "arm": Vector2(arm_h,arm_r), "leg": Vector2(leg_h,leg_r), "mouth": Vector3(0,0.1,0.3), "meshes": meshes, "eyes": baked,
		"sleeve": _sleeve(), "pants": _pants_color()}

func _assemble() -> void:
	_torso()
	_skirt()
	_head()
	_face()
	_hair()
	_hat()
	for side: float in [-1,1]:
		_arm(side)
		_leg(side)
	for fitting: String in z.fit: _fit(fitting)
	if int(z.wear) >= 3: _ribs()

# --- Paint ---------------------------------------------------------------------------------------------------------

## A steady 0..1 per face, so the same model always tears in the same places.
func _noise(part: int, j: int, i: int) -> float:
	return float(hash([z.id,part,j,i]) % 10007)/10007.0

## Torn cloth, blood and a little per-face shade, the way the rust patches break up a car's paint.
func _cloth(c: Color, part: int, j: int, i: int) -> Color:
	var n := _noise(part,j,i)
	var wear := float(z.wear)
	if has("shreds") and n < 0.55: return _flesh(part,j,i)
	if n < wear*0.022: return _flesh(part,j,i).darkened(0.12)
	if n > 1.0-wear*0.016: return BLOOD
	if c.a < 1: return c
	return c.darkened((n-0.5)*0.08)

func _flesh(part: int, j: int, i: int) -> Color:
	var n := _noise(part+50,j,i)
	if n < float(z.wear)*0.05: return skin.lerp(Color(0.38,0.3,0.4),0.35)
	if n > 0.985: return BLOOD
	return skin.darkened((n-0.5)*0.07)

func _pattern(c: Color, part: int, j: int, i: int, m: Vector3, y: float, front: float, outer: float) -> Color:
	var trim: Color = z.trim
	var n := _noise(part+100,j,i)
	match z.pattern:
		"spots": return trim if n < 0.26 else c
		"stripes": return trim if j%2 == 0 else c
		"check":
			if (i+j)%2 == 0: return c.lerp(trim,0.45)
			return trim if (i%2 == 0 and j%2 == 0) else c
		"bands": return trim if (y > 0.36 and y < 0.46) or (y > 0.62 and y < 0.7) else c
		"panel": return trim if outer > 0.92 else c
		"chest": return trim if front < 0.55 and y > 0.42 and y < 0.72 else c
		"camo":
			if n < 0.33: return trim
			return c.darkened(0.25) if n > 0.72 else c
	return c

## 0 at the centre of the chest, PI at the spine.
static func _front(m: Vector3, off := 0.0) -> float:
	return absf(wrapf(atan2(m.z-off,m.x)-PI*0.5,-PI,PI))

# --- Torso ---------------------------------------------------------------------------------------------------------

func _torso() -> void:
	var b := belly
	var key: Array[Vector4] = [Vector4(-0.04,w*0.72,d*0.8,0),Vector4(0.02,w*0.96,d*(1+b*0.6),b*d*0.3),
		Vector4(th*0.23,w*1.05*(1+b*0.25),d*1.14*(1+b),0.015+b*d*0.55),Vector4(th*0.6,w*(1+b*0.12),d*(1+b*0.55),b*d*0.3),
		Vector4(th*0.86,w*1.08,d*0.9,0),Vector4(th,w*0.6,d*0.7,0),Vector4(th+0.015,0.01,0.01,0)]
	torso_rings.clear()
	for k in key.size()-1:
		var steps := 1 if k >= key.size()-2 else 3
		for s in steps: torso_rings.append(key[k].lerp(key[k+1],float(s)/steps))
	torso_rings.append(key[-1])
	(f.torso as Forge).loft(torso_rings,12,_torso_paint,Vector3.ZERO,Basis.IDENTITY,true)
	var t: Forge = f.torso
	# Neck.
	var top: float = th+0.02+z.neck
	t.tube(Vector3(0,th-0.08,0),Vector3(0,top,0),0.09*sqrt(w/0.3),0.085,skin,Forge.PAINT,7)
	match z.top:
		"shirt","polo","chef","suit":
			for side: float in [-1,1]:
				var a := _on_torso(side*0.32,0.97,0.0)
				t.block(a+Vector3(0,0.015,0.01),Vector3(0.12,0.035,0.08),shirt.lightened(0.08) if z.top != "suit" else inner,Forge.PAINT,Basis(Vector3.FORWARD,side*0.5))
		"hoodie":
			t.ball(Vector3(0,th*0.94,-d*0.75),Vector3(w*0.62,0.13,0.12),shirt.darkened(0.1),Forge.PAINT,Basis.IDENTITY,8,3)
			t.block(_on_torso(0,0.24,0.012),Vector3(w*0.85,th*0.2,0.03),shirt.darkened(0.12))
			for side: float in [-1,1]: t.beam(_on_torso(side*0.12,0.9,0.02),_on_torso(side*0.13,0.7,0.03),0.018,z.trim)
		"overalls":
			var bib := _on_torso(0,0.52,0.014)
			t.block(bib,Vector3(w*0.62,0.05,0.025),Color(z.pants).darkened(0.15))
			for side: float in [-1,1]:
				t.beam(_on_torso(side*0.32,0.72,0.012),_on_torso(side*0.4,1.0,0.01)+Vector3(0,0.02,0),0.04,z.pants)
				t.beam(_on_torso(PI-side*0.4,1.0,0.01)+Vector3(0,0.02,0),_on_torso(PI-side*0.35,0.4,0.012),0.04,z.pants)
				t.block(_on_torso(side*0.32,0.72,0.02),Vector3(0.04,0.04,0.02),STEEL,METAL)
		"apron":
			for side: float in [-1,1]: t.beam(_on_torso(side*0.5,0.8,0.01),Vector3(side*0.06,th+0.01,0.05),0.025,inner)
			t.beam(_on_torso(PI*0.5,0.3,0.01),_on_torso(-PI*0.5,0.3,0.01),0.02,inner)
		"chef":
			for row: float in [-1,1]:
				for k in 3: t.ball(_on_torso(row*0.32,0.35+k*0.17,0.01),Vector3(0.022,0.022,0.012),z.trim,Forge.PAINT,Basis.IDENTITY,6,2)
		"jumpsuit":
			t.beam(_on_torso(0,0.1,0.008),_on_torso(0,0.95,0.008),0.016,STEEL,METAL)
		"suit","jacket","coat","cardigan":
			for side: float in [-1,1]: t.beam(_on_torso(side*0.4,0.98,0.01),_on_torso(side*0.38,0.45,0.02),0.04,shirt.darkened(0.12))
			if z.top == "cardigan":
				for k in 4: t.ball(_on_torso(0.42,0.25+k*0.15,0.01),Vector3(0.02,0.02,0.012),z.trim,Forge.PAINT,Basis.IDENTITY,6,2)
	if z.top == "shirt" or z.top == "polo":
		for k in (2 if z.top == "polo" else 5): t.ball(_on_torso(0,0.92-k*0.14,0.008),Vector3(0.016,0.016,0.01),shirt.lightened(0.3),Forge.PAINT,Basis.IDENTITY,6,2)

func _torso_paint(j: int, i: int, m: Vector3) -> Color:
	var y := m.y/th
	var front := _front(m)
	var c := shirt
	var cloth := true
	match z.top:
		"bare": cloth = false
		"tank": cloth = not ((y > 0.74 and absf(front-PI*0.5) < 0.8) or (y > 0.84 and (front < 0.6 or front > 2.6)))
		"scrubs": cloth = not (y > 0.76 and front < 0.35+(y-0.76)*1.8)
		"jacket","coat","cardigan":
			if front < 0.38:
				c = inner
				cloth = Color(z.inner).a > 0
		"suit":
			if front < 0.38 and y > 0.45: c = inner
		"vest":
			if front < 0.16: c = inner
		"apron":
			if front < 1.0 and y < 0.8: c = inner
		"overalls":
			if (front < 0.85 and y < 0.74) or y < 0.36: c = z.pants
		"dress","jumpsuit","coat": pass
	if z.crop and y < 0.34 and front < 1.45: cloth = false
	if y < 0.13 and cloth and z.top not in ["dress","jumpsuit","coat","overalls"]:
		return _cloth(Color(z.pants) if y > 0.04 else Color(z.pants).darkened(0.35),0,j,i)
	if not cloth: return _flesh(0,j,i)
	if c == shirt: c = _pattern(c,0,j,i,m,y,front,absf(cos(atan2(m.z,m.x))))
	return _cloth(c,0,j,i)

## A point on the torso's surface: angle 0 is the chest centre, +PI/2 the zombie's left (-X) side; y is a fraction of th.
func _on_torso(angle: float, y: float, lift: float) -> Vector3:
	var h := y*th
	var s := torso_rings[0]
	for k in torso_rings.size()-1:
		if torso_rings[k+1].x >= h:
			var a := torso_rings[k]
			var b := torso_rings[k+1]
			s = a.lerp(b,clampf((h-a.x)/maxf(b.x-a.x,0.0001),0,1))
			break
		s = torso_rings[k+1]
	var t := PI*0.5+angle
	var p := Vector3(cos(t)*s.y,h,sin(t)*s.z+s.w)
	var out := Vector3(cos(t)*s.z,0,sin(t)*s.y).normalized()
	return p+out*lift

# --- Skirts, coat tails ----------------------------------------------------------------------------------------------

func _skirt() -> void:
	var hips: Forge = f.hips
	var b := belly
	var dd := d*(1+b*0.6)
	var off := b*d*0.3
	match [z.top,z.legwear]:
		["dress",_],[_,"skirt"]:
			var long: float = 0.44 if z.top == "dress" else 0.32
			var c: Color = shirt if z.top == "dress" else Color(z.pants)
			var rings: Array[Vector4] = [Vector4(-long,w*1.28,dd*1.36,off),Vector4(-long*0.6,w*1.18,dd*1.26,off),Vector4(-long*0.25,w*1.06,dd*1.14,off),Vector4(0.06,w*0.98,dd*1.04,off)]
			hips.loft(rings,12,func(j: int, i: int, m: Vector3) -> Color:
				if z.top == "dress": return _cloth(_pattern(c,1,j+20,i,m,0.5,_front(m),absf(cos(atan2(m.z,m.x)))),1,j,i)
				return _cloth(c,1,j,i),Vector3.ZERO,Basis.IDENTITY,false,true)
		["coat",_]:
			var rings: Array[Vector4] = [Vector4(-0.46,w*1.2,dd*1.3,off),Vector4(-0.2,w*1.1,dd*1.18,off),Vector4(0.06,w*0.98,dd*1.04,off)]
			hips.loft(rings,12,func(j: int, i: int, m: Vector3) -> Color:
				if _front(m,off) < 0.42: return Color(0,0,0,0)
				return _cloth(_pattern(shirt,1,j+20,i,m,0.5,_front(m),absf(cos(atan2(m.z,m.x)))),1,j,i),Vector3.ZERO,Basis.IDENTITY,false,true)
		[_,"tutu"]:
			for k in 3:
				var y := -0.02-k*0.05
				hips.ball(Vector3(0,y,0),Vector3(w*1.75-k*0.06,0.035,dd*1.9-k*0.04),Color(z.pants).lightened(k*0.12),Forge.PAINT,Basis.IDENTITY,12,2)

# --- Head ------------------------------------------------------------------------------------------------------------

func _head() -> void:
	var hd: Forge = f.head
	var s: Array[Vector4] = [Vector4(-0.02,0.08,0.11,0.025),Vector4(0.03,0.22,0.21,0.035),Vector4(0.16,0.29,0.25,0.015),Vector4(0.32,0.325,0.255,0),Vector4(0.46,0.31,0.24,-0.015),Vector4(0.57,0.23,0.19,-0.025),Vector4(0.63,0.08,0.08,-0.025),Vector4(0.64,0.001,0.001,-0.025)]
	match z.head:
		"long":
			for k in s.size(): s[k] = Vector4(s[k].x*(1.08 if s[k].x > 0.2 else 1.0),s[k].y*0.92,s[k].z,s[k].w)
		"square":
			for k in [1,2]: s[k] = Vector4(s[k].x,s[k].y*1.2,s[k].z*1.05,s[k].w)
		"egg":
			s[1] = Vector4(s[1].x,s[1].y*0.75,s[1].z*0.85,s[1].w)
			for k in [4,5]: s[k] = Vector4(s[k].x,s[k].y*1.08,s[k].z*1.06,s[k].w)
	hd.loft(s,10,_head_paint)

func _head_paint(j: int, i: int, m: Vector3) -> Color:
	var hair: Color = z.hair_color
	var top := m.y > 0.47 or (m.y > 0.2 and m.z < -0.05)
	match z.hair:
		"buzz","bun","curlers","ponytail","long","mullet","fringe":
			if top: return hair.darkened((_noise(2,j,i)-0.5)*0.1)
		"comb":
			if (m.y > 0.2 and absf(m.x) > 0.2 and m.z < 0.12) or (m.y > 0.2 and m.z < -0.1): return hair
		"mohawk":
			if m.y > 0.2 and absf(m.x) > 0.12 and m.z < 0.12: return skin.lerp(hair,0.25)
	if z.hat == "hood" and m.z > 0.12: return skin.darkened(0.55)
	return _flesh(2,j,i)

func _face() -> void:
	var hd: Forge = f.head
	var tint := skin.lerp(Color(0.47,0.56,0.28),0.35)
	# Ears.
	for side: float in [-1,1]:
		if side < 0 and int(z.ears) < 2:
			hd.ball(Vector3(-0.315,0.27,0.01),Vector3(0.025,0.05,0.04),GUM,WET,Basis.IDENTITY,6,2)
			continue
		hd.ball(Vector3(side*0.31,0.27,0),Vector3(0.065,0.11,0.06),skin,Forge.PAINT,Basis.IDENTITY,7,3)
		hd.ball(Vector3(side*0.35,0.27,0.035),Vector3(0.025,0.06,0.02),skin.darkened(0.25),Forge.PAINT,Basis.IDENTITY,6,2)
	# Muzzle and mouth.
	var jaw: String = z.jaw
	var drop := -0.03 if jaw == "gape" else 0.0
	var push := 0.04 if jaw == "under" else 0.0
	hd.ball(Vector3(0.035,0.035+drop,0.235+push),Vector3(0.165,0.08,0.09),tint.darkened(0.1),Forge.PAINT,Basis(Vector3.BACK,deg_to_rad(-12)),8,3)
	var gum := GLOW if has("acid") else WET
	var gum_color := ACID if has("acid") else GUM
	match jaw:
		"gape": hd.ball(Vector3(0.02,0.085,0.29),Vector3(0.15,0.085,0.05),gum_color,gum,Basis(Vector3.BACK,deg_to_rad(-8)),8,3)
		"grin": hd.ball(Vector3(0.02,0.1,0.29),Vector3(0.2,0.045,0.05),gum_color,gum,Basis(Vector3.BACK,deg_to_rad(-6)),8,3)
		"under": hd.ball(Vector3(0.025,0.1,0.3),Vector3(0.14,0.035,0.05),gum_color,gum,Basis(Vector3.BACK,deg_to_rad(-12)),8,3)
		_: hd.ball(Vector3(0.025,0.095,0.285),Vector3(0.14,0.055,0.045),gum_color,gum,Basis(Vector3.BACK,deg_to_rad(-12)),8,3)
	var count := int(z.teeth)*(2 if jaw == "grin" else 1)
	var span := 0.3 if jaw == "grin" else 0.21
	for k in count:
		var x := -span*0.5+span*(k+0.5)/count+0.02
		var n := _noise(3,k,0)
		var tooth := BONE.lerp(Color(0.62,0.5,0.24),n*0.6)
		var size := Vector3(0.04 if jaw != "grin" else 0.032,0.065 if k%2 == 0 else 0.05,0.03)
		var at := Vector3(x,0.115,0.33)
		var up := 1.0
		match jaw:
			"under":
				at = Vector3(x,0.095+push*0.5,0.35)
				up = -1.0
			"gape":
				if k%2 == 1: at = Vector3(x,0.04,0.315)
				else: at.y = 0.13
				up = -1.0 if k%2 == 1 else 1.0
			"grin": at = Vector3(x,0.1,0.335-absf(x)*0.2)
		hd.block(at-Vector3(0,size.y*0.3*up,0),size,tooth,WET,Basis(Vector3.BACK,deg_to_rad(-10+k*7+n*8)))
	if jaw in ["slack","gape"]:
		hd.ball(Vector3(0.07,0.05+drop,0.32),Vector3(0.045,0.03,0.055),ACID if has("acid") else Color(0.72,0.28,0.3),GLOW if has("acid") else WET,Basis.IDENTITY,6,3)
	# Nose.
	var nose_color := Color(0.95,0.95,0.92) if z.nose == "zinc" else tint
	match z.nose:
		"pointy":
			hd.tube(Vector3(-0.01,0.23,0.27),Vector3(-0.02,0.15,0.46),0.065,0.012,tint,Forge.PAINT,6)
		"broken":
			hd.ball(Vector3(0.03,0.2,0.32),Vector3(0.095,0.08,0.12),tint,Forge.PAINT,Basis(Vector3.BACK,deg_to_rad(28))*Basis(Vector3.UP,deg_to_rad(20)),7,3)
			hd.block(Vector3(0.03,0.24,0.42),Vector3(0.1,0.03,0.02),Color(0.92,0.86,0.72))
		_:
			hd.ball(Vector3(-0.025,0.2,0.32),Vector3(0.1,0.085,0.13),nose_color,Forge.PAINT,Basis(Vector3.BACK,deg_to_rad(-15)),7,3)
			for side: float in [-1,1]: hd.ball(Vector3(-0.025+side*0.04,0.15,0.4),Vector3(0.018,0.012,0.012),GUM,WET,Basis.IDENTITY,5,2)
	# Brows: lopsided for the dim ones, slanted in for the angry ones.
	var brow: Color = Color(z.hair_color).darkened(0.25) if z.hair != "bald" else skin.darkened(0.35)
	if z.eyes == "glare":
		for side: float in [-1,1]: hd.beam(Vector3(side*0.22,0.47,0.18),Vector3(side*0.05,0.42,0.25),0.04,brow)
	else:
		hd.beam(Vector3(-0.24,0.47,0.17),Vector3(-0.07,0.48,0.23),0.045,brow)
		hd.beam(Vector3(0.08,0.43,0.23),Vector3(0.2,0.44,0.19),0.04,brow)
	_eyes()

func _eyes() -> void:
	var list := []
	match z.eyes:
		"wide": list = [[Vector3(-0.13,0.34,0.23),Vector3(0.23,0.26,0.18),-0.1],[Vector3(0.13,0.34,0.23),Vector3(0.22,0.25,0.18),0.1]]
		"squint": list = [[Vector3(-0.13,0.34,0.24),Vector3(0.18,0.11,0.13),-0.15],[Vector3(0.13,0.33,0.24),Vector3(0.16,0.09,0.12),0.2]]
		"glare": list = [[Vector3(-0.12,0.35,0.24),Vector3(0.17,0.12,0.13),-0.3],[Vector3(0.12,0.35,0.24),Vector3(0.17,0.12,0.13),0.3]]
		"pop":
			list = [[Vector3(-0.13,0.35,0.23),Vector3(0.22,0.25,0.18),-0.2],[Vector3(0.17,0.13,0.37),Vector3(0.16,0.17,0.14),0.4]]
			(f.head as Forge).ball(Vector3(0.13,0.32,0.235),Vector3(0.07,0.08,0.03),GUM,WET,Basis.IDENTITY,7,3)
			(f.head as Forge).beam(Vector3(0.13,0.3,0.25),Vector3(0.16,0.17,0.33),0.025,Color(0.7,0.2,0.2))
		_: list = [[Vector3(-0.13,0.35,0.23),Vector3(0.22,0.25,0.18),-0.2],[Vector3(0.13,0.31,0.24),Vector3(0.19,0.21,0.16),0.15]]
	var glare: bool = z.eyes == "glare"
	for e: Array in list:
		var eye := Forge.new()
		var size: Vector3 = e[1]
		eye.ball(Vector3.ZERO,size*0.5,Color(0.97,0.94,0.8),WET,Basis.IDENTITY,8,4)
		eye.ball(Vector3(0,-size.y*0.03,size.z*0.45),Vector3(size.x*0.2,size.y*0.315,0.014),z.pupil,GLOW if glare else WET,Basis.IDENTITY,7,2)
		if not glare: eye.ball(Vector3(-0.012,0.025,size.z*0.53),Vector3(0.009,0.012,0.005),Color.WHITE,WET,Basis.IDENTITY,5,2)
		eyes.append([e[0],e[2],eye])

# --- Hair and hats ---------------------------------------------------------------------------------------------------

func _hair() -> void:
	var hd: Forge = f.head
	var c: Color = z.hair_color
	match z.hair:
		"tufts":
			for k in 5:
				var base := Vector3(-0.2+k*0.085,0.53,-0.04)
				var tip := base+Basis(Vector3.BACK,deg_to_rad(18-k*9))*Vector3(0,0.17,0)
				hd.tube(base,tip,0.05,0.004,c,Forge.PAINT,5)
		"spiky":
			for k in 9:
				var a := TAU*k/9.0
				var base := Vector3(cos(a)*0.16,0.56,sin(a)*0.13-0.04)
				hd.tube(base,base+Vector3(cos(a)*0.12,0.14,sin(a)*0.1),0.05,0.004,c,Forge.PAINT,5)
		"mohawk":
			for k in 6:
				var t := float(k)/5.0
				var at := Vector3(0,0.6-absf(t-0.4)*0.12,0.2-t*0.45)
				hd.block(at+Vector3(0,0.07,0),Vector3(0.035,0.16+0.04*sin(t*PI),0.09),c,Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(-20+t*50)))
		"comb":
			for k in 4: hd.beam(Vector3(-0.29,0.46+k*0.02,0.1-k*0.08),Vector3(0.24,0.6,0.06-k*0.08),0.022,c)
		"long":
			var length := 0.85 if z.kind == "witch" else 0.55
			for k in 9:
				var a := PI*1.1+PI*0.8*k/8.0
				var top := Vector3(cos(a)*0.28,0.45,sin(a)*0.22-0.02)
				hd.beam(top,top*Vector3(1.15,0,1.25)+Vector3(0,0.45-length+(_noise(4,k,0)-0.5)*0.12,0),0.075,c.darkened(_noise(4,k,1)*0.15))
			if z.kind == "witch":
				for side: float in [-1,1]: hd.beam(Vector3(side*0.17,0.52,0.2),Vector3(side*0.15,-0.1,0.3),0.07,c)
		"bun": hd.ball(Vector3(0,0.56,-0.22),Vector3(0.12,0.11,0.11),c,Forge.PAINT,Basis.IDENTITY,8,4)
		"curlers":
			for k in 6:
				var at := Vector3(-0.16+(k%3)*0.16,0.6-(k/3)*0.06,0.1-(k/3)*0.2)
				hd.tube(at-Vector3(0.06,0,0),at+Vector3(0.06,0,0),0.045,0.045,z.hat_color,Forge.PAINT,6)
		"afro": hd.ball(Vector3(0,0.5,-0.05),Vector3(0.42,0.36,0.4),c,Forge.PAINT,Basis.IDENTITY,10,5)
		"mullet": hd.block(Vector3(0,0.18,-0.25),Vector3(0.38,0.36,0.08),c,Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(10)))
		"ponytail":
			hd.tube(Vector3(0,0.42,-0.24),Vector3(0,0.1,-0.4),0.09,0.05,c,Forge.PAINT,6)
			hd.ball(Vector3(0,0.4,-0.26),Vector3(0.06,0.04,0.06),z.hat_color,Forge.PAINT,Basis.IDENTITY,6,2)
		"fringe": hd.block(Vector3(0.02,0.5,0.2),Vector3(0.52,0.1,0.1),c,Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(-25))*Basis(Vector3.BACK,deg_to_rad(-8)))

func _hat() -> void:
	var hd: Forge = f.head
	var c: Color = z.hat_color
	var dome := func(center: Vector3, radii: Vector3, color: Color) -> void: hd.ball(center,radii,color,Forge.PAINT,Basis.IDENTITY,10,3,0.0,PI*0.5)
	var disc := func(center: Vector3, radii: Vector3, color: Color, tilt := 0.0) -> void: hd.ball(center,radii,color,Forge.PAINT,Basis(Vector3.RIGHT,tilt),12,2)
	match z.hat:
		"cap","cap_back":
			dome.call(Vector3(0,0.42,-0.03),Vector3(0.34,0.24,0.3),c)
			var back := -1.0 if z.hat == "cap_back" else 1.0
			hd.block(Vector3(0,0.44,0.3*back),Vector3(0.3,0.025,0.22),c.darkened(0.15),Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(-8*back)))
			hd.ball(Vector3(0,0.66,-0.03),Vector3(0.03,0.02,0.03),c.darkened(0.2),Forge.PAINT,Basis.IDENTITY,6,2)
		"hard_hat","fire":
			dome.call(Vector3(0,0.42,-0.02),Vector3(0.36,0.28,0.33),c)
			disc.call(Vector3(0,0.43,-0.07 if z.hat == "fire" else 0.0),Vector3(0.42,0.025,0.42 if z.hat == "fire" else 0.38),c.darkened(0.08))
			hd.beam(Vector3(0,0.7,0.2),Vector3(0,0.71,-0.25),0.05,c.lightened(0.1))
			if z.hat == "fire": hd.block(Vector3(0,0.6,0.3),Vector3(0.15,0.13,0.03),GOLD,METAL,Basis(Vector3.RIGHT,deg_to_rad(-25)))
		"helmet":
			dome.call(Vector3(0,0.38,-0.02),Vector3(0.38,0.32,0.36),c)
			disc.call(Vector3(0,0.39,-0.02),Vector3(0.4,0.02,0.38),c.darkened(0.15))
			for side: float in [-1,1]: hd.beam(Vector3(side*0.3,0.38,0.02),Vector3(side*0.16,0.0,0.15),0.018,DARK)
		"helmet_bike":
			dome.call(Vector3(0,0.44,-0.06),Vector3(0.34,0.24,0.38),c)
			for k in 3: hd.beam(Vector3(-0.12+k*0.12,0.67,0.15),Vector3(-0.12+k*0.12,0.66,-0.28),0.03,DARK)
		"beanie","bobble","surgical","trapper":
			dome.call(Vector3(0,0.38,-0.03),Vector3(0.345,0.3,0.29),c)
			if z.hat != "surgical": hd.ball(Vector3(0,0.41,-0.03),Vector3(0.355,0.06,0.3),c.darkened(0.15),Forge.PAINT,Basis.IDENTITY,12,2)
			if z.hat == "bobble": hd.ball(Vector3(0,0.71,-0.03),Vector3(0.09,0.09,0.09),Color(0.95,0.95,0.92),Forge.PAINT,Basis.IDENTITY,7,3)
			if z.hat == "trapper":
				for side: float in [-1,1]: hd.block(Vector3(side*0.32,0.25,-0.02),Vector3(0.06,0.24,0.2),c.lightened(0.3))
				hd.block(Vector3(0,0.47,0.24),Vector3(0.5,0.08,0.06),c.lightened(0.3),Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(-15)))
		"police":
			hd.tube(Vector3(0,0.42,-0.02),Vector3(0,0.62,-0.02),0.33,0.37,c,Forge.PAINT,12)
			hd.ball(Vector3(0,0.46,-0.02),Vector3(0.34,0.04,0.3),DARK,Forge.PAINT,Basis.IDENTITY,12,2)
			hd.block(Vector3(0,0.43,0.3),Vector3(0.3,0.025,0.16),DARK,WET,Basis(Vector3.RIGHT,deg_to_rad(-12)))
			hd.block(Vector3(0,0.54,0.33),Vector3(0.07,0.08,0.02),GOLD,METAL)
		"pillbox":
			hd.tube(Vector3(0.08,0.58,0.02),Vector3(0.1,0.72,0.02),0.17,0.17,c,Forge.PAINT,10)
			hd.ball(Vector3(0.08,0.6,0.02),Vector3(0.18,0.025,0.18),GOLD,METAL,Basis.IDENTITY,10,2)
		"chef":
			hd.tube(Vector3(0,0.42,-0.02),Vector3(0,0.56,-0.02),0.33,0.34,c,Forge.PAINT,12)
			hd.ball(Vector3(0,0.72,-0.02),Vector3(0.38,0.22,0.36),c,Forge.PAINT,Basis.IDENTITY,10,4)
			for k in 4: hd.ball(Vector3(cos(k*1.6)*0.2,0.84,sin(k*1.6)*0.18),Vector3(0.14,0.1,0.14),c.darkened(0.04),Forge.PAINT,Basis.IDENTITY,7,3)
		"nurse":
			hd.block(Vector3(0,0.6,0.1),Vector3(0.34,0.12,0.14),c,Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(-25)))
			hd.block(Vector3(0,0.63,0.18),Vector3(0.08,0.025,0.02),Color(0.8,0.1,0.1),Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(-25)))
			hd.block(Vector3(0,0.63,0.18),Vector3(0.025,0.08,0.02),Color(0.8,0.1,0.1),Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(-25)))
		"bucket","bush","straw","fedora","top_hat":
			var tall := {"bucket": 0.2, "bush": 0.2, "straw": 0.18, "fedora": 0.22, "top_hat": 0.45}[z.hat] as float
			var brim := {"bucket": 0.44, "bush": 0.52, "straw": 0.58, "fedora": 0.46, "top_hat": 0.42}[z.hat] as float
			var base := 0.44
			hd.tube(Vector3(0,base,-0.02),Vector3(0,base+tall,-0.02),0.34 if z.hat != "top_hat" else 0.28,0.29 if z.hat != "top_hat" else 0.28,c,Forge.PAINT,10)
			disc.call(Vector3(0,base,-0.02),Vector3(brim,0.025,brim*0.95),c.darkened(0.08),deg_to_rad(6) if z.hat == "bucket" else 0.0)
			var band := Color(0.15,0.12,0.1) if z.hat in ["fedora","top_hat","bush"] else Color(0.7,0.15,0.12)
			hd.tube(Vector3(0,base+0.02,-0.02),Vector3(0,base+0.07,-0.02),0.345 if z.hat != "top_hat" else 0.285,0.335 if z.hat != "top_hat" else 0.285,band,Forge.PAINT,10,false)
			if z.hat == "bush": hd.block(Vector3(-0.38,base+0.12,-0.02),Vector3(0.03,0.2,0.36),c.darkened(0.08),Forge.PAINT,Basis(Vector3.BACK,deg_to_rad(-15)))
		"headband": hd.ball(Vector3(0,0.46,-0.015),Vector3(0.325,0.045,0.255),c,Forge.PAINT,Basis.IDENTITY,10,2)
		"bandana":
			dome.call(Vector3(0,0.4,-0.02),Vector3(0.335,0.26,0.27),c)
			for side: float in [-1,1]: hd.beam(Vector3(side*0.03,0.4,-0.27),Vector3(side*0.12,0.2,-0.34),0.04,c.darkened(0.1))
			for k in 6: hd.ball(Vector3(cos(k*1.1)*0.22,0.55,sin(k*1.1)*0.18),Vector3(0.025,0.01,0.025),Color(0.95,0.95,0.92),Forge.PAINT,Basis.IDENTITY,5,2)
		"hood":
			var s: Array[Vector4] = [Vector4(-0.12,0.36,0.33,-0.04),Vector4(0.1,0.38,0.33,-0.04),Vector4(0.36,0.4,0.33,-0.05),Vector4(0.58,0.32,0.28,-0.07),Vector4(0.72,0.12,0.12,-0.1),Vector4(0.75,0.01,0.01,-0.1)]
			hd.loft(s,12,func(j: int, i: int, m: Vector3) -> Color:
				if _front(m,-0.05) < 0.85 and m.y < 0.6: return Color(0,0,0,0)
				return _cloth(shirt,2,j+40,i),Vector3.ZERO,Basis.IDENTITY,false,true)
		"cone":
			hd.ball(Vector3(0,0.47,0),Vector3(0.36,0.03,0.36),c.darkened(0.15),Forge.PAINT,Basis.IDENTITY,4,2)
			hd.tube(Vector3(0,0.47,0),Vector3(0,1.08,0),0.27,0.03,c,Forge.PAINT,10)
			hd.tube(Vector3(0,0.66,0),Vector3(0,0.78,0),0.195,0.15,Color(0.95,0.95,0.92),Forge.PAINT,10,false)
		"santa":
			hd.tube(Vector3(0,0.44,-0.02),Vector3(0.12,0.9,-0.22),0.34,0.03,c,Forge.PAINT,10)
			hd.ball(Vector3(0,0.45,-0.02),Vector3(0.37,0.07,0.31),Color(0.97,0.97,0.95),Forge.PAINT,Basis.IDENTITY,12,2)
			hd.ball(Vector3(0.12,0.9,-0.22),Vector3(0.08,0.08,0.08),Color(0.97,0.97,0.95),Forge.PAINT,Basis.IDENTITY,7,3)
		"paper":
			hd.block(Vector3(0,0.6,-0.02),Vector3(0.18,0.16,0.5),c,Forge.PAINT,Basis(Vector3.FORWARD,0.0))
			hd.block(Vector3(0,0.53,-0.02),Vector3(0.24,0.03,0.52),Color(0.85,0.2,0.15))
		"veil":
			hd.ball(Vector3(0,0.58,0.04),Vector3(0.24,0.03,0.18),GOLD,METAL,Basis(Vector3.RIGHT,deg_to_rad(-15)),10,2)
			var v: Array[Vector4] = [Vector4(-0.7,0.42,0.36,-0.12),Vector4(-0.1,0.38,0.32,-0.08),Vector4(0.4,0.35,0.29,-0.04),Vector4(0.62,0.22,0.2,-0.02)]
			hd.loft(v,10,func(j: int, i: int, m: Vector3) -> Color:
				return Color(0,0,0,0) if _front(m,-0.04) < 1.4 else c.darkened(_noise(5,j,i)*0.08),Vector3.ZERO,Basis.IDENTITY,false,true)

# --- Limbs -----------------------------------------------------------------------------------------------------------

func _sleeve() -> Color:
	if z.top in ["bare","tank"] or z.sleeves == "none": return skin
	return inner if z.top == "vest" else shirt

func _pants_color() -> Color:
	return skin if z.legwear in ["bare","tutu"] or (z.top == "dress" and z.legwear != "trousers") else z.pants

func _arm(side: float) -> void:
	var up: Forge = f["arm_l" if side < 0 else "arm_r"]
	var fore: Forge = f["fore_l" if side < 0 else "fore_r"]
	var r := arm_r
	var h := arm_h
	var sleeve := _sleeve()
	var bare := sleeve == skin
	var part := 10 if side < 0 else 11
	var long: bool = z.sleeves in ["long","rolled"] and not bare
	var upper: Array[Vector4] = [Vector4(-h*0.43,r*0.9,r*0.9,0.01),Vector4(-h*0.25,r*0.97,r*0.97,0.005),Vector4(-r*0.4,r,r,0),Vector4(r*0.2,r*0.85,r*0.85,0),Vector4(r*0.5,0.001,0.001,0)]
	up.loft(upper,8,func(j: int, i: int, m: Vector3) -> Color:
		if bare or (z.sleeves == "short" and m.y < -h*0.34): return _flesh(part,j,i)
		var c := _pattern(sleeve,part,j,i,m,0.5,1.0,absf(cos(atan2(m.z,m.x))) if signf(m.x) == side else 0.0) if sleeve == shirt else sleeve
		return _cloth(c,part,j,i),Vector3.ZERO,Basis.IDENTITY,true)
	if z.sleeves == "short" and not bare:
		up.tube(Vector3(0,-h*0.3,0.005),Vector3(0,-h*0.36,0.007),r*1.06,r*1.04,sleeve.darkened(0.1),Forge.PAINT,8,false)
	# Forearm, from the elbow.
	fore.ball(Vector3.ZERO,Vector3.ONE*r*0.93,sleeve if long else skin,Forge.PAINT,Basis.IDENTITY,8,4)
	var lower: Array[Vector4] = [Vector4(-h*0.43,r*0.7,r*0.7,0.02),Vector4(-h*0.38,r*0.74,r*0.72,0.015),Vector4(-h*0.18,r*0.82,r*0.82,0.006),Vector4(0,r*0.86,r*0.86,0)]
	var rolled: bool = z.sleeves == "rolled"
	fore.loft(lower,8,func(j: int, i: int, m: Vector3) -> Color:
		if not long or (rolled and m.y < -h*0.1): return _flesh(part+2,j,i)
		return _cloth(_pattern(sleeve,part+2,j,i,m,0.5,1.0,0.0) if sleeve == shirt else sleeve,part+2,j,i))
	if rolled: fore.tube(Vector3(0,-h*0.06,0.003),Vector3(0,-h*0.13,0.006),r*0.95,r*0.92,sleeve.lightened(0.06),Forge.PAINT,8,false)
	elif long: fore.tube(Vector3(0,-h*0.34,0.014),Vector3(0,-h*0.4,0.017),r*0.82,r*0.8,sleeve.darkened(0.12),Forge.PAINT,8,false)
	_hand(fore,side)

func _hand(fore: Forge, side: float) -> void:
	var r := arm_r
	var h := arm_h
	var s: float = z.arms
	var glove := skin
	for kind: String in ["gloves","gloves_blue","gloves_white","gloves_garden"]:
		if has(kind): glove = {"gloves": Color(0.24,0.2,0.16), "gloves_blue": Color(0.35,0.55,0.9), "gloves_white": Color(0.96,0.96,0.94), "gloves_garden": Color(0.35,0.6,0.3)}[kind]
	if has("glove_one") and side < 0: glove = Color(0.96,0.96,0.94)
	if has("boxing_gloves"):
		fore.ball(Vector3(0,-h*0.52,0.05),Vector3(0.13,0.15,0.14)*s,Color(0.8,0.1,0.1),WET,Basis.IDENTITY,9,4)
		fore.tube(Vector3(0,-h*0.38,0.02),Vector3(0,-h*0.45,0.03),r*0.95,r*0.95,Color(0.96,0.96,0.94),Forge.PAINT,8)
		return
	fore.ball(Vector3(0,-h*0.49,0.04),Vector3(0.095,0.085,0.088)*s,glove,Forge.PAINT,Basis.IDENTITY,8,4)
	fore.ball(Vector3(-side*r*0.8,-h*0.46,0.08),Vector3(0.04,0.06,0.045)*s,glove,Forge.PAINT,Basis(Vector3.BACK,deg_to_rad(side*25)),6,3)
	var claw := 0.38 if has("claws_long") else (0.13 if has("claws") else 0.0)
	for k in 3:
		var x := (-r*0.5+k*r*0.5)
		var a := Vector3(x,-h*0.53,0.09*s)
		var b := Vector3(x,-h*0.6-0.02*s,0.085*s)
		fore.beam(a,b,0.042*s,glove.darkened(0.04))
		if claw > 0: fore.tube(b,b+Vector3(0,-claw,claw*0.25),0.016,0.002,BONE,WET,4)
	if has("tape"):
		fore.tube(Vector3(0,-h*0.36,0.014),Vector3(0,-h*0.43,0.02),r*0.78,r*0.74,Color(0.9,0.88,0.82),Forge.PAINT,8,false)

func _leg(side: float) -> void:
	var up: Forge = f["leg_l" if side < 0 else "leg_r"]
	var shin: Forge = f["shin_l" if side < 0 else "shin_r"]
	var r := leg_r
	var h := leg_h
	var part := 20 if side < 0 else 21
	var pants := _pants_color()
	var bare := pants == skin
	var lw: String = z.legwear
	var stripe: bool = has("leg_stripes")
	var upper: Array[Vector4] = [Vector4(-h*0.43,r*0.9,r*0.92,0.01),Vector4(-h*0.25,r*0.97,r,0.005),Vector4(-r*0.4,r,r*1.04,0),Vector4(r*0.3,r*0.7,r*0.7,0),Vector4(r*0.55,0.001,0.001,0)]
	up.loft(upper,8,func(j: int, i: int, m: Vector3) -> Color:
		if bare or lw == "skirt": return _flesh(part,j,i)
		if lw == "shorts" and m.y < -h*0.32: return _flesh(part,j,i)
		if stripe and signf(m.x) == side and absf(cos(atan2(m.z,m.x))) > 0.9: return z.trim
		return _cloth(pants,part,j,i))
	if lw == "shorts": up.tube(Vector3(0,-h*0.27,0.006),Vector3(0,-h*0.33,0.008),r*1.08,r*1.06,Color(pants).darkened(0.1),Forge.PAINT,8,false)
	# Shin, from the knee.
	var torn: bool = lw == "torn" and (side < 0 or z.kind == "tank")
	var trousers: bool = not bare and lw in ["trousers","torn"]
	var socks: Color = z.socks
	var sole := -h*0.58
	shin.ball(Vector3.ZERO,Vector3.ONE*r*0.93,pants if trousers else skin,Forge.PAINT,Basis.IDENTITY,8,4)
	var lower: Array[Vector4] = [Vector4(sole+0.1,r*0.74,r*0.74,0.03),Vector4(-h*0.2,r*0.84,r*0.86,0.012),Vector4(0,r*0.86,r*0.88,0)]
	shin.loft(lower,8,func(j: int, i: int, m: Vector3) -> Color:
		if trousers and not (torn and m.y < -h*(0.12 if z.kind != "tank" else 0.05)):
			if stripe and signf(m.x) == side and absf(cos(atan2(m.z,m.x))) > 0.9: return z.trim
			return _cloth(pants,part+2,j,i)
		if socks.a > 0 and m.y < -h*0.3: return socks
		return _flesh(part+2,j,i))
	if torn:
		var cut := -h*(0.12 if z.kind != "tank" else 0.05)
		for k in 5:
			var a := TAU*k/5.0
			shin.tube(Vector3(cos(a)*r*0.85,cut+0.01,sin(a)*r*0.85+0.01),Vector3(cos(a)*r*0.8,cut-0.05-_noise(part,k,9)*0.06,sin(a)*r*0.8+0.015),0.03,0.002,pants,Forge.PAINT,4)
	if has("knee_pads"): shin.block(Vector3(0,-0.02,r*0.9),Vector3(r*1.6,0.11,0.05),DARK)
	_shoe(shin,sole,side)

func _shoe(shin: Forge, sole: float, side: float) -> void:
	var c: Color = z.shoe
	var r := leg_r
	var h := leg_h
	match z.shoes:
		"bare","sandals":
			shin.ball(Vector3(0,sole+0.03,0.08),Vector3(0.11,0.08,0.18),skin,Forge.PAINT,Basis.IDENTITY,8,3,0.0,PI*0.5)
			for k in 4: shin.ball(Vector3(-0.06+k*0.04,sole+0.03,0.24),Vector3(0.022,0.022,0.03),skin.darkened(0.06),Forge.PAINT,Basis.IDENTITY,5,2)
			if z.shoes == "sandals":
				shin.block(Vector3(0,sole+0.012,0.08),Vector3(0.24,0.025,0.4),Color(0.45,0.3,0.18))
				shin.beam(Vector3(-0.1,sole+0.07,0.12),Vector3(0.1,sole+0.07,0.12),0.03,c)
			if Color(z.socks).a > 0: shin.ball(Vector3(0,sole+0.03,0.08),Vector3(0.115,0.085,0.17),z.socks,Forge.PAINT,Basis.IDENTITY,8,3,0.0,PI*0.5)
		"slippers":
			shin.ball(Vector3(0,sole+0.06,0.08),Vector3(0.15,0.09,0.22),c,Forge.PAINT,Basis.IDENTITY,9,4)
			shin.ball(Vector3(0,sole+0.1,0.2),Vector3(0.09,0.05,0.07),c.lightened(0.25),Forge.PAINT,Basis.IDENTITY,7,3)
		"flats":
			shin.ball(Vector3(0,sole+0.02,0.07),Vector3(0.12,0.08,0.19),c,WET,Basis.IDENTITY,8,3,0.0,PI*0.5)
			shin.block(Vector3(0,sole+0.01,0.07),Vector3(0.23,0.02,0.37),c.darkened(0.3))
		_:
			var boot: bool = z.shoes in ["boots","wellies"]
			var shine := WET if z.shoes in ["smart","wellies"] else Forge.PAINT
			var tall: float = {"wellies": h*0.42, "boots": h*0.2}.get(z.shoes,0.0)
			var sole_c := Color(0.95,0.95,0.92) if z.shoes == "sneakers" else Color(0.08,0.08,0.09)
			var thick := 0.055 if z.shoes in ["sneakers","boots","studs"] else 0.035
			shin.ball(Vector3(0,sole+thick,0.07),Vector3(0.14,0.13 if boot else 0.1,0.22),c,shine,Basis.IDENTITY,9,3,0.0,PI*0.5)
			shin.block(Vector3(0,sole+thick*0.5,0.075),Vector3(0.29,thick,0.45),sole_c)
			if tall > 0: shin.tube(Vector3(0,sole+0.05,0.03),Vector3(0,sole+0.05+tall,0.025),r*1.0,r*1.05,c,shine,8)
			if z.shoes in ["boots","sneakers","studs"]:
				for k in 3: shin.beam(Vector3(-0.05,sole+thick+0.07+k*0.025,0.13+k*0.025),Vector3(0.05,sole+thick+0.07+k*0.025,0.13+k*0.025),0.016,Color(0.92,0.9,0.82) if z.shoes != "boots" else Color(0.75,0.62,0.4))
			if z.shoes == "studs":
				for k in 4: shin.block(Vector3(-0.07+(k%2)*0.14,sole-0.01,-0.05+(k/2)*0.24),Vector3(0.04,0.03,0.04),DARK)

# --- Fittings --------------------------------------------------------------------------------------------------------

func _fit(fitting: String) -> void:
	var t: Forge = f.torso
	var hd: Forge = f.head
	match fitting:
		"watch":
			var fore: Forge = f.fore_l
			fore.tube(Vector3(0,-arm_h*0.36,0.014),Vector3(0,-arm_h*0.41,0.018),arm_r*0.78,arm_r*0.76,DARK,Forge.PAINT,8)
			fore.block(Vector3(0,-arm_h*0.385,arm_r*0.8),Vector3(0.05,0.05,0.02),STEEL,METAL)
		"headphones":
			for k in 4: hd.beam(_arc(k/4.0),_arc((k+1)/4.0),0.035,DARK)
			for side: float in [-1,1]: hd.ball(Vector3(side*0.33,0.29,0),Vector3(0.05,0.1,0.09),Color(0.85,0.2,0.15),Forge.PAINT,Basis.IDENTITY,8,3)
		"satchel","camera","binoculars":
			t.beam(_on_torso(-0.6,1.0,0.02)+Vector3(0,0.02,0),_on_torso(0.9,0.15,0.03),0.035,Color(0.35,0.22,0.12))
			t.beam(_on_torso(PI+0.6,1.0,0.02)+Vector3(0,0.02,0),_on_torso(PI-0.9,0.15,0.03),0.035,Color(0.35,0.22,0.12))
			match fitting:
				"satchel": t.block(_on_torso(1.2,0.15,0.07),Vector3(0.24,0.2,0.08),Color(0.55,0.32,0.15),Forge.PAINT,Basis(Vector3.UP,-1.0))
				"camera":
					var at := _on_torso(0.05,0.55,0.06)
					t.block(at,Vector3(0.18,0.11,0.07),DARK)
					t.tube(at+Vector3(0,0,0.03),at+Vector3(0,0,0.1),0.04,0.035,STEEL,METAL,8)
				"binoculars":
					for side: float in [-1,1]:
						var at := _on_torso(side*0.12,0.6,0.04)
						t.tube(at,at+Vector3(0,-0.02,0.14),0.035,0.04,DARK,Forge.PAINT,7)
		"tie","bowtie":
			var top := _on_torso(0,0.97,0.01)
			if fitting == "bowtie":
				for side: float in [-1,1]: t.ball(top+Vector3(side*0.045,0,0.01),Vector3(0.05,0.035,0.02),z.trim,Forge.PAINT,Basis.IDENTITY,6,2)
			else:
				t.block(top,Vector3(0.05,0.045,0.03),z.trim)
				t.beam(top,_on_torso(0,0.42,0.012),0.06,z.trim)
		"lanyard","whistle","dog_tags","stethoscope","pearls","medals":
			var c: Color = {"lanyard": Color(0.2,0.35,0.75), "whistle": Color(0.9,0.2,0.15), "dog_tags": STEEL, "stethoscope": DARK, "pearls": Color(0.95,0.94,0.88), "medals": Color(0.6,0.15,0.2)}[fitting]
			if fitting == "pearls":
				for k in 11:
					var a := -1.2+k*0.24
					t.ball(_on_torso(a,0.95,0.01),Vector3.ONE*0.022,c,WET,Basis.IDENTITY,6,3)
				return
			if fitting == "medals":
				for k in 3:
					var at := _on_torso(-0.45-k*0.12,0.7,0.01)
					t.block(at+Vector3(0,0.03,0),Vector3(0.04,0.05,0.015),[Color(0.6,0.15,0.2),Color(0.2,0.3,0.6),Color(0.85,0.75,0.2)][k])
					t.ball(at-Vector3(0,0.02,-0.01),Vector3(0.025,0.025,0.008),GOLD,METAL,Basis.IDENTITY,6,2)
				return
			var low := _on_torso(0.05 if fitting != "stethoscope" else 0,0.55,0.02)
			for side: float in [-1,1]: t.beam(_on_torso(side*0.35,0.98,0.01),low,0.02,c)
			match fitting:
				"lanyard": t.block(low+Vector3(0,-0.05,0.01),Vector3(0.08,0.1,0.012),Color(0.96,0.96,0.94))
				"whistle": t.block(low+Vector3(0,-0.02,0.02),Vector3(0.035,0.035,0.07),STEEL,METAL)
				"dog_tags":
					for k in 2: t.block(low+Vector3(k*0.03-0.015,-0.03-k*0.01,0.01),Vector3(0.035,0.05,0.008),STEEL,METAL)
				"stethoscope": t.ball(low+Vector3(0,-0.02,0.015),Vector3(0.035,0.035,0.012),STEEL,METAL,Basis.IDENTITY,7,2)
		"nametag": t.block(_on_torso(-0.5,0.66,0.01),Vector3(0.1,0.05,0.012),Color(0.96,0.96,0.94))
		"badge","patches":
			t.block(_on_torso(-0.48,0.68,0.012),Vector3(0.07,0.08,0.015),GOLD if fitting == "badge" else Color(0.8,0.3,0.15),METAL if fitting == "badge" else Forge.PAINT)
			if fitting == "patches":
				for side: float in [-1,1]: (f["arm_l" if side < 0 else "arm_r"] as Forge).block(Vector3(side*arm_r*0.98,-arm_h*0.18,0),Vector3(0.02,0.08,0.07),[Color(0.25,0.5,0.3),Color(0.85,0.7,0.2)][int(side > 0)])
		"radio":
			var at := _on_torso(0.55,0.88,0.03)
			t.block(at,Vector3(0.06,0.11,0.04),DARK)
			t.beam(at+Vector3(0.02,0.05,0),at+Vector3(0.02,0.16,0),0.012,DARK)
		"backpack","backpack_big":
			var big := fitting == "backpack_big"
			var back := _on_torso(PI,0.55,0.0)
			t.block(back+Vector3(0,0,-0.11 if not big else -0.15),Vector3(0.38,0.44 if not big else 0.62,0.2 if not big else 0.28),Color(0.3,0.45,0.6) if not big else Color(0.75,0.45,0.15))
			if big: t.tube(back+Vector3(-0.22,0.36,-0.15),back+Vector3(0.22,0.36,-0.15),0.08,0.08,Color(0.3,0.42,0.28),Forge.PAINT,8)
			for side: float in [-1,1]: t.beam(_on_torso(side*0.4,0.98,0.02),_on_torso(side*0.45,0.25,0.02),0.035,DARK)
		"toolbelt","belt_gold","belt_black":
			var c := Color(0.45,0.3,0.15) if fitting == "toolbelt" else DARK
			var ring := torso_rings[3]
			t.ball(Vector3(0,0.08,ring.w),Vector3(ring.y*1.04,0.035,ring.z*1.06),c,Forge.PAINT,Basis.IDENTITY,12,2)
			if fitting == "belt_gold": t.block(_on_torso(0,0.11,0.03),Vector3(0.2,0.13,0.03),GOLD,METAL)
			elif fitting == "belt_black": t.block(_on_torso(0,0.11,0.03),Vector3(0.09,0.07,0.02),STEEL,METAL)
			else:
				for side: float in [-1,1]: t.block(_on_torso(side*1.2,0.04,0.05),Vector3(0.1,0.13,0.08),c.darkened(0.15))
				t.beam(_on_torso(1.4,0.06,0.07),_on_torso(1.4,-0.2,0.08),0.025,Color(0.5,0.32,0.15))
		"keys":
			for k in 4: t.block(_on_torso(-1.1,0.06,0.03)+Vector3(0,-0.04-k*0.015,0),Vector3(0.015,0.05,0.008),STEEL,METAL,Basis(Vector3.BACK,k*0.4-0.6))
		"cleaver":
			hd.block(Vector3(0.1,0.7,0.0),Vector3(0.025,0.18,0.3),STEEL,METAL,Basis(Vector3.BACK,deg_to_rad(-25)))
			hd.block(Vector3(0.16,0.82,-0.0),Vector3(0.03,0.04,0.32),STEEL.darkened(0.2),METAL,Basis(Vector3.BACK,deg_to_rad(-25)))
			hd.beam(Vector3(0.13,0.72,-0.16),Vector3(0.2,0.78,-0.4),0.045,Color(0.35,0.2,0.1))
			hd.ball(Vector3(0.07,0.6,0.05),Vector3(0.06,0.03,0.08),BLOOD,WET,Basis.IDENTITY,6,2)
		"moustache":
			for side: float in [-1,1]: hd.ball(Vector3(-0.02+side*0.07,0.135,0.36),Vector3(0.08,0.03,0.035),Color(z.hair_color) if z.hair != "bald" else Color(0.5,0.48,0.45),Forge.PAINT,Basis(Vector3.BACK,side*0.3),7,2)
		"beard","beard_white":
			var c: Color = Color(0.96,0.96,0.94) if fitting == "beard_white" else (Color(z.hair_color) if z.hair != "bald" else Color(0.35,0.25,0.15))
			hd.ball(Vector3(0.02,0.04,0.2),Vector3(0.26,0.16,0.15),c,Forge.PAINT,Basis.IDENTITY,9,4,-PI*0.5,0.3)
			hd.tube(Vector3(0.02,-0.06,0.23),Vector3(0.02,-0.2,0.27),0.12,0.02,c,Forge.PAINT,7)
		"braces":
			for side: float in [-1,1]:
				t.beam(_on_torso(side*0.35,0.12,0.015),_on_torso(side*0.4,1.0,0.012)+Vector3(0,0.02,0),0.03,Color(0.7,0.15,0.12))
				t.beam(_on_torso(PI-side*0.4,1.0,0.012)+Vector3(0,0.02,0),_on_torso(PI-side*0.2,0.12,0.015),0.03,Color(0.7,0.15,0.12))
		"mask":
			hd.block(Vector3(0.02,0.02,0.25),Vector3(0.3,0.1,0.08),Color(0.6,0.78,0.88),Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(20)))
			for side: float in [-1,1]: hd.beam(Vector3(side*0.15,0.03,0.24),Vector3(side*0.3,0.25,0.04),0.012,Color(0.92,0.92,0.92))
		"shades","glasses":
			for side: float in [-1,1]:
				var at := Vector3(side*0.13,0.34,0.36)
				if fitting == "shades": hd.block(at,Vector3(0.2,0.11,0.03),DARK,WET)
				else:
					for e: Array in [[Vector3(-0.09,0.06,0),Vector3(0.09,0.06,0)],[Vector3(-0.09,-0.06,0),Vector3(0.09,-0.06,0)],[Vector3(-0.09,-0.06,0),Vector3(-0.09,0.06,0)],[Vector3(0.09,-0.06,0),Vector3(0.09,0.06,0)]]:
						hd.beam(at+e[0],at+e[1],0.018,Color(0.2,0.12,0.08))
				hd.beam(at+Vector3(side*0.09,0.03,0),Vector3(side*0.31,0.33,0.06),0.016,DARK)
			hd.beam(Vector3(-0.04,0.36,0.36),Vector3(0.04,0.36,0.36),0.018,DARK)
		"cuffs":
			var fore: Forge = f.fore_r
			fore.tube(Vector3(0,-arm_h*0.37,0.014),Vector3(0,-arm_h*0.41,0.018),arm_r*0.86,arm_r*0.84,STEEL,METAL,8,false)
			for k in 3: fore.beam(Vector3(0.0,-arm_h*0.42-k*0.05,arm_r*0.8),Vector3(0.0,-arm_h*0.42-(k+1)*0.05,arm_r*0.8+0.01),0.02,STEEL,METAL)
			fore.tube(Vector3(0,-arm_h*0.42-0.2,arm_r*0.8),Vector3(0,-arm_h*0.42-0.23,arm_r*0.8),0.06,0.06,STEEL,METAL,8,false)
		"bib":
			var at := _on_torso(0,0.45,0.012)
			t.block(at,Vector3(0.22,0.16,0.012),Color(0.96,0.96,0.94))
			for k in 3: t.block(at+Vector3(-0.06+k*0.06,0,0.008),Vector3(0.035,0.08,0.006),DARK)
		"bow": hd.ball(Vector3(0,0.55,-0.24),Vector3(0.14,0.06,0.04),z.trim,Forge.PAINT,Basis.IDENTITY,6,2)
		"studs":
			for side: float in [-1,1]:
				for k in 3: t.tube(_on_torso(side*1.1,0.92-k*0.05,0.0),_on_torso(side*1.1,0.92-k*0.05,0.05),0.018,0.002,STEEL,METAL,5)
		"scarf","neckerchief":
			var c: Color = z.trim if fitting == "neckerchief" else Color(0.8,0.2,0.22)
			t.tube(Vector3(0,th*0.94,0),Vector3(0,th*1.03,0),w*0.68,w*0.58,c,Forge.PAINT,10)
			t.beam(_on_torso(-0.3,0.95,0.03),_on_torso(-0.35,0.6,0.04),0.06 if fitting == "scarf" else 0.04,c.darkened(0.08))
			if fitting == "neckerchief": t.ball(_on_torso(0,0.86,0.03),Vector3(0.03,0.03,0.02),Color(0.5,0.3,0.15),Forge.PAINT,Basis.IDENTITY,6,2)
		"pockets":
			for side: float in [-1,1]:
				for k in 2: t.block(_on_torso(side*(0.35+k*0.35),0.5+k*0.18,0.012),Vector3(0.09,0.09,0.03),Color(z.shirt).darkened(0.12))
		"rod":
			var fore: Forge = f.fore_r
			var grip := Vector3(0,-arm_h*0.5,0.12)
			fore.beam(grip-Vector3(0,0,0.2),grip+Vector3(0,0.35,1.1),0.025,Color(0.3,0.2,0.12))
			fore.tube(grip+Vector3(0.04,0,0),grip+Vector3(0.1,0,0),0.05,0.05,STEEL,METAL,8)
			fore.beam(grip+Vector3(0,0.35,1.1),grip+Vector3(0,-0.4,1.15),0.006,Color(0.9,0.9,0.9))
		"fish":
			var fore: Forge = f.fore_l
			var at := Vector3(0,-arm_h*0.62,0.12)
			fore.ball(at,Vector3(0.05,0.08,0.16),Color(0.55,0.65,0.7),WET,Basis.IDENTITY,7,3)
			fore.block(at+Vector3(0,0,-0.18),Vector3(0.01,0.1,0.07),Color(0.45,0.55,0.6),WET)
			fore.ball(at+Vector3(0.03,0.02,0.11),Vector3(0.012,0.012,0.012),DARK,WET,Basis.IDENTITY,5,2)
		"boils":
			for k in 16:
				var a := (_noise(60,k,0)-0.5)*TAU*0.9
				var size := 0.03+_noise(60,k,1)*0.06
				t.ball(_on_torso(a,0.2+_noise(60,k,2)*0.7,size*0.4),Vector3.ONE*size,PUS.lerp(Color(0.75,0.45,0.35),_noise(60,k,3)),WET,Basis.IDENTITY,7,3)
			for k in 3: hd.ball(Vector3(-0.2+k*0.2,0.45-k*0.08,0.18),Vector3.ONE*0.035,PUS,WET,Basis.IDENTITY,6,3)
		"tumours":
			for k in 5: hd.ball(Vector3(-0.25+_noise(61,k,0)*0.5,0.12+_noise(61,k,1)*0.35,0.2+_noise(61,k,2)*0.06),Vector3.ONE*(0.05+_noise(61,k,3)*0.05),TUMOUR,WET,Basis.IDENTITY,7,3)
			for k in 5: t.ball(_on_torso(-0.8+_noise(62,k,0)*1.6,0.2+_noise(62,k,1)*0.6,0.02),Vector3.ONE*(0.045+_noise(62,k,2)*0.05),TUMOUR,WET,Basis.IDENTITY,7,3)
			(f.arm_l as Forge).ball(Vector3(-arm_r*0.8,-arm_h*0.2,0.03),Vector3.ONE*0.06,TUMOUR,WET,Basis.IDENTITY,7,3)
		"acid":
			for k in 3: t.ball(_on_torso(-0.15+k*0.12,0.8-k*0.12,0.01),Vector3(0.025,0.05+k*0.02,0.015),ACID,GLOW,Basis.IDENTITY,6,3)
			hd.ball(Vector3(0.05,-0.02,0.3),Vector3(0.02,0.05,0.02),ACID,GLOW,Basis.IDENTITY,6,3)
			for k in 4: t.ball(Vector3(-0.06+k*0.04,th+0.05+k*0.06,0.08),Vector3.ONE*0.035,ACID.darkened(0.3),WET,Basis.IDENTITY,6,3)
		"lumps":
			for k in 8: t.ball(_on_torso(PI*0.5+_noise(63,k,0)*PI,0.3+_noise(63,k,1)*0.6,0.03),Vector3.ONE*(0.12+_noise(63,k,2)*0.13),skin.darkened(0.08+_noise(63,k,3)*0.1),Forge.PAINT,Basis.IDENTITY,8,4)
			for side: float in [-1,1]: (f["arm_l" if side < 0 else "arm_r"] as Forge).ball(Vector3(side*arm_r*0.4,0.0,-0.05),Vector3(arm_r*1.1,arm_r*0.9,arm_r*1.0),skin.darkened(0.05),Forge.PAINT,Basis.IDENTITY,8,4)
		"chain":
			for k in 9:
				var a := _on_torso(-0.9+k*0.2,0.95-k*0.09,0.03)
				var b := _on_torso(-0.9+(k+1)*0.2,0.95-(k+1)*0.09,0.03)
				t.beam(a,b,0.035 if k%2 == 0 else 0.025,STEEL,METAL)
		"plates":
			for side: float in [-1,1]:
				t.block(_on_torso(side*1.25,0.9,0.05),Vector3(0.3,0.06,0.3),STEEL.darkened(0.25),METAL,Basis(Vector3.FORWARD,side*0.4))
			t.block(_on_torso(0.2,0.55,0.03),Vector3(0.36,0.3,0.03),Color(0.5,0.35,0.25),METAL,Basis(Vector3.BACK,0.15))
			t.beam(_on_torso(-1.2,0.7,0.03),_on_torso(1.2,0.45,0.04),0.04,DARK)
		"stitches":
			for k in 6:
				var a := _on_torso(-0.6+k*0.22,0.6-k*0.04,0.01)
				t.beam(a+Vector3(0,0.04,0),a-Vector3(0,0.04,0),0.015,DARK)
			t.beam(_on_torso(-0.6,0.6,0.008),_on_torso(0.5,0.4,0.008),0.012,DARK)
			hd.beam(Vector3(-0.28,0.5,0.1),Vector3(0.0,0.6,0.15),0.012,DARK)
		"bandage":
			hd.tube(Vector3(0,0.42,-0.01),Vector3(0.02,0.5,0.0),0.335,0.33,Color(0.95,0.93,0.86),Forge.PAINT,10,false)
			(f.arm_r as Forge).tube(Vector3(0,-arm_h*0.15,0),Vector3(0,-arm_h*0.28,0.004),arm_r*1.04,arm_r*1.02,Color(0.95,0.93,0.86),Forge.PAINT,8,false)
		"zip": t.beam(_on_torso(0,0.1,0.01),_on_torso(0,0.98,0.01),0.018,STEEL,METAL)

## A point on a headband arc from one ear (0) over the crown to the other (1).
func _arc(t: float) -> Vector3:
	var a := PI*t
	return Vector3(cos(a)*0.34,0.3+sin(a)*0.4,0)

## Bare ribs through a hole in the shirt, for the worst-kept.
func _ribs() -> void:
	var t: Forge = f.torso
	var at := _on_torso(-0.7,0.55,0.0)
	t.ball(at,Vector3(0.12,0.12,0.04),GUM,WET,Basis(Vector3.UP,0.7),7,3)
	for k in 3:
		var y := 0.45+k*0.08
		t.beam(_on_torso(-0.45,y,0.015),_on_torso(-0.95,y-0.02,0.015),0.028,BONE)
