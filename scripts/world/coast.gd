class_name Coast
extends RefCounted
## Island shorelines with character instead of one strip of sand all the way round. Each island's
## shore is split into stretches: proper beaches (parasols, loungers, beach huts, lifeguards, ice
## cream vans and seagulls), working ports (a quay out into the sea with gantry cranes, container
## stacks, a shipbuilding hall and a moored freighter), cliffs (grassy headlands rising off rock
## faces) and sea walls with a railed promenade. The kinds blend into each other round the shore.
##
## The playable interior stays flat at y = 0, because navigation, spawning and the city all
## assume it. Height lives on the coast: anything raised is blocked on the nav grid, and the
## stretches with harbours and the ferry pier keep the plain shelf so every boat route still works.

const OFFSETS := [-16.0, -10.0, -6.0, -3.0, -1.5, 0.0, 2.0, 3.0, 3.6, 6.0, 10.0, 14.0, 20.0, 26.0, 30.0, 34.0, 36.0, 36.6, 38.0, 40.0, 42.0, 44.0, 46.0, 48.0, 50.0, 54.0, 62.0, 75.0]
const BLEND := 0.07  # radians over which one kind of shore turns into the next
## Stretches of shore as [kind, from angle, to angle]. Angle 0 faces east, where every island's
## harbour is, and positive angles run south. Shore not listed keeps the plain shelf.
const LAYOUTS := [
	# Barea: promenades either side of the harbour, a long south beach, the ferry pier (plain) in
	# the west, the shipyard beside the north-west industrial estate and cliffs along the north.
	[["wall", 0.22, 0.75], ["beach", 0.75, 2.05], ["wall", 2.05, 2.62], ["wall", 3.12, -2.95], ["port", -2.95, -2.2], ["wall", -2.2, -1.85], ["cliff", -1.85, -0.55], ["wall", -0.55, -0.22]],
	[["port", 2.0, -2.4], ["cliff", -2.1, -0.9], ["wall", 0.45, 1.7]],  # Rustwater Works
	[["cliff", -2.6, -0.5], ["beach", 0.6, 2.4]],  # Pinefall Reserve
	[["beach", 0.45, 2.0], ["cliff", -2.3, -1.3]],  # Sunfield County
	[["cliff", 0.45, 2.5], ["cliff", 2.5, -1.9], ["cliff", -1.9, -0.45]],  # Last Light
]
const PORT_NAMES := {0: ["BAREA SHIPYARD", "BAREA STAR"], 1: ["RUSTWATER DOCKS", "RUST BUCKET"]}
const SAND := Color(0.86, 0.76, 0.52)
const ROCK := Color(0.5, 0.46, 0.42)
const QUAY := Color(0.62, 0.6, 0.56)
const TURF := Color(0.38, 0.55, 0.27)
const CANOPIES := [Color(0.92, 0.3, 0.25), Color(0.25, 0.55, 0.85), Color(0.98, 0.82, 0.25), Color(0.3, 0.7, 0.5), Color(0.95, 0.55, 0.7), Color(0.98, 0.98, 0.95)]
const TOWELS := [Color(0.95, 0.4, 0.3), Color(0.3, 0.75, 0.85), Color(0.98, 0.85, 0.3), Color(0.6, 0.4, 0.8), Color(0.4, 0.8, 0.45)]
const HUTS := [Color(0.95, 0.6, 0.65), Color(0.55, 0.8, 0.9), Color(0.98, 0.88, 0.5), Color(0.6, 0.85, 0.6), Color(0.85, 0.75, 0.95)]
const CONTAINERS := [Color(0.75, 0.25, 0.18), Color(0.2, 0.4, 0.65), Color(0.25, 0.5, 0.3), Color(0.9, 0.65, 0.15), Color(0.55, 0.55, 0.58), Color(0.9, 0.9, 0.88)]
const CRANES := [Color(0.85, 0.25, 0.2), Color(0.2, 0.45, 0.75), Color(0.95, 0.7, 0.15)]
const ROCKS := [Color(0.5, 0.46, 0.42), Color(0.42, 0.4, 0.38), Color(0.58, 0.54, 0.48)]
const LEAVES := [Color(0.33, 0.52, 0.15), Color(0.48, 0.62, 0.2), Color(0.25, 0.43, 0.15)]

var world: OpenWorld
var batch := Batch.new()
var rng := RandomNumberGenerator.new()


func _init(w: OpenWorld) -> void:
	world = w


# --- Shape of the shore -------------------------------------------------------------------------

## How much of each kind of shore applies at this angle; the weights sum to 1.
static func weights(index: int, a: float) -> Dictionary:
	var w := {}
	var total := 0.0
	for s: Array in LAYOUTS[index]:
		var inside := minf(wrapf(a - s[1], -PI, PI), wrapf(s[2] - a, -PI, PI))
		var k := smoothstep(-BLEND, BLEND, inside)
		if k > 0.0:
			w[s[0]] = w.get(s[0], 0.0) + k
			total += k
	if total < 1.0:
		w["plain"] = 1.0 - total
	else:
		for key: String in w:
			w[key] /= total
	return w


## Ground height for one kind of shore, o metres seaward of the coastline (negative is inland).
static func profile(kind: String, o: float, a: float, index: int) -> float:
	match kind:
		"beach":
			# A long, gentle shelf: dry sand for ~35 m before the water (y = -0.8) laps over it.
			if o <= 0.0:
				return 0.0
			return -o / 44.0 if o <= 44.0 else -1.0 - (o - 44.0) * 0.07
		"cliff":
			var top := cliff_top(index, a)
			var face := cliff_face(index, a)
			if o <= -10.0:
				return 0.0
			if o <= -4.0:
				return (o + 10.0) / 6.0 * 2.5  # a grassy bank
			if o <= 0.0:
				return lerpf(2.5, top, (o + 4.0) / 4.0)  # then rock, too steep to climb
			if o < face:
				# A crown that rolls over towards the edge.
				return top + 1.5 * sin(o * 0.3 + a * 20.0) - maxf(o - face + 8.0, 0.0) * 0.6
			if o < face + 3.0:
				return lerpf(top, -4.0, (o - face) / 3.0)  # sheer face into the sea
			return -4.0 - (o - face - 3.0) * 0.05
		"port":
			# A concrete apron 36 m out to a quay wall with deep water alongside.
			if o <= 36.0:
				return 0.0
			return lerpf(0.0, -5.0, minf((o - 36.0) / 0.6, 1.0))
		"wall":
			if o <= 3.0:
				return 0.0
			return lerpf(0.0, -2.6, minf((o - 3.0) / 0.6, 1.0)) - maxf(o - 3.6, 0.0) * 0.02
	# Plain: the old shelf, sloping under the water.
	if o <= 0.0:
		return 0.0
	return -1.4 * o / 22.0 if o <= 22.0 else -1.4 - (o - 22.0) * 0.03


static func cliff_top(index: int, a: float) -> float:
	var scale := 1.0 if index == 0 else 0.7
	return (30.0 + 8.0 * sin(a * 13.0 + index * 2.0) + 4.0 * sin(a * 37.0 + 1.0)) * scale


static func cliff_face(index: int, a: float) -> float:
	return 32.0 + 6.0 * sin(a * 17.0 + index)


static func _blend(w: Dictionary, o: float, a: float, index: int) -> float:
	var h := 0.0
	for kind: String in w:
		h += w[kind] * profile(kind, o, a, index)
	return h


static func _edge(index: int, a: float) -> Vector2:
	var island: Dictionary = OpenWorld.ISLANDS[index]
	return Vector2(cos(a), sin(a)) * island.radius * OpenWorld.edge(a, index)


## Height of the ground at p on this island's shore (0 inland).
static func height_at(index: int, p: Vector3) -> float:
	var island: Dictionary = OpenWorld.ISLANDS[index]
	var d: Vector2 = Vector2(p.x, p.z) - island.center
	var dn: Vector2 = d / island.radius
	var a := atan2(dn.y, dn.x)
	var o: float = d.length() - _edge(index, a).length()
	if o < OFFSETS[0]:
		return 0.0
	return _blend(weights(index, a), o, a, index)


static func _dominant(w: Dictionary) -> String:
	var best := "plain"
	var bw := -1.0
	for kind: String in w:
		if w[kind] > bw:
			bw = w[kind]
			best = kind
	return best


# --- Terrain mesh -------------------------------------------------------------------------------

enum { LAND, SAND_S, ROCK_S, QUAY_S, TURF_S }


## The island's ground: a flat fan inland and a strip of shore profile all the way round.
static func terrain(root: Node3D, index: int) -> void:
	var island: Dictionary = OpenWorld.ISLANDS[index]
	var center := Vector3(island.center.x, 0, island.center.y)
	var n := int(TAU * (island.radius.x + island.radius.y) * 0.5 / 12.0)
	var tools: Array[SurfaceTool] = []
	var used := [false, false, false, false, false]
	for k in 5:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(st)
	var rows: Array = []
	var kinds: Array[String] = []
	for s in n + 1:
		var a := TAU * s / n
		var e := _edge(index, a)
		var dir := e.normalized()
		var w := weights(index, wrapf(a, -PI, PI))
		var row := PackedVector3Array()
		for o: float in OFFSETS:
			var p: Vector2 = island.center + e + dir * o
			row.append(Vector3(p.x, _blend(w, o, a, index), p.y))
		rows.append(row)
		kinds.append(_dominant(w))
	for s in n:
		var r0: PackedVector3Array = rows[s]
		var r1: PackedVector3Array = rows[s + 1]
		for p: Vector3 in [center, r0[0], r1[0]]:
			tools[LAND].add_vertex(p)
		used[LAND] = true
		for i in OFFSETS.size() - 1:
			var o_mid: float = (OFFSETS[i] + OFFSETS[i + 1]) * 0.5
			var h_mid := (r0[i].y + r0[i + 1].y + r1[i].y + r1[i + 1].y) * 0.25
			var rise := absf(r0[i + 1].y - r0[i].y) + absf(r1[i + 1].y - r1[i].y)
			var slope: float = rise * 0.5 / (OFFSETS[i + 1] - OFFSETS[i])
			var surf := _surface(kinds[s], o_mid, h_mid, slope)
			used[surf] = true
			for p: Vector3 in [r0[i], r1[i + 1], r1[i], r0[i], r0[i + 1], r1[i + 1]]:
				tools[surf].add_vertex(p)
	var mesh := ArrayMesh.new()
	var mats := [[island.color, "grass"], [SAND, "sand"], [ROCK, "concrete"], [QUAY, "concrete"], [TURF, "grass"]]
	for k in 5:
		if not used[k]:
			continue
		tools[k].generate_normals()
		tools[k].commit(mesh)
		Build.paint = mats[k][1]
		mesh.surface_set_material(mesh.get_surface_count() - 1, Build.mat(mats[k][0]))
		Build.paint = ""
	var body := StaticBody3D.new()
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)


static func _surface(kind: String, o: float, h: float, slope: float) -> int:
	if slope > 1.0:
		return QUAY_S if kind == "port" or kind == "wall" else ROCK_S
	match kind:
		"cliff":
			if o <= -10.0:
				return LAND
			return TURF_S if h > -0.5 else ROCK_S
		"beach":
			return SAND_S if o > -10.0 else LAND
		"port", "wall":
			if o <= 0.0:
				return LAND
			return QUAY_S if h > -0.5 else ROCK_S
	return SAND_S if o > 0.0 else LAND


# --- Dressing -----------------------------------------------------------------------------------

func dress(index: int) -> void:
	rng.seed = 90210 + index * 7919
	if not world.markers.has("coast"):
		world.markers["coast"] = []  # {kind, island, pos: mid-stretch coastline, dir: out to sea}
	for s: Array in LAYOUTS[index]:
		var mid := _frame(index, wrapf(s[1] + wrapf(s[2] - s[1], 0.0, TAU) * 0.5, -PI, PI))
		world.markers.coast.append({"kind": s[0], "island": index, "pos": mid.origin, "dir": mid.basis.z})
		match String(s[0]):
			"beach": _beach(index, s)
			"cliff": _cliff(index, s)
			"port": _port(index, s)
			"wall": _wall(index, s)


func flush() -> void:
	batch.flush(world.root)


## Evenly spaced angles along a stretch, keeping clear of the blends at either end.
func _stretch(index: int, s: Array, spacing: float) -> Array[float]:
	var island: Dictionary = OpenWorld.ISLANDS[index]
	var r: float = (island.radius.x + island.radius.y) * 0.5
	var span := wrapf(s[2] - s[1], 0.0, TAU) - BLEND * 3.0
	var out: Array[float] = []
	var n := int(span * r / spacing)
	for k in n:
		out.append(wrapf(s[1] + BLEND * 1.5 + (k + 0.5) * span / n, -PI, PI))
	return out


## Local frame on the coastline: x runs along the shore, z points out to sea, y = 0.
func _frame(index: int, a: float) -> Transform3D:
	var island: Dictionary = OpenWorld.ISLANDS[index]
	var e := _edge(index, a)
	var dir := Vector3(e.x, 0, e.y).normalized()
	return Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), Vector3(island.center.x + e.x, 0, island.center.y + e.y))


## The frame moved to a spot on the shore and dropped onto the ground there.
func _ground(index: int, f: Transform3D, lpos: Vector3) -> Transform3D:
	var p := f * lpos
	p.y = height_at(index, p) + lpos.y
	return Transform3D(f.basis, p)


func _part(key: String, color: Color, base: Transform3D, lpos: Vector3, lsize: Vector3, lrot := Basis(), mesh: Mesh = null, tint := true, surface := "none", emission := 0.0) -> void:
	batch.add(key, mesh if mesh else Batch.box, color, base * Transform3D(lrot * Basis.from_scale(lsize), lpos), emission, surface, tint)


## An invisible box collider (props are drawn in the batches), blocking the nav grid beneath it.
func _solid(base: Transform3D, lpos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.transform = base * Transform3D(Basis(), lpos)
	body.collision_layer = 1
	world.root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	_block(body.position, Vector2(size.x, size.z).length() * 0.5 + 1.0)


## Keep pathing and spawns off the ground under a prop.
func _block(p: Vector3, radius: float) -> void:
	var a := world.grid.cell_of(p - Vector3.ONE * radius)
	var b := world.grid.cell_of(p + Vector3.ONE * radius)
	for z in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if world.grid.inside(Vector2i(x, z)):
				world.grid.set_cell(Vector2i(x, z), NavGrid.Cell.PROP)


func _tree(base: Transform3D, s: float, pine: bool) -> void:
	_part("trunk", Color(0.43, 0.27, 0.13), base, Vector3(0, 1.3, 0) * s, Vector3(0.35, 2.6, 0.35) * s, Basis(), Batch.post, false)
	if pine:
		for k in 3:
			_part("leaf", Color(0.18, 0.36, 0.2), base, Vector3(0, 2.6 + k * 1.5, 0) * s, Vector3(3.2 - k * 0.8, 2.4, 3.2 - k * 0.8) * s, Basis(), Batch.cone)
		return
	var k := rng.randi() % LEAVES.size()
	_part("leaf", LEAVES[k], base, Vector3(0, 3.4, 0) * s, Vector3(3.2, 2.8, 3.0) * s, Basis(), Batch.ball)
	_part("leaf", LEAVES[(k + 1) % LEAVES.size()], base, Vector3(0.7, 3.0, 0.4) * s, Vector3(2.0, 1.8, 2.0) * s, Basis(), Batch.ball)


func _sign(text: String, base: Transform3D, lpos: Vector3, yaw: float, size: int, color: Color, range_end := 400.0) -> void:
	var l := Build.label(world.root, text, base * lpos, size, color)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = base.basis.get_euler().y + yaw
	l.outline_size = 24
	l.visibility_range_end = range_end


# --- Beach --------------------------------------------------------------------------------------

func _beach(index: int, s: Array) -> void:
	var angles := _stretch(index, s, 14.0)
	var n := angles.size()
	for k in n:
		var f := _frame(index, angles[k])
		_part("boardwalk", Color(0.62, 0.45, 0.3), f, Vector3(0, 0.07, -13), Vector3(14.4, 0.14, 4.0), Basis(), null, false, "wood")
		if k % 18 == 9:
			_lifeguard(index, f)
		if n > 20 and (k == n / 3 or k == 2 * n / 3):
			_ice_cream_van(index, f)
		var roll := rng.randf()
		if roll < 0.5:
			_parasols(index, f)
		elif roll < 0.62 and k % 18 != 9:
			_huts(index, f)
		elif roll < 0.74:
			_sandcastle(index, f)
		if rng.randf() < 0.22:
			for g in rng.randi_range(2, 4):
				Seagull.spawn(world.root, _ground(index, f, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(2, 28))).origin, rng.randi())
	for k in maxi(1, n / 25):
		var f := _frame(index, angles[rng.randi() % n])
		Seagull.spawn(world.root, f * Vector3(0, 14, 15), rng.randi(), true)


func _parasols(index: int, f: Transform3D) -> void:
	var base := _ground(index, f, Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(4, 24)))
	var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
	_part("parasol_pole", Color(0.92, 0.92, 0.9), base, tilt * Vector3(0, 1.2, 0), Vector3(0.07, 2.4, 0.07), tilt, Batch.post, false)
	_part("canopy", CANOPIES[rng.randi() % CANOPIES.size()], base, tilt * Vector3(0, 2.45, 0), Vector3(2.8, 0.75, 2.8), tilt, Batch.cone, true, "fabric")
	_part("canopy_tip", Color(0.98, 0.98, 0.95), base, tilt * Vector3(0, 2.85, 0), Vector3(0.18, 0.18, 0.18), Basis(), Batch.ball, false)
	var col: Color = [Color(0.98, 0.98, 0.95), Color(0.3, 0.55, 0.85), Color(0.95, 0.45, 0.35)][rng.randi() % 3]
	var sides: Array = [-1.0, 1.0] if rng.randf() < 0.6 else [1.0 if rng.randf() < 0.5 else -1.0]
	for side: float in sides:
		_lounger(base, Vector3(side * 1.0, 0, -0.4), col)
	_part("towel", TOWELS[rng.randi() % TOWELS.size()], base, Vector3(rng.randf_range(-2.5, 2.5), 0.02, 2.2), Vector3(0.9, 0.03, 1.8), Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)), null, true, "fabric")
	if rng.randf() < 0.3:
		_part("beachball", CANOPIES[rng.randi() % CANOPIES.size()], base, Vector3(rng.randf_range(-3, 3), 0.25, rng.randf_range(3, 5)), Vector3.ONE * 0.5, Basis(), Batch.ball)


## A sun lounger facing the sea, backrest up at the landward end.
func _lounger(base: Transform3D, lpos: Vector3, col: Color) -> void:
	_part("lounger", col, base, lpos + Vector3(0, 0.34, 0.25), Vector3(0.65, 0.08, 1.3), Basis(), null, true, "fabric")
	_part("lounger", col, base, lpos + Vector3(0, 0.6, -0.62), Vector3(0.65, 0.08, 0.75), Basis(Vector3.RIGHT, 0.75), null, true, "fabric")
	for x: float in [-0.28, 0.28]:
		for z: float in [-0.35, 0.8]:
			_part("lounger_leg", Color(0.85, 0.85, 0.82), base, lpos + Vector3(x, 0.15, z), Vector3(0.05, 0.3, 0.05), Basis(), null, false)


## A row of three beach huts at the top of the sand, doors to the sea.
func _huts(index: int, f: Transform3D) -> void:
	var mid := _ground(index, f, Vector3(0, 0, -6))
	for k in 3:
		var base := _ground(index, f, Vector3(-3.2 + k * 3.2, 0, -6))
		var col: Color = HUTS[rng.randi() % HUTS.size()]
		_part("hut", col, base, Vector3(0, 1.25, 0), Vector3(2.6, 2.5, 2.2), Basis(), null, true, "wood")
		_part("hut_roof", Color(0.96, 0.96, 0.93), base, Vector3(0, 2.9, 0), Vector3(2.9, 0.8, 2.5), Basis(), Batch.prism, false)
		_part("hut_door", col.darkened(0.3), base, Vector3(0, 1.0, 1.11), Vector3(1.1, 1.9, 0.05))
		_part("hut_trim", Color(0.96, 0.96, 0.93), base, Vector3(0, 0.1, 1.12), Vector3(2.6, 0.2, 0.06), Basis(), null, false)
	_solid(mid, Vector3(0, 1.25, 0), Vector3(9.6, 2.5, 2.2))


func _sandcastle(index: int, f: Transform3D) -> void:
	var base := _ground(index, f, Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(10, 26)))
	var sand := SAND.darkened(0.08)
	_part("castle", sand, base, Vector3(0, 0.25, 0), Vector3(1.4, 0.5, 1.4), Basis(), null, false, "sand")
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_part("castle_tower", sand, base, Vector3(c.x * 0.65, 0.4, c.y * 0.65), Vector3(0.45, 0.8, 0.45), Basis(), Batch.post, false, "sand")
	_part("bucket", CANOPIES[rng.randi() % 4], base, Vector3(1.3, 0.18, 0.4), Vector3(0.35, 0.36, 0.35), Basis(), Batch.post)
	# A striped windbreak behind it.
	for k in 4:
		_part("windbreak", Color(0.92, 0.3, 0.25) if k % 2 == 0 else Color(0.98, 0.98, 0.95), base, Vector3(-1.6 + k * 0.8, 0.6, -2.0), Vector3(0.8, 1.1, 0.04), Basis(), null, true, "fabric")
		_part("windbreak_pole", Color(0.55, 0.4, 0.25), base, Vector3(-2.0 + k * 0.8, 0.65, -2.0), Vector3(0.05, 1.3, 0.05), Basis(), null, false)


func _lifeguard(index: int, f: Transform3D) -> void:
	var base := _ground(index, f, Vector3(0, 0, 8))
	var white := Color(0.97, 0.97, 0.94)
	for x: float in [-1.1, 1.1]:
		for z: float in [-1.1, 1.1]:
			_part("lg_leg", white, base, Vector3(x, 1.5, z), Vector3(0.15, 3.0, 0.15), Basis(), null, false)
	_part("lg_deck", Color(0.62, 0.45, 0.3), base, Vector3(0, 3.05, 0), Vector3(2.8, 0.15, 2.8), Basis(), null, false, "wood")
	_part("lg_hut", Color(0.86, 0.2, 0.18), base, Vector3(0, 4.0, -0.3), Vector3(2.2, 1.8, 1.8), Basis(), null, false)
	_part("lg_glass", Color(0.2, 0.3, 0.4), base, Vector3(0, 4.2, 0.61), Vector3(1.8, 0.7, 0.04), Basis(), null, false)
	_part("lg_roof", white, base, Vector3(0, 5.0, -0.3), Vector3(2.6, 0.2, 2.3), Basis(), null, false)
	for k in 6:
		_part("lg_leg", white, base, Vector3(0, 0.3 + k * 0.5, 1.6 + 0.08 * (5 - k)), Vector3(0.8, 0.06, 0.08), Basis(), null, false)
	_part("lg_leg", white, base, Vector3(0, 6.0, 1.2), Vector3(0.06, 2.4, 0.06), Basis(), null, false)
	_part("lg_flag", Color(0.95, 0.85, 0.2), base, Vector3(0.45, 6.8, 1.2), Vector3(0.8, 0.45, 0.03))
	_sign("LIFEGUARD", base, Vector3(0, 4.0, 0.64), 0.0, 60, Color(1, 1, 1), 160.0)


## An ice cream van parked behind the boardwalk, hatch open to the beach.
func _ice_cream_van(index: int, f: Transform3D) -> void:
	var base := _ground(index, f, Vector3(0, 0, -18.5))
	var body := StaticBody3D.new()
	body.transform = base * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO)
	body.collision_layer = 1
	world.root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.3, 2.8, 5.2)
	cs.shape = bs
	cs.position.y = 1.4
	body.add_child(cs)
	var pink := Color(0.98, 0.78, 0.85)
	var mint := Color(0.55, 0.88, 0.78)
	Build.box(body, Vector3(2.2, 1.9, 5.0), Color(0.98, 0.95, 0.93), Vector3(0, 1.45, 0))
	Build.box(body, Vector3(2.24, 0.5, 5.04), mint, Vector3(0, 0.7, 0))
	Build.box(body, Vector3(2.24, 0.25, 5.04), pink, Vector3(0, 2.3, 0))
	Build.box(body, Vector3(2.0, 0.85, 0.08), Color(0.2, 0.28, 0.36), Vector3(0, 1.8, 2.52))
	Build.box(body, Vector3(0.06, 0.95, 2.4), Color(0.25, 0.2, 0.22), Vector3(1.12, 1.6, -0.7))
	Build.box(body, Vector3(0.9, 0.06, 2.6), pink, Vector3(1.5, 2.15, -0.7), Vector3(0, 0, -14))
	Build.box(body, Vector3(0.4, 0.1, 2.4), Color(0.85, 0.85, 0.82), Vector3(1.3, 1.1, -0.7))
	# The giant cone on the roof.
	Build.cyl(body, 0.4, 0.04, 1.1, Color(0.85, 0.62, 0.32), Vector3(0, 3.1, -1.4))
	Build.sphere(body, 0.42, pink, Vector3(0, 3.75, -1.4))
	Build.sphere(body, 0.34, mint, Vector3(0, 4.2, -1.4))
	Build.sphere(body, 0.1, Color(0.85, 0.15, 0.15), Vector3(0, 4.55, -1.4))
	for x: float in [-1.05, 1.05]:
		for z: float in [-1.6, 1.6]:
			Build.cyl(body, 0.38, 0.38, 0.3, Color(0.12, 0.12, 0.12), Vector3(x, 0.38, z), Vector3(0, 0, 90))
	var l := Build.label(body, "ICE CREAM", Vector3(1.14, 2.55, -0.2), 70, Color(0.85, 0.2, 0.45))
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = PI * 0.5
	l.outline_size = 16
	l.outline_modulate = Color(1, 1, 1)
	for g in body.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 260.0
	_block(base.origin, 3.8)
	# Gulls know where the ice cream is.
	for k in 3:
		Seagull.spawn(world.root, _ground(index, f, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-12, -8))).origin + Vector3.UP * 0.14, rng.randi())


# --- Cliffs -------------------------------------------------------------------------------------

func _cliff(index: int, s: Array) -> void:
	var angles := _stretch(index, s, 12.0)
	var pine := index == 2 or index == 4
	for k in angles.size():
		var a := angles[k]
		var f := _frame(index, a)
		var face := cliff_face(index, a)
		if rng.randf() < 0.55:
			_tree(_ground(index, f, Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(4.0, face - 6.0))), rng.randf_range(1.0, 1.6), pine or rng.randf() < 0.3)
		if rng.randf() < 0.7:
			var g := rng.randi() % LEAVES.size()
			var sz := rng.randf_range(1.4, 2.6)
			_part("gorse", LEAVES[g].darkened(0.1), _ground(index, f, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(1.0, face - 2.0))), Vector3(0, sz * 0.25, 0), Vector3(sz, sz * 0.7, sz), Basis(), Batch.ball)
		# Fallen rock at the foot of the face, half in the water.
		for r in rng.randi_range(1, 3):
			var p := f * Vector3(rng.randf_range(-6, 6), 0, face + rng.randf_range(3.5, 12.0))
			var sz := rng.randf_range(2.0, 5.0)
			_part("boulder", ROCKS[rng.randi() % ROCKS.size()], Transform3D(f.basis, Vector3(p.x, rng.randf_range(-2.5, -1.0), p.z)), Vector3.ZERO, Vector3(sz, sz * 0.7, sz * 0.9), Basis(Vector3.UP, rng.randf() * TAU), Batch.ball, true, "concrete")
		if k == angles.size() / 2 and index == 0:
			_lookout(index, f)
		if k % 14 == 7:
			_sea_stack(f, cliff_top(index, a), face)
		if k % 20 == 10:
			Seagull.spawn(world.root, f * Vector3(0, 0, 20) + Vector3.UP * (height_at(index, f * Vector3(0, 0, 20)) + 10.0), rng.randi(), true)


## A rock pillar standing off the cliffs, its top still grassed over.
func _sea_stack(f: Transform3D, top: float, face: float) -> void:
	var r := rng.randf_range(4.0, 7.0)
	var h := top * rng.randf_range(0.55, 0.85) + 4.0
	var base := f * Vector3(rng.randf_range(-8, 8), 0, face + rng.randf_range(14.0, 24.0))
	var t := Transform3D(f.basis, Vector3(base.x, -4.0, base.z))
	var col: Color = ROCKS[rng.randi() % ROCKS.size()]
	_part("stack", col, t, Vector3(0, h * 0.5, 0), Vector3(r * 2.0, h, r * 1.8), Basis(Vector3.UP, rng.randf() * TAU), Batch.post, true, "concrete")
	_part("stack", col.darkened(0.1), t, Vector3(r * 0.6, h * 0.3, r * 0.3), Vector3(r * 1.4, h * 0.6, r * 1.3), Basis(), Batch.post, true, "concrete")
	_part("gorse", TURF.darkened(0.1), t, Vector3(0, h, 0), Vector3(r * 2.1, 1.6, r * 1.9), Basis(), Batch.ball)
	_solid(t, Vector3(0, h * 0.5, 0), Vector3(r * 1.6, h, r * 1.6))


## A coastguard lookout on the highest headland, flag flying.
func _lookout(index: int, f: Transform3D) -> void:
	var base := _ground(index, f, Vector3(0, 0, 12))
	_part("lookout", Color(0.97, 0.97, 0.94), base, Vector3(0, 2.0, 0), Vector3(5, 4, 5), Basis(), null, false, "plaster")
	_part("lookout_glass", Color(0.2, 0.3, 0.4), base, Vector3(0, 3.0, 0), Vector3(5.1, 1.0, 5.1), Basis(), null, false)
	_part("lookout_roof", Color(0.86, 0.2, 0.18), base, Vector3(0, 4.6, 0), Vector3(6, 1.2, 6), Basis(), Batch.cone, false)
	_part("lookout_mast", Color(0.85, 0.85, 0.82), base, Vector3(3.5, 5, 0), Vector3(0.15, 10, 0.15), Basis(), null, false)
	_part("lookout_flag", Color(0.2, 0.35, 0.75), base, Vector3(4.1, 9.4, 0), Vector3(1.2, 0.7, 0.04))
	_sign("COASTGUARD", base, Vector3(0, 3.0, 2.6), 0.0, 90, Color(0.15, 0.25, 0.6), 250.0)


# --- Sea wall -----------------------------------------------------------------------------------

func _wall(index: int, s: Array) -> void:
	var angles := _stretch(index, s, 3.0)
	var green := Color(0.16, 0.32, 0.28)
	for k in angles.size():
		var f := _frame(index, angles[k])
		_part("promenade", Color(0.8, 0.68, 0.56), f, Vector3(0, 0.03, -5.5), Vector3(3.15, 0.06, 17.0), Basis(), null, false, "paving")
		if k % 8 == 4:
			_part("planter", Color(0.7, 0.66, 0.6), f, Vector3(0, 0.35, -9.5), Vector3(2.2, 0.7, 2.2), Basis(), null, false, "concrete")
			_tree(_ground(index, f, Vector3(0, 0.7, -9.5)), rng.randf_range(0.9, 1.2), false)
			_solid(f, Vector3(0, 0.35, -9.5), Vector3(2.2, 0.7, 2.2))
		_part("rail_post", green, f, Vector3(0, 0.55, 2.6), Vector3(0.09, 1.1, 0.09), Basis(), null, false)
		_part("rail", green, f, Vector3(0, 1.08, 2.6), Vector3(3.05, 0.07, 0.07), Basis(), null, false)
		_part("rail", green, f, Vector3(0, 0.6, 2.6), Vector3(3.05, 0.05, 0.05), Basis(), null, false)
		if k % 12 == 0:
			_part("prom_lamp_post", green, f, Vector3(0, 2.4, 1.6), Vector3(0.14, 4.8, 0.14), Basis(), null, false)
			_part("prom_lamp", Color(1.0, 0.95, 0.75), f, Vector3(0, 4.9, 1.6), Vector3(0.5, 0.5, 0.5), Basis(), Batch.ball, false, "none", 2.0)
		if k % 16 == 8:
			_part("prom_bench", Color(0.55, 0.38, 0.22), f, Vector3(0, 0.45, 0.4), Vector3(1.8, 0.08, 0.5), Basis(), null, false, "wood")
			_part("prom_bench", Color(0.55, 0.38, 0.22), f, Vector3(0, 0.8, 0.12), Vector3(1.8, 0.45, 0.06), Basis(Vector3.RIGHT, -0.2), null, false, "wood")
			for x: float in [-0.8, 0.8]:
				_part("rail_post", green, f, Vector3(x, 0.22, 0.4), Vector3(0.08, 0.45, 0.4), Basis(), null, false)
		if k % 2 == 0:
			var p := f * Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(4.8, 9.0))
			var sz := rng.randf_range(1.6, 2.8)
			_part("boulder", ROCKS[rng.randi() % ROCKS.size()], Transform3D(f.basis, Vector3(p.x, rng.randf_range(-2.4, -1.6), p.z)), Vector3.ZERO, Vector3(sz, sz * 0.7, sz * 0.9), Basis(Vector3.UP, rng.randf() * TAU), Batch.ball, true, "concrete")


# --- Port ---------------------------------------------------------------------------------------

func _port(index: int, s: Array) -> void:
	var angles := _stretch(index, s, 12.0)
	var n := angles.size()
	var hall_k := n / 5
	var ship_k := n / 2
	var tank_k := n * 4 / 5
	var names: Array = PORT_NAMES.get(index, ["DOCKS", "SEA STAR"])
	for k in n:
		var f := _frame(index, angles[k])
		_part("quay_edge", Color(0.95, 0.78, 0.15), f, Vector3(0, 0.02, 35.5), Vector3(12.05, 0.04, 0.5), Basis(), null, false)
		_part("bollard", Color(0.2, 0.2, 0.22), f, Vector3(0, 0.35, 34.6), Vector3(0.45, 0.7, 0.45), Basis(), Batch.post, false)
		_part("fender", Color(0.1, 0.1, 0.1), f, Vector3(3, -1.2, 36.7), Vector3(1.6, 1.6, 0.6), Basis(), null, false)
		if k % 9 == 4:
			_crane(f)
		if k == hall_k:
			_ship_hall(f, names[0])
		elif k == tank_k:
			_tanks(f)
		elif absi(k - hall_k) > 2 and absi(k - tank_k) > 1:
			for row: float in [8.0, 15.5]:
				for x: float in [-3.05, 3.05]:
					var h := rng.randi_range(0, 4)
					if h > 0:
						_stack(f, Vector3(x, 0, row), h)
			if rng.randf() < 0.15:
				_forklift(f, Vector3(rng.randf_range(-4, 4), 0, 22.0))
		if k == ship_k:
			_ship(f, names[1])
	for k in 3:
		Seagull.spawn(world.root, _frame(index, angles[rng.randi() % n]) * Vector3(0, 24, 30), rng.randi(), true)


## A stack of shipping containers, lengthwise along the quay.
func _stack(f: Transform3D, lpos: Vector3, h: int) -> void:
	for k in h:
		_part("container", CONTAINERS[rng.randi() % CONTAINERS.size()], f, lpos + Vector3(0, 1.3 + k * 2.6, 0), Vector3(6.0, 2.58, 2.45), Basis(), null, true, "metal")
	_solid(f, lpos + Vector3(0, 1.3 * h, 0), Vector3(6.0, 2.6 * h, 2.45))


## A ship-to-shore gantry crane straddling the quay edge, boom out over the water.
func _crane(f: Transform3D) -> void:
	var col: Color = CRANES[rng.randi() % CRANES.size()]
	for x: float in [-7.0, 7.0]:
		for z: float in [25.5, 34.0]:
			_part("crane", col, f, Vector3(x, 14, z), Vector3(1.2, 28, 1.2), Basis(), null, true, "metal")
			_solid(f, Vector3(x, 1.5, z), Vector3(1.4, 3.0, 1.4))
		_part("crane", col, f, Vector3(x, 28, 29.75), Vector3(1.4, 1.4, 9.9), Basis(), null, true, "metal")
		_part("crane", col, f, Vector3(x, 12, 29.75), Vector3(1.0, 1.0, 9.9), Basis(), null, true, "metal")
	for z: float in [25.5, 34.0]:
		_part("crane", col, f, Vector3(0, 28, z), Vector3(15.2, 1.4, 1.4), Basis(), null, true, "metal")
	_part("crane", col, f, Vector3(0, 30.5, 40), Vector3(2.6, 2.2, 54), Basis(), null, true, "metal")
	_part("crane", col, f, Vector3(0, 36, 29.75), Vector3(2.0, 10, 2.0), Basis(), null, true, "metal")
	# Stays from the tower top out to the boom tip and back over the counterweight.
	for tip: Vector3 in [Vector3(0, 31.6, 66), Vector3(0, 31.6, 14)]:
		var top := Vector3(0, 41, 29.75)
		var d := tip - top
		_part("crane_stay", Color(0.3, 0.3, 0.32), f, (top + tip) * 0.5, Vector3(0.18, 0.18, d.length()), Basis(Vector3.RIGHT, -atan2(d.y, d.z)), null, false)
	_part("crane_house", Color(0.95, 0.95, 0.92), f, Vector3(0, 33.4, 18), Vector3(5, 3.6, 7), Basis(), null, false)
	_part("crane_cab", Color(0.2, 0.28, 0.36), f, Vector3(0, 28.6, 37), Vector3(2.2, 2.0, 2.2), Basis(), null, false)


## A freighter moored alongside, deck stacked with containers.
func _ship(f: Transform3D, ship_name: String) -> void:
	var hull := Color(0.18, 0.22, 0.32)
	_part("hull", hull, f, Vector3(-6, 1.0, 45), Vector3(110, 8.0, 16), Basis(), null, true, "metal")
	_part("hull_band", Color(0.6, 0.15, 0.12), f, Vector3(-6, -1.1, 45), Vector3(110.2, 1.6, 16.2), Basis(), null, false)
	_part("hull_deck", Color(0.55, 0.32, 0.25), f, Vector3(-6, 5.05, 45), Vector3(109.8, 0.1, 15.8), Basis(), null, false)
	# Bow: a prism laid flat, pointing along the quay.
	_part("hull", hull, f, Vector3(-68, 1.0, 45), Vector3(16, 14, 8), Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5), Batch.prism, true, "metal")
	for bay in 11:
		for col in 5:
			var h := rng.randi_range(0, 3)
			for k in h:
				_part("container", CONTAINERS[rng.randi() % CONTAINERS.size()], f, Vector3(-52 + bay * 6.4, 6.4 + k * 2.6, 40 + col * 2.5), Vector3(6.0, 2.58, 2.45), Basis(), null, true, "metal")
	_part("bridge", Color(0.95, 0.95, 0.92), f, Vector3(42, 11, 45), Vector3(10, 12, 14), Basis(), null, false, "painted")
	_part("bridge_glass", Color(0.2, 0.28, 0.36), f, Vector3(42, 15.8, 45), Vector3(10.1, 1.0, 14.1), Basis(), null, false)
	_part("bridge_wing", Color(0.95, 0.95, 0.92), f, Vector3(38.5, 16.6, 45), Vector3(3, 0.3, 18), Basis(), null, false)
	_part("funnel", Color(0.85, 0.25, 0.2), f, Vector3(46, 19.5, 45), Vector3(3.2, 5, 3.2), Basis(), Batch.post, false)
	_part("funnel_top", Color(0.1, 0.1, 0.1), f, Vector3(46, 22.3, 45), Vector3(3.3, 0.8, 3.3), Basis(), Batch.post, false)
	_solid(f, Vector3(-6, 1.0, 45), Vector3(110, 8.0, 16))
	_sign(ship_name, f, Vector3(-30, 3.2, 36.9), PI, 260, Color(0.95, 0.95, 0.92), 500.0)


## The shipbuilding hall: open to the sea, a new hull on blocks inside.
func _ship_hall(f: Transform3D, hall_name: String) -> void:
	var wall := Color(0.55, 0.62, 0.68)
	var h := 26.0
	_part("hall", wall, f, Vector3(0, h * 0.5, 2.5), Vector3(48, h, 1.0), Basis(), null, false, "metal")
	_solid(f, Vector3(0, h * 0.5, 2.5), Vector3(48, h, 1.0))
	for x: float in [-24.0, 24.0]:
		_part("hall", wall, f, Vector3(x, h * 0.5, 16), Vector3(1.0, h, 28), Basis(), null, false, "metal")
		_solid(f, Vector3(x, h * 0.5, 16), Vector3(1.0, h, 28))
	_part("hall_roof", Color(0.35, 0.4, 0.45), f, Vector3(0, h + 0.4, 16), Vector3(49.5, 0.8, 29), Basis(), null, false, "metal")
	_part("hall_band", Color(0.95, 0.78, 0.15), f, Vector3(0, h - 1.5, 30.2), Vector3(49.5, 3.0, 0.4), Basis(), null, false)
	_part("hall_crane", Color(0.95, 0.78, 0.15), f, Vector3(0, h - 4, 16), Vector3(46, 1.2, 1.6), Basis(), null, false)
	# The hull under construction: red primer below, bare steel above, on keel blocks.
	_part("newhull", Color(0.7, 0.25, 0.18), f, Vector3(-2, 3.5, 16), Vector3(34, 3.0, 11), Basis(), null, false, "metal")
	_part("newhull_top", Color(0.55, 0.58, 0.6), f, Vector3(-2, 7.0, 16), Vector3(34, 4.0, 11), Basis(), null, false, "metal")
	_part("newhull_top", Color(0.55, 0.58, 0.6), f, Vector3(19, 5.5, 16), Vector3(11, 8, 7), Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5), Batch.prism, false, "metal")
	for k in 6:
		_part("keelblock", Color(0.4, 0.3, 0.2), f, Vector3(-16 + k * 6, 1.0, 16), Vector3(1.2, 2.0, 3.0), Basis(), null, false, "wood")
	_solid(f, Vector3(0, 4.5, 16), Vector3(42, 9, 11))
	# Scaffolding along the near side.
	for k in 8:
		_part("scaffold", Color(0.75, 0.75, 0.72), f, Vector3(-17 + k * 4.6, 5.5, 9.6), Vector3(0.12, 11, 0.12), Basis(), null, false)
	for y: float in [3.0, 6.0, 9.0]:
		_part("scaffold", Color(0.75, 0.75, 0.72), f, Vector3(-1, y, 9.6), Vector3(33, 0.12, 0.12), Basis(), null, false)
		_part("scaffold_deck", Color(0.6, 0.45, 0.3), f, Vector3(-1, y - 0.1, 9.9), Vector3(33, 0.08, 0.8), Basis(), null, false, "wood")
	_sign(hall_name, f, Vector3(0, h - 1.5, 30.45), 0.0, 400, Color(0.12, 0.12, 0.12), 700.0)
	_sign(hall_name, f, Vector3(0, h - 4.0, 1.95), PI, 400, Color(0.95, 0.95, 0.92), 700.0)


func _tanks(f: Transform3D) -> void:
	for x: float in [-14.0, 0.0, 14.0]:
		var p := f * Vector3(x, 0, 16)
		Build.solid_cyl(world.root, 6.0, 11.0, Color(0.88, 0.88, 0.85), p + Vector3.UP * 5.5, 20)
		_part("tank_band", Color(0.2, 0.45, 0.35), Transform3D(f.basis, p), Vector3(0, 9.5, 0), Vector3(12.2, 1.0, 12.2), Basis(), Batch.post, false)
	_part("pipe", Color(0.6, 0.6, 0.62), f, Vector3(0, 1.0, 23.5), Vector3(32, 0.6, 0.6), Basis(), null, false)


func _forklift(f: Transform3D, lpos: Vector3) -> void:
	var yaw := Basis(Vector3.UP, rng.randf() * TAU)
	var y := Color(0.95, 0.72, 0.12)
	_part("forklift", y, f, lpos + yaw * Vector3(0, 0.9, 0), Vector3(1.3, 1.2, 2.2), yaw, null, false)
	_part("forklift_cage", Color(0.15, 0.15, 0.15), f, lpos + yaw * Vector3(0, 2.0, -0.2), Vector3(1.2, 1.0, 1.2), yaw, null, false)
	_part("forklift_cage", Color(0.15, 0.15, 0.15), f, lpos + yaw * Vector3(0, 1.4, 1.25), Vector3(1.0, 2.6, 0.12), yaw, null, false)
