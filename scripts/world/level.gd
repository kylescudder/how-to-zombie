class_name Level
extends Node3D
## One island. Spawned by Main's LevelSpawner on every peer. Owns the entity spawner
## (players, zombies, projectiles) and all host-side rules: selling, gambling, explosions,
## bosses and the seagull that rescues downed players.

const MAX_CORPSES := 24
const GULL_DELAY_TEAM := 25.0
const GULL_DELAY_SOLO := 4.0

var island := 0
var markers := {}
var entities: Node3D
var spawner: MultiplayerSpawner
var _next_id := 1
var _rng := RandomNumberGenerator.new()
var _downed_time := {}  # peer -> seconds downed (host)
var _bobbers: Array[Node3D] = []
var _npcs: Array[Node] = []
var _boat_nodes: Array[Node] = []


func setup(idx: int) -> void:
	island = idx
	name = "Level%d" % idx


func _ready() -> void:
	_rng.randomize()
	add_to_group("level")
	_build_environment()
	var geo := Node3D.new()
	geo.name = "Geometry"
	add_child(geo)
	markers = Islands.build(geo, island)
	_build_water()
	for n in geo.find_children("*", "", true, false):
		if n.has_meta("idle_npc"):
			_npcs.append(n)
		if n.has_meta("bob"):
			_boat_nodes.append(n)

	entities = Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = NodePath("../Entities")
	spawner.spawn_function = _spawn_entity

	# Brain Bank hopper: drop or throw corpses in to sell them.
	var hopper := Area3D.new()
	hopper.collision_layer = 0
	hopper.collision_mask = 4
	hopper.position = markers.grinder
	add_child(hopper)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.6, 1.4, 2.6)
	cs.shape = bs
	hopper.add_child(cs)
	hopper.body_entered.connect(_on_hopper_body)

	for t in get_tree().get_nodes_in_group("trampoline"):
		if is_ancestor_of(t):
			t.body_entered.connect(_on_trampoline)

	if Net.is_host():
		Net.players_changed.connect(_sync_players)
		_sync_players()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for b in _boat_nodes:
		b.position.y = sin(t * 1.3) * 0.12
		b.rotation.z = sin(t * 0.9) * 0.03
	for n in _npcs:
		n.animate(delta, 0.0, 0.0)
		n.rotation.y = sin(t * 0.5) * 0.4
	if Net.is_host():
		_host_tick(delta)


# --- Entities -----------------------------------------------------------------

func _spawn_entity(data: Dictionary) -> Node:
	var node: Node
	match data.kind:
		"player":
			node = Player.new()
		"zombie":
			node = Zombie.new()
		"projectile":
			node = Projectile.new()
	node.setup(data)
	node.name = data.name
	return node


func _sync_players() -> void:
	for id in Net.players:
		if not entities.has_node("P%d" % id):
			var spawn: Vector3 = markers.spawn + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
			spawner.spawn({"kind": "player", "name": "P%d" % id, "peer": id, "pos": spawn})
	for p in get_players():
		if not Net.players.has(p.peer_id):
			p.queue_free()
	for p in get_players():
		p.refresh_cosmetics()


func get_players() -> Array:
	return entities.get_children().filter(func(n): return n is Player)


func get_zombies() -> Array:
	return entities.get_children().filter(func(n): return n is Zombie)


func get_player(peer_id: int) -> Player:
	return entities.get_node_or_null("P%d" % peer_id) as Player


func local_player() -> Player:
	return get_player(multiplayer.get_unique_id())


func spawn_zombie(type: String, pos: Vector3, vel: Vector3, size := 1.0, state := Zombie.State.AIR) -> Zombie:
	var data := {"kind": "zombie", "name": "Z%d" % _next_id, "type": type, "size": size, "pos": pos, "vel": vel, "state": state}
	_next_id += 1
	return spawner.spawn(data) as Zombie


func spawn_projectile(type: String, pos: Vector3, vel: Vector3, attacker: int) -> void:
	var data := {"kind": "projectile", "name": "X%d" % _next_id, "type": type, "pos": pos, "vel": vel, "attacker": attacker}
	_next_id += 1
	spawner.spawn(data)


## Velocity that lobs something from a to b in roughly `time` seconds.
static func lob_velocity(a: Vector3, b: Vector3, time: float, gravity := 9.8) -> Vector3:
	var d := b - a
	return Vector3(d.x / time, (d.y + 0.5 * gravity * time * time) / time, d.z / time)


# --- Host rules ---------------------------------------------------------------

func _host_tick(delta: float) -> void:
	# Corpse cap: oldest corpses sink into the sea.
	var corpses := get_zombies().filter(func(z): return z.state == Zombie.State.DEAD and z.holder == 0)
	if corpses.size() > MAX_CORPSES:
		corpses.sort_custom(func(a, b): return a.death_time < b.death_time)
		for i in corpses.size() - MAX_CORPSES:
			corpses[i].queue_free()

	# Seagull rescue for downed players.
	var players := get_players()
	var all_down := players.size() > 0 and players.all(func(p): return p.downed)
	for p in players:
		if not p.downed or p.gull_incoming:
			_downed_time.erase(p.peer_id)
			continue
		_downed_time[p.peer_id] = _downed_time.get(p.peer_id, 0.0) + delta
		var delay := GULL_DELAY_SOLO if (players.size() == 1 or all_down) else GULL_DELAY_TEAM
		if _downed_time[p.peer_id] >= delay:
			p.gull_incoming = true
			fx_gull.rpc(p.peer_id, markers.drop_spot)

	# Boss fell in the sea and drifted off / everyone wiped: keep fighting, it's fine.
	if Game.boss_alive and get_tree().get_nodes_in_group("boss").is_empty():
		Game.boss_alive = false
		Game.mark_dirty()


func _on_hopper_body(body: Node) -> void:
	if not Net.is_host() or not (body is Zombie):
		return
	var z := body as Zombie
	if z.state == Zombie.State.DEAD:
		sell(z, z.last_holder)


func sell(z: Zombie, seller: int) -> void:
	if not Net.is_host() or z.is_queued_for_deletion() or z.state != Zombie.State.DEAD:
		return
	var value := z.value
	Game.add_money(value)
	Game.event("sell", value)
	var who := Net.player_name(seller) if seller != 0 else "The tide"
	Game.toast.rpc("%s sold %s for %s%s" % [who, z.display_name(), DB.format_money(value), ("  (x%.1f)" % z.mult) if z.mult > 1.01 else ""])
	fx_popup.rpc(markers.grinder + Vector3(0, 1.5, 0), "+" + DB.format_money(value), Color(0.4, 1.0, 0.4), 96)
	fx_burst.rpc(markers.grinder, Color(0.5, 0.9, 0.3), 30, 6.0)
	fx_sound.rpc("cash", markers.grinder)
	fx_sound.rpc("squelch", markers.grinder)
	z.release_hold()
	z.queue_free()


func gamble(z: Zombie, peer: int) -> void:
	if not Net.is_host() or z.state != Zombie.State.DEAD or z.is_queued_for_deletion():
		return
	var rare := z.is_rare()
	var value := z.value
	z.release_hold()
	z.queue_free()
	Game.event("slot")
	fx_sound.rpc("spin", markers.slot)
	await get_tree().create_timer(1.2).timeout
	var locked_hats := DB.HATS.filter(func(h): return h not in Game.hats)
	var roll := _rng.randf()
	if (rare or roll < 0.15) and not locked_hats.is_empty():
		var hat: String = locked_hats[_rng.randi() % locked_hats.size()]
		Game.hats.append(hat)
		Game.mark_dirty()
		Game.save_game()
		fx_popup.rpc(markers.slot + Vector3(0, 2, 0), "NEW HAT!", Color(1.0, 0.8, 0.2), 110)
		fx_sound.rpc("jackpot", markers.slot)
		fx_burst.rpc(markers.slot + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.2), 60, 8.0)
		Game.toast.rpc("%s won the %s! Try it on at Doc's mirror." % [Net.player_name(peer), DB.HAT_NAMES[hat]])
	elif rare or roll < 0.45:
		var win := value * 3
		Game.add_money(win)
		fx_popup.rpc(markers.slot + Vector3(0, 2, 0), "JACKPOT +" + DB.format_money(win), Color(1.0, 0.85, 0.2), 110)
		fx_sound.rpc("jackpot", markers.slot)
		Game.toast.rpc("%s hit the jackpot: %s!" % [Net.player_name(peer), DB.format_money(win)])
	else:
		var duds := ["A single tooth.", "Lint.", "Nothing. The brain is judging you.", "A coupon for 0% off.", "One (1) toe."]
		fx_popup.rpc(markers.slot + Vector3(0, 2, 0), duds[_rng.randi() % duds.size()], Color(0.8, 0.8, 0.85), 64)
		fx_sound.rpc("deny", markers.slot)


func summon_boss(peer: int) -> void:
	if not Net.is_host() or not Game.has_bait or Game.boss_alive:
		return
	Game.has_bait = false
	Game.boss_alive = true
	Game.mark_dirty()
	var type: String = DB.ISLANDS[island].boss
	Game.toast.rpc("%s poured the chum... something BIG is coming!" % Net.player_name(peer))
	fx_burst.rpc(markers.chum, Color(0.6, 0.15, 0.1), 40, 4.0)
	fx_sound.rpc("splash", markers.chum)
	await get_tree().create_timer(2.5).timeout
	var from: Vector3 = markers.boss_spawn
	var z := spawn_zombie(type, from, lob_velocity(from, markers.boss_target, 2.4), 1.0)
	fx_sound.rpc("roar", from)
	fx_burst.rpc(Vector3(from.x, 0.2, from.z), Color(0.9, 0.95, 1.0), 80, 10.0)
	Game.toast.rpc("%s has risen from the deep!" % z.display_name())


func on_boss_killed(z: Zombie) -> void:
	Game.boss_alive = false
	Game.event("boss")
	fx_burst.rpc(z.global_position + Vector3.UP * 2, Color(1.0, 0.8, 0.2), 120, 14.0)
	fx_sound.rpc("jackpot", z.global_position)


## Damages zombies and (lightly) players in a radius. Host only.
func explode(pos: Vector3, radius: float, damage: float, knock: float, attacker: int, flags := {}) -> void:
	if not Net.is_host():
		return
	fx_explosion.rpc(pos, radius)
	var f := flags.duplicate()
	f["explosion"] = true
	for z in get_zombies():
		var d: float = z.global_position.distance_to(pos)
		if d > radius:
			continue
		var fall := 1.0 - d / radius * 0.6
		var dir: Vector3 = (z.global_position + Vector3.UP * 0.8 - pos).normalized()
		dir.y = max(dir.y, 0.45)
		z.take_hit(damage * fall, dir.normalized() * knock * fall, f, attacker, pos)
	for p in get_players():
		var d: float = p.global_position.distance_to(pos)
		if d > radius:
			continue
		var fall := 1.0 - d / radius * 0.6
		var dir: Vector3 = (p.global_position - pos).normalized()
		dir.y = 0.7
		p.host_damage(damage * 0.25 * fall if attacker > 0 else damage * fall, dir.normalized() * knock * 0.6 * fall)


func _on_trampoline(body: Node) -> void:
	if body is Player and body.is_multiplayer_authority():
		body.velocity.y = 17.0
		Sfx.play("plop", body.global_position, 0.0, 0.6)
	elif body is Zombie and Net.is_host():
		body.launch(Vector3(0, 16, 0))


# --- Effects (run on every peer) ---------------------------------------------

@rpc("authority", "call_local", "unreliable")
func fx_popup(pos: Vector3, text: String, color: Color, size: int = 72) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 18
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.006
	add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(0, 2.2, 0), 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.0)
	l.scale = Vector3.ONE * 0.2
	tw.tween_property(l, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(l.queue_free)


@rpc("any_peer", "call_local", "unreliable")
func fx_burst(pos: Vector3, color: Color, amount: int = 20, speed: float = 5.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = clampi(amount, 1, 200)
	p.lifetime = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.14
	m.material = Build.mat(color)
	p.mesh = m
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


@rpc("authority", "call_local", "unreliable")
func fx_explosion(pos: Vector3, radius: float) -> void:
	Sfx.play("explosion", pos)
	fx_burst(pos, Color(1.0, 0.55, 0.15), 50, radius * 2.5)
	fx_burst(pos, Color(0.3, 0.3, 0.3), 30, radius * 1.2)
	if DisplayServer.get_name() == "headless":
		return
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	s.mesh = sm
	s.material_override = Build.mat(Color(1.0, 0.75, 0.3, 0.85), 1.0, 3.0)
	add_child(s)
	s.global_position = pos
	s.scale = Vector3.ONE * 0.3
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * radius, 0.18)
	tw.tween_property(s, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(s.queue_free)
	var lp := local_player()
	if lp:
		lp.add_shake(clamp(1.0 - lp.global_position.distance_to(pos) / (radius * 4.0), 0.0, 1.0) * 0.6)


@rpc("any_peer", "call_remote", "unreliable")
func fx_tracer(from: Vector3, to: Vector3) -> void:
	draw_tracer(from, to)


func draw_tracer(from: Vector3, to: Vector3) -> void:
	if DisplayServer.get_name() == "headless" or from.distance_to(to) < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := from.distance_to(to)
	bm.size = Vector3(0.03, 0.03, len)
	mi.mesh = bm
	mi.material_override = Build.mat(Color(1.0, 0.95, 0.6), 1.0, 4.0)
	add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if abs((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1), 0.08)
	tw.tween_callback(mi.queue_free)


@rpc("any_peer", "call_local", "unreliable")
func fx_sound(sound: String, pos: Vector3) -> void:
	Sfx.play(sound, pos)


@rpc("authority", "call_local", "reliable")
func fx_gull(peer: int, drop: Vector3) -> void:
	var p := get_player(peer)
	if p == null:
		return
	var g := Gull.new()
	add_child(g)
	g.start(p, drop)


# --- Environment --------------------------------------------------------------

func _build_environment() -> void:
	var data: Dictionary = DB.ISLANDS[island]
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = data.sky_top
	sm.sky_horizon_color = data.sky_horizon
	sm.ground_horizon_color = data.sky_horizon
	sm.ground_bottom_color = data.water.darkened(0.4)
	sm.sun_angle_max = 30.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = data.fog
	env.fog_density = 0.006
	env.fog_sky_affect = 0.25
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _build_water() -> void:
	var data: Dictionary = DB.ISLANDS[island]
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 500)
	plane.subdivide_width = 160
	plane.subdivide_depth = 160
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://scripts/world/water.gdshader")
	sm.set_shader_parameter("deep_color", data.water)
	sm.set_shader_parameter("shallow_color", data.water.lightened(0.35))
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = DB.WATER_LEVEL
	add_child(mi)


## Is there water deep enough to fish at this XZ? Returns floor height (or -INF if open sea).
func floor_height(x: float, z: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 20, z), Vector3(x, -9, z), 1)
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else -INF
