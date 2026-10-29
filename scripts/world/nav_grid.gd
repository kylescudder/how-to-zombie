class_name NavGrid
extends RefCounted
## 1 m walkability grid over the whole chapter (maps are flat, so 2D is enough).
## Infected follow flow fields (one BFS shared by the whole horde); bots use A*.

enum Cell { VOID, WALK, PROP, DOOR }

const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var cell_size := 1.0
var origin := Vector2.ZERO  # world x/z of cell (0, 0)'s corner
var w := 0
var h := 0
var cells := PackedByteArray()  # Cell per cell (what MapGen built there)
var walk := PackedByteArray()   # 1 = infected and bots can walk here right now
var zone := PackedByteArray()   # which MapGen zone a walkable cell belongs to (1-based)
var astar := AStarGrid2D.new()


func _init(width: int, height: int, world_origin: Vector2, resolution := 1.0) -> void:
	cell_size = resolution
	w = width
	h = height
	origin = world_origin
	cells.resize(w * h)
	walk.resize(w * h)
	zone.resize(w * h)


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x)/cell_size), floori((p.z - origin.y)/cell_size))


func center(c: Vector2i) -> Vector3:
	return Vector3(origin.x + (c.x + 0.5)*cell_size, 0.0, origin.y + (c.y + 0.5)*cell_size)


func cell_state(c: Vector2i) -> int:
	return cells[idx(c)] if inside(c) else Cell.VOID


func walkable(c: Vector2i) -> bool:
	return inside(c) and walk[idx(c)] == 1


func walkable_at(p: Vector3) -> bool:
	return walkable(cell_of(p))


func set_cell(c: Vector2i, state: int, z := 0) -> void:
	if not inside(c):
		return
	var i := idx(c)
	cells[i] = state
	walk[i] = 1 if state == Cell.WALK else 0
	if state == Cell.WALK and z > 0:
		zone[i] = z


## Opens or closes a door/gate's cells for pathing.
func set_open(r: Rect2i, open: bool) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if inside(c) and cells[idx(c)] == Cell.DOOR:
				walk[idx(c)] = 1 if open else 0
				astar.set_point_solid(c, not open)


func build_astar() -> void:
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2.ONE*cell_size
	astar.offset = origin + Vector2.ONE*cell_size*0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in h:
		for x in w:
			if walk[y * w + x] == 0:
				astar.set_point_solid(Vector2i(x, y), true)


## Closest walkable cell to p (searches outward a few metres).
func nearest_walkable(p: Vector3, radius := 6) -> Vector2i:
	var c := cell_of(p)
	if walkable(c):
		return c
	for r in range(1, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if walkable(n):
					return n
	return Vector2i(-1, -1)


## World-space path for bots. Empty if there's no route.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := nearest_walkable(from)
	var b := nearest_walkable(to)
	if a.x < 0 or b.x < 0:
		return out
	for p in astar.get_point_path(a, b):
		out.append(Vector3(p.x, 0.0, p.y))
	return out


## Straight walkable line between two points (cheap grid raymarch).
func clear_line(a: Vector3, b: Vector3) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var steps := int(d.length() / 0.5) + 1
	for i in steps + 1:
		var t := float(i) / steps
		if not walkable_at(a.lerp(b, t)):
			return false
	return true


class Flow:
	## Breadth-first distance from a set of source cells, computed a slice at a time so a big
	## map never causes a frame spike. Readers always see the last finished field.
	var grid: NavGrid
	var dist := PackedInt32Array()   # finished field (-1 = unreached)
	var _work := PackedInt32Array()
	var _queue := PackedInt32Array()
	var _head := 0
	var _tail := 0
	var max_dist := 220
	var busy := false
	var generation := 0

	func _init(g: NavGrid) -> void:
		grid = g
		dist.resize(g.w * g.h)
		dist.fill(-1)
		_work.resize(g.w * g.h)
		_queue.resize(g.w * g.h)

	func start(sources: Array) -> void:
		_work.fill(-1)
		_head = 0
		_tail = 0
		for s in sources:
			var c: Vector2i = s
			if grid.walkable(c) and _work[grid.idx(c)] == -1:
				_work[grid.idx(c)] = 0
				_queue[_tail] = grid.idx(c)
				_tail += 1
		busy = true

	## Processes up to `budget` cells. Returns true when a new field was published.
	func step(budget: int) -> bool:
		if not busy:
			return false
		var w := grid.w
		var walk := grid.walk
		var n := 0
		while _head < _tail and n < budget:
			var i := _queue[_head]
			_head += 1
			n += 1
			var d := _work[i] + 1
			if d > max_dist:
				continue
			var x := i % w
			var y := i / w
			for k in 8:
				var o: Vector2i = NEIGHBOURS[k]
				var nx := x + o.x
				var ny := y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= grid.h:
					continue
				var j := ny * w + nx
				if walk[j] == 0 or _work[j] != -1:
					continue
				if k >= 4 and (walk[y * w + nx] == 0 or walk[ny * w + x] == 0):
					continue  # no corner cutting
				_work[j] = d
				_queue[_tail] = j
				_tail += 1
		if _head >= _tail:
			var t := dist
			dist = _work
			_work = t
			busy = false
			generation += 1
			return true
		return false

	func distance_at(p: Vector3) -> int:
		var c := grid.cell_of(p)
		return dist[grid.idx(c)] if grid.inside(c) else -1

	## Direction to walk from p to get closer to the sources (ZERO if unknown or arrived).
	func dir_at(p: Vector3) -> Vector3:
		var c := grid.cell_of(p)
		if not grid.inside(c):
			return Vector3.ZERO
		var here := dist[grid.idx(c)]
		if here <= 0:
			return Vector3.ZERO
		var best := here
		var best_c := c
		for k in 8:
			var o: Vector2i = NEIGHBOURS[k]
			var n := c + o
			if not grid.inside(n):
				continue
			var d := dist[grid.idx(n)]
			if d < 0 or d >= best:
				continue
			if k >= 4 and (not grid.walkable(Vector2i(n.x, c.y)) or not grid.walkable(Vector2i(c.x, n.y))):
				continue
			best = d
			best_c = n
		if best_c == c:
			return Vector3.ZERO
		var to := grid.center(best_c) - Vector3(p.x, 0.0, p.z)
		to.y = 0.0
		return to.normalized()
