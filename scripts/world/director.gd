class_name Director
extends Node
## The AI Director (host only). Keeps wandering infected ahead of the team, sends hordes and
## specials from out of sight, drops one Tank and one Witch per chapter, and runs the
## crescendo and finale events. Pacing follows L4D's rhythm: build up, peak, relax.

const WANDER_AHEAD_MIN := 30.0
const WANDER_AHEAD_MAX := 90.0
const WANDER_TARGET := 12

var level: Level
var flow: NavGrid.Flow
var lure_flow: NavGrid.Flow
var lure_pos := Vector3.INF
var active := false   # starts once someone leaves the start safe room
var relax_t := 0.0
var mob_t := 0.0
var special_t := 0.0
var wander_t := 0.0
var tank_at := -1.0   # progress (0..1) where this chapter's Tank shows up
var tank_alive := false
var crescendo_t := 0.0
var crescendo_wave := 0.0
var finale_stage := -1
var finale_t := 0.0
var finale_waves := 0
var pending: Array = []   # [{"type", "pos", "horde"}] spawned a few per frame
var _lure_t := 0.0
var _rng := RandomNumberGenerator.new()
var _flow_sources_t := 0.0


func _init(lvl: Level) -> void:
	level = lvl
	name = "Director"


func _ready() -> void:
	_rng.randomize()
	flow = NavGrid.Flow.new(level.nav)
	lure_flow = NavGrid.Flow.new(level.nav)
	lure_flow.max_dist = 60
	var ch: Dictionary = Game.chapter_data()
	if not level.open_world and ch.get("tank", false):
		tank_at = _rng.randf_range(0.35, 0.75)
	mob_t = _mob_interval() * 0.6
	special_t = _special_interval() * 0.5


func _mob_interval() -> float:
	return _rng.randf_range(85.0, 140.0) / Game.diff().horde


func _special_interval() -> float:
	return float(Game.diff().special_every) * _rng.randf_range(0.7, 1.3)


func _process(delta: float) -> void:
	if not Net.is_host() or Game.phase != "playing":
		return
	_update_flows(delta)
	_spawn_pending()
	if _lure_t > 0.0:
		_lure_t -= delta
		if _lure_t <= 0.0:
			lure_pos = Vector3.INF
	if not active:
		for s: Survivor in level.get_survivors():
			if not s.dead and not level.in_start_room(s.global_position):
				active = true
				break
		if not active:
			return
	relax_t = maxf(relax_t - delta, 0.0)
	_wanderers(delta)
	if crescendo_t > 0.0:
		_crescendo(delta)
	elif finale_stage >= 0:
		_finale(delta)
	else:
		_pacing(delta)
	_cull()


# --- Flow fields --------------------------------------------------------------------------

func _update_flows(_delta: float) -> void:
	if not flow.busy:
		var src: Array = []
		for s: Survivor in level.get_survivors():
			if not s.dead:
				var c := level.nav.nearest_walkable(s.global_position, 3)
				if c.x >= 0:
					src.append(c)
		flow.start(src)
	flow.step(6000)
	if lure_pos != Vector3.INF:
		if not lure_flow.busy:
			var c := level.nav.nearest_walkable(lure_pos, 3)
			lure_flow.start([c] if c.x >= 0 else [])
		lure_flow.step(3000)


func set_lure(p: Vector3, time: float) -> void:
	if lure_pos == Vector3.INF or p.distance_to(lure_pos) > 1.0:
		lure_flow.start([level.nav.nearest_walkable(p, 3)])
		while not lure_flow.step(100000):
			pass
	lure_pos = p
	_lure_t = maxf(_lure_t, time)


# --- Pacing ---------------------------------------------------------------------------------

func progress() -> float:
	var best := 0.0
	for s: Survivor in level.get_survivors():
		if not s.dead:
			best = maxf(best, level.progress_of(s.global_position))
	return best


func _pacing(delta: float) -> void:
	if level.open_world:
		for survivor: Survivor in level.get_survivors():
			if OpenWorld.land_index(survivor.global_position) == 1 and not tank_alive and tank_at != -2:
				tank_at = -2
				spawn_tank()
	if tank_at >= 0.0 and progress() >= tank_at and not tank_alive:
		tank_at = -1.0
		spawn_tank()
	if relax_t > 0.0:
		return
	mob_t -= delta
	if mob_t <= 0.0:
		mob_t = _mob_interval()
		spawn_mob(int(_rng.randi_range(14, 22) * Game.diff().horde), true)
	special_t -= delta
	if special_t <= 0.0:
		special_t = _special_interval()
		if not tank_alive:
			spawn_special()


func _wanderers(delta: float) -> void:
	wander_t -= delta
	if wander_t > 0.0:
		return
	wander_t = 2.5
	var lead := -1.0 if level.open_world else progress() * level.length_z()
	var count := 0
	for inf: Infected in level.all_infected():
		if inf.type == "common" and not inf.alert:
			count += 1
	var commons := level.count_commons()
	var want := mini(WANDER_TARGET - count, DB.MAX_COMMONS - commons)
	for i in mini(want, 4):
		var p := find_spawn(WANDER_AHEAD_MIN, WANDER_AHEAD_MAX, lead)
		if p != Vector3.INF:
			pending.append({"type": "common", "pos": p, "horde": false})


func _cull() -> void:
	# Commons that got left far behind just vanish, like in L4D.
	for inf: Infected in level.all_infected():
		if inf.type != "common" or inf.is_dead():
			continue
		var near := false
		for s: Survivor in level.get_survivors():
			if not s.dead and s.global_position.distance_to(inf.global_position) < 110.0:
				near = true
				break
		if not near:
			inf.queue_free()


## A random walkable spot `lo`..`hi` metres (walking distance) from the nearest survivor that
## nobody can see. With `ahead_z` >= 0 it prefers spots further along the map than that.
func find_spawn(lo: float, hi: float, ahead_z := -1.0) -> Vector3:
	var nav := level.nav
	for attempt in 220:
		var c := Vector2i(_rng.randi_range(0, nav.w - 1), _rng.randi_range(0, nav.h - 1))
		if level.open_world:
			var survivors := level.get_survivors().filter(func(s): return not s.dead and level.vehicle_for_slot(s.slot)==null)
			if survivors.is_empty(): return Vector3.INF
			var center: Vector3 = survivors[_rng.randi()%survivors.size()].global_position
			var angle := _rng.randf()*TAU
			var distance := _rng.randf_range(lo,hi)
			c = nav.cell_of(center+Vector3(cos(angle),0,sin(angle))*distance)
		if not nav.walkable(c):
			continue
		var d := flow.dist[nav.idx(c)] * nav.cell_size
		if d < lo or d > hi:
			continue
		var p := nav.center(c)
		if ahead_z >= 0.0 and p.z < level.start_z() + ahead_z and attempt < 160:
			continue
		if level.in_start_room(p) or level.in_end_room(p):
			continue
		if _seen(p):
			continue
		return p
	return Vector3.INF


func _seen(p: Vector3) -> bool:
	for s: Survivor in level.get_survivors():
		if s.dead:
			continue
		if s.global_position.distance_to(p) < 12.0:
			return true
		if level.open_world and s.global_position.distance_to(p)>45: continue
		if level.line_of_sight(s.eye_position(), p + Vector3.UP * 1.0):
			return true
	return false


func _spawn_pending() -> void:
	for i in mini(pending.size(), 3):
		var e: Dictionary = pending.pop_front()
		if e.type == "common" and level.count_commons() >= DB.MAX_COMMONS:
			continue
		level.spawn_infected(e.type, e.pos, e.horde)


func spawn_mob(n: int, music: bool) -> void:
	var spots: Array = []
	for i in 2:
		var p := find_spawn(28.0, 60.0)
		if p != Vector3.INF:
			spots.append(p)
	if spots.is_empty():
		return
	for i in n:
		var base: Vector3 = spots[i % spots.size()]
		var c := level.nav.nearest_walkable(base + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3)), 3)
		pending.append({"type": "common", "pos": level.nav.center(c) if c.x >= 0 else base, "horde": true})
	for inf: Infected in level.all_infected():
		inf.become_alert()
	if music:
		level.fx_sound.rpc("horde_music", Vector3.INF)
		level.fx_sound.rpc("scream", spots[0])


func spawn_special(type := "") -> void:
	var alive := {}
	var count := 0
	for inf: Infected in level.all_infected():
		if not inf.is_dead() and inf.type in DB.SPECIALS:
			alive[inf.type] = true
			count += 1
	if count >= int(Game.diff().max_specials):
		return
	if type == "":
		var options: Array = DB.SPECIALS.filter(func(t): return not alive.has(t))
		if options.is_empty():
			return
		type = options[_rng.randi() % options.size()]
	var p := find_spawn(22.0, 45.0)
	if p != Vector3.INF:
		level.spawn_infected(type, p, true)


func spawn_tank() -> void:
	var p := find_spawn(30.0, 55.0)
	if p == Vector3.INF:
		p = find_spawn(15.0, 80.0)
	if p == Vector3.INF:
		return
	tank_alive = true
	level.spawn_infected("tank", p, true)
	level.fx_sound.rpc("tank_music", Vector3.INF)
	Game.toast.rpc("TANK!", Color(1.0, 0.3, 0.2))


func on_tank_died() -> void:
	tank_alive = false
	for inf: Infected in level.all_infected():
		if inf.is_tank() and not inf.is_dead():
			tank_alive = true
	relax_t = 20.0


func on_witch_startled() -> void:
	level.fx_sound.rpc("witch_scream", Vector3.INF)


func place_witch() -> void:
	var spots: Array = level.markers.witch_spots.filter(func(p): return p.z > level.start_z() + 40.0 and level.nav.walkable_at(p))
	if spots.is_empty():
		return
	var p: Vector3 = spots[_rng.randi() % spots.size()]
	var w := level.spawn_infected("witch", p, false)
	if w:
		w.rotation.y = _rng.randf() * TAU
		w.net_yaw = w.rotation.y


# --- Crescendo (warehouse gate) and finale ---------------------------------------------------

func start_crescendo(duration: float) -> void:
	crescendo_t = duration
	crescendo_wave = 2.0
	level.fx_sound.rpc("horde_music", Vector3.INF)


func _crescendo(delta: float) -> void:
	crescendo_t -= delta
	crescendo_wave -= delta
	if crescendo_wave <= 0.0:
		crescendo_wave = 11.0
		spawn_mob(int(_rng.randi_range(10, 14) * Game.diff().horde), false)
		if _rng.randf() < 0.5:
			spawn_special()
	if crescendo_t <= 0.0:
		level.crescendo_done()
		relax_t = 15.0
		mob_t = _mob_interval()


func start_finale() -> void:
	finale_stage = 0
	_enter_stage()


func _enter_stage() -> void:
	Game.finale_stage = finale_stage
	Game.mark_dirty()
	finale_t = 0.0
	finale_waves = 0
	if finale_stage >= DB.FINALE.size():
		return
	var st: Dictionary = DB.FINALE[finale_stage]
	match st.kind:
		"tank":
			for i in int(st.count):
				spawn_tank()
		"rescue":
			level.start_rescue()
		"horde":
			level.fx_sound.rpc("horde_music", Vector3.INF)


func _finale(delta: float) -> void:
	if finale_stage >= DB.FINALE.size():
		return
	var st: Dictionary = DB.FINALE[finale_stage]
	finale_t += delta
	var next := false
	match st.kind:
		"horde":
			if finale_waves < int(st.count):
				if finale_t > 2.0 + finale_waves * 12.0:
					finale_waves += 1
					spawn_mob(int(_rng.randi_range(14, 20) * Game.diff().horde), false)
					if _rng.randf() < 0.6:
						spawn_special()
			elif finale_t > 2.0 + finale_waves * 12.0 + 4.0 and level.count_commons() < 6:
				next = true
		"wait":
			special_t -= delta
			if special_t <= 0.0:
				special_t = _special_interval()
				spawn_special()
			next = finale_t >= float(st.time)
		"tank":
			if finale_t > 3.0 and not tank_alive:
				next = true
			elif finale_t > 3.0 and fmod(finale_t, 15.0) < delta:
				spawn_mob(8, false)
		"rescue":
			# Keep the pressure on until everyone's aboard.
			if fmod(finale_t, 14.0) < delta:
				spawn_mob(int(12 * Game.diff().horde), false)
			if fmod(finale_t, 20.0) < delta:
				spawn_special()
	if next:
		finale_stage += 1
		_enter_stage()
