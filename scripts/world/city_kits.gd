class_name CityKits
extends RefCounted
## Building kits that give Barea's ordinary blocks their own character: terraced streets and
## detached homes in the suburbs, courtyard flats and mixed frontages in town, parks and car
## parks for breathing room, and warehouse yards in the industrial north-west. Everything is
## drawn through BareaCity's batches, and solid volumes stay inside the 48 m lot so streets,
## roadblock gaps and street pockets are untouched. Deterministic: only the city's rng is used.

const HOUSES := [Color(0.93, 0.78, 0.62), Color(0.72, 0.84, 0.82), Color(0.95, 0.9, 0.78), Color(0.84, 0.6, 0.5), Color(0.78, 0.82, 0.62), Color(0.96, 0.84, 0.5), Color(0.7, 0.66, 0.78), Color(0.66, 0.42, 0.32)]
const HOUSE_BRICK := [3, 7]
const ROOFS := [Color(0.66, 0.3, 0.22), Color(0.3, 0.33, 0.38), Color(0.42, 0.3, 0.24), Color(0.3, 0.42, 0.38), Color(0.55, 0.22, 0.2)]
const MEMBRANES := [Color(0.22, 0.22, 0.24), Color(0.55, 0.53, 0.5), Color(0.72, 0.71, 0.68), Color(0.36, 0.48, 0.27)]
const DOORS := [Color(0.62, 0.16, 0.14), Color(0.16, 0.3, 0.5), Color(0.2, 0.42, 0.3), Color(0.95, 0.8, 0.3), Color(0.25, 0.2, 0.18)]
const CONTAINERS := [Color(0.75, 0.25, 0.18), Color(0.2, 0.4, 0.65), Color(0.25, 0.5, 0.3), Color(0.9, 0.65, 0.15), Color(0.55, 0.55, 0.58)]
const LEAVES := [Color(0.33, 0.52, 0.15), Color(0.48, 0.62, 0.2), Color(0.25, 0.43, 0.15)]
const PARAPET := Color(0.4, 0.38, 0.36)
const LAWN := Color(0.42, 0.58, 0.28)
const HALF := BareaCity.LOT * 0.5


# --- Shared pieces ---------------------------------------------------------------------------

## A flat roof: a coloured membrane inside a parapet rim, so roofs stop reading as grey lids.
static func flat_roof(city: BareaCity, c: Vector3, size: Vector3, h: float) -> void:
	var m := city.rng.randi() % MEMBRANES.size()
	city._tile("membrane", MEMBRANES[m], c + Vector3.UP * (h + 0.03), Vector3(size.x - 0.1, 0.06, size.z - 0.1))
	for s: float in [-1.0, 1.0]:
		city._tile("parapet", PARAPET, c + Vector3(0, h + 0.4, s * (size.z * 0.5 + 0.1)), Vector3(size.x + 0.6, 0.8, 0.4))
		city._tile("parapet", PARAPET, c + Vector3(s * (size.x * 0.5 + 0.1), h + 0.4, 0), Vector3(0.4, 0.8, size.z + 0.6))


## A pitched roof. ridge: the horizontal axis the ridge runs along; span: width across it.
static func gable(city: BareaCity, c: Vector3, ridge: Vector3, span: float, length: float, h: float, rise: float, roof_i: int) -> void:
	var yaw := PI * 0.5 if absf(ridge.x) > 0.5 else 0.0
	city._shape("gable", city._prism, ROOFS[roof_i], c + Vector3.UP * (h + rise * 0.5), Vector3(span + 0.8, rise, length + 0.5), yaw)


static func window(city: BareaCity, p: Vector3, face: Vector3, w: float, h: float) -> void:
	var lit := city.rng.randf() < 0.15
	var basis := Basis(Vector3.UP, atan2(face.x, face.z)) * Basis.from_scale(Vector3(w, h, 1))
	city._add("win_lit" if lit else "win", city._quad, Color(1.0, 0.9, 0.6) if lit else Color(0.24, 0.32, 0.4), Transform3D(basis, p), 1.2 if lit else 0.0)
	city._window_trim(p - face * 0.06, face, w, h)


## A lollipop tree: a trunk and two canopies, all in shared batches.
static func tree(city: BareaCity, p: Vector3, s := 1.0) -> void:
	var rng := city.rng
	city._shape("trunk", city._post, Color(0.43, 0.27, 0.13), p + Vector3.UP * 1.3 * s, Vector3(0.35, 2.6, 0.35) * s)
	var k := rng.randi() % LEAVES.size()
	city._shape("leaf", city._ball, LEAVES[k], p + Vector3.UP * 3.4 * s, Vector3(3.2, 2.8, 3.0) * s * rng.randf_range(0.85, 1.15))
	city._shape("leaf", city._ball, LEAVES[(k + 1) % LEAVES.size()], p + Vector3(0.7, 3.0, 0.4) * s, Vector3(2.0, 1.8, 2.0) * s)


static func lawn(city: BareaCity, c: Vector3, size: Vector2) -> void:
	city._tile("lawn", LAWN, c + Vector3.UP * 0.075, Vector3(size.x, 0.02, size.y))


## A house: walls, windows front and back, a front door, a pitched roof and maybe a chimney.
## face is the street side. Collision is optional so a terrace can share one body per row.
static func house(city: BareaCity, hc: Vector3, size: Vector3, face: Vector3, floors: int, collide: bool, gabled_front := false) -> void:
	var rng := city.rng
	var ci := rng.randi() % HOUSES.size()
	city._volume("brickhouse" if ci in HOUSE_BRICK else "house", HOUSES[ci], size, hc + Vector3.UP * size.y * 0.5, collide)
	var run := Vector3(absf(face.z), 0, absf(face.x))
	var frontage := absf(size.dot(run))
	var depth := absf(size.dot(face.abs()))
	var ridge := face.abs() if gabled_front else run
	var span := frontage if gabled_front else depth
	var length := depth if gabled_front else frontage
	var rise := span * rng.randf_range(0.32, 0.45)
	gable(city, hc, ridge, span, length, size.y, rise, rng.randi() % ROOFS.size())
	if rng.randf() < 0.55:
		var end := ridge * length * 0.3 * (1.0 if rng.randf() < 0.5 else -1.0)
		city._tile("chimney", Color(0.6, 0.32, 0.24), hc + end + Vector3.UP * (size.y + rise * 0.6), Vector3(0.8, rise * 0.9 + 0.6, 0.8))
	var n := maxi(1, int(frontage / 2.8))
	var door_k := 0 if rng.randf() < 0.5 else n - 1
	for f: Vector3 in [face, -face]:
		var wall := hc + f * (depth * 0.5 + 0.06)
		for fl in floors:
			for k in n:
				var p := wall + run * (-frontage * 0.5 + (k + 0.5) * frontage / n) + Vector3.UP * (1.6 + fl * 3.1)
				if fl == 0 and f == face and k == door_k:
					var di := rng.randi() % DOORS.size()
					city._tile("door", DOORS[di], Vector3(p.x, 1.05, p.z), Vector3(1.1, 2.1, 0.12), atan2(f.x, f.z))
					city._tile("step", Color(0.62, 0.6, 0.56), Vector3(p.x, 0.12, p.z) + f * 0.45, Vector3(1.6, 0.16, 0.8), atan2(f.x, f.z))
					continue
				window(city, p, f, minf(1.3, frontage / n * 0.55), 1.4)


static func container(city: BareaCity, p: Vector3, along_x: bool, stack := 1) -> void:
	var size := Vector3(6.0, 2.6, 2.5) if along_x else Vector3(2.5, 2.6, 6.0)
	for k in stack:
		var ci := city.rng.randi() % CONTAINERS.size()
		city._tile("container", CONTAINERS[ci], p + Vector3.UP * (1.3 + k * 2.6), size)
	city._solid(Vector3(size.x, 2.6 * stack, size.z), p + Vector3.UP * 1.3 * stack, 0.6)


# --- Residential ---------------------------------------------------------------------------

## Two rows of terraced houses back to back across a shared garden, gated at both ends.
static func terrace(city: BareaCity, c: Vector3) -> void:
	var rng := city.rng
	var along_x := rng.randf() < 0.5
	var run := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var across := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var depth := 10.0
	var inner := HALF - 1.0
	for side: float in [-1.0, 1.0]:
		var face := across * side
		var row_c := c + face * (HALF - 1.5 - depth * 0.5)
		var t := -inner
		var low := INF
		var gabled_front := rng.randf() < 0.3
		while t < inner - 0.5:
			var w := rng.randf_range(5.5, 7.5)
			if inner - (t + w) < 5.0:
				w = inner - t
			var floors := 2 if rng.randf() < 0.8 else 3
			var h := floors * 3.1 + 0.6
			low = minf(low, h)
			var size := run * w + across * depth + Vector3.UP * h
			house(city, row_c + run * (t + w * 0.5), size, face, floors, false, gabled_front)
			t += w
		# Houses differ only above the lowest eaves, so one body per row is enough.
		city._solid(run * inner * 2.0 + across * depth + Vector3.UP * low, row_c + Vector3.UP * low * 0.5)
	var garden := inner * 2.0 - 2.0 * (depth + 0.5)
	lawn(city, c, Vector2(inner * 2.0, garden) if along_x else Vector2(garden, inner * 2.0))
	for k in rng.randi_range(2, 4):
		tree(city, c + run * rng.randf_range(-inner + 3.0, inner - 3.0) + across * rng.randf_range(-garden, garden) * 0.3, rng.randf_range(0.8, 1.1))
	var shed := c + run * rng.randf_range(-12.0, 12.0)
	city._wall(run * 2.4 + across * 2.0 + Vector3.UP * 2.2, Color(0.5, 0.36, 0.22), shed + Vector3.UP * 1.1)
	city._tile("shedroof", Color(0.3, 0.33, 0.38), shed + Vector3.UP * 2.3, run * 2.8 + across * 2.4 + Vector3.UP * 0.12)
	# Garden walls close each open end, with a gate gap.
	var hedge := Color(0.27, 0.42, 0.2)
	for end: float in [-1.0, 1.0]:
		for s: float in [-1.0, 1.0]:
			var len := garden * 0.5 - 1.5
			city._wall(run * 0.8 + across * len + Vector3.UP * 1.3, hedge, c + run * end * (inner - 0.4) + across * s * (1.5 + len * 0.5) + Vector3.UP * 0.65)
	if rng.randf() < 0.4:
		city.ow.markers.items.append(c + run * rng.randf_range(-10.0, 10.0) + Vector3.UP * 0.1)


## Four detached houses set back behind front gardens, with driveways and the odd car.
static func detached(city: BareaCity, c: Vector3) -> void:
	var rng := city.rng
	lawn(city, c, Vector2(BareaCity.LOT - 0.5, BareaCity.LOT - 0.5))
	for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var qc := c + Vector3(q.x * 12.0, 0, q.y * 12.0)
		var face := Vector3(q.x, 0, 0) if rng.randf() < 0.5 else Vector3(0, 0, q.y)
		var run := Vector3(absf(face.z), 0, absf(face.x))
		var floors := 1 if rng.randf() < 0.25 else 2
		var depth := rng.randf_range(7.5, 9.0)
		var frontage := rng.randf_range(9.0, 12.0)
		var h := floors * 3.1 + 0.6
		var hc := qc - face * 2.0 + run * (q.dot(Vector2(run.x, run.z)) * -0.5)
		house(city, hc, run * frontage + face.abs() * depth + Vector3.UP * h, face, floors, true, rng.randf() < 0.5)
		# Driveway beside the house, out to the street.
		var side := run * (frontage * 0.5 + 1.8) * (-1.0 if q.dot(Vector2(run.x, run.z)) > 0 else 1.0)
		var drive_len := 12.0 - (-2.0 - depth * 0.5) - 0.5
		var drive_c := hc + side + face * (12.0 + 2.0 - drive_len * 0.5 - 0.3)
		city._tile("drive", Color(0.55, 0.53, 0.5), drive_c + Vector3.UP * 0.085, run * 3.2 + face.abs() * drive_len + Vector3.UP * 0.02)
		if rng.randf() < 0.45:
			city._parked(drive_c + face * 1.5, atan2(face.x, face.z), false)
		tree(city, qc + face * 7.5 - side * 0.6, rng.randf_range(0.7, 1.0))
		# Front hedge along the pavement, broken by the drive and a garden path.
		var edge := qc + face * 11.6
		var hedge := Color(0.27, 0.42, 0.2)
		var drive_off := side.dot(run)
		var gap_a := minf(drive_off, 0.0) - 1.8
		var gap_b := maxf(drive_off, 0.0) + 1.8
		for seg: Vector2 in [Vector2(-11.5, gap_a), Vector2(gap_b, 11.5)]:
			var len := seg.y - seg.x
			if len > 0.8:
				city._wall(run * len + face.abs() * 0.7 + Vector3.UP * 1.1, hedge, edge + run * (seg.x + len * 0.5) + Vector3.UP * 0.55)


## Mansion blocks around a courtyard, entered through a gap in one wing.
static func courtyard(city: BareaCity, c: Vector3, tall: bool) -> void:
	var rng := city.rng
	var ci := rng.randi() % BareaCity.FACADES.size()
	var h := rng.randf_range(16.0, 32.0) if tall else rng.randf_range(12.0, 22.0)
	var d := 11.0
	var outer := HALF - 1.0
	var gate := rng.randi() % 4
	var wings: Array = [
		[Vector3(0, 0, -outer + d * 0.5), Vector3(outer * 2.0, 0, d)],
		[Vector3(0, 0, outer - d * 0.5), Vector3(outer * 2.0, 0, d)],
		[Vector3(-outer + d * 0.5, 0, 0), Vector3(d, 0, outer * 2.0 - d * 2.0)],
		[Vector3(outer - d * 0.5, 0, 0), Vector3(d, 0, outer * 2.0 - d * 2.0)],
	]
	for w in 4:
		var off: Vector3 = wings[w][0]
		var size: Vector3 = wings[w][1]
		var parts: Array = [[off, size]]
		if w == gate:
			# Split the wing around a 6 m archway into the courtyard.
			var long_x := size.x > size.z
			var piece := ((size.x if long_x else size.z) - 6.0) * 0.5
			var step := Vector3(piece * 0.5 + 3.0, 0, 0) if long_x else Vector3(0, 0, piece * 0.5 + 3.0)
			var cut := Vector3(piece, 0, size.z) if long_x else Vector3(size.x, 0, piece)
			parts = [[off - step, cut], [off + step, cut]]
		for p: Array in parts:
			var pc: Vector3 = c + p[0]
			var ps: Vector3 = p[1]
			city._mass(ci, Vector3(ps.x, h, ps.z), pc + Vector3.UP * h * 0.5, true)
			city._windows(pc, Vector3(ps.x, h, ps.z), 4.5, 3.4, 1.5, false)
			flat_roof(city, pc, ps, h)
	var yard := outer * 2.0 - d * 2.0
	if rng.randf() < 0.5:
		lawn(city, c, Vector2(yard, yard))
	else:
		city._tile("plaza", Color(0.82, 0.76, 0.64), c + Vector3.UP * 0.075, Vector3(yard, 0.02, yard))
	tree(city, c, 1.4)
	for k in 2:
		var bp := c + Vector3(-5.0 + k * 10.0, 0, 5.0)
		Build.solid_box(city.root, Vector3(2.0, 0.5, 0.6), Color(0.5, 0.32, 0.18), bp + Vector3.UP * 0.25)
	city.ow.markers.items.append(c + Vector3(rng.randf_range(-6, 6), 0.1, -6))


## A frontage of two or three buildings of different heights, colours and shops.
static func mixed(city: BareaCity, c: Vector3) -> void:
	var rng := city.rng
	var along_x := rng.randf() < 0.5
	var n := rng.randi_range(2, 3)
	var cuts: Array[float] = []
	var total := 0.0
	for k in n:
		cuts.append(rng.randf_range(0.7, 1.3))
		total += cuts[k]
	var t := -HALF
	for k in n:
		var w := cuts[k] / total * BareaCity.LOT
		var off := Vector3(t + w * 0.5, 0, 0) if along_x else Vector3(0, 0, t + w * 0.5)
		var size := Vector3(w, 0, BareaCity.LOT) if along_x else Vector3(BareaCity.LOT, 0, w)
		# The ends of a row are corner buildings: tall enough to hold the corner.
		var h := rng.randf_range(16.0, 34.0) if k == 0 or k == n - 1 else rng.randf_range(8.0, 20.0)
		city._midrise(c + off, size, h, c)
		t += w


static func park(city: BareaCity, c: Vector3) -> void:
	var rng := city.rng
	lawn(city, c, Vector2(BareaCity.LOT, BareaCity.LOT))
	for axis: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		city._tile("parkpath", Color(0.78, 0.7, 0.55), c + Vector3.UP * 0.09, axis * BareaCity.LOT + Vector3(axis.z, 0, axis.x) * 3.5 + Vector3.UP * 0.02)
	# Fountain or bandstand where the paths cross.
	if rng.randf() < 0.5:
		Build.solid_cyl(city.root, 4.0, 0.8, Color(0.75, 0.72, 0.68), c + Vector3.UP * 0.4, 20)
		Build.cyl(city.root, 3.4, 3.4, 0.05, Color(0.3, 0.6, 0.75), c + Vector3.UP * 0.82, Vector3.ZERO, 20)
		Build.cyl(city.root, 0.4, 0.6, 2.2, Color(0.75, 0.72, 0.68), c + Vector3.UP * 1.9, Vector3.ZERO, 10)
		city._block_nav(c, Vector3(8, 0, 8), 0.3)
	else:
		Build.solid_cyl(city.root, 4.5, 0.6, Color(0.85, 0.82, 0.75), c + Vector3.UP * 0.3, 8)
		for k in 8:
			var a := k * TAU / 8.0
			city._shape("bandpost", city._post, Color(0.95, 0.95, 0.92), c + Vector3(cos(a) * 4.0, 2.1, sin(a) * 4.0), Vector3(0.2, 3.0, 0.2))
		city._shape("bandroof", city._cone, Color(0.2, 0.45, 0.35), c + Vector3.UP * 4.4, Vector3(10.0, 2.2, 10.0))
		city._block_nav(c, Vector3(9, 0, 9), 0.3)
	for qx: float in [-1.0, 1.0]:
		for qz: float in [-1.0, 1.0]:
			for k in rng.randi_range(2, 3):
				tree(city, c + Vector3(qx * rng.randf_range(6.0, 20.0), 0, qz * rng.randf_range(6.0, 20.0)), rng.randf_range(0.9, 1.4))
			var bp := c + Vector3(qx * 9.0, 0, qz * 2.8)
			Build.solid_box(city.root, Vector3(2.0, 0.5, 0.6), Color(0.5, 0.32, 0.18), bp + Vector3.UP * 0.25)
	# Railings round the edge, open where the paths meet the street.
	for f: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var run := Vector3(absf(f.z), 0, absf(f.x))
		for s: float in [-1.0, 1.0]:
			city._tile("railing", Color(0.15, 0.2, 0.18), c + f * (HALF - 0.2) + run * s * 13.0 + Vector3.UP * 0.55, run * 20.0 + f.abs() * 0.12 + Vector3.UP * 1.1)
	city.ow.markers.items.append(c + Vector3(rng.randf_range(-15, 15), 0.1, 2.0))


static func surface_carpark(city: BareaCity, c: Vector3) -> void:
	var rng := city.rng
	city._tile("lot_tarmac", Color(0.32, 0.33, 0.35), c + Vector3.UP * 0.075, Vector3(BareaCity.LOT, 0.02, BareaCity.LOT))
	for row: float in [-14.0, 0.0, 14.0]:
		for k in 9:
			var x := -19.0 + k * 4.75
			city._tile("bay", Color(0.92, 0.92, 0.88), c + Vector3(x - 2.375, 0.09, row), Vector3(0.15, 0.01, 5.0))
			if rng.randf() < 0.4:
				city._parked(c + Vector3(x, 0, row), 0.0, rng.randf() < 0.05)
	Build.solid_box(city.root, Vector3(2.4, 2.6, 2.4), Color(0.85, 0.75, 0.3), c + Vector3(HALF - 3.0, 1.3, HALF - 3.0))
	city._tile("boothroof", Color(0.25, 0.4, 0.7), c + Vector3(HALF - 3.0, 2.7, HALF - 3.0), Vector3(3.0, 0.2, 3.0))
	var s := city._sign("P", c + Vector3(HALF - 3.0, 4.2, HALF - 1.6), 0.0, 260, Color(1, 1, 1))
	s.visibility_range_end = 200.0


## A multi-storey car park: open decks on columns, a few cars left on the roof.
static func parking_garage(city: BareaCity, c: Vector3) -> void:
	var rng := city.rng
	var decks := rng.randi_range(3, 5)
	var size := BareaCity.LOT - 2.0
	var h := decks * 3.2
	city._tile("garage_core", Color(0.12, 0.13, 0.15), c + Vector3.UP * h * 0.5, Vector3(size - 1.6, h, size - 1.6))
	city._solid(Vector3(size, h, size), c + Vector3.UP * h * 0.5)
	for k in decks + 1:
		city._tile("deck", Color(0.68, 0.67, 0.64), c + Vector3.UP * (k * 3.2 + 0.5), Vector3(size, 1.0 if k > 0 else 0.2, size))
	for x: float in [-1.0, -0.33, 0.33, 1.0]:
		for z: float in [-1.0, 1.0]:
			city._tile("deckpost", Color(0.6, 0.59, 0.56), c + Vector3(x * size * 0.48, h * 0.5, z * size * 0.48), Vector3(0.6, h, 0.6))
	city._tile("deckstripe", Color(0.95, 0.75, 0.1), c + Vector3(0, 1.25, size * 0.5 + 0.02), Vector3(size, 0.25, 0.05))
	for k in rng.randi_range(2, 5):
		city._parked(c + Vector3(rng.randf_range(-18, 18), h + 1.0, rng.randf_range(-18, 18)), rng.randf() * TAU, false)
	var s := city._sign("P  PARKING", c + Vector3(0, h - 1.0, size * 0.5 + 0.4), 0.0, 260, Color(1, 1, 1))
	s.visibility_range_end = 260.0


# --- Industrial ------------------------------------------------------------------------------

## A shed with a sawtooth or barrel roof, roller shutters onto a yard of containers.
static func warehouse(city: BareaCity, c: Vector3) -> void:
	var rng := city.rng
	city._tile("yard", Color(0.5, 0.49, 0.46), c + Vector3.UP * 0.075, Vector3(BareaCity.LOT, 0.02, BareaCity.LOT))
	var ci: int = [3, 6, 2][rng.randi() % 3]
	var face := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][rng.randi() % 4] as Vector3
	var run := Vector3(absf(face.z), 0, absf(face.x))
	var depth := rng.randf_range(24.0, 30.0)
	var width := BareaCity.LOT - 4.0
	var h := rng.randf_range(8.0, 12.0)
	var sc := c - face * (HALF - 1.0 - depth * 0.5)
	var size := run * width + face.abs() * depth
	city._mass(ci, size + Vector3.UP * h, sc + Vector3.UP * h * 0.5, true)
	# A company-coloured dado and a strip of high windows break up the long walls.
	var band := rng.randi() % CONTAINERS.size()
	city._tile("dado", CONTAINERS[band], sc + Vector3.UP * 1.0, size + Vector3(0.12, 2.0, 0.12))
	city._tile("clerestory", Color(0.2, 0.3, 0.4), sc + Vector3.UP * (h - 1.6), size + Vector3(0.1, 1.2, 0.1))
	for f: Vector3 in [run, -run, face, -face]:
		var along := Vector3(absf(f.z), 0, absf(f.x))
		var wall := absf(size.dot(along))
		var n := int(wall / 4.0)
		for k in n:
			var p := sc + f * (absf(size.dot(f)) * 0.5 + 0.08) + along * (-wall * 0.5 + (k + 0.5) * wall / n) + Vector3.UP * (h - 1.6)
			city._tile("mullion", Color(0.85, 0.85, 0.82), p, along * 0.25 + f.abs() * 0.1 + Vector3.UP * 1.3)
	if rng.randf() < 0.55:
		# Sawtooth: north-light teeth with dark glazing on their steep faces.
		var teeth := 5
		var tw := width / teeth
		for k in teeth:
			var tc := sc + run * (-width * 0.5 + (k + 0.5) * tw) + Vector3.UP * (h + 1.4)
			var yaw := atan2(run.x, run.z) - PI * 0.5
			city._shape("sawtooth", city._ramp, Color(0.55, 0.57, 0.6), tc, Vector3(tw, 2.8, depth), yaw)
			city._tile("glazing", Color(0.2, 0.3, 0.4), tc + run * (-tw * 0.5 + 0.08), run * 0.1 + face.abs() * (depth - 0.2) + Vector3.UP * 2.6)
	else:
		# Barrel vault: a cylinder laid along the shed, squashed into a shallow curve.
		var across := run.cross(Vector3.UP)
		city._add("barrel", city._post, Color(0.55, 0.57, 0.6), Transform3D(Basis(across * depth, run * width, Vector3.UP * depth * 0.3), sc + Vector3.UP * h))
	city._tile("parapet", PARAPET, sc + Vector3.UP * (h + 0.2), size + Vector3(0.6, 0.4, 0.6))
	# Loading bays facing the yard.
	var front := sc + face * (depth * 0.5 + 0.06)
	for k in 3:
		var bay := front + run * (-12.0 + k * 12.0)
		city._tile("shutter", Color(0.7, 0.72, 0.74), bay + Vector3.UP * 2.4, run * 5.0 + face.abs() * 0.12 + Vector3.UP * 4.8)
		city._tile("bayband", Color(0.95, 0.75, 0.1), bay + face * 0.05 + Vector3.UP * 5.0, run * 5.6 + face.abs() * 0.15 + Vector3.UP * 0.3)
		city._tile("bumper", Color(0.12, 0.12, 0.12), bay + face * 0.25 + Vector3.UP * 0.9, run * 5.0 + face.abs() * 0.4 + Vector3.UP * 0.3)
	var sign := city._sign(["BAREA FREIGHT", "COLD STORE", "TOOL & DIE", "PALLET CO.", "BOTTLING"][rng.randi() % 5], front + face * 0.1 + Vector3.UP * (h - 1.6), atan2(face.x, face.z), 180, Color(0.15, 0.15, 0.15))
	sign.visibility_range_end = 200.0
	# Yard: stacked containers along the edge, the odd chimney.
	var yard := c + face * (HALF - (BareaCity.LOT - depth - 2.0) * 0.5)
	for k in rng.randi_range(1, 3):
		container(city, yard + run * (-17.0 + k * 9.0) + face * rng.randf_range(2.0, 4.0), face.z == 0.0, rng.randi_range(1, 2))
	if rng.randf() < 0.45:
		var stack := sc + run * width * 0.35 - face * depth * 0.2
		Build.solid_cyl(city.root, 1.1, h + 12.0, Color(0.62, 0.32, 0.24), stack + Vector3.UP * (h + 12.0) * 0.5, 12)
		city._tile("stackband", Color(0.9, 0.9, 0.88), stack + Vector3.UP * (h + 10.0), Vector3(2.4, 0.6, 2.4))
	city.ow.markers.items.append(yard + run * 14.0 + Vector3.UP * 0.1)


## A fenced storage yard: rows of stacked containers and a gatehouse.
static func container_yard(city: BareaCity, c: Vector3) -> void:
	var rng := city.rng
	city._tile("yard", Color(0.5, 0.49, 0.46), c + Vector3.UP * 0.075, Vector3(BareaCity.LOT, 0.02, BareaCity.LOT))
	var along_x := rng.randf() < 0.5
	for row: float in [-15.0, -5.0, 5.0, 15.0]:
		for k in 3:
			if rng.randf() < 0.2:
				continue
			var o := -12.0 + k * 12.0
			var p := c + (Vector3(o, 0, row) if along_x else Vector3(row, 0, o))
			container(city, p, along_x, rng.randi_range(1, 3))
	Build.solid_box(city.root, Vector3(3.0, 3.0, 3.0), Color(0.85, 0.85, 0.82), c + Vector3(HALF - 3.0, 1.5, -HALF + 3.0))
	city._tile("boothroof", Color(0.25, 0.4, 0.7), c + Vector3(HALF - 3.0, 3.1, -HALF + 3.0), Vector3(3.6, 0.2, 3.6))
	city.ow.markers.items.append(c + Vector3(0, 0.1, 0))
