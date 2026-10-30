class_name BareaCity
extends RefCounted
## Barea City: a metropolis of city blocks on a 64 m grid with 16 m streets. Skyscrapers
## downtown, mid-rise blocks with alleys elsewhere, plus petrol stations, convenience stores,
## a police station, a fire station, a plaza and the Price Slasher Megamart (home of the
## Yellow Sticker idol). Army roadblocks close streets to cars but leave a gap you can squeeze
## through on foot, so the city plays as corridors. Deterministic: every peer builds the same.

const PITCH := 64.0
const STREET := 16.0
const LOT := PITCH - STREET  # 48 m buildable square per block
const FACADES := [Color(0.62, 0.78, 0.8), Color(0.93, 0.86, 0.68), Color(0.78, 0.47, 0.36), Color(0.48, 0.55, 0.62), Color(0.86, 0.71, 0.33), Color(0.66, 0.73, 0.55), Color(0.9, 0.9, 0.86), Color(0.58, 0.45, 0.6)]
const SHOPS := ["DONUT DEN", "BAREA BANK", "PIZZA PALACE", "LAUNDROMAT", "PAWN & GUNS", "PHARMACY", "NOODLE BAR", "VIDEO RENTAL", "HARDWARE", "BARBER"]
const CAR_COLORS := [Color(0.85, 0.3, 0.25), Color(0.25, 0.5, 0.8), Color(0.95, 0.85, 0.4), Color(0.3, 0.65, 0.45), Color(0.9, 0.9, 0.88), Color(0.35, 0.35, 0.4), Color(0.95, 0.55, 0.2)]

var ow: OpenWorld
var root: Node3D
var index := 0
var center := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var blocks := {}  # Vector2i -> kind
var _mm := {}     # batched meshes: key -> {"mesh", "mat", "xforms"}
var _downtown := Vector3.ZERO


static func build(world: OpenWorld, island_index: int) -> BareaCity:
	var c := BareaCity.new()
	c.ow = world
	c.root = world.root
	c.index = island_index
	var island: Dictionary = OpenWorld.ISLANDS[island_index]
	c.center = Vector3(island.center.x, 0, island.center.y)
	c.rng.seed = 51200
	c._generate()
	return c


func _generate() -> void:
	ow.markers["street_pockets"] = []
	ow.markers["npcs"] = []
	ow.markers["idol"] = Vector3.INF
	ow.markers["city_blocks"] = []
	ow.markers["roadblocks"] = []
	var dock := OpenWorld.dock(index)
	_terminal = ferry_terminal(index)
	ow.markers["ferry_terminal"] = _terminal
	var span_i := int(OpenWorld.ISLANDS[index].radius.x / PITCH) + 2
	var span_j := int(OpenWorld.ISLANDS[index].radius.y / PITCH) + 2
	for j in range(-span_j, span_j):
		for i in range(-span_i, span_i):
			var b := Vector2i(i, j)
			var c := block_center(b)
			if c.x > dock.x - 120.0 or c.distance_to(_terminal) < 130.0:
				continue
			var ok := true
			for corner: Vector3 in [Vector3(-34, 0, -34), Vector3(34, 0, -34), Vector3(-34, 0, 34), Vector3(34, 0, 34)]:
				if OpenWorld.land_index(c + corner, 24.0) != index:
					ok = false
			if ok:
				blocks[b] = "building"
	_downtown = center + Vector3(60, 0, 0)
	_assign_landmarks()
	_ground()
	for b: Vector2i in blocks:
		ow.markers.city_blocks.append(block_center(b))
		match String(blocks[b]):
			"petrol": _petrol(b)
			"store": _store(b)
			"police": _police(b)
			"fire": _fire(b)
			"plaza": _plaza(b)
			"megamart": _megamart(b)
			"substation": _substation(b)
			_: _buildings(b)
	_street_life()
	_roadblocks()
	_harbour_front()
	_ferry_front()
	_flush()


func block_center(b: Vector2i) -> Vector3:
	return center + Vector3((b.x + 0.5) * PITCH, 0, (b.y + 0.5) * PITCH)


func _nearest_free(target: Vector3) -> Vector2i:
	var best := Vector2i(999, 999)
	var bd := INF
	for b: Vector2i in blocks:
		if blocks[b] != "building":
			continue
		var d := block_center(b).distance_to(target)
		if d < bd:
			bd = d
			best = b
	return best


func _assign_landmarks() -> void:
	# Each act of Barea's story lives in its own district, a long way from the last.
	var dock := OpenWorld.dock(index)
	var picks := [
		["police", center + Vector3(420, 0, -500)],     # Act 2: north-east
		["substation", center + Vector3(-450, 0, -560)],  # Act 3: north-west industrial
		["megamart", center + Vector3(-120, 0, 520)],   # Act 4: south
		["fire", center + Vector3(520, 0, 380)],
		["plaza", _downtown + Vector3(-60, 0, 110)],
		["petrol", dock + Vector3(-180, 0, 70)],
		["petrol", center + Vector3(-620, 0, 120)],
		["petrol", center + Vector3(150, 0, -680)],
		["petrol", center + Vector3(300, 0, 640)],
		["store", dock + Vector3(-200, 0, -90)],
		["store", _downtown + Vector3(220, 0, -260)],
		["store", center + Vector3(-560, 0, -200)],
		["store", center + Vector3(-300, 0, 300)],
		["store", center + Vector3(500, 0, -150)],
		["store", center + Vector3(-760, 0, 380)],
	]
	for p: Array in picks:
		var b := _nearest_free(p[1])
		if blocks.has(b):
			blocks[b] = p[0]


# --- Batched geometry ------------------------------------------------------------------

func _add(key: String, mesh: Mesh, color: Color, t: Transform3D, emission := 0.0) -> void:
	if not _mm.has(key):
		_mm[key] = {"mesh": mesh, "mat": Build.mat(color, 0.6, emission), "xforms": []}
	_mm[key].xforms.append(t)


func _flush() -> void:
	for key: String in _mm:
		var e: Dictionary = _mm[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = e.mesh
		mm.instance_count = e.xforms.size()
		for i in e.xforms.size():
			mm.set_instance_transform(i, e.xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_" + key
		mmi.multimesh = mm
		mmi.material_override = e.mat
		if key.begins_with("win") or key.begins_with("dash"):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)


var _unit_box := BoxMesh.new()
var _quad := QuadMesh.new()


func _tile(key: String, color: Color, pos: Vector3, size: Vector3, yaw := 0.0, emission := 0.0) -> void:
	_add(key, _unit_box, color, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), pos), emission)


# --- Ground ----------------------------------------------------------------------------

func _ground() -> void:
	for b: Vector2i in blocks:
		var c := block_center(b)
		# Asphalt tile covering this block plus half of each surrounding street.
		_tile("asphalt", Color(0.27, 0.28, 0.3), c + Vector3(0, 0.02, 0), Vector3(PITCH + 0.2, 0.04, PITCH + 0.2))
		_tile("sidewalk", Color(0.62, 0.6, 0.56), c + Vector3(0, 0.05, 0), Vector3(LOT + 4.0, 0.03, LOT + 4.0))
		# Centre-line dashes on the street to the east and south of this block.
		for k in 8:
			var o := -PITCH * 0.5 + 4.0 + k * 8.0
			_tile("dash", Color(0.95, 0.82, 0.3), c + Vector3(PITCH * 0.5, 0.045, o), Vector3(0.25, 0.01, 3.5))
			_tile("dash", Color(0.95, 0.82, 0.3), c + Vector3(o, 0.045, PITCH * 0.5), Vector3(3.5, 0.01, 0.25))
		# Zebra crossing at the corner
		for k in 5:
			_tile("zebra", Color(0.92, 0.92, 0.9), c + Vector3(PITCH * 0.5 - 6.0 + k * 1.6 - 3.2, 0.046, PITCH * 0.5 - 9.5), Vector3(0.8, 0.01, 3.0))


# --- Buildings --------------------------------------------------------------------------

func _buildings(b: Vector2i) -> void:
	var c := block_center(b)
	var pocket := StreetPockets.kind(b, _district(c))
	if pocket >= 0:
		StreetPockets.build(self,b,pocket)
		return
	var dist := Vector2(c.x - _downtown.x, c.z - _downtown.z).length()
	if dist < 230.0 and rng.randf() < 0.85:
		_skyscraper(c, lerpf(120.0, 48.0, dist / 230.0) * rng.randf_range(0.75, 1.15))
		return
	if rng.randf() < 0.35:
		# Two buildings with an alley between them.
		var along_x := rng.randf() < 0.5
		var w := (LOT - 6.0) * 0.5
		for side: float in [-1.0, 1.0]:
			var off := Vector3(side * (w * 0.5 + 3.0), 0, 0) if along_x else Vector3(0, 0, side * (w * 0.5 + 3.0))
			var size := Vector3(w, 0, LOT) if along_x else Vector3(LOT, 0, w)
			_midrise(c + off, size, rng.randf_range(10.0, 26.0))
		var alley := c + Vector3(0, 0.06, 0)
		_tile("alley", Color(0.33, 0.31, 0.3), alley, Vector3(6.0 if along_x else LOT, 0.02, LOT if along_x else 6.0))
		ow.markers.items.append(alley + Vector3(0, 0.1, 0))
		_dumpster(alley + (Vector3(1.4, 0, 8) if along_x else Vector3(8, 0, 1.4)))
		# Bollards at both ends: on foot only.
		var run := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
		var across := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		for end: float in [-1.0, 1.0]:
			for side: float in [-1.0, 1.0]:
				_barrier(c + run * end * (LOT * 0.5 - 0.5) + across * side * 2.05, across, 2.3)
		return
	_midrise(c, Vector3(LOT, 0, LOT), rng.randf_range(12.0, 34.0))


func _skyscraper(c: Vector3, h: float) -> void:
	var ci := rng.randi() % FACADES.size()
	var col: Color = FACADES[ci]
	var base := LOT - 2.0
	_mass(ci, Vector3(base, h, base), c + Vector3.UP * h * 0.5, true)
	_windows(c, Vector3(base, h, base), 4.0, 4.0, 4.0, true)
	var top := c + Vector3.UP * h
	# Setback tiers and a crown
	var tier := base
	for t in rng.randi_range(1, 2):
		tier *= rng.randf_range(0.6, 0.78)
		var th := rng.randf_range(8.0, 22.0)
		_mass(ci, Vector3(tier, th, tier), top + Vector3.UP * th * 0.5, false)
		_windows(top, Vector3(tier, th, tier), 4.0, 4.0, 0.0, true)
		top += Vector3.UP * th
	_tile("crown", col.darkened(0.25), top + Vector3.UP * 0.6, Vector3(tier + 1.0, 1.2, tier + 1.0))
	if rng.randf() < 0.6:
		_tile("antenna", Color(0.75, 0.75, 0.78), top + Vector3.UP * 7.0, Vector3(0.5, 14.0, 0.5))
		_tile("beacon", Color(1.0, 0.2, 0.15), top + Vector3.UP * 14.3, Vector3(0.9, 0.9, 0.9), 0.0, 3.0)
	# Lobby: a dark glass band at street level
	_tile("lobby", Color(0.15, 0.2, 0.26), c + Vector3.UP * 2.25, Vector3(base + 0.2, 4.5, base + 0.2))


func _midrise(c: Vector3, size: Vector3, h: float) -> void:
	var ci := rng.randi() % FACADES.size()
	if _district(c) == "industrial":
		ci = [3, 6, 2][rng.randi() % 3]
		h = minf(h, 14.0)
	_mass(ci, Vector3(size.x, h, size.z), c + Vector3.UP * h * 0.5, true)
	_windows(c, Vector3(size.x, h, size.z), 5.0, 3.6, 4.5, false)
	_tile("parapet", Color(0.4, 0.38, 0.36), c + Vector3.UP * (h + 0.4), Vector3(size.x + 0.8, 0.8, size.z + 0.8))
	# Rooftop clutter
	for k in rng.randi_range(1, 3):
		_tile("roofbox", Color(0.6, 0.62, 0.64), c + Vector3(rng.randf_range(-size.x, size.x) * 0.3, h + 0.8, rng.randf_range(-size.z, size.z) * 0.3), Vector3(2.5, 1.6, 2.0))
	if rng.randf() < 0.3:
		var wt := c + Vector3(size.x * 0.2, h, -size.z * 0.2)
		_tile("watertank", Color(0.55, 0.4, 0.28), wt + Vector3.UP * 4.5, Vector3(3.6, 3.5, 3.6))
		for leg: Vector3 in [Vector3(1.4, 0, 1.4), Vector3(-1.4, 0, 1.4), Vector3(1.4, 0, -1.4), Vector3(-1.4, 0, -1.4)]:
			_tile("tankleg", Color(0.3, 0.3, 0.3), wt + leg + Vector3.UP * 1.4, Vector3(0.2, 2.8, 0.2))
	if _district(c) == "industrial":
		return  # warehouses: no shopfronts
	# Shopfront with awning and sign on one street-facing side
	var face: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][rng.randi() % 4]
	var half := (size.z if face.z != 0 else size.x) * 0.5
	var width := (size.x if face.z != 0 else size.z) * 0.8
	var front := c + face * (half + 0.05)
	var yaw := atan2(face.x, face.z)
	var awning: Color = [Color(0.85, 0.25, 0.2), Color(0.2, 0.55, 0.45), Color(0.95, 0.75, 0.2), Color(0.25, 0.4, 0.7)][rng.randi() % 4]
	_tile("shopglass", Color(0.2, 0.35, 0.45), front + Vector3.UP * 1.7, Vector3(width, 3.0, 0.2), yaw)
	_tile("awning", awning, front + face * 1.0 + Vector3.UP * 3.6, Vector3(width, 0.25, 2.2), yaw)
	var sign := Build.label(root, SHOPS[rng.randi() % SHOPS.size()], front + face * 0.15 + Vector3.UP * 4.6, 160, Color(1, 0.96, 0.85))
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.rotation.y = yaw
	sign.outline_size = 24
	sign.visibility_range_end = 160.0


## Windows on all four faces of a box, batched into one draw per window colour.
func _windows(c: Vector3, size: Vector3, spacing: float, floor_h: float, start: float, tower: bool) -> void:
	var y := start + 2.0
	var lit_chance := 0.22 if tower else 0.15
	while y < size.y - 1.5:
		for f: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			var half := (size.z if f.z != 0 else size.x) * 0.5
			var width := size.x if f.z != 0 else size.z
			var along := Vector3(f.z, 0, f.x).abs()
			var n := int(width / spacing)
			for k in n:
				var off := -width * 0.5 + (k + 0.5) * width / n
				var p := c + f * (half + 0.06) + along * off + Vector3.UP * y
				var basis := Basis(Vector3.UP, atan2(f.x, f.z)) * Basis.from_scale(Vector3(spacing * (0.75 if tower else 0.5), floor_h * 0.6, 1))
				var key := "win_lit" if rng.randf() < lit_chance else ("win_tower" if tower else "win")
				var col := Color(1.0, 0.9, 0.6) if key == "win_lit" else (Color(0.42, 0.62, 0.72) if tower else Color(0.24, 0.32, 0.4))
				_add(key, _quad, col, Transform3D(basis, p), 1.2 if key == "win_lit" else 0.0)
		y += floor_h


func _dumpster(p: Vector3) -> void:
	Build.solid_box(root, Vector3(1.9, 1.3, 1.0), Color(0.2, 0.45, 0.3), p + Vector3.UP * 0.65)


func _sign(text: String, pos: Vector3, yaw: float, size := 220, color := Color(1, 0.95, 0.8)) -> Label3D:
	var l := Build.label(root, text, pos, size, color)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = yaw
	l.outline_size = 28
	return l


func _npc(id: String, pos: Vector3, yaw: float) -> void:
	ow.markers.npcs.append({"id": id, "pos": pos, "yaw": yaw})


# --- Landmarks --------------------------------------------------------------------------

func _petrol(b: Vector2i) -> void:
	var c := block_center(b)
	_tile("forecourt", Color(0.5, 0.5, 0.52), c + Vector3(0, 0.07, 0), Vector3(LOT, 0.02, LOT))
	# Kiosk at the back (west), canopy over the pumps
	var kiosk := c + Vector3(-15, 0, 0)
	ow._solid(Vector3(12, 4.5, 18), Color(0.95, 0.95, 0.92), kiosk + Vector3.UP * 2.25)
	Build.box(root, Vector3(12.4, 1.0, 18.4), Color(0.9, 0.2, 0.15), kiosk + Vector3.UP * 4.9)
	_tile("shopglass", Color(0.25, 0.45, 0.55), kiosk + Vector3(6.05, 1.6, 0), Vector3(0.2, 2.6, 12), 0.0)
	_sign("BAREA FUEL", kiosk + Vector3(6.3, 4.9, 0), PI * 0.5, 200)
	for x: float in [2.0, 14.0]:
		for z: float in [-8.0, 8.0]:
			Build.solid_box(root, Vector3(0.6, 6.0, 0.6), Color(0.85, 0.85, 0.85), c + Vector3(x, 3.0, z))
	Build.box(root, Vector3(16, 1.0, 22), Color(0.95, 0.95, 0.95), c + Vector3(8, 6.5, 0))
	Build.box(root, Vector3(16.2, 0.4, 22.2), Color(0.9, 0.2, 0.15), c + Vector3(8, 6.1, 0))
	for z: float in [-4.0, 4.0]:
		for x: float in [5.0, 11.0]:
			Build.solid_box(root, Vector3(0.9, 1.8, 0.6), Color(0.9, 0.3, 0.2), c + Vector3(x, 0.9, z))
			Build.box(root, Vector3(0.7, 0.5, 0.62), Color(0.15, 0.15, 0.15), c + Vector3(x, 1.4, z))
	# Price board on a pole
	Build.solid_box(root, Vector3(0.4, 8.0, 0.4), Color(0.7, 0.7, 0.7), c + Vector3(21, 4.0, -20))
	Build.box(root, Vector3(0.3, 3.0, 4.0), Color(0.95, 0.95, 0.95), c + Vector3(21, 8.5, -20))
	_sign("1.89", c + Vector3(21.2, 8.6, -20), PI * 0.5, 200, Color(0.9, 0.2, 0.1))
	ow.markers.caches.append({"pos": kiosk + Vector3(7.2, 0.9, 3), "items": ["pills", "molotov", "pipe_bomb"], "dir": Vector3(0, 0, 1)})
	Build.box(root, Vector3(1.0, 0.85, 3.0), Color(0.45, 0.32, 0.2), kiosk + Vector3(7.2, 0.42, 3))
	if not ow.markers.npcs.any(func(n): return n.id == "dev"):
		_npc("dev", kiosk + Vector3(8.0, 0.0, -2.0), PI * 0.5)


func _store(b: Vector2i) -> void:
	var c := block_center(b)
	_tile("forecourt", Color(0.4, 0.4, 0.42), c + Vector3(0, 0.07, 0), Vector3(LOT, 0.02, LOT))
	var shop := c + Vector3(-12, 0, 0)
	ow._solid(Vector3(22, 5.5, 34), Color(0.95, 0.9, 0.78), shop + Vector3.UP * 2.75)
	_tile("shopglass", Color(0.25, 0.45, 0.55), shop + Vector3(11.05, 1.8, 0), Vector3(0.2, 3.0, 24), 0.0)
	Build.box(root, Vector3(1.2, 1.6, 30), Color(0.2, 0.5, 0.3), shop + Vector3(11.6, 6.0, 0))
	_sign("BAREA MART 24/7", shop + Vector3(12.3, 6.0, 0), PI * 0.5, 220)
	# Car park out front, the odd alarmed car
	for k in 4:
		var p := c + Vector3(10, 0, -15 + k * 10)
		_parked(p, 0.0, rng.randf() < 0.4)
	ow.markers.items.append(shop + Vector3(13, 0.1, -6))
	ow.markers.items.append(shop + Vector3(13, 0.1, 6))


func _police(b: Vector2i) -> void:
	var c := block_center(b)
	_tile("forecourt", Color(0.45, 0.45, 0.47), c + Vector3(0, 0.07, 0), Vector3(LOT, 0.02, LOT))
	var hq := c + Vector3(-10, 0, 0)
	ow._solid(Vector3(26, 14, 40), Color(0.92, 0.93, 0.95), hq + Vector3.UP * 7.0)
	Build.box(root, Vector3(26.4, 2.0, 40.4), Color(0.15, 0.3, 0.65), hq + Vector3.UP * 5.0)
	_windows(hq, Vector3(26, 14, 40), 5.0, 4.0, 4.5, false)
	_sign("BAREA POLICE", hq + Vector3(13.3, 11.0, 0), PI * 0.5, 260, Color(0.2, 0.35, 0.75))
	# Blue lamps by the door, sandbags and parked squad cars
	for z: float in [-3.0, 3.0]:
		Build.sphere(root, 0.4, Color(0.3, 0.5, 1.0), hq + Vector3(13.3, 3.2, z)).material_override = Build.mat(Color(0.3, 0.5, 1.0), 0.4, 3.0)
	for k in 6:
		Build.solid_box(root, Vector3(1.2, 0.9, 3.0), Color(0.62, 0.55, 0.38), c + Vector3(8, 0.45, -9 + k * 3.6))
	for z: float in [-17.0, 15.0]:
		_parked(c + Vector3(16, 0, z), 0.0, false, true)
	_npc("okafor", hq + Vector3(15.0, 0.0, 2.0), PI * 0.5)
	_lockup(hq)
	var mg := MapGen.new()
	mg.root = root
	mg.markers = ow.markers
	mg._ammo_pile(hq + Vector3(15.5, 0.0, -6.0))
	ow.markers.caches.append({"pos": hq + Vector3(15.5, 0.9, 6.0), "items": ["rifle", "auto_shotgun", "pills"], "dir": Vector3(0, 0, 1)})
	Build.box(root, Vector3(1.0, 0.85, 2.6), Color(0.45, 0.32, 0.2), hq + Vector3(15.5, 0.42, 6.0))


func _fire(b: Vector2i) -> void:
	var c := block_center(b)
	_tile("forecourt", Color(0.45, 0.45, 0.47), c + Vector3(0, 0.07, 0), Vector3(LOT, 0.02, LOT))
	var st := c + Vector3(-10, 0, 0)
	ow._solid(Vector3(26, 11, 36), Color(0.78, 0.2, 0.15), st + Vector3.UP * 5.5)
	Build.box(root, Vector3(26.4, 1.0, 36.4), Color(0.95, 0.92, 0.85), st + Vector3.UP * 11.3)
	for z: float in [-11.0, 0.0, 11.0]:
		_tile("garage", Color(0.85, 0.85, 0.82), st + Vector3(13.05, 2.8, z), Vector3(0.2, 5.0, 8.5), 0.0)
	_sign("FIRE STATION 7", st + Vector3(13.3, 8.5, 0), PI * 0.5, 240)
	# Fire engine parked out front
	var truck := c + Vector3(10, 0, -11)
	Build.solid_box(root, Vector3(2.6, 2.8, 9.0), Color(0.85, 0.15, 0.1), truck + Vector3.UP * 1.6)
	Build.box(root, Vector3(2.65, 0.6, 2.4), Color(0.2, 0.3, 0.4), truck + Vector3(0, 2.3, 3.4))
	Build.box(root, Vector3(0.8, 0.3, 8.0), Color(0.85, 0.85, 0.85), truck + Vector3(0, 3.15, -0.5))
	for z: float in [-3.2, 0.0, 3.0]:
		for x: float in [-1.2, 1.2]:
			Build.cyl(root, 0.55, 0.55, 0.4, Color(0.08, 0.08, 0.08), truck + Vector3(x, 0.55, z), Vector3(0, 0, 90))
	_npc("bex", st + Vector3(15.0, 0.0, 6.0), PI * 0.5)
	ow.markers.caches.append({"pos": st + Vector3(15.5, 0.9, -1.0), "items": ["medkit", "medkit", "molotov", "axe"], "dir": Vector3(0, 0, 1)})
	Build.box(root, Vector3(1.0, 0.85, 3.0), Color(0.45, 0.32, 0.2), st + Vector3(15.5, 0.42, -1.0))


func _plaza(b: Vector2i) -> void:
	var c := block_center(b)
	_tile("plaza", Color(0.82, 0.76, 0.64), c + Vector3(0, 0.07, 0), Vector3(LOT, 0.02, LOT))
	Build.solid_cyl(root, 6.0, 0.9, Color(0.75, 0.72, 0.68), c + Vector3.UP * 0.45, 24)
	Build.cyl(root, 5.3, 5.3, 0.05, Color(0.3, 0.6, 0.75), c + Vector3.UP * 0.92, Vector3.ZERO, 24)
	# Statue: a golden shopping trolley, naturally
	var s := c + Vector3.UP * 0.9
	Build.box(root, Vector3(1.6, 2.0, 1.6), Color(0.6, 0.58, 0.55), s + Vector3.UP * 1.0)
	var gold := Color(0.95, 0.75, 0.25)
	Build.box(root, Vector3(1.6, 0.9, 1.0), gold, s + Vector3(0, 2.7, 0))
	Build.box(root, Vector3(0.1, 0.6, 1.0), gold, s + Vector3(0.85, 3.2, 0), Vector3(0, 0, -25))
	for x: float in [-0.6, 0.6]:
		for z: float in [-0.4, 0.4]:
			Build.sphere(root, 0.15, Color(0.2, 0.2, 0.2), s + Vector3(x, 2.15, z))
	for k in 8:
		var a := k * TAU / 8.0
		StreetArt.tree(root, c + Vector3(cos(a) * 18.0, 0, sin(a) * 18.0), 2.2)
		Build.solid_cyl(root, 0.4, 3.0, Color(0.35, 0.25, 0.16), c + Vector3(cos(a) * 18.0, 1.5, sin(a) * 18.0), 8)
		var bp := c + Vector3(cos(a + 0.4) * 11.0, 0, sin(a + 0.4) * 11.0)
		var bench := Build.solid_box(root, Vector3(2.0, 0.5, 0.6), Color(0.5, 0.32, 0.18), bp + Vector3.UP * 0.25)
		bench.rotation.y = -(a + 0.4)
	_npc("reg", c + Vector3(7.5, 0.0, 2.0), PI * 0.5)
	ow.markers.items.append(c + Vector3(-9, 0.1, -9))


## The Price Slasher Megamart: a proper indoor store. Doors on the east (street) side, aisles of
## shelving, checkouts, a "reduced to clear" stand with the discounted rifle, and the idol's
## shrine at the very back under the strip lights.
func _megamart(b: Vector2i) -> void:
	var c := block_center(b)
	_tile("forecourt", Color(0.38, 0.38, 0.4), c + Vector3(0, 0.07, 0), Vector3(LOT, 0.02, LOT))
	var col := Color(0.97, 0.88, 0.25)
	var w := 44.0      # footprint
	var h := 8.0       # wall height
	var t := 0.6       # wall thickness
	var door := 8.0
	var hw := w * 0.5
	# Walls: west, north, south solid; east split around the doors with glass shopfronts.
	_wall(Vector3(t, h, w), col, c + Vector3(-hw, h * 0.5, 0))
	_wall(Vector3(w, h, t), col, c + Vector3(0, h * 0.5, -hw))
	_wall(Vector3(w, h, t), col, c + Vector3(0, h * 0.5, hw))
	var side := (w - door) * 0.5
	for sgn: float in [-1.0, 1.0]:
		var z := sgn * (door * 0.5 + side * 0.5)
		_wall(Vector3(t, h, side), col, c + Vector3(hw, h * 0.5, z))
		_tile("shopglass", Color(0.25, 0.45, 0.55), c + Vector3(hw + 0.32, 2.2, z), Vector3(0.1, 3.6, side - 2.0))
	Build.box(root, Vector3(t + 0.2, h - 3.6, door), col, c + Vector3(hw, 3.6 + (h - 3.6) * 0.5, 0))
	# Roller shutter over the doors: down until the grid's back on.
	var shutter := StaticBody3D.new()
	shutter.name = "MegamartShutter"
	shutter.position = c + Vector3(hw + 0.5, 1.8, 0)
	shutter.collision_layer = 1
	root.add_child(shutter)
	var scs := CollisionShape3D.new()
	var sbs := BoxShape3D.new()
	sbs.size = Vector3(0.3, 3.6, door)
	scs.shape = sbs
	shutter.add_child(scs)
	Build.box(shutter, Vector3(0.3, 3.6, door), Color(0.6, 0.62, 0.64))
	for k in 9:
		Build.box(shutter, Vector3(0.34, 0.06, door), Color(0.45, 0.47, 0.5), Vector3(0, -1.6 + k * 0.4, 0))
	Build.label(shutter, "CLOSED - NO POWER", Vector3(0.25, 0.3, 0), 90, Color(0.85, 0.12, 0.1)).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	shutter.get_child(shutter.get_child_count() - 1).rotation.y = PI * 0.5
	ow.markers["shutter"] = {"node": shutter, "rect": _door_cells(shutter.position, Vector3(3.0, 3.6, door))}
	# Roof, with a red trim band and the sign over the doors.
	Build.solid_box(root, Vector3(w + 1.0, 0.6, w + 1.0), Color(0.55, 0.52, 0.48), c + Vector3(0, h + 0.3, 0))
	for sgn: float in [-1.0, 1.0]:
		Build.box(root, Vector3(w + 1.2, 1.4, 0.4), Color(0.85, 0.15, 0.12), c + Vector3(0, h - 0.3, sgn * (hw + 0.4)))
		Build.box(root, Vector3(0.4, 1.4, w + 1.2), Color(0.85, 0.15, 0.12), c + Vector3(sgn * (hw + 0.4), h - 0.3, 0))
	Build.box(root, Vector3(w - t, 0.1, w - t), Color(0.78, 0.78, 0.76), c + Vector3(0, h - 0.05, 0))
	_sign("PRICE SLASHER MEGAMART", c + Vector3(hw + 0.7, 6.0, 0), PI * 0.5, 280, Color(0.85, 0.12, 0.1))
	_sign("ENTRANCE", c + Vector3(hw + 0.5, 4.1, 0), PI * 0.5, 120, Color(1, 1, 1))
	# A giant Yellow Sticker billboard on the roof: you can see it across the city.
	var board := YellowSticker.make(16.0, 0.6)
	board.position = c + Vector3(-6, h + 13.0, 0)
	board.rotation.y = PI * 0.5
	root.add_child(board)
	for z: float in [-4.0, 4.0]:
		Build.box(root, Vector3(0.6, 9.0, 0.6), Color(0.4, 0.4, 0.42), c + Vector3(-6, h + 4.5, z))
	# Inside: tiled floor, strip lights, warm lamps.
	_tile("store_floor", Color(0.86, 0.85, 0.8), c + Vector3(0, 0.09, 0), Vector3(w - t, 0.02, w - t))
	for x: float in [-14.0, -4.0, 6.0, 16.0]:
		for z: float in [-14.0, 0.0, 14.0]:
			_tile("strip", Color(1.0, 0.98, 0.9), c + Vector3(x, h - 0.15, z), Vector3(5.0, 0.1, 0.5), 0.0, 3.0)
	for p: Vector3 in [Vector3(-14, 6.5, -10), Vector3(-14, 6.5, 10), Vector3(6, 6.5, -10), Vector3(6, 6.5, 10)]:
		var l := OmniLight3D.new()
		l.position = c + p
		l.light_color = Color(1.0, 0.96, 0.85)
		l.light_energy = 1.6
		l.omni_range = 18.0
		l.shadow_enabled = false
		root.add_child(l)
	# Aisles of shelving either side of the main aisle that runs from the doors to the shrine.
	var products := [Color(0.9, 0.3, 0.25), Color(0.3, 0.6, 0.9), Color(0.95, 0.8, 0.25), Color(0.4, 0.75, 0.4), Color(0.95, 0.55, 0.2), Color(0.8, 0.4, 0.75)]
	for sgn: float in [-1.0, 1.0]:
		for row in 3:
			var z := sgn * (6.0 + row * 5.0)
			_shelf(c + Vector3(-1.0, 0, z), 18.0, products)
	# Checkouts by the doors.
	for k in 3:
		var co := c + Vector3(hw - 7.0, 0, -12.0 + k * 4.0 + (8.0 if k > 0 else 0.0))
		Build.solid_box(root, Vector3(3.0, 1.0, 1.0), Color(0.3, 0.3, 0.34), co + Vector3.UP * 0.5)
		Build.box(root, Vector3(0.6, 0.5, 0.4), Color(0.12, 0.12, 0.14), co + Vector3(0.8, 1.25, 0))
		_tile("lane_light", Color(1.0, 0.85, 0.2), co + Vector3(1.4, 2.2, 0), Vector3(0.3, 0.4, 0.3), 0.0, 2.5)
	# The "reduced to clear" stand with the discounted rifle on it.
	var stand := c + Vector3(hw - 8.0, 0, 9.0)
	Build.solid_box(root, Vector3(2.4, 0.95, 1.2), Color(0.95, 0.85, 0.2), stand + Vector3.UP * 0.475)
	_sign("REDUCED TO CLEAR", stand + Vector3(0, 3.4, 0), PI * 0.5, 50, Color(0.85, 0.1, 0.1))
	var tag := YellowSticker.make(0.9, 0.08)
	tag.position = stand + Vector3(0.0, 1.55, -0.4)
	tag.rotation.y = PI * 0.5
	root.add_child(tag)
	ow.markers["deal_gun"] = stand + Vector3(0, 1.0, 0.1)
	# The shrine at the back: a pedestal ringed by shopping trolleys like standing stones.
	var shrine := c + Vector3(-15.0, 0, 0)
	Build.solid_cyl(root, 1.4, 1.1, Color(0.85, 0.82, 0.75), shrine + Vector3.UP * 0.55, 16)
	Build.cyl(root, 1.6, 1.6, 0.15, Color(0.95, 0.75, 0.2), shrine + Vector3.UP * 1.12, Vector3.ZERO, 16)
	for k in 10:
		var a := k * TAU / 10.0
		_trolley(shrine + Vector3(cos(a) * 4.5, 0, sin(a) * 4.5), -a + PI * 0.5)
	for k in 16:
		var a := k * TAU / 16.0
		_tile("candle", Color(1.0, 0.8, 0.4), shrine + Vector3(cos(a) * 2.8, 0.25, sin(a) * 2.8), Vector3(0.15, 0.3, 0.15), 0.0, 3.0)
	ow.markers.idol = shrine + Vector3.UP * 2.6
	for k in 3:
		_parked(c + Vector3(hw + 4.0, 0, -14 + k * 14), 0.0, k == 1)


## Solid wall that also blocks the nav grid (tight margin, so the doorway stays open).
func _wall(size: Vector3, col: Color, pos: Vector3) -> void:
	Build.solid_box(root, size, col, pos)
	_block_nav(pos, size, 0.6)


func _block_nav(pos: Vector3, size: Vector3, margin: float) -> void:
	var a := ow.grid.cell_of(pos - size * 0.5 - Vector3(margin, 0, margin))
	var b := ow.grid.cell_of(pos + size * 0.5 + Vector3(margin, 0, margin))
	for z in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			ow.grid.set_cell(Vector2i(x, z), NavGrid.Cell.PROP)


func _shelf(p: Vector3, length: float, products: Array) -> void:
	Build.solid_box(root, Vector3(length, 2.4, 1.2), Color(0.8, 0.8, 0.82), p + Vector3.UP * 1.2)
	_block_nav(p, Vector3(length, 0, 1.2), 0.2)
	for level_y: float in [0.45, 1.25, 2.05]:
		var x := -length * 0.5 + 0.5
		while x < length * 0.5 - 0.4:
			var col: Color = products[rng.randi() % products.size()]
			var ph := rng.randf_range(0.35, 0.6)
			for sgn: float in [-1.0, 1.0]:
				_tile("product%d" % products.find(col), col, p + Vector3(x, level_y + ph * 0.5, sgn * 0.65), Vector3(0.6, ph, 0.12))
			x += rng.randf_range(0.7, 1.0)


func _trolley(p: Vector3, yaw: float) -> void:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = yaw
	root.add_child(t)
	var metal := Color(0.7, 0.72, 0.75)
	Build.box(t, Vector3(0.6, 0.55, 0.9), metal, Vector3(0, 0.75, 0))
	Build.box(t, Vector3(0.62, 0.05, 0.05), Color(0.85, 0.15, 0.1), Vector3(0, 1.15, -0.5))
	for x: float in [-0.25, 0.25]:
		for z: float in [-0.35, 0.35]:
			Build.box(t, Vector3(0.04, 0.45, 0.04), metal, Vector3(x, 0.25, z))


# --- Streets ------------------------------------------------------------------------------

## A parked car. Alarmed ones blink red and set the city off when shot or rammed.
func _parked(p: Vector3, yaw: float, alarm: bool, police := false) -> void:
	var body := StaticBody3D.new()
	body.position = p
	body.rotation.y = yaw + rng.randf_range(-0.08, 0.08)
	body.collision_layer = 1
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0, 1.5, 4.4)
	cs.shape = bs
	cs.position.y = 0.75
	body.add_child(cs)
	StreetArt.car(body, Color(0.95, 0.95, 0.97) if police else CAR_COLORS[rng.randi() % CAR_COLORS.size()])
	_fade(body, 260.0)
	if police:
		Build.box(body, Vector3(2.05, 0.35, 1.6), Color(0.1, 0.15, 0.4), Vector3(0, 0.95, 0))
		Build.box(body, Vector3(0.5, 0.15, 0.3), Color(1.0, 0.15, 0.1), Vector3(-0.3, 1.82, 0.1), Vector3.ZERO, 3.0)
		Build.box(body, Vector3(0.5, 0.15, 0.3), Color(0.2, 0.35, 1.0), Vector3(0.3, 1.82, 0.1), Vector3.ZERO, 3.0)
	if alarm:
		body.set_meta("alarm", ow.markers.alarm_cars.size())
		var lamp := Build.box(body, Vector3(0.3, 0.12, 0.3), Color(1.0, 0.15, 0.1), Vector3(0, 1.86, -0.6), Vector3.ZERO, 4.0)
		lamp.name = "AlarmLamp"
		ow.markers.alarm_cars.append(p)


func _street_life() -> void:
	# Cars parked along the kerbs of every street next to a block, streetlights at corners.
	for bb: Vector2i in blocks:
		var c := block_center(bb)
		for k in 5:
			if k == 2:
				continue  # mid-street is where a roadblock may go; never park in its gap
			var z := -PITCH * 0.5 + 10.0 + k * 10.0
			if rng.randf() < 0.32:
				_parked(c + Vector3(PITCH * 0.5 - 5.5, 0, z), 0.0, rng.randf() < 0.1)
			var x := -PITCH * 0.5 + 10.0 + k * 10.0
			if rng.randf() < 0.32:
				_parked(c + Vector3(x, 0, PITCH * 0.5 - 5.5), PI * 0.5, rng.randf() < 0.1)
		var corner := c + Vector3(LOT * 0.5 + 1.0, 0, LOT * 0.5 + 1.0)
		_tile("pole", Color(0.25, 0.27, 0.3), corner + Vector3.UP * 3.5, Vector3(0.2, 7.0, 0.2))
		_tile("lamp", Color(1.0, 0.95, 0.75), corner + Vector3(-0.9, 7.0, -0.9), Vector3(0.8, 0.25, 0.8), 0.0, 2.0)
		if rng.randf() < 0.3:
			# Traffic light
			var tl := c + Vector3(LOT * 0.5 + 1.0, 0, -LOT * 0.5 - 1.0)
			_tile("pole", Color(0.25, 0.27, 0.3), tl + Vector3.UP * 2.5, Vector3(0.18, 5.0, 0.18))
			_tile("tlight", Color(0.15, 0.15, 0.15), tl + Vector3.UP * 5.2, Vector3(0.45, 1.3, 0.45))
			_tile("tlight_red", Color(1.0, 0.2, 0.15), tl + Vector3(0.24, 5.6, 0), Vector3(0.05, 0.3, 0.3), 0.0, 3.0)


## Army roadblocks across ~40% of street segments. Each leaves a 1.6 m gap: too narrow for
## any car, wide enough to squeeze through on foot (and for the horde to funnel through).
func _roadblocks() -> void:
	var dock := OpenWorld.dock(index)
	for bb: Vector2i in blocks:
		var c := block_center(bb)
		# Street to the east of this block (runs north-south) and to the south (runs east-west).
		for dir in 2:
			var mid := c + (Vector3(PITCH * 0.5, 0, 0) if dir == 0 else Vector3(0, 0, PITCH * 0.5))
			var neighbour := bb + (Vector2i(1, 0) if dir == 0 else Vector2i(0, 1))
			if not blocks.has(neighbour) and rng.randf() < 0.5:
				continue
			# Keep the first stretch of the main avenue from the harbour open so you can drive in.
			var on_avenue := dir == 1 and absf(mid.z - center.z) < 1.0
			if absf(mid.z - center.z) < PITCH * 0.5 and dir == 0 and mid.x > dock.x - 260.0:
				continue
			if on_avenue and mid.x > dock.x - 260.0:
				continue
			if rng.randf() > 0.42:
				continue
			_roadblock(mid, dir == 1)


## along_z: the barrier runs along z (it closes an east-west street); otherwise along x.
func _roadblock(mid: Vector3, along_z: bool) -> void:
	var span := STREET + 2.0
	var gap_at := rng.randf_range(-span * 0.3, span * 0.3)
	var gap := 1.6
	var axis := Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
	ow.markers.roadblocks.append({"pos": mid, "axis": axis, "gap": mid + axis * gap_at})
	var pieces := [[-span * 0.5, gap_at - gap * 0.5], [gap_at + gap * 0.5, span * 0.5]]
	for seg: Array in pieces:
		var a: float = seg[0]
		var b: float = seg[1]
		var t := a
		while t < b - 0.3:
			var len := minf(2.6, b - t)
			var p := mid + axis * (t + len * 0.5)
			_barrier(p, axis, len)
			if len >= 2.0 and rng.randf() < 0.25:
				_wreck(p, axis)
			t += len
	# Sign and hazard stripes
	var sign_pos := mid + axis * (gap_at + gap * 0.5 + 1.3) + Vector3.UP * 1.5
	var s := Build.label(root, "ROAD CLOSED", sign_pos, 90, Color(1.0, 0.9, 0.2))
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.outline_size = 18


func _barrier(p: Vector3, axis: Vector3, len: float) -> void:
	var yaw := atan2(axis.x, axis.z)
	var body := StaticBody3D.new()
	body.position = p
	body.rotation.y = yaw
	body.collision_layer = 1
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 1.15, len - 0.05)
	cs.shape = bs
	cs.position.y = 0.575
	body.add_child(cs)
	_tile("jersey_base", Color(0.78, 0.77, 0.74), p + Vector3(0, 0.225, 0), Vector3(0.7, 0.45, len - 0.05), yaw)
	_tile("jersey_top", Color(0.8, 0.79, 0.76), p + Vector3(0, 0.8, 0), Vector3(0.36, 0.7, len - 0.05), yaw)
	_tile("jersey_stripe", Color(0.95, 0.75, 0.1), p + Vector3(0, 0.95, 0), Vector3(0.38, 0.14, len * 0.5), yaw)


func _wreck(p: Vector3, axis: Vector3) -> void:
	var t := Node3D.new()
	t.position = p
	t.rotation.y = atan2(axis.x, axis.z) + rng.randf_range(-0.3, 0.3)
	t.rotation.z = rng.randf_range(-0.15, 0.15)
	root.add_child(t)
	StreetArt.car(t, Color(0.35, 0.3, 0.28))
	_fade(t, 260.0)


## The harbour front: Captain Marla waits by the boats.
func _harbour_front() -> void:
	var dock := OpenWorld.dock(index)
	_npc("marla", dock + Vector3(-6.0, 0.0, 6.5), -PI * 0.5)
	_sign("BAREA CITY", OpenWorld.camp(index) + Vector3(-16, 9.0, -14), PI * 0.5, 400, Color(1.0, 0.85, 0.2))


# --- Scale helpers ---------------------------------------------------------------------------

var _terminal := Vector3.ZERO


## The old ferry terminal on the far (west) shore, where Marla waits once the city's on alert.
static func ferry_terminal(island_index: int) -> Vector3:
	var island: Dictionary = OpenWorld.ISLANDS[island_index]
	var p := Vector3(island.center.x, 0, island.center.y + 260.0)
	while OpenWorld.land_index(p, 6.0) == island_index:
		p.x -= 4.0
	return p + Vector3(36.0, 0, 0)


func _district(c: Vector3) -> String:
	var l := c - center
	if l.x < -150.0 and l.z < -250.0:
		return "industrial"
	if Vector2(c.x - _downtown.x, c.z - _downtown.z).length() < 340.0:
		return "downtown"
	return "residential"


## A building volume: drawn in one batched mesh per facade colour, with a collision-only body
## (and a nav block) when it touches the street. Keeps a city this size cheap to draw.
func _mass(ci: int, size: Vector3, pos: Vector3, collide: bool) -> void:
	_tile("bld%d" % ci, FACADES[ci], pos, size)
	if not collide:
		return
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	_block_nav(pos, size, 2.0)


## Small props pop out with distance so hundreds of parked cars don't cost a frame.
func _fade(node: Node, dist: float) -> void:
	for g in node.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = dist
		(g as GeometryInstance3D).visibility_range_end_margin = 15.0
		(g as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Cells a lockable gate/shutter covers: blocked for pathing until the story opens it.
func _door_cells(pos: Vector3, size: Vector3) -> Rect2i:
	var a := ow.grid.cell_of(pos - size * 0.5)
	var b := ow.grid.cell_of(pos + size * 0.5)
	var r := Rect2i(a, b - a + Vector2i.ONE)
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			ow.grid.set_cell(Vector2i(x, z), NavGrid.Cell.DOOR)
	return r


# --- Act 2: the police evidence lockup ------------------------------------------------------

func _lockup(hq: Vector3) -> void:
	var booth := hq + Vector3(17.0, 0, -14.0)
	Build.solid_box(root, Vector3(4.0, 3.2, 4.0), Color(0.3, 0.32, 0.38), booth + Vector3.UP * 1.6)
	Build.box(root, Vector3(4.2, 0.3, 4.2), Color(0.15, 0.3, 0.65), booth + Vector3.UP * 3.3)
	_sign("EVIDENCE LOCKUP", booth + Vector3(2.15, 2.6, 0), PI * 0.5, 70, Color(1, 1, 1))
	Build.box(root, Vector3(0.1, 1.0, 1.4), Color(0.2, 0.15, 0.1), booth + Vector3(2.06, 1.3, 0))
	for k in 5:
		Build.box(root, Vector3(0.08, 0.2, 0.1), Color(0.95, 0.8, 0.3), booth + Vector3(2.12, 1.2 + (k % 2) * 0.2, -0.5 + k * 0.25), Vector3.ZERO, 1.5)
	ow.markers["keys"] = booth + Vector3(2.6, 1.2, 0)


# --- Act 3: the substation -------------------------------------------------------------------

func _substation(b: Vector2i) -> void:
	var c := block_center(b)
	_tile("gravel", Color(0.5, 0.48, 0.44), c + Vector3(0, 0.07, 0), Vector3(LOT, 0.02, LOT))
	var hw := LOT * 0.5 - 1.0
	var fence := Color(0.55, 0.58, 0.6)
	var gate_w := 7.0
	# Chain-link fence (solid for collision) with a locked gate on the east side.
	for seg: Array in [[Vector3(0, 0, -hw), Vector3(LOT - 2.0, 3.0, 0.2)], [Vector3(0, 0, hw), Vector3(LOT - 2.0, 3.0, 0.2)], [Vector3(-hw, 0, 0), Vector3(0.2, 3.0, LOT - 2.0)]]:
		var p: Vector3 = c + seg[0] + Vector3.UP * 1.5
		Build.solid_box(root, seg[1], fence, p)
		_block_nav(p, seg[1], 0.5)
	var side := (LOT - 2.0 - gate_w) * 0.5
	for sgn: float in [-1.0, 1.0]:
		var p := c + Vector3(hw, 1.5, sgn * (gate_w * 0.5 + side * 0.5))
		Build.solid_box(root, Vector3(0.2, 3.0, side), fence, p)
		_block_nav(p, Vector3(0.2, 3.0, side), 0.5)
	var gate := StaticBody3D.new()
	gate.name = "SubstationGate"
	gate.position = c + Vector3(hw, 1.5, 0)
	gate.collision_layer = 1
	root.add_child(gate)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.3, 3.0, gate_w)
	cs.shape = bs
	gate.add_child(cs)
	Build.box(gate, Vector3(0.3, 3.0, gate_w), Color(0.85, 0.7, 0.15))
	Build.label(gate, "DANGER  HIGH VOLTAGE", Vector3(0.3, 0.6, 0), 60, Color(0.1, 0.1, 0.1)).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ow.markers["sub_gate"] = {"node": gate, "rect": _door_cells(gate.position, Vector3(4.0, 3.0, gate_w))}
	_sign("BAREA GRID - SUBSTATION 4", c + Vector3(hw + 0.4, 4.6, 0), PI * 0.5, 160, Color(1, 0.85, 0.2))
	# Transformers, pylons and the breaker panel.
	for k in 4:
		var t := c + Vector3(-12.0 + (k % 2) * 12.0, 0, -10.0 + (k / 2) * 18.0)
		Build.solid_box(root, Vector3(5.0, 4.0, 3.5), Color(0.45, 0.5, 0.45), t + Vector3.UP * 2.0)
		for f in 6:
			Build.box(root, Vector3(0.12, 3.6, 3.7), Color(0.35, 0.4, 0.35), t + Vector3(-2.2 + f * 0.9, 2.0, 0))
		Build.cyl(root, 0.25, 0.3, 1.6, Color(0.6, 0.35, 0.25), t + Vector3(0, 4.8, 0))
		_block_nav(t, Vector3(5.0, 4.0, 3.5), 0.5)
	for z: float in [-18.0, 18.0]:
		var py := c + Vector3(-16, 0, z)
		Build.solid_box(root, Vector3(0.6, 16.0, 0.6), Color(0.4, 0.4, 0.42), py + Vector3.UP * 8.0)
		Build.box(root, Vector3(6.0, 0.4, 0.4), Color(0.4, 0.4, 0.42), py + Vector3.UP * 15.0)
	var panel := c + Vector3(6.0, 0, 4.0)
	Build.solid_box(root, Vector3(1.0, 2.2, 2.4), Color(0.3, 0.32, 0.3), panel + Vector3.UP * 1.1)
	Build.box(root, Vector3(0.1, 0.5, 0.5), Color(0.9, 0.15, 0.1), panel + Vector3(0.55, 1.5, 0.5), Vector3.ZERO, 2.0)
	_sign("MAIN BREAKER", panel + Vector3(0.6, 2.5, 0), PI * 0.5, 70, Color(1, 1, 1))
	ow.markers["breaker"] = panel + Vector3(1.0, 1.2, 0)


# --- Act 5: the old ferry terminal --------------------------------------------------------------

func _ferry_front() -> void:
	var t := _terminal
	# Tarmac apron, a tired terminal shed and a long pier out to Marla's boat.
	_tile("apron", Color(0.38, 0.38, 0.4), t + Vector3(10, 0.05, 0), Vector3(90, 0.04, 70))
	Build.solid_box(root, Vector3(18, 7, 26), Color(0.62, 0.7, 0.72), t + Vector3(30, 3.5, -26))
	Build.box(root, Vector3(19, 1.0, 27), Color(0.25, 0.4, 0.5), t + Vector3(30, 7.5, -26))
	_sign("OLD FERRY TERMINAL", t + Vector3(20.8, 6.0, -26), -PI * 0.5, 220, Color(1, 0.95, 0.85))
	# Long enough to reach past the big island's shallow beach shelf into deep water.
	var pier_len := 90.0
	Build.solid_box(root, Vector3(pier_len, 0.4, 9.0), Color(0.5, 0.38, 0.26), t + Vector3(-pier_len * 0.5 + 6.0, -0.2, 0))
	for k in range(0, int(pier_len), 6):
		for z: float in [-4.2, 4.2]:
			Build.cyl(root, 0.25, 0.28, 3.0, Color(0.35, 0.28, 0.21), t + Vector3(6.0 - k, -1.2, z))
	_sign("FERRY  →", t + Vector3(0, 3.5, 4.8), PI, 120, Color(1, 0.85, 0.2))
	# Appended after the standard vehicles (see OpenWorld) so existing vehicle indices stay put.
	ow.markers["ferry_boat"] = {"type": "boat", "pos": t + Vector3(-pier_len + 2.0, -0.45, 9.0), "yaw": PI * 0.5, "ferry": true}
	_npc("marla_ferry", t + Vector3(-pier_len + 9.0, 0.0, 2.5), PI * 0.5)
