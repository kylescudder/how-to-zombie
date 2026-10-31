class_name Level
extends Node3D
## One chapter. Spawned by Main's LevelSpawner on every peer; builds the same map everywhere
## from the chapter's seed. Owns the entity spawner (survivors, infected, projectiles,
## pickups) and every host-side rule: damage, revives, items, doors, the Director, and
## deciding when the chapter is won or lost.

## Bots hit for less, so the team stays the humans' to carry.
const BOT_DAMAGE := 0.6
const ITEM_TABLE := [
	["pills", 26], ["medkit", 7], ["pipe_bomb", 12], ["molotov", 12], ["bile_jar", 6],
	["bat", 4], ["axe", 3], ["machete", 3], ["pistol", 6], ["", 21],
]

var local_waypoint := Vector3.INF
var open_world := false
var chapter := 0
var markers := {}
var nav: NavGrid
var director: Director
var entities: Node3D
var spawner: MultiplayerSpawner
var doors: Array[Door] = []
var ammo_spots: Array = []
var rescue_ready := false
var gate_open := false
var gate_opening := false
var radio_used := false
var _gate: Node3D
var _gate_t := 0.0
var _boat: Node3D
var _boat_t := 0.0
var _next_id := 1
var _gen := 0
var _rng := RandomNumberGenerator.new()
var _end_t := 0.0
var _alarms_used := {}
var _toast_cb: Callable


func setup(d: Dictionary) -> void:
	chapter = int(d.chapter)
	open_world = d.get("open_world", false)


func _ready() -> void:
	_rng.randomize()
	add_to_group("level")
	LoadingScreen.report(0.02, 0)
	_build_environment()
	# Hidden while it builds: visible instances cost ~7 s of renderer time on the city's 50,000 meshes.
	var geo := Node3D.new()
	geo.name = "Geometry"
	geo.visible = false
	add_child(geo)
	var gen: Variant = OpenWorld.build(geo) if open_world else MapGen.build(geo, chapter)
	geo.visible = true
	LoadingScreen.report(0.82, 3)
	nav = gen.grid
	markers = gen.markers
	for n in geo.find_children("*", "Area3D", true, false):
		if n.get_meta("interact", "") == "ammo":
			ammo_spots.append((n as Node3D).global_position)
	for i in markers.doors.size():
		var d := Door.new()
		d.setup(i, markers.doors[i])
		add_child(d)
		doors.append(d)
		nav.set_open(d.cells, d.open)
	if not markers.gate.is_empty():
		_build_gate()
	if markers.button != Vector3.INF:
		Build.interact_zone(self, "button", Vector3(1.0, 1.4, 1.0), markers.button, "Open the gate (starts a horde!)")
	if open_world:
		_build_story()
	if markers.radio != Vector3.INF:
		Build.interact_zone(self, "radio", Vector3(1.4, 1.0, 1.0), markers.radio, "Use the radio (call for rescue)")
		_build_sea()
		_build_boat()

	entities = Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = NodePath("../Entities")
	spawner.spawn_function = _spawn_entity
	director = Director.new(self)
	add_child(director)

	if Net.is_host():
		Net.players_changed.connect(_sync_survivors)
		LoadingScreen.report(0.88, 4)
		_sync_survivors()
		LoadingScreen.report(0.92, 3)
		_place_items()
		if not open_world and Game.chapter_data().get("witch", false):
			director.place_witch()
	if Net.is_host() and open_world:
		for index in markers.vehicles.size():
			var data: Dictionary = markers.vehicles[index].duplicate()
			data.kind = "vehicle"
			data.name = "Vehicle%d" % index
			spawner.spawn(data)
		Game.show_banner.rpc("DEAD LOW TIDE — FREE ROAM", "Five islands. One squad. Take a vehicle and explore.")
	elif Net.is_host():
		Game.show_banner.rpc("CHAPTER %d: %s" % [chapter + 1, DB.CHAPTERS[chapter].name.to_upper()], DB.CAMPAIGN_NAME)


func _build_environment() -> void:
	var ch: Dictionary = DB.CHAPTERS[chapter]
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = ch.sky
	sm.sky_horizon_color = ch.fog.lightened(0.15)
	sm.ground_bottom_color = Color(0.02, 0.02, 0.03)
	sm.ground_horizon_color = ch.fog
	sm.sun_angle_max = 2.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62,0.73,0.76)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.fog_enabled = true
	env.fog_light_color = ch.fog
	env.fog_density = 0.00018 if open_world else 0.0035
	env.fog_sky_affect = 0.6
	env.glow_enabled = false
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, 35, 0)
	moon.light_color = Color(1.0,0.83,0.62)
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)


func _build_gate() -> void:
	_gate = Node3D.new()
	_gate.position = markers.gate.pos
	add_child(_gate)
	var w: float = markers.gate.width
	var body := StaticBody3D.new()
	body.collision_layer = 1
	_gate.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 7.0, 0.4)
	cs.shape = bs
	cs.position.y = 3.5
	body.add_child(cs)
	Build.box(body, Vector3(w, 7.0, 0.3), Color(0.45, 0.42, 0.38), Vector3(0, 3.5, 0))
	for i in 12:
		Build.box(body, Vector3(w, 0.08, 0.36), Color(0.35, 0.33, 0.3), Vector3(0, 0.4 + i * 0.55, 0))
	Build.box(body, Vector3(w, 0.4, 0.4), Color(0.8, 0.65, 0.1), Vector3(0, 0.2, 0))
	nav.set_open(markers.gate.rect, false)


func _build_sea() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	plane.subdivide_width = 60
	plane.subdivide_depth = 60
	water.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/water.gdshader")
	water.material_override = mat
	water.position = Vector3(0, -1.4, markers.end_z)
	add_child(water)


func _build_boat() -> void:
	_boat = Node3D.new()
	_boat.position = markers.boat_dock + Vector3(30, 0, 60)
	_boat.rotation.y = PI * 0.15
	add_child(_boat)
	Build.box(_boat, Vector3(5.0, 1.6, 12.0), Color(0.85, 0.85, 0.82), Vector3(0, -0.2, 0))
	Build.box(_boat, Vector3(4.6, 0.3, 11.0), Color(0.45, 0.32, 0.2), Vector3(0, 0.6, 0))
	Build.box(_boat, Vector3(3.0, 2.2, 3.5), Color(0.9, 0.9, 0.88), Vector3(0, 1.8, 1.5))
	Build.box(_boat, Vector3(3.05, 0.6, 3.55), Color(0.1, 0.15, 0.2), Vector3(0, 2.3, 1.5))
	Build.box(_boat, Vector3(5.05, 0.25, 12.05), Color(0.75, 0.15, 0.12), Vector3(0, 0.45, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.95, 0.8)
	l.light_energy = 4.0
	l.omni_range = 20.0
	l.position = Vector3(0, 4.0, 0)
	_boat.add_child(l)
	_boat.visible = false


func _process(delta: float) -> void:
	if _gate and gate_opening and not gate_open:
		_gate_t = minf(_gate_t + delta / 3.0, 1.0)
		_gate.position.y = markers.gate.pos.y + _gate_t * 6.6
	if _boat and _boat.visible:
		_boat_t = minf(_boat_t + delta / 12.0, 1.0)
		var from: Vector3 = markers.boat_dock + Vector3(30, 0, 60)
		_boat.position = from.lerp(markers.boat_dock, ease(_boat_t, 0.4)) + Vector3(0, sin(Time.get_ticks_msec() * 0.0015) * 0.12, 0)
		_boat.rotation.y = lerpf(PI * 0.15, 0.0, _boat_t)
	if Net.is_host():
		_host_tick(delta)


# --- Entities ---------------------------------------------------------------------------

func _spawn_entity(data: Dictionary) -> Node:
	var node: Node
	match data.kind:
		"survivor":
			node = Survivor.new()
		"infected":
			node = Infected.new()
		"projectile":
			node = Projectile.new()
		"pickup":
			node = Pickup.new()
		"vehicle":
			node = TeamVehicle.new()
	node.setup(data)
	node.name = data.name
	return node


func get_survivors() -> Array:
	return entities.get_children().filter(func(n): return n is Survivor and not n.is_queued_for_deletion())


func all_infected() -> Array:
	return entities.get_children().filter(func(n): return n is Infected and not n.is_queued_for_deletion())


func get_pickups() -> Array:
	return entities.get_children().filter(func(n): return n is Pickup and not n.is_queued_for_deletion())


func get_survivor(n: String) -> Survivor:
	if n == "":
		return null
	var s := entities.get_node_or_null(n) as Survivor
	return s if s and not s.is_queued_for_deletion() else null


func get_survivor_by_slot(slot: int) -> Survivor:
	for s: Survivor in get_survivors():
		if s.slot == slot:
			return s
	return null


func get_infected(n: String) -> Infected:
	if n == "":
		return null
	var i := entities.get_node_or_null(n) as Infected
	return i if i and not i.is_queued_for_deletion() else null


func local_survivor() -> Survivor:
	for s: Survivor in get_survivors():
		if s.is_me():
			return s
	return null


func count_commons() -> int:
	var n := 0
	for i: Infected in all_infected():
		if i.type == "common" and not i.is_dead():
			n += 1
	return n


func spawn_infected(type: String, pos: Vector3, horde: bool) -> Infected:
	var data := {"kind": "infected", "name": "I%d" % _next_id, "type": type, "pos": pos + Vector3.UP * 0.1, "horde": horde}
	_next_id += 1
	return spawner.spawn(data) as Infected


func spawn_projectile(type: String, pos: Vector3, vel: Vector3, attacker: int) -> void:
	var data := {"kind": "projectile", "name": "X%d" % _next_id, "type": type, "pos": pos, "vel": vel, "attacker": attacker}
	_next_id += 1
	spawner.spawn(data)


func spawn_pickup(item: String, pos: Vector3, extra := {}) -> void:
	var data := {"kind": "pickup", "name": "K%d" % _next_id, "item": item, "pos": pos, "yaw": _rng.randf() * TAU, "extra": extra}
	_next_id += 1
	spawner.spawn(data)


## Velocity that lobs something from a to b in roughly `time` seconds.
static func lob_velocity(a: Vector3, b: Vector3, time: float, gravity := 14.0) -> Vector3:
	var d := b - a
	return Vector3(d.x / time, (d.y + 0.5 * gravity * time * time) / time, d.z / time)


# --- Geometry queries --------------------------------------------------------------------

func line_of_sight(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func start_z() -> float:
	return (markers.start_room as Rect2).position.y


func length_z() -> float:
	return float(markers.end_z) - start_z()


func progress_of(p: Vector3) -> float:
	return clampf((p.z - start_z()) / maxf(length_z(), 1.0), 0.0, 1.0)


func in_start_room(p: Vector3) -> bool:
	if open_world:
		for index in OpenWorld.ISLANDS.size():
			if p.distance_to(OpenWorld.camp(index)) < 14: return true
		return false
	return (markers.start_room as Rect2).grow(0.3).has_point(Vector2(p.x, p.z))


func in_end_room(p: Vector3) -> bool:
	var r: Rect2 = markers.end_room
	return r.size.x > 0.0 and r.has_point(Vector2(p.x, p.z))


func respawn_point(s: Survivor) -> Vector3:
	for o: Survivor in get_survivors():
		if o != s and not o.dead:
			return o.global_position + Vector3.UP
	return markers.spawns[s.slot]


# --- Survivors: humans in their slots, bots everywhere else -----------------------------------

func _sync_survivors() -> void:
	for slot in DB.SURVIVORS.size():
		var want_peer := 0
		for id in Net.players:
			if Net.slot_of(id) == slot:
				want_peer = id
		var cur := get_survivor_by_slot(slot)
		if cur and ((cur.bot and want_peer == 0) or (not cur.bot and cur.peer_id == want_peer)):
			continue
		var st: Dictionary = Game.carry[slot] if Game.carry.size() > slot else {}
		var pos: Vector3 = markers.spawns[slot]
		var yaw := PI
		if cur:
			st = cur.respawn_state()
			st.dead = cur.dead
			st.incapped = cur.incapped
			st.hp = cur.hp
			pos = cur.global_position
			yaw = cur.rotation.y
			cur.queue_free()
		_gen += 1
		var data := {"kind": "survivor", "name": "S%d_%d" % [slot, _gen], "slot": slot, "peer": want_peer, "bot": want_peer == 0, "pos": pos, "yaw": yaw, "state": st}
		if want_peer!=0: data.appearance=Net.players[want_peer].get("appearance",{})
		var s := spawner.spawn(data) as Survivor
		if st.get("dead", false) or st.get("incapped", false):
			s.dead = bool(st.get("dead", false))
			s.incapped = bool(st.get("incapped", false))
			s.call_deferred("_push_health")
	# Late joiners need to know which doors are open etc. once their level exists.
	get_tree().create_timer(1.5).timeout.connect(_push_world_later)


func _push_world_later() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_push_world.rpc(_world_state())


func _place_items() -> void:
	if markers.get("deal_gun", Vector3.INF) != Vector3.INF:
		spawn_pickup("reduced_rifle", markers.deal_gun, {"price": int(DB.weapon("reduced_rifle").price)})
	for cache in markers.caches:
		var items: Array = cache.items
		var dir: Vector3 = cache.dir
		for i in items.size():
			var off := (i - (items.size() - 1) * 0.5) * 0.48
			spawn_pickup(items[i], cache.pos + dir * off)
	var total := 0
	for e in ITEM_TABLE:
		total += int(e[1])
	for p in markers.items:
		var roll := _rng.randi_range(0, total - 1)
		var item := ""
		for e in ITEM_TABLE:
			roll -= int(e[1])
			if roll < 0:
				item = e[0]
				break
		if item != "":
			spawn_pickup(item, p + Vector3.UP * 0.05)
	# A weapon cache roughly mid-map.
	if markers.items.size() > 4:
		var mid: Vector3 = markers.items[markers.items.size() / 2]
		var tier := "rifle" if chapter > 0 else "smg"
		spawn_pickup(tier, mid + Vector3(0.6, 0.05, 0))
		spawn_pickup("pump_shotgun" if chapter == 0 else "auto_shotgun", mid + Vector3(-0.6, 0.05, 0))


# --- Host rules -------------------------------------------------------------------------------

func _host_tick(delta: float) -> void:
	if open_world and Game.phase == "playing":
		_story_tick(delta)
	if Game.phase != "playing":
		_end_t -= delta
		if _end_t <= 0.0:
			_finish_phase()
		return
	var survivors := get_survivors()
	if survivors.is_empty():
		return
	# Lost: nobody left standing to help.
	var able := survivors.filter(func(s): return s.able())
	var humans_alive := survivors.filter(func(s): return not s.bot and not s.dead)
	var humans := survivors.filter(func(s): return not s.bot)
	if able.is_empty() or (humans.size() > 0 and humans_alive.is_empty()):
		Game.phase = "failed"
		Game.mark_dirty()
		Game.show_banner.rpc("MISSION FAILED", "Restarting the chapter...")
		_end_t = 6.0
		return
	if open_world: return
	# Won the chapter: every living person is inside the end safe room with the door shut.
	if markers.end_room.size.x > 0.0:
		var end_door: Door = null
		for d in doors:
			if d.kind == "end":
				end_door = d
		var inside := humans_alive.all(func(s): return in_end_room(s.global_position))
		if inside and end_door and not end_door.open and not humans_alive.is_empty():
			Game.phase = "complete"
			Game.mark_dirty()
			Game.show_banner.rpc("SAFE ROOM REACHED", "Chapter %d complete" % (chapter + 1))
			fx_sound.rpc("saferoom_music", Vector3.INF)
			_end_t = 6.0
			return
	# Rescued: everyone left alive is on the pier when the boat's in.
	if rescue_ready and _boat_t >= 1.0:
		var rz: Rect2 = markers.rescue_zone
		var standing := survivors.filter(func(s): return not s.dead and not s.incapped)
		var aboard := standing.filter(func(s): return rz.has_point(Vector2(s.global_position.x, s.global_position.z)))
		var humans_aboard := aboard.filter(func(s): return not s.bot)
		if not humans_aboard.is_empty() and humans_aboard.size() == humans_alive.filter(func(s): return not s.incapped).size():
			Game.phase = "victory"
			Game.mark_dirty()
			Game.show_banner.rpc("RESCUED!", "%d of 4 survivors made it out" % aboard.size())
			fx_sound.rpc("rescue_horn", Vector3.INF)
			_end_t = 20.0


func _finish_phase() -> void:
	match Game.phase:
		"complete":
			for s: Survivor in get_survivors():
				Game.carry[s.slot] = s.respawn_state()
			if chapter + 1 < DB.CHAPTERS.size():
				Game.goto_chapter(chapter + 1)
			else:
				Game.goto_chapter(chapter)
		"failed":
			# Wiped during Barea's escape: try the escape again from the hunt.
			if Game.story.get("barea", "") == "alert":
				Game.story.barea = "megamart"
				Game.story.event = ""
				Game.story.idol_carrier = -1
				Game.story.idol_drop = Vector3.INF
			Game.goto_chapter(chapter)
		"victory":
			Game.reset(0)
			Game.goto_chapter(0)


## Wakes up wandering commons near a loud noise (gunfire).
func make_noise(p: Vector3, radius: float) -> void:
	if not Net.is_host():
		return
	for inf: Infected in all_infected():
		if not inf.alert and inf.global_position.distance_to(p) < radius:
			inf.become_alert()


func bile_survivor(s: Survivor) -> void:
	if s.biled <= 0.0:
		director.spawn_mob(int(14 * Game.diff().horde), true)
		Game.toast.rpc("%s got puked on! Here they come!" % s.short_name(), Color(0.7, 1.0, 0.3))
	s.biled = 15.0
	s.set_biled.rpc(15.0)
	for inf: Infected in all_infected():
		if inf.type == "common":
			inf.become_alert()
			inf.target_name = s.name


func explode(p: Vector3, radius: float, dmg: float, attacker: int) -> void:
	fx_explosion.rpc(p, radius)
	for inf: Infected in all_infected():
		var d: float = inf.global_position.distance_to(p)
		if d < radius:
			inf.take_hit(dmg * (1.0 - d / radius * 0.5), false, (inf.global_position - p).normalized(), attacker, "blast")
	for s: Survivor in get_survivors():
		var d: float = s.global_position.distance_to(p)
		if d < radius * 0.6 and not s.dead:
			s.host_damage(10.0 * float(Game.diff().ff) + 2.0, (s.global_position - p).normalized(), "blast")
			s.host_knock((s.global_position - p).normalized() * 4.0 + Vector3.UP * 3.0)


func crescendo_done() -> void:
	if open_world:
		_event_done()
		return
	gate_open = true
	nav.set_open(markers.gate.rect, true)
	_set_gate.rpc(true, true)
	Game.toast.rpc("The gate is open! Go go go!", Color(0.6, 1.0, 0.5))


func start_rescue() -> void:
	rescue_ready = true
	_push_world.rpc(_world_state())
	Game.toast.rpc("The boat's coming! Get to the end of the pier!", Color(0.6, 1.0, 0.5))
	fx_sound.rpc("rescue_horn", Vector3.INF)


func _world_state() -> Dictionary:
	var ds := []
	for d in doors:
		ds.append(d.open)
	return {"doors": ds, "gate": gate_open, "gate_opening": gate_opening, "rescue": rescue_ready, "radio": radio_used, "story": Game.story}


@rpc("authority", "call_local", "reliable")
func _push_world(st: Dictionary) -> void:
	for i in mini(st.doors.size(), doors.size()):
		doors[i].set_open(st.doors[i])
	gate_opening = st.gate_opening
	if st.gate and not gate_open:
		gate_open = true
		_gate_t = 1.0
		if _gate:
			_gate.position.y = markers.gate.pos.y + 6.6
	rescue_ready = st.rescue
	if st.has("story"):
		Game.story = st.story
		_apply_story()
	radio_used = st.radio
	if _boat and rescue_ready:
		_boat.visible = true


@rpc("authority", "call_local", "reliable")
func _set_gate(opening: bool, opened: bool) -> void:
	gate_opening = opening
	if opened:
		gate_open = true
		_gate_t = 1.0
		if _gate:
			_gate.position.y = markers.gate.pos.y + 6.6
	if opening:
		Sfx.play("gate", markers.gate.pos + Vector3.UP * 3.0, 6.0)


# --- Requests from survivors' owners --------------------------------------------------------

func _sender_ok() -> bool:
	return Net.is_host()


@rpc("any_peer", "call_local", "reliable")
func request_hit(inf_name: String, dmg: float, headshot: bool, pos: Vector3, dir: Vector3, slot: int) -> void:
	if not _sender_ok():
		return
	var inf := get_infected(inf_name)
	if inf == null:
		return
	if inf.is_dead(): return
	var shooter := get_survivor_by_slot(slot)
	if shooter and shooter.bot: dmg *= BOT_DAMAGE
	inf.take_hit(dmg, headshot, dir, slot, "bullet")
	if shooter and not shooter.bot: shooter.confirm_hit.rpc_id(shooter.peer_id)
	_hit_feedback.rpc(pos, headshot, inf.is_dead())


@rpc("authority", "call_local", "unreliable")
func _hit_feedback(pos: Vector3, headshot: bool, killed: bool) -> void:
	if headshot and killed:
		Sfx.play("headshot", pos, -4.0)


@rpc("any_peer", "call_local", "reliable")
func request_ff(target: String, dmg: float, slot: int) -> void:
	if not _sender_ok():
		return
	var s := get_survivor(target)
	var mult: float = Game.diff().ff
	var shooter := get_survivor_by_slot(slot)
	if s == null or mult <= 0.0 or s.slot == slot or (shooter and shooter.bot):
		return
	s.host_damage(dmg * mult, Vector3.ZERO, "ff")
	Game.add_stat(slot, "ff", int(dmg * mult))
	if shooter and shooter.bot == false:
		_ff_warn.rpc("%s shot %s!" % [shooter.short_name(), s.short_name()])


@rpc("authority", "call_local", "reliable")
func _ff_warn(text: String) -> void:
	toast_local(text, Color(1.0, 0.6, 0.3))


@rpc("any_peer", "call_local", "reliable")
func request_shove(names: Array, mates: Array, dir: Vector3, slot: int) -> void:
	if not _sender_ok():
		return
	for n in names:
		var inf := get_infected(String(n))
		if inf:
			inf.shove(dir)
	for m in mates:
		var s := get_survivor(String(m))
		if s and s.pinned_by != "":
			var att := get_infected(s.pinned_by)
			if att:
				att.shove(dir)
			s.host_unpin()
			var by := get_survivor_by_slot(slot)
			if by:
				Game.toast.rpc("%s saved %s" % [by.short_name(), s.short_name()], Color(0.7, 0.9, 1.0))


@rpc("any_peer", "call_local", "reliable")
func request_throw(id: String, from: Vector3, vel: Vector3, slot: int) -> void:
	if not _sender_ok() or not (id in ["pipe_bomb", "molotov", "bile_jar"]):
		return
	spawn_projectile(id, from, vel, slot)


@rpc("any_peer", "call_local", "reliable")
func request_pickup(pickup_name: String, slot: int) -> void:
	if not _sender_ok():
		return
	var p := entities.get_node_or_null(pickup_name) as Pickup
	var s := get_survivor_by_slot(slot)
	if p == null or p.is_queued_for_deletion() or s == null or not s.able():
		return
	if p.global_position.distance_to(s.global_position) > 3.5 or not p.can_take(s):
		return
	var item := p.item
	var extra := p.extra.duplicate()
	if extra.has("price"):
		if Game.credits(slot) < int(extra.price):
			Game.toast.rpc("%s can't afford the %s (%d credits)." % [s.short_name(), DB.weapon(item).name, int(extra.price)], Color(1.0, 0.6, 0.3))
			return
		Game.arsenal[slot].credits -= int(extra.price)
		Game.mark_dirty()
		extra.erase("price")
		Game.toast.rpc("%s bought the %s. Bargain! (It won't last.)" % [s.short_name(), DB.weapon(item).name], Color(1.0, 0.85, 0.2))
	p.queue_free()
	s.receive_item.rpc_id(s.peer_id, item, extra)


@rpc("any_peer", "call_local", "reliable")
func request_drop(item: String, pos: Vector3, extra: Dictionary) -> void:
	if not _sender_ok():
		return
	spawn_pickup(item, Vector3(pos.x, maxf(pos.y - 0.4, 0.05), pos.z), extra)


@rpc("any_peer", "call_local", "reliable")
func request_revive(target: String, slot: int) -> void:
	if not _sender_ok():
		return
	var s := get_survivor(target)
	if s and s.incapped:
		s.host_revive()
		Game.add_stat(slot, "revives")
		var by := get_survivor_by_slot(slot)
		Game.toast.rpc("%s revived %s" % [by.short_name() if by else "Someone", s.short_name()], Color(0.7, 0.9, 1.0))


@rpc("any_peer", "call_local", "reliable")
func request_heal(target: String, _slot: int) -> void:
	if not _sender_ok():
		return
	var s := get_survivor(target)
	if s:
		s.host_heal()
		fx_sound.rpc("heal", s.global_position)


@rpc("any_peer", "call_local", "reliable")
func request_pills(target: String) -> void:
	if not _sender_ok():
		return
	var s := get_survivor(target)
	if s:
		s.host_pills()


@rpc("any_peer", "call_local", "reliable")
func request_give(target: String, item: String) -> void:
	if not _sender_ok():
		return
	var s := get_survivor(target)
	if s and item == "pills" and not s.net_inv.get("pills", false):
		s.receive_item.rpc_id(s.peer_id, "pills", {})


@rpc("any_peer", "call_local", "reliable")
func request_door(i: int) -> void:
	if not _sender_ok() or i < 0 or i >= doors.size():
		return
	var d := doors[i]
	var opening := not d.open
	nav.set_open(d.cells, opening)
	_push_world.rpc(_with_door(i, opening))


func _with_door(i: int, v: bool) -> Dictionary:
	var st := _world_state()
	st.doors[i] = v
	return st


@rpc("any_peer", "call_local", "reliable")
func request_button() -> void:
	if not _sender_ok() or gate_opening or gate_open:
		return
	gate_opening = true
	_set_gate.rpc(true, false)
	fx_sound.rpc("alarm", markers.button)
	Game.toast.rpc("The gate's grinding open... hold out!", Color(1.0, 0.7, 0.3))
	director.start_crescendo(45.0)


@rpc("any_peer", "call_local", "reliable")
func request_radio() -> void:
	if not _sender_ok() or radio_used:
		return
	radio_used = true
	_push_world.rpc(_world_state())
	fx_sound.rpc("radio", markers.radio)
	Game.toast.rpc("\"Rescue boat inbound. Hold out, survivors!\"", Color(0.6, 0.9, 1.0))
	director.start_finale()


@rpc("any_peer", "call_local", "reliable")
func request_alarm(i: int) -> void:
	if not _sender_ok() or _alarms_used.has(i):
		return
	_alarms_used[i] = true
	var p: Vector3 = markers.alarm_cars[i]
	Game.toast.rpc("Car alarm! Horde incoming!", Color(1.0, 0.5, 0.3))
	for k in 6:
		get_tree().create_timer(k * 1.0).timeout.connect(func(): fx_sound.rpc("alarm", p))
	director.spawn_mob(int(22 * Game.diff().horde), true)


# --- Effects --------------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func fx_sound(sound: String, pos: Vector3) -> void:
	Sfx.play(sound, pos, 4.0 if pos != Vector3.INF else -2.0)


@rpc("authority", "call_local", "reliable")
func fx_explosion(p: Vector3, radius: float) -> void:
	Sfx.play("explosion", p, 8.0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.25)
	flash.light_energy = 8.0
	flash.omni_range = radius * 3.0
	add_child(flash)
	flash.global_position = p + Vector3.UP
	var ball := Build.sphere(self, 1.0, Color(1.0, 0.55, 0.15), p + Vector3.UP * 0.5)
	ball.material_override = Build.mat(Color(1.0, 0.55, 0.15, 0.85), 0.5, 4.0)
	_burst(p + Vector3.UP * 0.5, Color(0.25, 0.22, 0.2), 30, 8.0, 1.2)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * radius * 0.8, 0.25)
	tw.tween_property(flash, "light_energy", 0.0, 0.5)
	tw.chain().tween_callback(func():
		ball.queue_free()
		flash.queue_free())
	var me := local_survivor()
	if me and me.global_position.distance_to(p) < radius * 3.0:
		me.add_shake(0.8)


@rpc("authority", "call_local", "reliable")
func fx_bile(p: Vector3, dir: Vector3) -> void:
	_burst(p, Color(0.55, 0.75, 0.15), 40, 6.0, 1.0, dir)


@rpc("authority", "call_local", "reliable")
func fx_smoke(p: Vector3) -> void:
	for i in 6:
		var puff := Build.sphere(self, 1.0, Color(0.5, 0.5, 0.45, 0.35), p + Vector3(_rng.randf_range(-2, 2), _rng.randf_range(0, 1.5), _rng.randf_range(-2, 2)), Vector3.ONE, 8)
		puff.material_override = Build.mat(Color(0.45, 0.45, 0.4, 0.35))
		var tw := create_tween()
		tw.tween_property(puff, "scale", Vector3.ONE * 2.2, 6.0)
		tw.tween_callback(puff.queue_free)
	Sfx.play("smoker", p, 4.0)


func fx_tracer_local(a: Vector3, b: Vector3) -> void:
	var d := a.distance_to(b)
	if d < 0.5:
		return
	# A short streak partway along the shot reads better than a beam the whole way.
	var t0 := randf_range(0.05, 0.35)
	var t1 := minf(t0 + 6.0 / d, 1.0)
	var p0 := a.lerp(b, t0)
	var p1 := a.lerp(b, t1)
	d = p0.distance_to(p1)
	a = p0
	b = p1
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, d)
	mi.mesh = bm
	mi.material_override = Build.mat(Color(1.0, 0.85, 0.55, 0.6), 0.5, 1.2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.04).timeout.connect(mi.queue_free)


func fx_blood_local(p: Vector3, dir: Vector3) -> void:
	_burst(p, Color(0.45, 0.04, 0.03), 8, 3.0, 0.5, dir)


func fx_spark_local(p: Vector3, normal: Vector3) -> void:
	_burst(p, Color(1.0, 0.85, 0.5), 4, 2.5, 0.25, normal)


func _burst(p: Vector3, c: Color, n: int, speed: float, life: float, dir := Vector3.ZERO) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.amount = n
	ps.lifetime = life
	ps.explosiveness = 1.0
	ps.direction = dir if dir != Vector3.ZERO else Vector3.UP
	ps.spread = 50.0 if dir != Vector3.ZERO else 180.0
	ps.initial_velocity_min = speed * 0.4
	ps.initial_velocity_max = speed
	ps.gravity = Vector3(0, -9.8, 0)
	ps.scale_amount_min = 0.5
	ps.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 4
	sm.rings = 2
	ps.mesh = sm
	ps.material_override = Build.mat(c, 0.6)
	add_child(ps)
	ps.global_position = p
	ps.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(ps.queue_free)


func toast_local(text: String, color := Color.WHITE) -> void:
	Game.toast_received.emit(text, color)


func at_gunsmith(s: Survivor) -> bool:
	if s == null or not s.able():
		return false
	for pos: Vector3 in markers.benches:
		if s.global_position.distance_to(pos) <= 3.0:
			return true
	return false


@rpc("any_peer", "call_local", "reliable")
func request_upgrade(slot: int, id: String, kind: String) -> void:
	if not Net.is_host() or Game.phase not in ["playing", "complete"]:
		return
	var s := get_survivor_by_slot(slot)
	var sender := multiplayer.get_remote_sender_id()
	if s == null or (sender != 0 and sender != s.peer_id) or (sender == 0 and s.peer_id != multiplayer.get_unique_id()):
		return
	if not at_gunsmith(s):
		return
	var owns := false
	for sl in ["primary", "secondary"]:
		if String(s.net_inv.get(sl, {}).get("id", "")) == id:
			owns = true
	if not owns:
		return
	Game.buy_upgrade(slot, id, kind)


func vehicle_for_slot(slot: int) -> TeamVehicle:
	if not entities: return null
	for entity in entities.get_children():
		if entity is TeamVehicle and slot in entity.seats: return entity
	return null

func vehicles() -> Array:
	return entities.get_children().filter(func(n): return n is TeamVehicle)


# --- Island stories (open world) ---------------------------------------------------------

var _idol: Node3D
var _siren_t := 0.0
var npcs: Array[StoryNPC] = []


func _build_story() -> void:
	for n: Dictionary in markers.get("npcs", []):
		var npc := StoryNPC.new()
		npc.setup(n.id, n.pos, n.yaw)
		add_child(npc)
		npcs.append(npc)
	if markers.get("idol", Vector3.INF) != Vector3.INF:
		_idol = Node3D.new()
		_idol.name = "Idol"
		_idol.position = markers.idol
		add_child(_idol)
		var art := YellowSticker.make(1.4)
		art.name = "Art"
		_idol.add_child(art)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.85, 0.3)
		glow.light_energy = 3.0
		glow.omni_range = 9.0
		_idol.add_child(glow)
		Build.interact_zone(_idol, "idol", Vector3(2.2, 2.6, 2.2), Vector3.ZERO, "Take the Yellow Sticker idol (one of you has to carry it)")
	if markers.get("keys", Vector3.INF) != Vector3.INF:
		_keys_zone = Build.interact_zone(self, "keys", Vector3(1.6, 1.6, 2.0), markers.keys, "Take the substation master keys (sets off the alarm!)")
	if markers.get("breaker", Vector3.INF) != Vector3.INF:
		_breaker_zone = Build.interact_zone(self, "breaker", Vector3(1.6, 2.0, 2.6), markers.breaker, "Throw the main breaker (90 s to power up - hold out!)")
	_apply_story()


func barea_stage() -> String:
	return String(Game.story.get("barea", "arrive"))


## Shows or hides story props to match Game.story (all peers).
func _apply_story() -> void:
	if _idol:
		# On its shrine before the alert; on the ground wherever its carrier went down during it.
		var drop: Vector3 = Game.story.get("idol_drop", Vector3.INF)
		var dropped := barea_stage() == "alert" and int(Game.story.get("idol_carrier", -1)) < 0 and drop != Vector3.INF
		_idol.visible = barea_stage() in ["arrive", "keys", "power", "megamart"] or dropped
		_idol.global_position = (drop + Vector3.UP * 1.0) if dropped else markers.idol
		_idol.scale = Vector3.ONE * (0.6 if dropped else 1.0)
		for c in _idol.get_children():
			if c is Area3D:
				(c as Area3D).collision_layer = 8 if _idol.visible else 0
	var stage := barea_stage()
	if _keys_zone:
		_keys_zone.collision_layer = 8 if stage == "keys" else 0
	if _breaker_zone:
		_breaker_zone.collision_layer = 8 if stage == "power" and not _event_running() else 0
	# Locks the story opens: the substation gate (with the keys), the Megamart shutters (with power).
	_set_lock(markers.get("sub_gate", {}), Story.reached(stage, "power"))
	_set_lock(markers.get("shutter", {}), Story.reached(stage, "megamart"))
	for n in npcs:
		var only_alert: bool = n.data.get("only_alert", false)
		n.visible = not only_alert or stage in ["alert", "escaped"]
		for c in n.find_children("*", "Area3D", true, false):
			(c as Area3D).collision_layer = 8 if n.visible else 0


func _set_lock(lock: Dictionary, open: bool) -> void:
	if lock.is_empty() or not is_instance_valid(lock.node):
		return
	var node: Node3D = lock.node
	nav.set_open(lock.rect, open)
	if open and not node.get_meta("opened", false):
		node.set_meta("opened", true)
		Sfx.play("gate", node.global_position, 4.0)
		var tw := create_tween()
		tw.tween_property(node, "position:y", node.position.y + 8.0, 3.0)
		for c in node.find_children("*", "CollisionShape3D", true, false):
			(c as CollisionShape3D).set_deferred("disabled", true)


func _event_running() -> bool:
	return String(Game.story.get("event", "")) != ""


## Seconds left on the current hold-out (any peer; the host stamps the end time).
func event_left() -> float:
	if not _event_running():
		return 0.0
	return maxf(float(Game.story.get("event_until", 0.0)) - Time.get_unix_time_from_system(), 0.0)


func _start_event(name: String, duration: float) -> void:
	Game.story.event = name
	Game.story.event_until = Time.get_unix_time_from_system() + duration
	Game.mark_dirty()
	director.start_crescendo(duration)
	_story_changed.rpc(Game.story)


## The director's crescendo ended: what that unlocks depends on which act we're in.
func _event_done() -> void:
	var ev := String(Game.story.get("event", ""))
	Game.story.event = ""
	match ev:
		"lockdown":
			Game.toast.rpc("The alarm's quiet. Head for Substation 4, north-west.", Color(0.6, 1.0, 0.5))
		"power":
			Game.story.barea = "megamart"
			Game.show_banner.rpc("THE GRID IS BACK", "The Megamart's shutters are rolling up. Head south.")
			fx_sound.rpc("rescue_horn", Vector3.INF)
	Game.mark_dirty()
	_story_changed.rpc(Game.story)


var _keys_zone: Area3D
var _breaker_zone: Area3D


@rpc("any_peer", "call_local", "reliable")
func request_keys(slot: int) -> void:
	if not _sender_ok() or barea_stage() != "keys":
		return
	var s := get_survivor_by_slot(slot)
	if s == null or not s.able() or s.global_position.distance_to(markers.keys) > 4.0:
		return
	Game.story.barea = "power"
	Game.show_banner.rpc("HOLDING-CELL ALARM", "%s took the keys. Hold out!" % s.short_name())
	fx_sound.rpc("alarm", markers.keys)
	_start_event("lockdown", Story.LOCKDOWN_TIME)


@rpc("any_peer", "call_local", "reliable")
func request_breaker(slot: int) -> void:
	if not _sender_ok() or barea_stage() != "power" or _event_running():
		return
	var s := get_survivor_by_slot(slot)
	if s == null or not s.able() or s.global_position.distance_to(markers.breaker) > 4.0:
		return
	Game.show_banner.rpc("POWERING UP", "Hold out while Substation 4 spins up the grid!")
	fx_sound.rpc("alarm", markers.breaker)
	_start_event("power", Story.POWER_TIME)


func _story_tick(delta: float) -> void:
	if _idol and _idol.visible:
		_idol.get_node("Art").rotation.y += delta * 0.8
	if barea_stage() != "alert":
		return
	# Whoever carries the idol drops it if they go down; someone has to grab it again.
	var carrier_slot := int(Game.story.get("idol_carrier", -1))
	if carrier_slot >= 0:
		var c := get_survivor_by_slot(carrier_slot)
		if c == null or c.dead or c.incapped:
			Game.story.idol_carrier = -1
			Game.story.idol_drop = c.global_position if c else markers.idol
			Game.mark_dirty()
			Game.toast.rpc("%s dropped the Yellow Sticker idol! Pick it up!" % (c.short_name() if c else "Someone"), Color(1.0, 0.75, 0.2))
			_story_changed.rpc(Game.story)
	# High alert: sirens, nonstop hordes, until everyone alive is on a boat out at sea.
	_siren_t -= delta
	if _siren_t <= 0.0:
		_siren_t = 5.5
		fx_sound.rpc("siren", Vector3.INF)
	var humans := get_survivors().filter(func(s): return not s.bot and not s.dead)
	if humans.is_empty():
		return
	if int(Game.story.get("idol_carrier", -1)) < 0:
		return  # you're not leaving without it
	var boat: TeamVehicle = null
	var carrier := get_survivor_by_slot(int(Game.story.idol_carrier))
	if carrier == null or vehicle_for_slot(carrier.slot) == null:
		return
	for s: Survivor in humans:
		var v := vehicle_for_slot(s.slot)
		if v == null or v.kind != "boat" or not v.ferry or (boat != null and v != boat):
			return
		boat = v
	if OpenWorld.land_index(boat.global_position, -170.0) == 0:
		return  # still too close to Barea's shore (the pier alone runs well out)
	if vehicle_for_slot(carrier.slot) != boat:
		return
	Game.story.barea = "escaped"
	Wardrobe.reward_escape()
	Game.mark_dirty()
	director.city_alert = false
	Game.show_banner.rpc("ESCAPED BAREA CITY", "The Yellow Sticker idol is yours. Next stop: the other islands.")
	fx_sound.rpc("rescue_horn", Vector3.INF)
	_story_changed.rpc(Game.story)


@rpc("any_peer", "call_local", "reliable")
func request_story_talk(npc_id: String) -> void:
	if not _sender_ok():
		return
	if barea_stage() == "arrive":
		Game.story.barea = "keys"
		Game.mark_dirty()
		Game.toast.rpc("New objective: the substation keys at Barea Police HQ, north-east.", Color(1.0, 0.85, 0.2))
		_story_changed.rpc(Game.story)


@rpc("any_peer", "call_local", "reliable")
func request_idol(slot: int) -> void:
	if not _sender_ok() or _idol == null or not _idol.visible:
		return
	var s := get_survivor_by_slot(slot)
	if s == null or not s.able() or s.global_position.distance_to(_idol.global_position) > 4.5:
		return
	if barea_stage() == "alert":
		# Picking a dropped idol back up.
		if int(Game.story.get("idol_carrier", -1)) >= 0:
			return
		Game.story.idol_carrier = slot
		Game.story.idol_drop = Vector3.INF
		Game.mark_dirty()
		Game.toast.rpc("%s has the idol again. Keep moving!" % s.short_name(), Color(1.0, 0.85, 0.2))
		_story_changed.rpc(Game.story)
		return
	if barea_stage() != "megamart":
		if barea_stage() in ["arrive", "keys", "power"]:
			Game.toast.rpc("The Megamart is shuttered. It needs power first.", Color(1.0, 0.7, 0.3))
		return
	Game.story.idol_carrier = slot
	Game.story.idol_drop = Vector3.INF
	Game.story.barea = "alert"
	Game.mark_dirty()
	director.city_alert = true
	director.relax_t = 0.0
	Game.show_banner.rpc("BAREA CITY IS ON HIGH ALERT", "%s took the Yellow Sticker idol." % s.short_name())
	Game.toast.rpc("Marla (radio): \"The harbour's overrun! I'm at the OLD FERRY TERMINAL on the west shore. Move!\"", Color(0.6, 0.9, 1.0))
	fx_sound.rpc("siren", Vector3.INF)
	fx_sound.rpc("horde_music", Vector3.INF)
	_story_changed.rpc(Game.story)


@rpc("authority", "call_local", "reliable")
func _story_changed(st: Dictionary) -> void:
	Game.story = st
	_apply_story()
	Game.state_changed.emit()


func npc(id: String) -> StoryNPC:
	for n in npcs:
		if n.id == id:
			return n
	return null
