class_name Projectile
extends Node3D
## Thrown and spat things, plus the ground hazards they leave behind. Host-simulated.
##   pipe_bomb: beeps and draws the horde for 6 s, then explodes
##   molotov:   bursts into a fire patch       bile_jar: horde attacks wherever it lands
##   rock:      Tank boulder                   spit:     Spitter glob -> acid_pool
##   fire / acid_pool: ground hazards that hurt whoever stands in them

const GRAVITY := 14.0

var type := "pipe_bomb"
var attacker := -1
var vel := Vector3.ZERO
var net_pos := Vector3.ZERO
var net_landed := false
var _t := 0.0
var _life := 0.0
var _tick := 0.0
var _beep := 0.0
var _visual: Node3D
var _light: OmniLight3D
var _flames: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func setup(d: Dictionary) -> void:
	type = d.type
	attacker = int(d.get("attacker", -1))
	position = d.pos
	net_pos = d.pos
	vel = d.get("vel", Vector3.ZERO)
	_rng.seed = hash(d.name)


func _init() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_landed"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS if prop == "net_pos" else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


func level() -> Level:
	return get_parent().get_parent() as Level


func _ready() -> void:
	match type:
		"pipe_bomb", "molotov", "bile_jar":
			_visual = ItemModels.make(type)
			add_child(_visual)
			if type == "pipe_bomb":
				_light = _make_light(Color(1.0, 0.2, 0.1), 0.0, 4.0)
		"rock":
			_visual = Node3D.new()
			add_child(_visual)
			Build.sphere(_visual, 0.7, Color(0.4, 0.38, 0.35), Vector3.ZERO, Vector3(1, 0.8, 0.9), 7)
			Build.sphere(_visual, 0.45, Color(0.35, 0.33, 0.3), Vector3(0.4, 0.3, 0.1), Vector3.ONE, 6)
		"spit":
			_visual = Build.sphere(self, 0.25, Color(0.5, 1.0, 0.2), Vector3.ZERO, Vector3.ONE, 6)
			(_visual as MeshInstance3D).material_override = Build.mat(Color(0.5, 1.0, 0.2), 0.5, 3.0)
		"fire":
			_life = 15.0
			_light = _make_light(Color(1.0, 0.55, 0.2), 4.0, 9.0)
			for i in 14:
				var a := _rng.randf() * TAU
				var r := sqrt(_rng.randf()) * 3.0
				var f := Build.cyl(self, 0.0, _rng.randf_range(0.25, 0.45), _rng.randf_range(0.8, 1.8), Color(1.0, 0.5, 0.1), Vector3(cos(a) * r, 0.5, sin(a) * r))
				f.material_override = Build.mat(Color(1.0, 0.45 + _rng.randf() * 0.3, 0.1), 0.5, 4.0)
				_flames.append(f)
			Build.cyl(self, 3.2, 3.2, 0.02, Color(0.1, 0.06, 0.04), Vector3(0, 0.02, 0), Vector3.ZERO, 16)
			Sfx.play("fire", global_position + Vector3.UP, 4.0)
		"acid_pool":
			_life = 7.0
			_light = _make_light(Color(0.4, 1.0, 0.2), 2.0, 6.0)
			var pool := Build.cyl(self, 2.4, 2.4, 0.03, Color(0.45, 0.9, 0.15), Vector3(0, 0.03, 0), Vector3.ZERO, 16)
			pool.material_override = Build.mat(Color(0.45, 0.9, 0.15, 0.8), 0.2, 1.5)
			_flames.append(pool)
			Sfx.play("acid", global_position, 4.0)


func _make_light(c: Color, energy: float, rng_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng_m
	l.position.y = 0.6
	add_child(l)
	return l


func _physics_process(delta: float) -> void:
	_t += delta
	if Net.is_host():
		_host(delta)
		net_pos = global_position
	else:
		global_position = global_position.lerp(net_pos, clampf(delta * 15.0, 0.0, 1.0))
	_visuals(delta)


func _visuals(delta: float) -> void:
	if _visual and not net_landed:
		_visual.rotate_x(delta * 8.0)
	if type == "pipe_bomb" and net_landed:
		_beep -= delta
		var rate := 0.5 - minf(_t, 6.0) * 0.07
		if _beep <= 0.0:
			_beep = maxf(rate, 0.08)
			Sfx.play("beep", global_position, 2.0)
			_light.light_energy = 3.0
		_light.light_energy = maxf(_light.light_energy - delta * 20.0, 0.0)
	if type == "fire":
		for f in _flames:
			f.scale.y = 0.7 + 0.5 * absf(sin(_t * 9.0 + f.position.x * 3.0))
		_light.light_energy = 3.5 + sin(_t * 23.0) * 0.8 + sin(_t * 7.0)


func _host(delta: float) -> void:
	var lvl := level()
	match type:
		"fire":
			_life -= delta
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.25
				for inf: Infected in lvl.all_infected():
					if not inf.is_dead() and _flat_dist(inf.global_position) < 3.2:
						inf.ignite(attacker)
				for s: Survivor in lvl.get_survivors():
					if not s.dead and _flat_dist(s.global_position) < 3.0:
						s.host_damage(2.0 if attacker >= 0 else 4.0, Vector3.ZERO, "fire")
			if _life <= 0.0:
				queue_free()
			return
		"acid_pool":
			_life -= delta
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.33
				var ramp := lerpf(1.0, 6.0, 1.0 - _life / 7.0)
				for s: Survivor in lvl.get_survivors():
					if not s.dead and _flat_dist(s.global_position) < 2.4:
						s.host_damage(ramp * Game.diff().special_dmg, Vector3.ZERO, "acid")
			if _life <= 0.0:
				queue_free()
			return
		"pipe_bomb":
			if net_landed:
				lvl.director.set_lure(global_position, 0.5)
				if _t > 6.0:
					lvl.explode(global_position, 7.0, 400.0, attacker)
					queue_free()
				return
	# Flying
	var from := global_position
	vel.y -= GRAVITY * delta
	var to := from + vel * delta
	var mask := 1 | (2 if type in ["rock", "spit"] else 0) | (4 if type in ["molotov", "bile_jar"] else 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		if _t > 6.0:
			_land(global_position, Vector3.UP)
		return
	_land(hit.position, hit.normal)


func _land(p: Vector3, normal: Vector3) -> void:
	var lvl := level()
	match type:
		"pipe_bomb":
			# Bounce once or twice, then settle and start beeping.
			if vel.length() > 4.0 and normal.y > 0.3:
				vel = vel.bounce(normal) * 0.35
				global_position = p + normal * 0.1
				return
			global_position = p + Vector3.UP * 0.1
			vel = Vector3.ZERO
			net_landed = true
			_t = 0.0
		"molotov":
			lvl.fx_sound.rpc("glass", p)
			lvl.spawn_projectile("fire", Vector3(p.x, maxf(p.y, 0.0), p.z), Vector3.ZERO, attacker)
			queue_free()
		"bile_jar":
			lvl.fx_sound.rpc("glass", p)
			lvl.fx_bile.rpc(p + Vector3.UP * 0.3, Vector3.ZERO)
			lvl.director.set_lure(p, 15.0)
			lvl.director.spawn_mob(12, false)
			queue_free()
		"rock":
			lvl.fx_explosion.rpc(p, 1.5)
			for s: Survivor in lvl.get_survivors():
				if not s.dead and s.global_position.distance_to(p) < 2.6:
					var dir := s.global_position - p
					dir.y = 0
					s.host_damage(24.0 * Game.diff().special_dmg, dir.normalized(), "tank")
					if not s.incapped:
						s.host_knock(dir.normalized() * 8.0 + Vector3.UP * 4.0)
			queue_free()
		"spit":
			lvl.spawn_projectile("acid_pool", Vector3(p.x, maxf(p.y, 0.0), p.z), Vector3.ZERO, -1)
			queue_free()


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
