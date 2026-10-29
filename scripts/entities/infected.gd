class_name Infected
extends CharacterBody3D
## Every infected: commons, the four specials, the Tank and the Witch. The host runs the AI
## (flow fields for pathing, one shared by the whole horde); clients just interpolate.

enum A { IDLE, RUN, ATTACK, STAGGER, CROUCH, LEAP, PIN, SPECIAL, SIT, DEAD, THROW, WANDER }

var type := "common"
var data: Dictionary
var size := 1.0
var hp := 50.0
var max_hp := 50.0
var anim: int = A.IDLE
var alert := false
var target_name := ""
var horde := false   # spawned as part of a horde: always chasing

# Replicated
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_anim := 0
var net_hp := 1.0
var net_link := ""        # survivor this special is pinning / tongue-ing / chasing (witch)
var net_hit_dir := Vector3.ZERO
var net_burning := false

var model: CharacterModel
var _rng := RandomNumberGenerator.new()
var _speed_mul := 1.0
var _attack_cd := 0.0
var _swing := 0.0
var _stagger_t := 0.0
var _stagger_vel := Vector3.ZERO
var _wander_dir := Vector3.ZERO
var _wander_t := 0.0
var _ability_cd := 3.0
var _state_t := 0.0
var _special := ""   # sub-state for specials: "", "windup", "leap", "pin", "tongue", "vomit", "spit", "throw", "flee"
var _victim := ""
var _los_lost := 0.0
var _anger := 0.0
var _burn_t := 0.0
var _burn_by := -1
var _last_attacker := -1
var _dead_t := 0.0
var _sound_t := 0.0
var _last_anim := -1
var _tongue: MeshInstance3D
var _leap_vel := Vector3.ZERO
var _retarget := 0.0
var _anim_speed := 0.0
var _fall := 0.0


func setup(d: Dictionary) -> void:
	type = d.type
	data = DB.INFECTED[type]
	size = float(data.size)
	max_hp = float(data.hp)
	if type == "tank":
		max_hp = float(Game.diff().tank_hp)
	hp = max_hp
	position = d.pos
	net_pos = d.pos
	horde = bool(d.get("horde", false))
	alert = horde or type not in ["common", "witch"]
	_rng.seed = hash(d.name)
	_speed_mul = _rng.randf_range(0.9, 1.1) if type == "common" else 1.0
	rotation.y = _rng.randf() * TAU
	net_yaw = rotation.y
	if type == "witch":
		anim = A.SIT
		net_anim = A.SIT
		rotation.y = float(d.get("yaw", 0.0))
		net_yaw = rotation.y
	elif not alert:
		anim = A.WANDER


func _init() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_yaw", "net_anim", "net_hp", "net_link", "net_hit_dir", "net_burning"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		var always: bool = prop in ["net_pos", "net_yaw"]
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS if always else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 20.0
	add_child(sync)


func _ready() -> void:
	add_to_group("infected")
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36 * (size if type != "tank" else 1.5)
	cap.height = (2.12 if type == "common" else 1.8) * size
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	model = CharacterModel.new()
	add_child(model)
	model.setup_infected(type, _rng.seed)
	if type != "tank":
		model.scale = Vector3.ONE * size
	_sound_t = _rng.randf_range(1.0, 6.0)
	if type == "smoker":
		_tongue = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 1.0
		cyl.radial_segments = 5
		_tongue.mesh = cyl
		_tongue.material_override = Build.mat(Color(0.7, 0.3, 0.35))
		_tongue.visible = false
		_tongue.top_level = true
		add_child(_tongue)


func level() -> Level:
	return get_parent().get_parent() as Level


func is_dead() -> bool:
	return net_anim == A.DEAD or hp <= 0.0


func is_tank() -> bool:
	return type == "tank"


func is_special() -> bool:
	return data.get("special", false) or data.get("boss", false)


func angry() -> bool:
	return type != "witch" or net_anim != A.SIT


func reach_scale() -> float:
	return 1.4 if type == "tank" else 1.0


func is_headshot(p: Vector3) -> bool:
	if type == "tank":
		return false
	var top := global_position.y + 1.95 * size
	if net_anim == A.SIT:
		top = global_position.y + 1.3 * size
	return p.y > top - 0.55 * size


func hp_fraction() -> float:
	return net_hp


# --- Frame -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Net.is_host():
		if anim == A.DEAD:
			_dead_t += delta
			if _dead_t > 10.0:
				queue_free()
		else:
			_host_ai(delta)
			net_pos = global_position
			net_yaw = rotation.y
			net_anim = anim
	else:
		global_position = global_position.lerp(net_pos, clampf(delta * 12.0, 0.0, 1.0))
		if global_position.distance_to(net_pos) > 5.0:
			global_position = net_pos
		rotation.y = lerp_angle(rotation.y, net_yaw, clampf(delta * 12.0, 0.0, 1.0))


func _process(delta: float) -> void:
	var moving := (net_pos - global_position).length() * 12.0 if not Net.is_host() else Vector2(velocity.x, velocity.z).length()
	_anim_speed = lerpf(_anim_speed, moving, clampf(delta * 8.0, 0.0, 1.0))
	if net_anim != _last_anim:
		_on_anim_changed(_last_anim, net_anim)
		_last_anim = net_anim
	_swing = maxf(_swing - delta * 3.0, 0.0)
	var pose := ""
	match net_anim:
		A.CROUCH, A.PIN:
			pose = "crouch"
		A.LEAP:
			pose = "pounce"
		A.SIT:
			pose = "sit"
		A.STAGGER:
			pose = "stagger"
		A.SPECIAL, A.THROW:
			pose = "vomit"
	if net_anim == A.DEAD:
		# Topple over away from the killing blow.
		_fall = minf(_fall + delta * 3.0, 1.0)
		model.rotation.x = -PI * 0.5 * _fall * (1.0 if net_hit_dir.dot(global_transform.basis.z) < 0.0 else -1.0)
		model.position.y = 0.2 * _fall
		model.animate(delta, 0.0, 0.0, "dead")
		model.rotation.x = -PI * 0.5 * _fall * (1.0 if net_hit_dir.dot(global_transform.basis.z) < 0.0 else -1.0)
		if _tongue:
			_tongue.visible = false
		return
	model.animate(delta, _anim_speed * (0.7 if type == "tank" else 1.0), _swing, pose)
	_update_tongue()
	_idle_sounds(delta)


func _on_anim_changed(from: int, to: int) -> void:
	if to == A.ATTACK:
		_swing = 1.0
	match to:
		A.DEAD:
			collision_layer = 0
			Sfx.play("die" if type != "tank" else "tank", global_position + Vector3.UP, 2.0 if is_special() else -2.0, 0.6 if type == "tank" else 1.0)
		A.CROUCH:
			if type == "hunter":
				Sfx.play("hunter", global_position + Vector3.UP, 4.0)
		A.LEAP:
			Sfx.play("pounce", global_position + Vector3.UP, 4.0)
		A.SPECIAL:
			match type:
				"boomer":
					Sfx.play("vomit", global_position + Vector3.UP, 6.0)
				"smoker":
					Sfx.play("tongue", global_position + Vector3.UP, 6.0)
				"spitter":
					Sfx.play("spit", global_position + Vector3.UP, 6.0)
		A.THROW:
			Sfx.play("tank", global_position + Vector3.UP, 6.0, 1.2)
		A.RUN:
			if from == A.SIT:
				Sfx.play("witch_scream", global_position + Vector3.UP, 10.0)
			elif from in [A.IDLE, A.WANDER] and type == "common" and _rng.randf() < 0.5:
				Sfx.play("scream", global_position + Vector3.UP, -2.0, _rng.randf_range(0.8, 1.2))


func _idle_sounds(delta: float) -> void:
	_sound_t -= delta
	if _sound_t > 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(global_position) > 40.0:
		_sound_t = 2.0
		return
	match type:
		"common":
			_sound_t = _rng.randf_range(4.0, 12.0)
			Sfx.play("groan", global_position + Vector3.UP * 1.5, -6.0, _rng.randf_range(0.8, 1.2))
		"boomer":
			_sound_t = 3.0
			Sfx.play("boomer", global_position + Vector3.UP, 2.0)
		"hunter":
			_sound_t = 4.0
			Sfx.play("hunter", global_position + Vector3.UP, -4.0, 0.8)
		"smoker":
			_sound_t = 3.5
			Sfx.play("smoker", global_position + Vector3.UP, 0.0)
		"spitter":
			_sound_t = 4.0
			Sfx.play("spitter", global_position + Vector3.UP, 0.0)
		"tank":
			_sound_t = 3.0
			Sfx.play("tank", global_position + Vector3.UP, 4.0)
		"witch":
			_sound_t = 2.3 if net_anim == A.SIT else 1.2
			Sfx.play("witch_cry" if net_anim == A.SIT else "witch_scream", global_position + Vector3.UP, 0.0 if net_anim == A.SIT else 4.0)


func _update_tongue() -> void:
	if _tongue == null:
		return
	var victim := level().get_survivor(net_link) if net_link != "" else null
	_tongue.visible = victim != null and net_anim == A.SPECIAL
	if _tongue.visible:
		var a := model.mouth.global_position
		var b := victim.global_position + Vector3.UP * 1.2
		var mid := (a + b) * 0.5
		_tongue.global_position = mid
		_tongue.scale = Vector3(1, a.distance_to(b), 1)
		var dir := (b - a).normalized()
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		var x := up.cross(dir).normalized()
		_tongue.global_basis = Basis(x, dir, x.cross(dir)).scaled(Vector3(1, a.distance_to(b), 1))


# --- Host AI ---------------------------------------------------------------------------

func _host_ai(delta: float) -> void:
	var lvl := level()
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_ability_cd = maxf(_ability_cd - delta, 0.0)
	_state_t += delta
	if _burn_t > 0.0:
		_burn_t -= delta
		net_burning = _burn_t > 0.0
		take_hit((25.0 if type != "tank" else 60.0) * delta, false, Vector3.ZERO, _burn_by, "fire")
		if anim == A.DEAD:
			return
	velocity.y -= 16.0 * delta
	if _stagger_t > 0.0:
		_stagger_t -= delta
		anim = A.STAGGER
		_stagger_vel = _stagger_vel.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = _stagger_vel.x
		velocity.z = _stagger_vel.z
		move_and_slide()
		if _stagger_t <= 0.0:
			anim = A.RUN if alert else A.WANDER
		return
	match type:
		"common":
			_ai_common(delta, lvl)
		"boomer":
			_ai_boomer(delta, lvl)
		"hunter":
			_ai_hunter(delta, lvl)
		"smoker":
			_ai_smoker(delta, lvl)
		"spitter":
			_ai_spitter(delta, lvl)
		"tank":
			_ai_tank(delta, lvl)
		"witch":
			_ai_witch(delta, lvl)
	if _special != "pin" and _special != "leap":
		_separate(lvl, delta)
		move_and_slide()
	if global_position.y < -10.0:
		take_hit(9999.0, false, Vector3.ZERO, -1, "fall")


func _target(lvl: Level) -> Survivor:
	return lvl.get_survivor(target_name) if target_name != "" else null


## Picks who to chase: biled survivors first, then the closest one by walking distance.
func _retarget_now(lvl: Level, delta: float) -> Survivor:
	_retarget -= delta
	var cur := _target(lvl)
	if _retarget > 0.0 and cur != null and not cur.dead:
		return cur
	_retarget = 0.6 + _rng.randf() * 0.4
	var best: Survivor
	var best_d := INF
	for s: Survivor in lvl.get_survivors():
		if s.dead:
			continue
		var d := s.global_position.distance_to(global_position)
		if s.biled > 0.0:
			d *= 0.25
		if s.incapped and type == "common":
			d *= 1.3
		if d < best_d:
			best_d = d
			best = s
	target_name = best.name if best else ""
	return best


func _chase(lvl: Level, to: Vector3, speed: float, delta: float, close := 4.0) -> void:
	var dir := Vector3.ZERO
	var flat := to - global_position
	flat.y = 0
	if flat.length() < close or (flat.length() < 12.0 and lvl.nav.clear_line(global_position, to)):
		dir = flat.normalized()
	else:
		dir = lvl.director.flow.dir_at(global_position)
		if dir == Vector3.ZERO:
			dir = flat.normalized()
	_move(dir, speed, delta)


func _move(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * speed, 30.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 30.0 * delta)
	if dir.length() > 0.1:
		_face(global_position + dir, delta)


func _face(p: Vector3, delta: float) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(delta * 10.0, 0.0, 1.0))


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)


## Keeps the horde from collapsing into one blob.
func _separate(lvl: Level, _delta: float) -> void:
	var push := Vector3.ZERO
	var me := global_position
	for o: Infected in lvl.all_infected():
		if o == self or o.anim == A.DEAD:
			continue
		var d: Vector3 = me - o.global_position
		d.y = 0
		var l := d.length()
		var r := 0.75 * (size + o.size) * 0.5 * (1.8 if o.type == "tank" or type == "tank" else 1.0)
		if l < r and l > 0.001:
			push += d / l * (r - l)
	velocity.x += push.x * 6.0
	velocity.z += push.z * 6.0


func _melee_target(lvl: Level, s: Survivor, delta: float, reach: float, dmg: float, cd: float) -> bool:
	var d := s.global_position.distance_to(global_position)
	if d > reach:
		return false
	_stop(delta)
	_face(s.global_position, delta)
	anim = A.ATTACK if _attack_cd > cd - 0.4 else A.RUN
	if _attack_cd <= 0.0:
		_attack_cd = cd
		anim = A.ATTACK
		lvl.fx_sound.rpc("zombie_hit", s.global_position + Vector3.UP)
		s.host_damage(dmg, (s.global_position - global_position).normalized(), type)
	return true


func _ai_common(delta: float, lvl: Level) -> void:
	var lure := lvl.director.lure_pos
	if lure != Vector3.INF and global_position.distance_to(lure) < 45.0:
		alert = true
		anim = A.RUN
		var flat := lure - global_position
		flat.y = 0
		if flat.length() > 1.5:
			var dir := lvl.director.lure_flow.dir_at(global_position)
			_move(dir if dir != Vector3.ZERO else flat.normalized(), float(data.speed) * _speed_mul, delta)
		else:
			_stop(delta)
		return
	if not alert:
		_wander(delta, lvl)
		return
	var s := _retarget_now(lvl, delta)
	if s == null:
		_stop(delta)
		anim = A.IDLE
		return
	var dmg: float = Game.diff().common_dmg
	if s.incapped:
		dmg *= 2.5
	if _melee_target(lvl, s, delta, 1.25, dmg, 1.1):
		return
	anim = A.RUN
	_chase(lvl, s.global_position, float(data.speed) * _speed_mul, delta)


func _wander(delta: float, lvl: Level) -> void:
	anim = A.WANDER
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = _rng.randf_range(2.0, 5.0)
		_wander_dir = Vector3.ZERO if _rng.randf() < 0.5 else Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
	var ahead := global_position + _wander_dir * 1.2
	if _wander_dir != Vector3.ZERO and not lvl.nav.walkable_at(ahead):
		_wander_dir = -_wander_dir
	_move(_wander_dir, 0.8, delta)
	# Notice survivors who get close, shine a light on us, or that we can see from nearby.
	for s: Survivor in lvl.get_survivors():
		if s.dead:
			continue
		var d := s.global_position.distance_to(global_position)
		var lit: bool = s.net_light and d < 14.0 and (-s.eye_basis().z).dot((global_position + Vector3.UP - s.eye_position()).normalized()) > 0.95
		if d < 7.0 or (lit and _rng.randf() < delta * 2.0):
			become_alert()
			return


func become_alert() -> void:
	if alert or type == "witch":
		return
	alert = true
	anim = A.RUN
	_retarget = 0.0


func _ai_boomer(delta: float, lvl: Level) -> void:
	var s := _retarget_now(lvl, delta)
	if s == null:
		_stop(delta)
		return
	var d := s.global_position.distance_to(global_position)
	if _special == "vomit":
		_stop(delta)
		_face(s.global_position, delta)
		if _state_t > 0.9:
			_special = ""
			_ability_cd = 25.0
			anim = A.RUN
		return
	if _ability_cd <= 0.0 and d < 6.5 and lvl.line_of_sight(global_position + Vector3.UP * 1.6, s.eye_position()):
		_special = "vomit"
		_state_t = 0.0
		anim = A.SPECIAL
		var fwd := (s.global_position - global_position).normalized()
		lvl.fx_bile.rpc(global_position + Vector3.UP * 1.6, fwd)
		for v: Survivor in lvl.get_survivors():
			var to := v.global_position - global_position
			if not v.dead and to.length() < 7.5 and fwd.angle_to(to.normalized()) < 0.5:
				lvl.bile_survivor(v)
		return
	if _melee_target(lvl, s, delta, 1.3, float(data.dmg) * Game.diff().special_dmg, 1.2):
		return
	anim = A.RUN
	_chase(lvl, s.global_position, float(data.speed), delta)


func _ai_hunter(delta: float, lvl: Level) -> void:
	var s := _target(lvl) if _special in ["pin", "leap"] else _retarget_now(lvl, delta)
	if s == null:
		_stop(delta)
		return
	match _special:
		"pin":
			if s.dead or s.pinned_by != name:
				_end_pin(lvl)
				return
			global_position = s.global_position + Vector3.UP * 0.25
			anim = A.PIN
			_attack_cd -= 0.0
			if _attack_cd <= 0.0:
				_attack_cd = 0.5
				_swing = 1.0
				s.host_damage(5.0 * Game.diff().special_dmg, Vector3.ZERO, "hunter")
			return
		"leap":
			anim = A.LEAP
			_leap_vel.y -= 16.0 * delta
			velocity = _leap_vel
			move_and_slide()
			for v: Survivor in lvl.get_survivors():
				if v.able() and v.global_position.distance_to(global_position) < 1.4:
					_special = "pin"
					target_name = v.name
					_attack_cd = 0.3
					v.host_pin(name, "hunter")
					lvl.fx_sound.rpc("pounce", v.global_position)
					Game.toast.rpc("%s was pounced by a Hunter!" % v.short_name(), Color(1.0, 0.5, 0.3))
					return
			if (is_on_floor() and _state_t > 0.2) or _state_t > 2.0:
				_special = ""
				_ability_cd = 1.5
				anim = A.RUN
			return
		"windup":
			_stop(delta)
			_face(s.global_position, delta)
			anim = A.CROUCH
			if _state_t > 0.7:
				_special = "leap"
				_state_t = 0.0
				var t := clampf(global_position.distance_to(s.global_position) / 14.0, 0.35, 0.8)
				_leap_vel = Level.lob_velocity(global_position, s.global_position + Vector3.UP * 0.6, t, 16.0)
			return
	var d := s.global_position.distance_to(global_position)
	if _ability_cd <= 0.0 and d > 2.5 and d < 15.0 and s.able() and lvl.line_of_sight(global_position + Vector3.UP, s.eye_position()):
		_special = "windup"
		_state_t = 0.0
		return
	if d < 1.4:
		_melee_target(lvl, s, delta, 1.4, 6.0 * Game.diff().special_dmg, 1.0)
		return
	anim = A.CROUCH if d < 20.0 else A.RUN
	_chase(lvl, s.global_position, float(data.speed) * (0.8 if d < 20.0 else 1.0), delta)


func _ai_smoker(delta: float, lvl: Level) -> void:
	if _special == "tongue":
		var v := _target(lvl)
		_stop(delta)
		anim = A.SPECIAL
		if v == null or v.dead or v.pinned_by != name:
			_end_pin(lvl)
			return
		_face(v.global_position, delta)
		if lvl.line_of_sight(global_position + Vector3.UP * 1.8, v.global_position + Vector3.UP):
			_los_lost = 0.0
		else:
			_los_lost += delta
			if _los_lost > 1.0:
				_end_pin(lvl)
				return
		if _attack_cd <= 0.0:
			_attack_cd = 1.0
			var close := v.global_position.distance_to(global_position) < 1.8
			v.host_damage((5.0 if close else 1.5) * Game.diff().special_dmg, Vector3.ZERO, "smoker")
		return
	var s := _retarget_now(lvl, delta)
	if s == null:
		_stop(delta)
		return
	var d := s.global_position.distance_to(global_position)
	if _ability_cd <= 0.0 and d < 24.0 and d > 3.0 and s.able() and lvl.line_of_sight(global_position + Vector3.UP * 1.8, s.eye_position()):
		_special = "tongue"
		target_name = s.name
		net_link = s.name
		_attack_cd = 0.8
		_los_lost = 0.0
		anim = A.SPECIAL
		s.host_pin(name, "smoker")
		Game.toast.rpc("%s got grabbed by a Smoker!" % s.short_name(), Color(1.0, 0.5, 0.3))
		return
	if _melee_target(lvl, s, delta, 1.3, 4.0 * Game.diff().special_dmg, 1.0):
		return
	anim = A.RUN
	if d > 18.0 or not lvl.line_of_sight(global_position + Vector3.UP * 1.8, s.eye_position()):
		_chase(lvl, s.global_position, float(data.speed), delta)
	else:
		_stop(delta)
		_face(s.global_position, delta)
		anim = A.IDLE


func _ai_spitter(delta: float, lvl: Level) -> void:
	var s := _retarget_now(lvl, delta)
	if s == null:
		_stop(delta)
		return
	if _special == "spit":
		_stop(delta)
		_face(s.global_position, delta)
		if _state_t > 0.6:
			_special = ""
			anim = A.RUN
		return
	var d := s.global_position.distance_to(global_position)
	if _ability_cd <= 0.0 and d < 22.0 and d > 4.0 and lvl.line_of_sight(global_position + Vector3.UP * 1.8, s.eye_position()):
		_special = "spit"
		_state_t = 0.0
		_ability_cd = 18.0
		anim = A.SPECIAL
		var from := global_position + Vector3.UP * 2.0
		lvl.spawn_projectile("spit", from, Level.lob_velocity(from, s.global_position, 0.9), -1)
		return
	if _melee_target(lvl, s, delta, 1.3, 3.0 * Game.diff().special_dmg, 1.0):
		return
	anim = A.RUN
	if d > 14.0 or not lvl.line_of_sight(global_position + Vector3.UP * 1.8, s.eye_position()):
		_chase(lvl, s.global_position, float(data.speed), delta)
	else:
		_stop(delta)
		_face(s.global_position, delta)
		anim = A.IDLE


func _ai_tank(delta: float, lvl: Level) -> void:
	var s := _retarget_now(lvl, delta)
	if s == null:
		_stop(delta)
		return
	if _special == "throw":
		_stop(delta)
		_face(s.global_position, delta)
		anim = A.THROW
		if _state_t > 1.1:
			_special = ""
			anim = A.RUN
			var from := global_position + Vector3.UP * 3.2
			var t := clampf(from.distance_to(s.global_position) / 22.0, 0.6, 1.4)
			lvl.spawn_projectile("rock", from, Level.lob_velocity(from, s.global_position + Vector3.UP, t), -1)
			lvl.fx_sound.rpc("rock", from)
		return
	var d := s.global_position.distance_to(global_position)
	if d < 2.4:
		_stop(delta)
		_face(s.global_position, delta)
		anim = A.ATTACK if _attack_cd > 0.9 else A.RUN
		if _attack_cd <= 0.0:
			_attack_cd = 1.5
			anim = A.ATTACK
			lvl.fx_sound.rpc("punch", s.global_position + Vector3.UP)
			var dir := (s.global_position - global_position)
			dir.y = 0
			s.host_damage(float(data.dmg) * Game.diff().special_dmg, dir.normalized(), "tank")
			if not s.incapped and not s.dead:
				s.host_knock(dir.normalized() * 11.0 + Vector3.UP * 6.0)
		return
	if _ability_cd <= 0.0 and d > 10.0 and d < 35.0 and lvl.line_of_sight(global_position + Vector3.UP * 2.5, s.eye_position()):
		_special = "throw"
		_state_t = 0.0
		_ability_cd = 7.0
		return
	anim = A.RUN
	_chase(lvl, s.global_position, float(data.speed) * (1.15 if net_burning else 1.0), delta)


func _ai_witch(delta: float, lvl: Level) -> void:
	if not alert:
		anim = A.SIT
		_stop(delta)
		for s: Survivor in lvl.get_survivors():
			if s.dead:
				continue
			var d := s.global_position.distance_to(global_position)
			var rate := 0.0
			if d < 9.0:
				rate += (1.0 - d / 9.0) * 0.45
			if s.net_light and d < 16.0 and (-s.eye_basis().z).dot((global_position + Vector3.UP - s.eye_position()).normalized()) > 0.93:
				rate += 0.5
			if rate > 0.0:
				_anger += rate * delta
				if _anger >= 1.0:
					_startle(lvl, s)
					return
		_anger = maxf(_anger - delta * 0.05, 0.0)
		return
	var v := _target(lvl)
	if _special == "flee" or v == null or v.dead:
		if _special != "flee":
			_special = "flee"
			_state_t = 0.0
			_wander_dir = (global_position - (v.global_position if v else global_position + global_transform.basis.z)).normalized()
			_wander_dir.y = 0
		anim = A.RUN
		_move(_wander_dir, 6.0, delta)
		if _state_t > 8.0:
			queue_free()
		return
	if _melee_target(lvl, v, delta, 1.5, 0.0, 1.0):
		if _attack_cd >= 0.99:
			if not v.incapped:
				if Game.diff().witch_incaps:
					v.host_damage(v.total_hp() + 1.0, Vector3.ZERO, "witch")
				else:
					v.host_damage(9999.0, Vector3.ZERO, "witch")
					if not v.dead:
						v.host_damage(9999.0, Vector3.ZERO, "witch")
			else:
				v.host_damage(20.0, Vector3.ZERO, "witch")
		return
	anim = A.RUN
	_chase(lvl, v.global_position, float(data.speed), delta, 6.0)


func _startle(lvl: Level, by: Survivor) -> void:
	if alert:
		return
	alert = true
	target_name = by.name
	net_link = by.name
	anim = A.RUN
	_state_t = 0.0
	Game.toast.rpc("%s startled the Witch!" % by.short_name(), Color(1.0, 0.35, 0.35))
	lvl.director.on_witch_startled()


func _end_pin(lvl: Level) -> void:
	var v := _target(lvl)
	if v and v.pinned_by == name:
		v.host_unpin()
	_special = ""
	net_link = ""
	_ability_cd = 12.0 if type == "smoker" else 3.0
	anim = A.RUN


# --- Damage (host) ----------------------------------------------------------------------

## kind: "bullet", "melee", "blast", "fire", "shove", "fall"
func take_hit(dmg: float, headshot: bool, dir: Vector3, attacker: int, kind := "bullet") -> void:
	if not Net.is_host() or anim == A.DEAD:
		return
	var lvl := level()
	if headshot and kind == "bullet":
		dmg *= 4.0 if type == "common" else (1.5 if type == "witch" else 2.0)
	hp -= dmg
	net_hp = clampf(hp / max_hp, 0.0, 1.0)
	_last_attacker = attacker
	if type == "witch" and not alert:
		var s := lvl.get_survivor_by_slot(attacker)
		if s:
			_startle(lvl, s)
	elif not alert:
		become_alert()
	if type == "tank" and target_name == "" and attacker >= 0:
		var s := lvl.get_survivor_by_slot(attacker)
		if s:
			target_name = s.name
	if hp <= 0.0:
		_die(dir, attacker, headshot, kind)


func _die(dir: Vector3, attacker: int, headshot: bool, kind: String) -> void:
	var lvl := level()
	if _special in ["pin", "tongue"]:
		_end_pin(lvl)
	anim = A.DEAD
	net_anim = A.DEAD
	net_hit_dir = dir
	net_link = ""
	collision_layer = 0
	velocity = Vector3.ZERO
	if attacker >= 0:
		Game.add_stat(attacker, "specials" if is_special() else "kills")
		if headshot:
			Game.add_stat(attacker, "headshots")
	match type:
		"boomer":
			lvl.fx_bile.rpc(global_position + Vector3.UP, Vector3.ZERO)
			for v: Survivor in lvl.get_survivors():
				if not v.dead and v.global_position.distance_to(global_position) < 3.5:
					lvl.bile_survivor(v)
			lvl.fx_sound.rpc("explosion", global_position)
		"smoker":
			lvl.fx_smoke.rpc(global_position + Vector3.UP)
		"spitter":
			lvl.spawn_projectile("acid_pool", global_position + Vector3.UP * 0.3, Vector3.ZERO, -1)
		"tank":
			Game.toast.rpc("The Tank is dead!", Color(0.6, 1.0, 0.5))
			lvl.director.on_tank_died()
	if is_special() and attacker >= 0:
		var s := lvl.get_survivor_by_slot(attacker)
		if s:
			Game.toast.rpc("%s killed the %s" % [s.short_name(), data.name], Color(0.8, 0.9, 1.0))


func shove(dir: Vector3) -> void:
	if not Net.is_host() or anim == A.DEAD:
		return
	if type in ["tank", "witch"]:
		return
	if _special in ["pin", "tongue", "leap"]:
		_end_pin(level())
	_special = ""
	_stagger_t = 1.0 if type == "common" else 1.4
	_stagger_vel = dir.normalized() * 5.5
	_ability_cd = maxf(_ability_cd, 2.0)
	become_alert()


func ignite(attacker: int) -> void:
	_burn_t = 12.0
	_burn_by = attacker
	net_burning = true
	become_alert()
