class_name Zombie
extends RigidBody3D
## A zombie (or boss). Simulated on the host as a rigid body so hits send it tumbling;
## clients get a frozen copy that smoothly follows the host's transform.

enum State { AIR, WALK, ATTACK, TUMBLE, DEAD }

var type := "shambler"
var data: Dictionary
var size := 1.0
var state: int = State.AIR
var hp := 40.0
var max_hp := 40.0
var value := 0
var mult := 1.0
var holder := 0       # Peer currently carrying the corpse.
var last_holder := 0  # Who last touched it (credited when it falls in the grinder).
var death_time := 0.0
var boss := false

# Replicated
var net_pos := Vector3.ZERO
var net_rot := Quaternion.IDENTITY
var net_state := 0
var net_hp := 1.0
var net_attack := 0.0

var model: CharacterModel
var _rng := RandomNumberGenerator.new()
var _spawn_vel := Vector3.ZERO
var _settle := 0.0
var _air_time := 0.0
var _attack_t := 0.0
var _attack_cd := 0.0
var _ability_t := 3.0
var _ability2_t := 6.0
var _groan_t := 3.0
var _last_attacker := 0
var _last_flags := {}
var _target: Node3D
var _retarget := 0.0
var _upright_basis := Basis.IDENTITY
var _walk_dir := Vector3.ZERO
var _anim_speed := 0.0
var _head_shape_idx := 1
var _hold_grace := 0.0

static var _last_kill := {}  # attacker -> time, for multi-kills


func setup(d: Dictionary) -> void:
	type = d.type
	data = DB.ZOMBIES[type]
	size = float(d.get("size", 1.0)) * float(data.get("scale", 1.0))
	boss = data.get("boss", false)
	max_hp = float(data.hp) * (size if not boss else 1.0)
	hp = max_hp
	state = int(d.get("state", State.AIR))
	position = d.pos
	net_pos = d.pos
	_spawn_vel = d.get("vel", Vector3.ZERO)
	_rng.seed = hash(d.name)


func _init() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_rot", "net_state", "net_hp", "net_attack"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS if prop in ["net_pos", "net_rot"] else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


func _ready() -> void:
	add_to_group("zombies")
	if boss:
		add_to_group("boss")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	mass = 60.0 * size * size
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.15
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.9 * size, 0)
	angular_damp = 1.5
	linear_damp = 0.15
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	can_sleep = false

	var body_shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36 * size * float(data.get("belly", 1.0)) ** 0.5
	cap.height = 1.5 * size
	body_shape.shape = cap
	body_shape.position = Vector3(0, 0.75 * size, 0)
	add_child(body_shape)
	var head_shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.3 * size
	head_shape.shape = sph
	head_shape.position = Vector3(0, 1.72 * size, 0)
	add_child(head_shape)

	model = CharacterModel.new()
	add_child(model)
	model.scale = Vector3.ONE * size
	model.setup(data.skin, data.shirt, data.pants, true, float(data.get("belly", 1.0)), data.get("hat", "none"))
	if data.get("rare", false):
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m: StandardMaterial3D = mi.material_override
			if m:
				mi.material_override = Build.mat(m.albedo_color, 0.2, 0.5)
	if boss:
		var l := Build.label(self, data.name, Vector3(0, 2.4 * size + 0.6, 0), 96, Color(1.0, 0.4, 0.3))
		l.no_depth_test = true

	if Net.is_host():
		linear_velocity = _spawn_vel
		if state == State.AIR:
			angular_velocity = Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-2, 2), _rng.randf_range(-3, 3))
		lock_rotation = state == State.WALK
	else:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	global_position = net_pos


func display_name() -> String:
	return ("Huge " if size > 1.3 and not boss else ("Tiny " if size < 0.8 and type != "mini" else "")) + data.name


func is_rare() -> bool:
	return data.get("rare", false)


func is_dead() -> bool:
	return (state if Net.is_host() else net_state) == State.DEAD


func hp_fraction() -> float:
	return net_hp


func is_head_shape(shape_idx: int) -> bool:
	return shape_idx == _head_shape_idx


# --- Per-frame ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not Net.is_host():
		# Smoothly follow the host.
		var k := clampf(delta * 15.0, 0.0, 1.0)
		var prev := global_position
		global_position = global_position.lerp(net_pos, k) if global_position.distance_to(net_pos) < 6.0 else net_pos
		quaternion = quaternion.slerp(net_rot.normalized(), k)
		var spd := (global_position - prev).length() / maxf(delta, 0.0001)
		_anim_speed = lerp(_anim_speed, spd, 0.2)
		if net_state != State.DEAD:
			model.animate(delta, _anim_speed if net_state == State.WALK else 0.0, net_attack)
		return
	_host_physics(delta)
	net_pos = global_position
	net_rot = quaternion
	net_state = state
	net_hp = hp / max_hp


func _host_physics(delta: float) -> void:
	var in_water := global_position.y < DB.WATER_LEVEL - 0.4
	# Buoyancy: everything floats (corpses bob, zombies doggy-paddle).
	if global_position.y < DB.WATER_LEVEL - 0.6 * size:
		var depth := DB.WATER_LEVEL - 0.6 * size - global_position.y
		apply_central_force(Vector3.UP * mass * (9.8 + min(depth, 2.0) * 9.0) - linear_velocity * mass * 1.2)

	if holder != 0:
		_follow_holder(delta)

	match state:
		State.AIR, State.TUMBLE:
			_air_time += delta
			# Freshly hooked zombies sail through the pier/rails on the way up.
			var rising := state == State.AIR and linear_velocity.y > 0.0 and _air_time < 2.5
			collision_mask = (2 | 4) if rising else (1 | 2 | 4)
			var touching := get_contact_count() > 0 or in_water
			if touching and linear_velocity.length() < 1.6:
				_settle += delta
			else:
				_settle = max(_settle - delta * 0.5, 0.0)
			if _settle > (0.6 if state == State.AIR else 1.1) or _air_time > 7.0:
				_stand_up()
			model.animate(delta, 0.0, 0.0)
		State.WALK, State.ATTACK:
			_ai(delta, in_water)
		State.DEAD:
			pass
	_attack_cd = max(_attack_cd - delta, 0.0)


func _integrate_forces(s: PhysicsDirectBodyState3D) -> void:
	if not Net.is_host():
		return
	if state == State.WALK or state == State.ATTACK:
		var v := s.linear_velocity
		var spd: float = float(data.speed) * (0.55 if global_position.y < DB.WATER_LEVEL - 0.4 else 1.0)
		if state == State.ATTACK:
			spd *= 0.2
		var want := _walk_dir * spd
		v.x = lerp(v.x, want.x, 0.25)
		v.z = lerp(v.z, want.z, 0.25)
		s.linear_velocity = v
		s.angular_velocity = Vector3.ZERO
		if _walk_dir.length() > 0.1:
			var yaw := atan2(_walk_dir.x, _walk_dir.z)
			var cur := s.transform.basis.get_euler()
			var target := Basis(Vector3.UP, lerp_angle(cur.y, yaw, 0.15))
			s.transform = Transform3D(target, s.transform.origin)


func _ai(delta: float, in_water: bool) -> void:
	_retarget -= delta
	if _retarget <= 0.0 or not is_instance_valid(_target) or (_target is Player and _target.downed):
		_retarget = 1.0
		_target = _find_target()
	_groan_t -= delta
	if _groan_t < 0.0:
		_groan_t = _rng.randf_range(4.0, 9.0)
		get_level().fx_sound.rpc("groan" if not boss else "roar", global_position + Vector3.UP)

	var to := Vector3.ZERO
	var dist := 999.0
	if _target:
		to = _target.global_position - global_position
		to.y = 0
		dist = to.length()
	elif get_level():
		to = get_level().markers.spawn - global_position
		to.y = 0
		if to.length() < 3.0:
			to = Vector3.ZERO
	_walk_dir = to.normalized() if to.length() > 0.5 else Vector3.ZERO

	var reach := 1.1 + 0.45 * size
	if state == State.WALK:
		if _target and dist < reach and _attack_cd <= 0.0:
			state = State.ATTACK
			_attack_t = 0.0
		var spd := Vector2(linear_velocity.x, linear_velocity.z).length()
		model.animate(delta, spd, 0.0)
	elif state == State.ATTACK:
		_attack_t += delta
		var wind := 0.55 if not boss else 0.8
		net_attack = clamp(_attack_t / wind, 0.0, 1.0)
		model.animate(delta, 0.0, net_attack)
		if _attack_t >= wind:
			if _target is Player and dist < reach + 0.6:
				var push: Vector3 = to.normalized() * (4.0 + size * 3.0) + Vector3.UP * (2.0 + size)
				_target.host_damage(float(data.damage), push)
				get_level().fx_sound.rpc("hit", _target.global_position + Vector3.UP)
			state = State.WALK
			net_attack = 0.0
			_attack_cd = 1.1 if not boss else 1.6

	if boss:
		_boss_abilities(delta, dist)


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_d := 45.0 if not boss else 120.0
	var lvl := get_level()
	if lvl == null:
		return null
	for p in lvl.get_players():
		if p.downed:
			continue
		var d: float = p.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _stand_up() -> void:
	if state == State.DEAD:
		return
	collision_mask = 1 | 2 | 4
	_settle = 0.0
	_air_time = 0.0
	state = State.WALK
	lock_rotation = true
	var yaw := global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3.UP * 0.25)
	angular_velocity = Vector3.ZERO


func launch(impulse_vel: Vector3) -> void:
	if not Net.is_host():
		return
	if state != State.DEAD:
		state = State.TUMBLE
		lock_rotation = false
		_settle = 0.0
		_air_time = 0.0
	linear_velocity += impulse_vel
	angular_velocity += Vector3(_rng.randf_range(-4, 4), _rng.randf_range(-2, 2), _rng.randf_range(-4, 4))


# --- Damage & death (host) ---------------------------------------------------

func take_hit(damage: float, impulse: Vector3, flags: Dictionary, attacker: int, hit_pos: Vector3) -> void:
	if not Net.is_host() or is_queued_for_deletion():
		return
	var kick := impulse / maxf(size * size * (0.5 if not boss else 3.0), 0.3)
	if state == State.DEAD:
		# Corpses are physics toys: juggle them!
		linear_velocity += kick
		angular_velocity += Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-3, 3), _rng.randf_range(-6, 6))
		get_level().fx_burst.rpc(hit_pos, data.skin.darkened(0.3), 6, 3.0)
		return
	var before := hp
	hp -= damage
	_last_attacker = attacker
	_last_flags = flags
	get_level().fx_burst.rpc(hit_pos, Color(0.45, 0.75, 0.2), 10 if damage < 30 else 20, 4.0)
	if hp <= 0.0:
		collision_mask = 1 | 2 | 4
		_die(flags, attacker, damage > before * 2.0 and before > 10.0, hit_pos)
		linear_velocity += kick * 1.3
		angular_velocity += Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-3, 3), _rng.randf_range(-6, 6))
		return
	if kick.length() > (6.0 if not boss else 14.0):
		launch(kick)
	else:
		linear_velocity += kick * 0.3


func _die(flags: Dictionary, attacker: int, overkill: bool, hit_pos: Vector3) -> void:
	var lvl := get_level()
	var airborne := state in [State.AIR, State.TUMBLE] and get_contact_count() == 0 and not _near_ground(0.5)
	var in_water := global_position.y < DB.WATER_LEVEL - 0.3
	var bonuses: Array = []
	for f in ["headshot", "explosion", "slap", "melee", "homerun", "longshot", "chain", "harpoon"]:
		if flags.get(f, false):
			bonuses.append(f)
	if airborne:
		bonuses.append("airborne")
	if in_water:
		bonuses.append("water")
	if overkill:
		bonuses.append("overkill")
	var now := Time.get_ticks_msec() / 1000.0
	if attacker > 0 and now - float(_last_kill.get(attacker, -10.0)) < 1.5:
		bonuses.append("multikill")
	if attacker > 0:
		_last_kill[attacker] = now
	if "slap" in bonuses and "melee" in bonuses:
		bonuses.erase("melee")

	mult = 1.0
	for b in bonuses:
		mult += float(DB.BONUSES[b].value)
	var base := float(data.value) * (1.0 if boss else size * size)
	value = int(round(base * mult))
	state = State.DEAD
	death_time = now
	lock_rotation = false
	can_sleep = true
	add_to_group("corpses")
	remove_from_group("boss")
	net_attack = 0.0

	var top := global_position + Vector3.UP * (2.2 * size + 0.4)
	var i := 0
	for b in bonuses:
		lvl.fx_popup.rpc(top + Vector3.UP * 0.55 * i, "%s +%s" % [DB.BONUSES[b].text, str(DB.BONUSES[b].value)], Color(1.0, 0.85, 0.25), 64)
		i += 1
	lvl.fx_popup.rpc(top + Vector3.UP * 0.55 * i, ("x%.1f  " % mult if mult > 1.01 else "") + DB.format_money(value), Color(0.5, 1.0, 0.5) if mult < 2.0 else Color(1.0, 0.4, 0.9), 90 if mult < 2.0 else 120)
	lvl.fx_sound.rpc("die", global_position)
	lvl.fx_burst.rpc(hit_pos, Color(0.4, 0.75, 0.2), 25, 6.0)
	Game.event("kill", 1, {"mult": mult, "headshot": "headshot" in bonuses, "airborne": airborne, "type": type})
	if boss:
		lvl.on_boss_killed(self)
	if data.get("explodes", false):
		var r := 4.5 if not boss else 9.0
		lvl.call_deferred("explode", global_position + Vector3.UP, r, 45.0 if not boss else 80.0, 18.0, attacker, {"chain": true})


func _near_ground(dist: float) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * dist, 1)
	return not space.intersect_ray(q).is_empty() or global_position.y < DB.WATER_LEVEL


# --- Carrying corpses (host) ---------------------------------------------------

func try_grab(peer: int) -> bool:
	if state != State.DEAD or holder != 0:
		return false
	if boss or size > 2.0:
		return false  # Too heavy; kick it into the grinder instead.
	holder = peer
	last_holder = peer
	gravity_scale = 0.0
	_hold_grace = 0.75  # The owner's hold point takes a moment to replicate.
	return true


func release_hold(throw_vel := Vector3.ZERO) -> void:
	holder = 0
	gravity_scale = 1.0
	if throw_vel != Vector3.ZERO:
		linear_velocity = throw_vel
		angular_velocity = Vector3(_rng.randf_range(-5, 5), _rng.randf_range(-3, 3), _rng.randf_range(-5, 5))


func _follow_holder(delta: float) -> void:
	var p: Player = get_level().get_player(holder)
	if p == null or p.downed:
		release_hold()
		return
	_hold_grace -= delta
	var hold: Vector3 = p.net_hold
	if _hold_grace > 0.0 or hold.distance_to(p.global_position) > 4.0:
		hold = p.global_position + Vector3.UP * 1.4 - p.global_transform.basis.z * 2.0
	var target: Vector3 = hold - Vector3.UP * 0.9 * size
	var to := target - global_position
	if to.length() > 7.0 and _hold_grace <= 0.0:
		release_hold()
		return
	linear_velocity = to * 12.0
	angular_velocity *= 0.8


# --- Bosses ---------------------------------------------------------------------

func _boss_abilities(delta: float, dist: float) -> void:
	var lvl := get_level()
	_ability_t -= delta
	_ability2_t -= delta
	var tpos: Vector3 = _target.global_position if _target else lvl.markers.spawn
	match type:
		"big_bloaty":
			if _ability_t <= 0.0:
				_ability_t = 7.0
				lvl.fx_sound.rpc("squelch", global_position)
				for i in 3:
					var dest := tpos + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
					var from := global_position + Vector3.UP * 2.5 * size
					lvl.spawn_zombie("mini", from, Level.lob_velocity(from, dest, 1.2), 1.0)
			if _ability2_t <= 0.0 and dist < 6.0:
				_ability2_t = 4.0
				_stomp(7.0, 15.0)
		"grill_dad":
			if _ability_t <= 0.0:
				_ability_t = 2.8
				var from := global_position + Vector3.UP * 2.2 * size
				lvl.spawn_projectile("patty", from, Level.lob_velocity(from, tpos + Vector3.UP, 1.1), 0)
			if _ability2_t <= 0.0:
				_ability2_t = 10.0
				for i in 2:
					var from := global_position + Vector3.UP * 2.0 * size
					lvl.spawn_zombie("runner", from, Level.lob_velocity(from, tpos + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)), 1.3))
		"mall_santa":
			if _ability_t <= 0.0:
				_ability_t = 5.5
				for i in 3:
					var from := global_position + Vector3.UP * 2.4 * size
					var dest := tpos + Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
					lvl.spawn_projectile("present", from, Level.lob_velocity(from, dest, 1.3), 0)
			if _ability2_t <= 0.0:
				_ability2_t = 11.0
				lvl.fx_sound.rpc("roar", global_position)
				for i in 4:
					var from := global_position + Vector3.UP * 2.4 * size
					lvl.spawn_zombie("mini", from, Level.lob_velocity(from, tpos + Vector3(_rng.randf_range(-7, 7), 0, _rng.randf_range(-7, 7)), 1.4))
			if dist < 6.0 and _attack_cd <= 0.0 and _rng.randf() < delta:
				_stomp(7.0, 18.0)


func _stomp(radius: float, knock: float) -> void:
	var lvl := get_level()
	lvl.fx_burst.rpc(global_position, Color(0.85, 0.8, 0.6), 40, 7.0)
	lvl.fx_sound.rpc("explosion", global_position)
	for p in lvl.get_players():
		var d: float = p.global_position.distance_to(global_position)
		if d < radius:
			var dir: Vector3 = (p.global_position - global_position).normalized()
			dir.y = 0.8
			p.host_damage(12.0, dir.normalized() * knock)


func get_level() -> Level:
	var n := get_parent()
	while n and not (n is Level):
		n = n.get_parent()
	return n as Level
