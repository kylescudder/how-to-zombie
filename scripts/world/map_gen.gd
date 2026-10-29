class_name MapGen
extends RefCounted
## Builds a chapter out of segments laid end to end along +Z: safe rooms, streets, alleys,
## warehouses and so on. Each segment carves walkable zones into a 1 m NavGrid and drops
## props on it; walls are then grown around everything walkable and merged into big boxes.
## The layout only depends on the chapter's fixed seed, so every peer builds the same map.

const GRID_W := 96
const LANE := 1  # keep |x - cx| <= LANE clear of props so there's always a way through

const SEG_LEN := {
	"saferoom_start": 9, "saferoom_end": 9, "street": 52, "street_alarm": 52, "alley": 36,
	"park": 40, "warehouse": 40, "warehouse_gate": 38, "yard": 40, "containers": 56, "docks_finale": 58,
}

const BRICK := [Color(0.62,0.39,0.27),Color(0.29,0.47,0.42),Color(0.73,0.57,0.36),Color(0.35,0.46,0.53),Color(0.64,0.42,0.32),Color(0.46,0.47,0.35)]
const CAR := [Color(0.6, 0.12, 0.1), Color(0.15, 0.25, 0.45), Color(0.75, 0.72, 0.65), Color(0.18, 0.18, 0.2), Color(0.25, 0.4, 0.3), Color(0.7, 0.55, 0.2)]
const CONTAINER := [Color(0.6, 0.2, 0.15), Color(0.15, 0.3, 0.55), Color(0.2, 0.45, 0.3), Color(0.75, 0.45, 0.15), Color(0.4, 0.4, 0.42)]

var root: Node3D
var grid: NavGrid
var rng := RandomNumberGenerator.new()
var zones: Array = []  # [{rect: Rect2i, wall_h, ceil_h, floor: Color, wall: Color, kind, windows}]
var markers := {
	"art_corner": Vector3.INF, "benches": [], "spawns": [], "doors": [], "items": [], "caches": [], "witch_spots": [], "alarm_cars": [],
	"path": [], "start_room": Rect2(), "end_room": Rect2(), "gate": {}, "button": Vector3.INF,
	"radio": Vector3.INF, "rescue_zone": Rect2(), "boat_dock": Vector3.INF, "end_z": 0.0, "lights": 0,
}
var cz := 2
var cx := GRID_W / 2
var chapter: Dictionary
var _win_dark: Array[Transform3D] = []
var _win_lit: Array[Transform3D] = []
var _extra_floors: Array[Rect2i] = []


static func build(parent: Node3D, chapter_idx: int) -> MapGen:
	var g := MapGen.new()
	g.root = parent
	g.chapter = DB.CHAPTERS[chapter_idx]
	g.rng.seed = int(g.chapter.seed)
	g._generate()
	return g


func _generate() -> void:
	var length := 4
	for s in chapter.segments:
		length += SEG_LEN[s]
	length += 20 if chapter.get("finale", false) else 2
	grid = NavGrid.new(GRID_W, length, Vector2(-GRID_W / 2.0, -2.0))
	for s in chapter.segments:
		markers.path.append(_w(cx, cz))
		call("_seg_" + s)
	markers.path.append(_w(cx, cz))
	markers.end_z = grid.origin.y + cz
	_build_floors()
	_build_walls()
	_build_windows()
	grid.build_astar()


# --- Helpers ---------------------------------------------------------------------

## World position of a cell corner (x, z) in grid units.
func _w(x: float, z: float, y := 0.0) -> Vector3:
	return Vector3(grid.origin.x + x, y, grid.origin.y + z)


func _zone(r: Rect2i, wall_h: float, ceil_h: float, floor_c: Color, wall_c: Color, kind: String, windows := false) -> int:
	r = r.intersection(Rect2i(1, 1, grid.w - 2, grid.h - 2))
	zones.append({"rect": r, "wall_h": wall_h, "ceil_h": ceil_h, "floor": floor_c, "wall": wall_c, "kind": kind, "windows": windows})
	var zi := zones.size()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if grid.cell_state(c) == NavGrid.Cell.VOID:
				grid.set_cell(c, NavGrid.Cell.WALK, zi)
	return zi


## Marks cells as blocked by a prop. Skips the guaranteed-clear lane unless forced.
func _block(x0: int, z0: int, sx: int, sz: int, force := false) -> bool:
	if not force and x0 <= cx + LANE and x0 + sx - 1 >= cx - LANE:
		return false
	for y in range(z0, z0 + sz):
		for x in range(x0, x0 + sx):
			if grid.cell_state(Vector2i(x, y)) != NavGrid.Cell.WALK:
				return false
	for y in range(z0, z0 + sz):
		for x in range(x0, x0 + sx):
			var c := Vector2i(x, y)
			grid.cells[grid.idx(c)] = NavGrid.Cell.PROP
			grid.walk[grid.idx(c)] = 0
	return true


func _unblock(x0: int, z0: int, sx: int, sz: int) -> void:
	for y in range(z0, z0 + sz):
		for x in range(x0, x0 + sx):
			var c := Vector2i(x, y)
			grid.cells[grid.idx(c)] = NavGrid.Cell.WALK
			grid.walk[grid.idx(c)] = 1


func _door_row(z: int, zone_i: int, width := 2) -> Rect2i:
	var r := Rect2i(cx - width / 2, z, width, 1)
	for x in range(r.position.x, r.end.x):
		grid.set_cell(Vector2i(x, z), NavGrid.Cell.DOOR)
		grid.zone[grid.idx(Vector2i(x, z))] = zone_i
	_extra_floors.append(r)
	return r


func _cx_clamp(v: int, half: int) -> int:
	return clampi(v, half + 3, GRID_W - half - 4)


func _light(pos: Vector3, color: Color, energy: float, rng_m: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.1
	l.shadow_enabled = false
	root.add_child(l)
	markers.lights += 1


func _street_lamp(pos: Vector3, facing: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = facing
	root.add_child(n)
	Build.cyl(n, 0.07, 0.1, 5.6, Color(0.2, 0.22, 0.24), Vector3(0, 2.8, 0))
	Build.box(n, Vector3(0.1, 0.1, 1.4), Color(0.2, 0.22, 0.24), Vector3(0, 5.5, 0.6))
	Build.box(n, Vector3(0.4, 0.12, 0.5), Color(1.0, 0.85, 0.6), Vector3(0, 5.4, 1.2), Vector3.ZERO, 3.0)
	_light(pos + Vector3(0, 5.0, 0) + Basis(Vector3.UP, facing) * Vector3(0, 0, 1.2), Color(1.0, 0.78, 0.5), 2.2, 14.0)


func _item_spot(x: float, z: float) -> void:
	markers.items.append(_w(x, z, 0.0))


func _car(x0: int, z0: int, along_z := true, alarm := false) -> bool:
	var sx := 2 if along_z else 5
	var sz := 5 if along_z else 2
	if not _block(x0, z0, sx, sz):
		return false
	var c: Color = CAR[rng.randi() % CAR.size()]
	var body := StaticBody3D.new()
	body.position = _w(x0 + sx * 0.5, z0 + sz * 0.5)
	body.rotation.y = 0.0 if along_z else PI * 0.5
	body.rotation.y += rng.randf_range(-0.08, 0.08)
	body.collision_layer = 1
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.5, 4.4)
	cs.shape = bs
	cs.position.y = 0.75
	body.add_child(cs)
	StreetArt.car(body,c)
	if alarm:
		body.set_meta("alarm", markers.alarm_cars.size())
		var lamp := Build.box(body, Vector3(0.3, 0.12, 0.3), Color(1.0, 0.15, 0.1), Vector3(0, 1.66, -0.2), Vector3.ZERO, 4.0)
		lamp.name = "AlarmLamp"
		markers.alarm_cars.append(body.position)
	return true


func _dumpster(x0: int, z0: int, force := false) -> void:
	if _block(x0, z0, 2, 1, force):
		var p := _w(x0 + 1.0, z0 + 0.5)
		Build.solid_box(root, Vector3(1.9, 1.3, 1.0), Color(0.15, 0.35, 0.2), p + Vector3(0, 0.65, 0))
		Build.box(root, Vector3(2.0, 0.08, 1.1), Color(0.1, 0.25, 0.14), p + Vector3(0, 1.35, 0), Vector3(8, 0, 0))


func _crates(x0: int, z0: int, sx: int, sz: int, h: float) -> void:
	if _block(x0, z0, sx, sz):
		var p := _w(x0 + sx * 0.5, z0 + sz * 0.5)
		Build.solid_box(root, Vector3(sx - 0.1, h, sz - 0.1), Color(0.5, 0.38, 0.22), p + Vector3(0, h * 0.5, 0))
		Build.box(root, Vector3(sx - 0.05, 0.08, sz - 0.05), Color(0.38, 0.28, 0.16), p + Vector3(0, h * 0.5, 0))


func _ammo_pile(pos: Vector3) -> void:
	Build.box(root, Vector3(0.9, 0.35, 0.6), Color(0.3, 0.35, 0.22), pos + Vector3(0, 0.18, 0))
	Build.box(root, Vector3(0.7, 0.3, 0.5), Color(0.35, 0.4, 0.25), pos + Vector3(0.1, 0.5, 0), Vector3(0, 20, 0))
	Build.label(root, "AMMO", pos + Vector3(0, 0.95, 0), 28, Color(1.0, 0.85, 0.4))
	Build.interact_zone(root, "ammo", Vector3(1.4, 1.2, 1.2), pos + Vector3(0, 0.5, 0), "Refill ammo")


# --- Segments --------------------------------------------------------------------

func _seg_saferoom_start() -> void:
	var zi := _saferoom_box(cz, true)
	var r: Rect2i = zones[zi - 1].rect
	markers.start_room = Rect2(_w(r.position.x, r.position.y).x, _w(0, r.position.y).z, r.size.x, r.size.y)
	for i in 4:
		markers.spawns.append(_w(cx - 2.5 + i * 1.7, cz + 2.5, 0.1))
	var cache: Array = chapter.start_weapons.duplicate()
	cache.append_array(["medkit", "medkit", "medkit", "medkit"])
	markers.caches.append({"pos": _w(cx - 3.2, cz + 4.0, 0.85), "dir": Vector3(0, 0, 1), "items": cache})
	_ammo_pile(_w(cx + 3.0, cz + 6.5))
	var d := _door_row(cz + 8, zi)
	markers.doors.append({"rect": d, "pos": _w(cx, cz + 8.5), "kind": "start"})
	cz += 9


func _seg_saferoom_end() -> void:
	var d := _door_row(cz, 0)
	var zi := _saferoom_box(cz + 1, false)
	for x in range(d.position.x, d.end.x):
		grid.zone[grid.idx(Vector2i(x, cz))] = zi
	var r: Rect2i = zones[zi - 1].rect
	markers.end_room = Rect2(_w(r.position.x, 0).x, _w(0, r.position.y).z, r.size.x, r.size.y)
	markers.doors.append({"rect": d, "pos": _w(cx, cz + 0.5), "kind": "end"})
	var cache: Array = ["medkit", "medkit", "medkit", "medkit"]
	var nxt := DB.CHAPTERS.find(chapter) + 1
	if nxt < DB.CHAPTERS.size():
		cache.append_array(DB.CHAPTERS[nxt].start_weapons.slice(0, 2))
	markers.caches.append({"pos": _w(cx - 3.2, cz + 5.0, 0.85), "dir": Vector3(0, 0, 1), "items": cache})
	_ammo_pile(_w(cx + 3.0, cz + 6.5))
	cz += 9


func _saferoom_box(z0: int, _start: bool) -> int:
	var wall := Color(0.38, 0.42, 0.36)
	var zi := _zone(Rect2i(cx - 4, z0, 8, 8), 3.6, 3.2, Color(0.3, 0.28, 0.26), wall, "saferoom")
	var base := _w(cx, z0)
	# Table with the supplies, bunks, sign, warm light.
	Build.box(root, Vector3(1.0, 0.08, 4.0), Color(0.45, 0.32, 0.2), base + Vector3(-3.2, 0.8, 4.0))
	for lz: float in [2.3, 5.7]:
		Build.box(root, Vector3(0.08, 0.8, 0.08), Color(0.3, 0.2, 0.12), base + Vector3(-3.2, 0.4, lz))
	_block(cx - 4, z0 + 2, 1, 4, true)
	Build.box(root, Vector3(1.0, 0.5, 2.0), Color(0.25, 0.3, 0.25), base + Vector3(3.3, 0.35, 2.0))
	Build.box(root, Vector3(1.0, 0.15, 2.0), Color(0.75, 0.75, 0.7), base + Vector3(3.3, 0.65, 2.0))
	_block(cx + 3, z0 + 1, 1, 2, true)
	var sign := Build.label(root, "SAFE ROOM", base + Vector3(0, 2.6, 0.1), 40, Color(0.9, 0.2, 0.15))
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.rotation.y = PI
	var sign2 := Build.label(root, "SAFE ROOM", base + Vector3(0, 2.6, 7.9), 40, Color(0.9, 0.2, 0.15))
	sign2.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_light(base + Vector3(0, 2.7, 4.0), Color(1.0, 0.8, 0.55), 1.6, 9.0)
	Build.box(root, Vector3(0.5, 0.06, 0.5), Color(1.0, 0.85, 0.6), base + Vector3(0, 3.18, 4.0), Vector3.ZERO, 3.0)
	_gunsmith(base + Vector3(3.2, 0, 4.6))
	_block(cx + 3, z0 + 4, 1, 2, true)
	return zi


func _seg_street() -> void:
	_street(false)


func _seg_street_alarm() -> void:
	_street(true)


func _street(alarm: bool) -> void:
	cx = _cx_clamp(cx, 10)
	var len: int = SEG_LEN.street
	var z0 := cz
	_zone(Rect2i(cx - 10, z0, 20, len), 11.0, 0.0, Color(0.24,0.26,0.27), BRICK[rng.randi() % BRICK.size()], "street", true)
	var mid := _w(cx, z0)
	# Sidewalks, centre line
	for side: float in [-1, 1]:
		Build.box(root, Vector3(3.0, 0.03, len), Color(0.57,0.53,0.42), mid + Vector3(side * 8.5, 0.015, len * 0.5))
		Build.box(root, Vector3(0.2, 0.05, len), Color(0.45, 0.44, 0.42), mid + Vector3(side * 7.0, 0.02, len * 0.5))
	for i in range(0, len, 6):
		Build.box(root, Vector3(0.15, 0.03, 2.5), Color(0.75, 0.6, 0.15), mid + Vector3(0, 0.02, i + 1.5))
	# Lamps
	for i in range(4, len, 14):
		var side := -1 if (i / 14) % 2 == 0 else 1
		_street_lamp(mid + Vector3(side * 8.8, 0, i), -side * PI * 0.5)
	# Parked cars along the kerbs, wrecks in the road.
	var alarm_placed := false
	for side: float in [-1, 1]:
		var z := z0 + rng.randi_range(2, 6)
		while z < z0 + len - 6:
			if rng.randf() < 0.55:
				var make_alarm := alarm and not alarm_placed and z > z0 + 15 and side == 1
				if _car(cx + (5 if side > 0 else -7), z, true, make_alarm) and make_alarm:
					alarm_placed = true
			z += rng.randi_range(7, 11)
	for i in rng.randi_range(1, 2):
		var x := cx + (rng.randi_range(2, 4) if rng.randf() < 0.5 else -rng.randi_range(6, 8))
		_car(x, z0 + rng.randi_range(8, len - 12), rng.randf() < 0.5)
	for i in 2:
		_dumpster(cx + (8 if i == 0 else -10), z0 + rng.randi_range(4, len - 6))
	for i in 3:
		_item_spot(cx + (8.5 if rng.randf() < 0.5 else -8.5), z0 + rng.randi_range(6, len - 4))
	if markers.art_corner == Vector3.INF:
		markers.art_corner = mid + Vector3(9.9,0,30)
		StreetArt.corner(root,markers.art_corner,-PI*0.5)
		_block(cx+9,z0+26,1,8,true)
	markers.witch_spots.append(_w(cx - 8.5, z0 + len * 0.5))
	cz += len


func _seg_alley() -> void:
	var len: int = SEG_LEN.alley
	var z0 := cz
	var wall: Color = BRICK[rng.randi() % BRICK.size()].darkened(0.15)
	var floor_c := Color(0.2, 0.19, 0.18)
	_zone(Rect2i(cx - 2, z0, 5, 16), 9.0, 0.0, floor_c, wall, "alley", true)
	var shift := rng.randi_range(8, 14) * (1 if rng.randf() < 0.5 else -1)
	var cx2 := _cx_clamp(cx + shift, 12)
	var lo := mini(cx, cx2) - 2
	var hi := maxi(cx, cx2) + 3
	_zone(Rect2i(lo, z0 + 13, hi - lo, 5), 9.0, 0.0, floor_c, wall, "alley", true)
	var old_cx := cx
	cx = cx2
	_zone(Rect2i(cx - 2, z0 + 15, 5, len - 15), 9.0, 0.0, floor_c, wall, "alley", true)
	_dumpster(old_cx + 1, z0 + 5, true)
	_dumpster(cx + 1, z0 + 24, true)
	_light(_w(old_cx + 0.5, z0 + 8, 4.0), Color(1.0, 0.7, 0.4), 1.5, 9.0)
	Build.sphere(root, 0.15, Color(1.0, 0.8, 0.5), _w(old_cx + 0.5, z0 + 8, 4.2), Vector3.ONE, 6).material_override = Build.mat(Color(1.0, 0.8, 0.5), 0.5, 4.0)
	_light(_w(cx + 0.5, z0 + 26, 4.0), Color(1.0, 0.7, 0.4), 1.5, 9.0)
	_item_spot(lo + 1.0, z0 + 15.5)
	_item_spot(cx + 2.0, z0 + len - 3)
	markers.witch_spots.append(_w(hi - 1.0, z0 + 15.5))
	cz += len


func _seg_park() -> void:
	cx = _cx_clamp(cx, 17)
	var len: int = SEG_LEN.park
	var z0 := cz
	_zone(Rect2i(cx - 17, z0, 34, len), 10.0, 0.0, Color(0.13, 0.2, 0.11), BRICK[rng.randi() % BRICK.size()], "park", true)
	var mid := _w(cx, z0)
	Build.box(root, Vector3(4.0, 0.03, len), Color(0.3, 0.27, 0.22), mid + Vector3(0, 0.015, len * 0.5))
	for i in 14:
		var x := cx + rng.randi_range(-15, 14)
		var z := z0 + rng.randi_range(2, len - 3)
		if _block(x, z, 1, 1):
			var p := _w(x + 0.5, z + 0.5)
			Build.solid_cyl(root, 0.25, 3.0, Color(0.3, 0.2, 0.12), p + Vector3(0, 1.5, 0), 8)
			var leaf := Color(0.12, 0.25, 0.1).lerp(Color(0.2, 0.32, 0.12), rng.randf())
			Build.sphere(root, 1.6, leaf, p + Vector3(0, 3.8, 0), Vector3(1, 0.85, 1), 8)
			Build.sphere(root, 1.1, leaf.lightened(0.05), p + Vector3(0.6, 4.6, 0.3), Vector3.ONE, 8)
	for i in 5:
		var x := cx + rng.randi_range(-12, 10)
		var z := z0 + rng.randi_range(4, len - 5)
		if _block(x, z, 2, 1):
			var p := _w(x + 1.0, z + 0.5)
			Build.solid_box(root, Vector3(1.8, 0.45, 0.6), Color(0.35, 0.22, 0.12), p + Vector3(0, 0.25, 0))
			Build.box(root, Vector3(1.8, 0.5, 0.1), Color(0.35, 0.22, 0.12), p + Vector3(0, 0.7, -0.28))
	# Fountain off to one side
	var fx := cx + 8
	var fz := z0 + len / 2 - 2
	if _block(fx, fz, 4, 4):
		var p := _w(fx + 2.0, fz + 2.0)
		Build.solid_cyl(root, 2.0, 0.7, Color(0.45, 0.45, 0.48), p + Vector3(0, 0.35, 0), 16)
		Build.cyl(root, 1.7, 1.7, 0.05, Color(0.1, 0.2, 0.25), p + Vector3(0, 0.71, 0), Vector3.ZERO, 16)
		Build.cyl(root, 0.25, 0.35, 1.8, Color(0.45, 0.45, 0.48), p + Vector3(0, 1.2, 0))
	for i: float in [6, 20, 34]:
		_street_lamp(mid + Vector3(-2.6 if i == 20 else 2.6, 0, i), 0.0)
	for i in 3:
		_item_spot(cx + rng.randi_range(-14, 14), z0 + rng.randi_range(5, len - 5))
	markers.witch_spots.append(_w(cx - 13, z0 + len * 0.6))
	cz += len


func _seg_warehouse() -> void:
	cx = _cx_clamp(cx, 12)
	var len: int = SEG_LEN.warehouse
	_warehouse_room(cz, len)
	cz += len


func _warehouse_room(z0: int, len: int) -> void:
	_zone(Rect2i(cx - 12, z0, 24, len), 7.4, 7.0, Color(0.33, 0.33, 0.33), Color(0.32, 0.38, 0.42), "warehouse")
	var mid := _w(cx, z0)
	# Shelving racks with aisles between them.
	for rx: float in [-10, -6, 4, 8]:
		var z := z0 + 4
		while z < z0 + len - 12:
			var l := rng.randi_range(6, 10)
			if _block(cx + rx, z, 2, l):
				_rack(_w(cx + rx + 1.0, z + l * 0.5), l)
			z += l + rng.randi_range(3, 5)
	for i in 4:
		_crates(cx + rng.randi_range(-11, 9), z0 + rng.randi_range(2, len - 4), 2, 2, rng.randf_range(1.0, 2.2))
	for i in range(5, len, 10):
		for side: float in [-5, 5]:
			_light(mid + Vector3(side, 6.4, i), Color(0.85, 0.95, 1.0), 1.4, 12.0)
			Build.box(root, Vector3(0.3, 0.08, 2.0), Color(0.9, 0.95, 1.0), mid + Vector3(side, 6.9, i), Vector3.ZERO, 3.0)
	for i in 3:
		_item_spot(cx + rng.randi_range(-11, 11), z0 + rng.randi_range(3, len - 3))
	markers.witch_spots.append(_w(cx + 11, z0 + len - 4))


## Pallet racking: invisible collision block, orange beams, blue uprights, boxes on the shelves.
func _rack(p: Vector3, l: int) -> void:
	var body := StaticBody3D.new()
	body.position = p
	body.collision_layer = 1
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 3.6, l - 0.1)
	cs.shape = bs
	cs.position.y = 1.8
	body.add_child(cs)
	for k in range(0, l + 1, 3):
		var z := -l * 0.5 + minf(k, l - 0.1)
		for x: float in [-0.85, 0.85]:
			Build.box(body, Vector3(0.08, 3.6, 0.08), Color(0.15, 0.25, 0.55), Vector3(x, 1.8, z))
	for sh: float in [0.15, 1.3, 2.45, 3.55]:
		for x: float in [-0.85, 0.85]:
			Build.box(body, Vector3(0.08, 0.12, l), Color(0.85, 0.45, 0.1), Vector3(x, sh, 0))
		Build.box(body, Vector3(1.75, 0.04, l), Color(0.35, 0.28, 0.2), Vector3(0, sh + 0.06, 0))
	for level_i in 3:
		var y := 0.2 + level_i * 1.15
		var zz := -l * 0.5 + 0.7
		while zz < l * 0.5 - 0.7:
			if rng.randf() < 0.8:
				var h := rng.randf_range(0.5, 0.95)
				var c := Color(0.55, 0.42, 0.25).lerp(Color(0.7, 0.6, 0.45), rng.randf())
				Build.box(body, Vector3(rng.randf_range(1.0, 1.5), h, rng.randf_range(0.8, 1.2)), c, Vector3(0, y + h * 0.5, zz))
			zz += rng.randf_range(1.2, 1.6)


func _seg_warehouse_gate() -> void:
	cx = _cx_clamp(cx, 12)
	var len: int = SEG_LEN.warehouse_gate
	var z0 := cz
	var zi := _zone(Rect2i(cx - 12, z0, 24, len), 7.4, 7.0, Color(0.3, 0.3, 0.31), Color(0.38, 0.3, 0.26), "warehouse")
	var gz := z0 + 24
	var gate := Rect2i(cx - 11, gz, 22, 1)
	for x in range(gate.position.x, gate.end.x):
		grid.set_cell(Vector2i(x, gz), NavGrid.Cell.DOOR)
		grid.zone[grid.idx(Vector2i(x, gz))] = zi
	# Wall the gate row off at the edges.
	_block(cx - 12, gz, 1, 1, true)
	_block(cx + 11, gz, 1, 1, true)
	Build.solid_box(root, Vector3(1, 7.4, 1), Color(0.38, 0.3, 0.26), _w(cx - 11.5, gz + 0.5, 3.7))
	Build.solid_box(root, Vector3(1, 7.4, 1), Color(0.38, 0.3, 0.26), _w(cx + 11.5, gz + 0.5, 3.7))
	markers.gate = {"rect": gate, "pos": _w(cx, gz + 0.5), "width": 22.0}
	markers.button = _w(cx - 9, gz - 3, 1.2)
	var panel := Build.box(root, Vector3(0.8, 1.2, 0.3), Color(0.25, 0.25, 0.28), markers.button + Vector3(0, 0.0, 0))
	panel.name = "GatePanel"
	Build.box(root, Vector3(0.3, 0.3, 0.1), Color(0.9, 0.15, 0.1), markers.button + Vector3(0, 0.15, -0.18), Vector3.ZERO, 2.0)
	Build.box(root, Vector3(0.1, 1.2, 0.1), Color(0.2, 0.2, 0.22), markers.button + Vector3(0, -0.6, 0))
	var l := Build.label(root, "GATE CONTROL", markers.button + Vector3(0, 0.9, 0), 28, Color(1.0, 0.85, 0.3))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	for i in range(5, len, 10):
		_light(_w(cx, z0 + i, 6.4), Color(1.0, 0.75, 0.55), 1.5, 14.0)
	for i in 3:
		_crates(cx + rng.randi_range(-11, 9), z0 + rng.randi_range(2, 18), 2, 2, rng.randf_range(1.0, 2.4))
	_crates(cx + rng.randi_range(-11, 9), gz + rng.randi_range(4, 10), 2, 2, 1.4)
	_ammo_pile(_w(cx + 8, z0 + 16))
	markers.caches.append({"pos": _w(cx + 9.5, z0 + 12, 0.85), "dir": Vector3(0, 0, 1), "items": ["molotov", "pipe_bomb", "pills", "pills"]})
	Build.box(root, Vector3(1.0, 0.08, 3.0), Color(0.45, 0.32, 0.2), _w(cx + 9.5, z0 + 12, 0.8))
	_block(cx + 9, z0 + 10, 1, 3, true)
	cz += len


func _seg_yard() -> void:
	cx = _cx_clamp(cx, 15)
	var len: int = SEG_LEN.yard
	var z0 := cz
	_zone(Rect2i(cx - 15, z0, 30, len), 7.0, 0.0, Color(0.22, 0.22, 0.23), Color(0.32, 0.36, 0.4), "yard", true)
	for i in 3:
		var x := cx + rng.randi_range(-14, 10)
		var z := z0 + rng.randi_range(3, len - 14)
		if _block(x, z, 3, 11):
			var p := _w(x + 1.5, z + 5.5)
			Build.solid_box(root, Vector3(2.8, 3.2, 10.8), Color(0.75, 0.75, 0.72), p + Vector3(0, 2.0, 0))
			Build.box(root, Vector3(2.6, 0.5, 10.6), Color(0.15, 0.15, 0.15), p + Vector3(0, 0.25, 0))
	for i in 6:
		var x := cx + rng.randi_range(-14, 13)
		var z := z0 + rng.randi_range(2, len - 3)
		_crates(x, z, 1, 1, rng.randf_range(0.6, 1.5))
	for i in range(6, len, 16):
		for side: float in [-13, 13]:
			var p := _w(cx + side, z0 + i)
			Build.solid_cyl(root, 0.15, 9.0, Color(0.3, 0.3, 0.32), p + Vector3(0, 4.5, 0), 6)
			Build.box(root, Vector3(1.2, 0.5, 0.4), Color(1.0, 0.95, 0.8), p + Vector3(0, 9.0, 0), Vector3.ZERO, 3.0)
			_light(p + Vector3(-signf(side) * 2.0, 8.5, 0), Color(0.95, 0.95, 1.0), 2.6, 20.0)
	for i in 3:
		_item_spot(cx + rng.randi_range(-12, 12), z0 + rng.randi_range(4, len - 4))
	markers.witch_spots.append(_w(cx + 13, z0 + 6))
	cz += len


func _seg_containers() -> void:
	cx = _cx_clamp(cx, 15)
	var len: int = SEG_LEN.containers
	var z0 := cz
	_zone(Rect2i(cx - 15, z0, 30, len), 6.0, 0.0, Color(0.24, 0.23, 0.22), Color(0.3, 0.33, 0.36), "containers", true)
	var placed := 0
	var tries := 0
	while placed < 16 and tries < 80:
		tries += 1
		var along := rng.randf() < 0.6
		var sx := 3 if along else 7
		var sz := 7 if along else 3
		var x := cx + rng.randi_range(-15, 15 - sx)
		var z := z0 + rng.randi_range(2, len - sz - 2)
		if not _block(x, z, sx, sz, true):
			continue
		if not _connected(Vector2i(cx, z0), Vector2i(cx, z0 + len - 1), Rect2i(cx - 15, z0, 30, len)):
			_unblock(x, z, sx, sz)
			continue
		placed += 1
		var c: Color = CONTAINER[rng.randi() % CONTAINER.size()]
		var p := _w(x + sx * 0.5, z + sz * 0.5)
		var size := Vector3(sx - 0.2, 2.6, sz - 0.2)
		Build.solid_box(root, size, c, p + Vector3(0, 1.3, 0))
		for k in range(1, 7):
			var off := -0.5 + k / 7.0
			Build.box(root, Vector3(0.06, 2.5, size.z + 0.04) if not along else Vector3(size.x + 0.04, 2.5, 0.06), c.darkened(0.2), p + (Vector3(off * size.x, 1.3, 0) if not along else Vector3(0, 1.3, off * size.z)))
		if rng.randf() < 0.4:
			Build.box(root, size, CONTAINER[rng.randi() % CONTAINER.size()], p + Vector3(0, 3.9, 0))
	for i in range(8, len, 18):
		var p := _w(cx + (13 if (i / 18) % 2 == 0 else -13), z0 + i)
		Build.solid_cyl(root, 0.15, 10.0, Color(0.3, 0.3, 0.32), p + Vector3(0, 5.0, 0), 6)
		Build.box(root, Vector3(1.2, 0.5, 0.4), Color(1.0, 0.95, 0.8), p + Vector3(0, 10.0, 0), Vector3.ZERO, 3.0)
		_light(p + Vector3(0, 9.5, 0), Color(0.95, 0.95, 1.0), 3.0, 24.0)
	for i in 4:
		_item_spot(cx + rng.randi_range(-13, 13), z0 + rng.randi_range(4, len - 4))
	cz += len


func _seg_docks_finale() -> void:
	cx = _cx_clamp(cx, 22)
	var len: int = SEG_LEN.docks_finale
	var z0 := cz
	_zone(Rect2i(cx - 22, z0, 44, len), 1.1, 0.0, Color(0.3, 0.3, 0.3), Color(0.45, 0.4, 0.2), "docks")
	var mid := _w(cx, z0)
	# Big sheds along both sides
	for side: float in [-1, 1]:
		var x := cx - 22 if side < 0 else cx + 14
		_block(x, z0 + 4, 8, 22, true)
		var p := _w(x + 4.0, z0 + 15.0)
		Build.solid_box(root, Vector3(8, 9, 22), Color(0.35, 0.38, 0.42), p + Vector3(0, 4.5, 0))
		Build.box(root, Vector3(8.4, 0.4, 22.4), Color(0.25, 0.27, 0.3), p + Vector3(0, 9.1, 0))
		Build.box(root, Vector3(0.1, 4.5, 6.0), Color(0.2, 0.22, 0.25), p + Vector3(-side * 4.05, 2.25, 0))
	# Radio hut in the middle
	var hx := cx - 2
	var hz := z0 + 30
	_block(hx, hz, 4, 3, true)
	var hp := _w(hx + 2.0, hz + 1.5)
	Build.solid_box(root, Vector3(4, 2.8, 3), Color(0.5, 0.45, 0.35), hp + Vector3(0, 1.4, 0))
	Build.box(root, Vector3(4.4, 0.2, 3.4), Color(0.3, 0.25, 0.2), hp + Vector3(0, 2.9, 0))
	Build.box(root, Vector3(1.2, 0.6, 0.5), Color(0.2, 0.22, 0.2), hp + Vector3(0, 1.1, -1.7))
	Build.box(root, Vector3(0.2, 0.15, 0.05), Color(0.2, 1.0, 0.3), hp + Vector3(0.3, 1.25, -1.96), Vector3.ZERO, 3.0)
	Build.cyl(root, 0.03, 0.03, 3.0, Color(0.6, 0.6, 0.6), hp + Vector3(1.5, 4.4, 0.5))
	markers.radio = hp + Vector3(0, 1.1, -2.0)
	_light(hp + Vector3(0, 3.6, -2.5), Color(1.0, 0.85, 0.6), 2.0, 12.0)
	# Supplies for the stand
	_ammo_pile(_w(cx + 4, z0 + 28))
	markers.caches.append({"pos": _w(cx - 6, z0 + 28, 0.85), "dir": Vector3(0, 0, 1), "items": ["medkit", "medkit", "medkit", "medkit", "molotov", "pipe_bomb", "molotov", "pipe_bomb"]})
	Build.box(root, Vector3(1.0, 0.08, 5.0), Color(0.45, 0.32, 0.2), _w(cx - 6, z0 + 28, 0.8))
	_block(cx - 7, z0 + 25, 1, 6, true)
	for i in 4:
		_crates(cx + rng.randi_range(-12, 10), z0 + rng.randi_range(8, len - 8), 2, 2, rng.randf_range(1.0, 1.6))
	for i in range(6, len, 14):
		for side: float in [-12, 12]:
			var p := _w(cx + side, z0 + i)
			Build.solid_cyl(root, 0.15, 10.0, Color(0.3, 0.3, 0.32), p + Vector3(0, 5.0, 0), 6)
			Build.box(root, Vector3(1.2, 0.5, 0.4), Color(1.0, 0.95, 0.8), p + Vector3(0, 10.0, 0), Vector3.ZERO, 3.0)
			_light(p + Vector3(0, 9.5, 0), Color(0.95, 0.95, 1.0), 2.6, 22.0)
	# Pier out to sea where the boat comes in.
	var pz := z0 + len
	_zone(Rect2i(cx - 4, pz, 8, 16), 1.1, 0.0, Color(0.36, 0.26, 0.16), Color(0.45, 0.4, 0.2), "pier")
	for i in range(0, 16, 2):
		Build.box(root, Vector3(8, 0.05, 0.12), Color(0.25, 0.18, 0.1), _w(cx, pz + i, 0.01))
	markers.rescue_zone = Rect2(_w(cx - 4, 0).x, _w(0, pz + 9).z, 8, 7)
	markers.boat_dock = _w(cx + 7.5, pz + 12, 0.0)
	for i in 3:
		_item_spot(cx + rng.randi_range(-10, 10), z0 + rng.randi_range(4, 20))
	cz += len + 16


## Flood fill inside `bounds` only (cheap enough to run after every container we place).
func _connected(a: Vector2i, b: Vector2i, bounds: Rect2i) -> bool:
	var seen := {a: true}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if c == b:
			return true
		for k in 4:
			var n: Vector2i = c + NavGrid.NEIGHBOURS[k]
			if bounds.has_point(n) and grid.walkable(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return false


# --- Geometry from the grid ---------------------------------------------------------

func _build_floors() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	var i := 0
	for z in zones:
		var r: Rect2i = z.rect
		var size := Vector3(r.size.x, 0.4, r.size.y)
		var pos := _w(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, -0.2 + i * 0.002)
		Build.box(root, size, z.floor, pos)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		body.add_child(cs)
		if z.ceil_h > 0.0:
			Build.box(root, Vector3(r.size.x + 2, 0.4, r.size.y + 2), z.wall.darkened(0.35), pos + Vector3(0, z.ceil_h + 0.4, 0))
		i += 1
	for r in _extra_floors:
		var size := Vector3(r.size.x, 0.4, r.size.y)
		var pos := _w(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, -0.2)
		Build.box(root, size, Color(0.3, 0.28, 0.26), pos)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		body.add_child(cs)


## Every empty cell touching something walkable becomes wall; neighbouring wall cells of the
## same zone are merged into the biggest boxes we can find (greedy meshing).
func _build_walls() -> void:
	var owner := PackedInt32Array()
	owner.resize(grid.w * grid.h)
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if grid.cell_state(c) != NavGrid.Cell.VOID:
				continue
			var best := 0
			var best_h := -1.0
			for o in NavGrid.NEIGHBOURS:
				var n: Vector2i = c + o
				if not grid.inside(n) or grid.cell_state(n) == NavGrid.Cell.VOID:
					continue
				var zi := grid.zone[grid.idx(n)]
				if zi > 0 and zones[zi - 1].wall_h > best_h:
					best_h = zones[zi - 1].wall_h
					best = zi
			owner[grid.idx(c)] = best
	var done := PackedByteArray()
	done.resize(grid.w * grid.h)
	for y in grid.h:
		for x in grid.w:
			var i := y * grid.w + x
			var zi := owner[i]
			if zi == 0 or done[i]:
				continue
			var x1 := x
			while x1 + 1 < grid.w and owner[y * grid.w + x1 + 1] == zi and not done[y * grid.w + x1 + 1]:
				x1 += 1
			var y1 := y
			var grow := true
			while grow and y1 + 1 < grid.h:
				for xx in range(x, x1 + 1):
					var j := (y1 + 1) * grid.w + xx
					if owner[j] != zi or done[j]:
						grow = false
						break
				if grow:
					y1 += 1
			for yy in range(y, y1 + 1):
				for xx in range(x, x1 + 1):
					done[yy * grid.w + xx] = 1
			_wall_box(Rect2i(x, y, x1 - x + 1, y1 - y + 1), zones[zi - 1])


func _wall_box(r: Rect2i, z: Dictionary) -> void:
	# Long outdoor runs are split into separate "buildings" of varying height and colour.
	var long_x := r.size.x >= r.size.y
	var total := r.size.x if long_x else r.size.y
	var outdoor: bool = z.ceil_h <= 0.0 and z.wall_h > 4.0
	var start := 0
	while start < total:
		var piece := total - start
		if outdoor and piece > 16:
			piece = rng.randi_range(8, 14)
		var sub := Rect2i(r.position.x + (start if long_x else 0), r.position.y + (0 if long_x else start), piece if long_x else r.size.x, r.size.y if long_x else piece)
		var h: float = z.wall_h
		var col: Color = z.wall
		if outdoor:
			h += float(rng.randi_range(-2, 5))
			col = BRICK[rng.randi() % BRICK.size()] if rng.randf() < 0.6 else z.wall
		var size := Vector3(sub.size.x, h + 1.0, sub.size.y)
		var pos := _w(sub.position.x + sub.size.x * 0.5, sub.position.y + sub.size.y * 0.5, (h - 1.0) * 0.5)
		Build.solid_box(root, size, col, pos)
		if outdoor:
			Build.box(root, Vector3(size.x + 0.3, 0.3, size.z + 0.3), col.darkened(0.3), pos + Vector3(0, h * 0.5 + 0.5, 0))
		if z.windows:
			_windows_for(sub, h)
		start += piece


func _windows_for(r: Rect2i, h: float) -> void:
	# Check each face; only faces that look onto walkable ground get windows.
	var faces := [
		[Vector2i(r.position.x + r.size.x / 2, r.position.y - 1), Vector3(0, 0, -1)],
		[Vector2i(r.position.x + r.size.x / 2, r.end.y), Vector3(0, 0, 1)],
		[Vector2i(r.position.x - 1, r.position.y + r.size.y / 2), Vector3(-1, 0, 0)],
		[Vector2i(r.end.x, r.position.y + r.size.y / 2), Vector3(1, 0, 0)],
	]
	var center := _w(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5)
	for f in faces:
		var probe: Vector2i = f[0]
		if grid.cell_state(probe) == NavGrid.Cell.VOID:
			continue
		var n: Vector3 = f[1]
		var along := Vector3(n.z, 0, n.x).abs()
		var width := float(r.size.x if n.z != 0 else r.size.y)
		var depth := float(r.size.y if n.z != 0 else r.size.x)
		var count := int(width / 3.0)
		for k in count:
			var off := -width * 0.5 + (k + 0.5) * width / count
			var y := 3.2
			while y < h - 1.2:
				var p := center + n * (depth * 0.5 + 0.03) + along * off + Vector3(0, y, 0)
				var t := Transform3D(Basis.looking_at(n, Vector3.UP), p)
				if rng.randf() < 0.18:
					_win_lit.append(t)
				else:
					_win_dark.append(t)
				y += 3.4
		# A doorway on the ground floor now and then.
		if rng.randf() < 0.5 and width >= 4:
			var p := center + n * (depth * 0.5 + 0.03) + along * rng.randf_range(-width * 0.3, width * 0.3) + Vector3(0, 1.1, 0)
			Build.box(root, Vector3(1.3, 2.2, 0.1), Color(0.08, 0.07, 0.07), p, Vector3(0, rad_to_deg(atan2(n.x, n.z)), 0))


func _build_windows() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.7)
	for lit in [false, true]:
		var list: Array[Transform3D] = _win_lit if lit else _win_dark
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = list.size()
		for i in list.size():
			# QuadMesh faces +Z; looking_at points -Z at the normal, so flip it round.
			mm.set_instance_transform(i, list[i].rotated_local(Vector3.UP, PI))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Build.mat(Color(0.93,0.77,0.43),0.7,0.3) if lit else Build.mat(Color(0.05, 0.07, 0.1), 0.2)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)


func _gunsmith(pos: Vector3) -> void:
	markers.benches.append(pos + Vector3(0, 1.1, 0))
	Build.solid_box(root, Vector3(0.9, 0.12, 1.8), Color(0.23, 0.29, 0.28), pos + Vector3.UP * 0.9)
	for z: float in [-0.65, 0.65]:
		Build.box(root, Vector3(0.65, 0.85, 0.08), Color(0.12, 0.17, 0.17), pos + Vector3(0, 0.43, z))
	Build.box(root, Vector3(0.08, 0.85, 1.85), Color(0.12, 0.19, 0.18), pos + Vector3(0.4, 1.35, 0))
	for z: float in [-0.6, -0.2, 0.2, 0.6]:
		Build.cyl(root, 0.018, 0.018, 0.22, Color(0.65, 0.67, 0.62), pos + Vector3(0.3, 1.35, z), Vector3(0, 0, 60), 12)
	Build.box(root, Vector3(0.5, 0.025, 1.3), Color(0.08, 0.14, 0.13), pos + Vector3(0, 0.975, 0))
	Build.box(root, Vector3(0.12, 0.1, 0.18), Color(0.8, 0.52, 0.18), pos + Vector3(-0.15, 1.03, 0.5))
	Build.label(root, "GUNSMITH / UPGRADES", pos + Vector3(0, 2.0, 0), 24, Color(0.5, 0.95, 0.8))
	Build.interact_zone(root, "gunsmith", Vector3(1.0, 1.0, 1.8), pos + Vector3(0, 1.0, 0), "Gunsmith · weapon stats & upgrades")
