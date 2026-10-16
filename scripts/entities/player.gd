class_name Player
extends CharacterBody3D
## First-person survivor. Movement, aiming, weapons and fishing run on the owning peer
## (snappy feel); damage, money and zombie physics are decided by the host via RPC.

enum Rod { IDLE, CHARGING, FLYING, WAITING, BITE, REELING, RETURNING }

const WALK := 5.0
const SPRINT := 8.2
const JUMP := 6.0
const GRAVITY := 16.0
const MAX_HP := 100.0
const REVIVE_SLAPS := 4

var peer_id := 1

# Replicated from the owner
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0
var net_item := "rod"
var net_attack := 0.0
var net_bobber := Vector3.ZERO
var net_bobber_state := 0
var net_hold := Vector3.ZERO

# Decided by the host, pushed with _set_health
var hp := MAX_HP
var downed := false
var gull_incoming := false
var gull_dropped := false
var _slaps := 0

# Local-only
var head: Node3D
var camera: Camera3D
var viewmodel: Node3D
var vm_item: Node3D
var body_model: CharacterModel
var body_item: Node3D
var name_label: Label3D
var line_mesh: MeshInstance3D
var bobber_mesh: Node3D
var ui_open := false
var items: Array = []
var item_idx := 0
var ammo := {}
var reload_t := 0.0
var holding := ""
var prompt := ""
var _look_target: Object
var _cooldown := 0.0
var _swing := 0.0
var _recoil := 0.0
var _shake := 0.0
var _pitch := 0.0
var _anim_speed := 0.0
var _rng := RandomNumberGenerator.new()
var _bob_t := 0.0

# Fishing
var rod_state: int = Rod.IDLE
var cast_power := 0.0
var bobber := Vector3.ZERO
var _bobber_vel := Vector3.ZERO
var _bite_t := 0.0
var _bite_window := 0.0
var _fly_t := 0.0
var hooked := ""
var _hooked_size := 1.0
var tension := 0.0
var stamina := 1.0
var reel_dist := 0.0
var thrashing := false
var _thrash_t := 2.0
var _reel_click := 0.0
# Rises with each reel click and decays, so mashing reels faster than holding.
var _reel_heat := 0.0
var reel_boost := 0.0
var _since_click := 1.0
var _splash_t := 0.0


func setup(d: Dictionary) -> void:
	peer_id = int(d.peer)
	position = d.pos
	net_pos = d.pos
	set_multiplayer_authority(peer_id, true)


func _init() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_yaw", "net_pitch", "net_item", "net_attack", "net_bobber", "net_bobber_state", "net_hold"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		var always: bool = prop in ["net_pos", "net_yaw", "net_pitch", "net_bobber", "net_hold"]
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS if always else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


func is_local() -> bool:
	return is_multiplayer_authority()


func _ready() -> void:
	add_to_group("players")
	_rng.randomize()
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)

	body_model = CharacterModel.new()
	add_child(body_model)
	var info: Dictionary = Net.players.get(peer_id, {})
	var color: Color = DB.PLAYER_COLORS[int(info.get("color", 0)) % DB.PLAYER_COLORS.size()]
	body_model.setup(Color(0.96, 0.78, 0.62), color, Color(0.25, 0.3, 0.45), false, 1.0, info.get("hat", "none"))
	body_model.rotation.y = PI  # Model faces +Z; the player looks down -Z.

	head = Node3D.new()
	head.position = Vector3(0, 1.62, 0)
	add_child(head)

	line_mesh = MeshInstance3D.new()
	line_mesh.top_level = true
	line_mesh.mesh = ImmediateMesh.new()
	line_mesh.material_override = Build.mat(Color(0.95, 0.95, 0.95), 1.0, 0.5)
	line_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line_mesh)
	bobber_mesh = Node3D.new()
	bobber_mesh.top_level = true
	add_child(bobber_mesh)
	Build.sphere(bobber_mesh, 0.09, Color(0.95, 0.15, 0.15), Vector3.ZERO)
	Build.sphere(bobber_mesh, 0.091, Color.WHITE, Vector3(0, 0.03, 0), Vector3(1, 0.5, 1))
	bobber_mesh.visible = false

	if is_local():
		camera = Camera3D.new()
		camera.fov = Settings.fov
		camera.near = 0.05
		camera.cull_mask = 0xFFFFF & ~2  # Hide our own body (render layer 2), keep its shadow.
		head.add_child(camera)
		camera.make_current()
		viewmodel = Node3D.new()
		viewmodel.position = Vector3(0.32, -0.28, -0.5)
		camera.add_child(viewmodel)
		for mi in body_model.find_children("*", "MeshInstance3D", true, false):
			mi.layers = 2
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Game.state_changed.connect(_refresh_items)
	else:
		name_label = Build.label(self, info.get("name", "Survivor"), Vector3(0, 2.45, 0), 48, color.lightened(0.3))
		name_label.no_depth_test = true
	global_position = net_pos
	if is_local():
		_refresh_items()
	else:
		_update_body_item()


func refresh_cosmetics() -> void:
	var info: Dictionary = Net.players.get(peer_id, {})
	body_model.set_hat(info.get("hat", "none"))
	if is_local():
		for mi in body_model.find_children("*", "MeshInstance3D", true, false):
			mi.layers = 2
	if name_label:
		name_label.text = info.get("name", "Survivor")


func _refresh_items() -> void:
	var cur: String = items[item_idx] if item_idx < items.size() else "rod"
	items = Game.weapons_owned()
	item_idx = max(items.find(cur), 0)
	for w in items:
		if DB.WEAPONS[w].kind == "gun" and not ammo.has(w):
			ammo[w] = int(DB.WEAPONS[w].mag)
	_equip(item_idx, true)


func current_item() -> String:
	return items[item_idx] if item_idx < items.size() else "rod"


var _vm_key := ""
var _body_key := ""


func _equip(idx: int, force := false) -> void:
	if items.is_empty():
		return
	idx = posmod(idx, items.size())
	if idx == item_idx and not force:
		return
	if current_item() == "rod" and items[idx] != "rod":
		_reset_rod()
	if idx != item_idx:
		reload_t = 0.0
	item_idx = idx
	net_item = current_item()
	var key := net_item + Game.best_rod()
	if key != _vm_key:
		_vm_key = key
		if vm_item:
			vm_item.queue_free()
		vm_item = ItemModels.make(net_item, Game.best_rod())
		if net_item == "rod":
			vm_item.scale = Vector3.ONE * 0.55
			vm_item.position = Vector3(0.05, -0.05, 0.1)
		viewmodel.add_child(vm_item)
		if not force:
			_swing = 0.6
			Sfx.play("click")
	_update_body_item()


func _update_body_item() -> void:
	var key := net_item + Game.best_rod()
	if key == _body_key:
		return
	_body_key = key
	if body_item:
		body_item.queue_free()
	body_item = ItemModels.make(net_item, Game.best_rod())
	body_item.rotation_degrees = Vector3(-90, 0, 0)
	body_model.hand_r.add_child(body_item)
	if is_local():
		for mi in body_item.find_children("*", "MeshInstance3D", true, false):
			mi.layers = 2


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or ui_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * Settings.mouse_sensitivity
		_pitch = clamp(_pitch - event.relative.y * Settings.mouse_sensitivity, -1.5, 1.5)
	if downed:
		return
	if event.is_action_pressed("next_slot"):
		_equip(item_idx + 1)
	elif event.is_action_pressed("prev_slot"):
		_equip(item_idx - 1)
	for i in 10:
		if event.is_action_pressed("slot_%d" % (i + 1)) and i < items.size():
			_equip(i)
	if event.is_action_pressed("interact"):
		_interact()
	if event.is_action_pressed("reload"):
		_start_reload()
	if event.is_action_pressed("drop") and holding != "":
		_release(Vector3.ZERO)


func _physics_process(delta: float) -> void:
	if not is_local():
		var k := clampf(delta * 14.0, 0.0, 1.0)
		var prev := global_position
		global_position = global_position.lerp(net_pos, k) if global_position.distance_to(net_pos) < 8.0 else net_pos
		rotation.y = lerp_angle(rotation.y, net_yaw, k)
		head.rotation.x = lerp(head.rotation.x, net_pitch, k)
		_anim_speed = lerp(_anim_speed, Vector2(global_position.x - prev.x, global_position.z - prev.z).length() / max(delta, 0.0001), 0.2)
		body_model.animate(delta, _anim_speed, net_attack, downed)
		_update_body_item()
		if body_item:
			body_item.visible = not downed
		return
	_local_move(delta)
	net_pos = global_position
	net_yaw = rotation.y
	net_pitch = _pitch
	if holding != "":
		net_hold = camera.global_position - camera.global_transform.basis.z * 2.0


func _local_move(delta: float) -> void:
	if gull_incoming and not gull_dropped:
		return
	var input := Vector2.ZERO
	if not ui_open and not downed:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		rotation.y -= look.x * delta * 3.0
		_pitch = clamp(_pitch - look.y * delta * 2.4, -1.5, 1.5)
	head.rotation.x = _pitch
	head.position.y = lerp(head.position.y, 0.45 if downed else 1.62, clampf(delta * 6.0, 0.0, 1.0))
	var sprinting := Input.is_action_pressed("sprint") and not ui_open
	var speed := SPRINT if sprinting else WALK
	if rod_state == Rod.REELING:
		speed *= 0.4
	var dir := (global_transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	var in_water := global_position.y < DB.WATER_LEVEL - 1.0
	var accel := 12.0 if is_on_floor() else 4.0
	if in_water:
		speed *= 0.55
		accel = 5.0
		var target_y := DB.WATER_LEVEL - 1.15
		velocity.y += ((target_y - global_position.y) * 10.0 - velocity.y * 3.0) * delta
		if Input.is_action_just_pressed("jump") and not ui_open and not downed and global_position.y > target_y - 0.4:
			velocity.y = 9.0
			Sfx.play("splash", global_position, -6.0)
	else:
		velocity.y -= GRAVITY * delta
		if is_on_floor() and Input.is_action_just_pressed("jump") and not ui_open and not downed:
			velocity.y = JUMP
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * speed * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * speed * delta)
	move_and_slide()
	if global_position.y < -12.0:
		var lvl := _level()
		global_position = lvl.markers.spawn if lvl else Vector3(0, 3, 0)
		velocity = Vector3.ZERO
	var hspeed := Vector2(velocity.x, velocity.z).length()
	body_model.animate(delta, hspeed, _swing, downed)
	# Head bob + camera shake
	if is_on_floor() and hspeed > 0.5:
		_bob_t += delta * hspeed * 1.6
	camera.position = Vector3(0, sin(_bob_t * 2.0) * 0.04, 0) + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.15
	_shake = max(_shake - delta * 2.0, 0.0)


func _process(delta: float) -> void:
	_draw_line()
	if not is_local():
		return
	_cooldown = max(_cooldown - delta, 0.0)
	_swing = max(_swing - delta * 4.0, 0.0)
	_recoil = max(_recoil - delta * 6.0, 0.0)
	net_attack = _swing
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo[current_item()] = int(DB.WEAPONS[current_item()].mag)
	if viewmodel:
		var rel := 1.0 if reload_t > 0.0 else 0.0
		viewmodel.rotation = Vector3(_recoil * 0.4 - _swing * 1.1 - rel * 0.6, _swing * 0.6, -_swing * 0.3)
		viewmodel.position = Vector3(0.32, -0.28 - rel * 0.15, -0.5 + _recoil * 0.12)
		viewmodel.visible = not downed and holding == ""
	_update_prompt()
	if ui_open or downed:
		if rod_state == Rod.CHARGING:
			rod_state = Rod.IDLE
		return
	if holding != "":
		if Input.is_action_just_pressed("primary"):
			_release(-camera.global_transform.basis.z * 15.0 + Vector3.UP * 3.0)
		return
	var item := current_item()
	var kind: String = DB.WEAPONS[item].kind
	match kind:
		"rod":
			_rod_process(delta)
		"melee":
			if Input.is_action_pressed("primary") and _cooldown <= 0.0:
				_melee(item)
		"gun":
			var auto := item == "smg"
			var fire := Input.is_action_pressed("primary") if auto else Input.is_action_just_pressed("primary")
			if fire and _cooldown <= 0.0 and reload_t <= 0.0:
				_shoot(item)
		"throw":
			if Input.is_action_just_pressed("primary") and _cooldown <= 0.0:
				_throw(item)


func add_shake(amount: float) -> void:
	_shake = max(_shake, amount)


# --- Fishing --------------------------------------------------------------------

func _rod_tip() -> Vector3:
	var src := vm_item if is_local() and vm_item and viewmodel.visible else body_item
	if src and src.has_node("Tip"):
		return src.get_node("Tip").global_position
	return global_position + Vector3.UP * 1.5


func _rod_process(delta: float) -> void:
	var rod: Dictionary = DB.RODS[Game.best_rod()]
	var lvl := _level()
	match rod_state:
		Rod.IDLE:
			if Input.is_action_just_pressed("secondary"):
				rod_state = Rod.CHARGING
				cast_power = 0.0
		Rod.CHARGING:
			cast_power = min(cast_power + delta * 0.9, 1.0)
			_swing = cast_power * 0.5
			if not Input.is_action_pressed("secondary"):
				var fwd := -camera.global_transform.basis.z
				bobber = _rod_tip()
				_bobber_vel = fwd * (5.0 + 13.0 * cast_power) * float(rod.cast) + Vector3.UP * 4.0
				_fly_t = 0.0
				rod_state = Rod.FLYING
				_swing = 1.0
				Sfx.play("cast", global_position)
		Rod.FLYING:
			_fly_t += delta
			var prev := bobber
			_bobber_vel.y -= 14.0 * delta
			bobber += _bobber_vel * delta
			var q := PhysicsRayQueryParameters3D.create(prev, bobber, 1)
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty() and _fly_t > 0.05:
				_toast_local("Landed on dry land. Cast into deep water!")
				rod_state = Rod.RETURNING
			elif bobber.y <= DB.WATER_LEVEL:
				bobber.y = DB.WATER_LEVEL
				if lvl and lvl.floor_height(bobber.x, bobber.z) > -1.6:
					_toast_local("Too shallow! Zombies lurk in deep water.")
					rod_state = Rod.RETURNING
				else:
					rod_state = Rod.WAITING
					_bite_t = _rng.randf_range(2.0, 6.5) * float(rod.lure)
					Sfx.play("plop", bobber)
					if lvl:
						lvl.fx_burst.rpc(bobber, Color(0.85, 0.95, 1.0), 10, 3.0)
			elif _fly_t > 4.0:
				rod_state = Rod.RETURNING
		Rod.WAITING:
			_bite_t -= delta
			bobber.y = DB.WATER_LEVEL + sin(Time.get_ticks_msec() * 0.004) * 0.04
			if Input.is_action_just_pressed("secondary"):
				rod_state = Rod.RETURNING
			elif Input.is_action_pressed("primary"):
				# Reeling with nothing on the line drags the bobber in.
				var to_me := _rod_tip() - bobber
				to_me.y = 0
				bobber += to_me.normalized() * minf(4.0 * delta, to_me.length())
				var flat := bobber - global_position
				flat.y = 0
				if flat.length() < 3.0 or (lvl and lvl.floor_height(bobber.x, bobber.z) > -1.6):
					rod_state = Rod.RETURNING
			if rod_state == Rod.WAITING and _bite_t <= 0.0:
				rod_state = Rod.BITE
				_bite_window = 1.1
				hooked = DB.roll_zombie(Game.island, Game.best_rod(), _rng)
				_hooked_size = _rng.randf_range(0.8, 1.35) if hooked != "golden" else 1.0
				Sfx.play("bite", bobber, 4.0)
		Rod.BITE:
			_bite_window -= delta
			bobber.y = DB.WATER_LEVEL - 0.15 + sin(Time.get_ticks_msec() * 0.03) * 0.08
			if Input.is_action_just_pressed("primary"):
				rod_state = Rod.REELING
				tension = 0.2
				stamina = 1.0
				var flat := bobber - global_position
				flat.y = 0
				reel_dist = flat.length()
				_thrash_t = 1.0
				_reel_heat = 0.0
				_since_click = 1.0
				Sfx.play("splash", bobber)
			elif _bite_window <= 0.0:
				rod_state = Rod.WAITING
				_bite_t = _rng.randf_range(1.5, 4.0) * float(rod.lure)
				_toast_local("Missed it! Left-click when the bobber dips.")
		Rod.REELING:
			_reel(delta, rod, lvl)
		Rod.RETURNING:
			bobber = bobber.lerp(_rod_tip(), clampf(delta * 8.0, 0.0, 1.0))
			if bobber.distance_to(_rod_tip()) < 0.4:
				rod_state = Rod.IDLE
	net_bobber = bobber
	net_bobber_state = rod_state


func _reel(delta: float, rod: Dictionary, lvl: Level) -> void:
	var fight: float = DB.ZOMBIES[hooked].fight * (0.8 + _hooked_size * 0.2)
	_thrash_t -= delta
	if _thrash_t <= 0.0:
		thrashing = not thrashing
		_thrash_t = _rng.randf_range(0.5, 1.1) if thrashing else _rng.randf_range(1.3, 3.2)
	var tired := stamina < 0.3
	var pull := fight * (2.2 if thrashing else 1.0) * (0.4 if tired else 1.0)
	# Hold to reel steadily; mash to reel up to ~3.5x faster, at the cost of more line tension.
	if Input.is_action_just_pressed("primary"):
		_reel_heat = minf(_reel_heat + 1.0, 5.0)
		_since_click = 0.0
		Sfx.play("reel", global_position, -6.0, 1.0 + _reel_heat * 0.08)
	_since_click += delta
	# Gaps between mashed clicks still count as reeling, but letting go properly stops at once.
	var mashing := _since_click < 0.15
	_reel_heat = maxf(_reel_heat - (2.5 if mashing else 8.0) * delta, 0.0)
	reel_boost = _reel_heat * 0.55
	if Input.is_action_pressed("primary") or mashing:
		var speed := 1.0 + reel_boost
		tension += (0.22 + pull * 0.85) * (1.0 + 0.4 * reel_boost) * delta / float(rod.line)
		reel_dist -= 3.2 * float(rod.reel) * speed * delta * (1.0 - 0.25 * pull)
		stamina -= delta * 0.085 * (1.0 + tension) * (1.0 + 0.5 * reel_boost)
		_reel_click -= delta
		if _reel_click <= 0.0:
			_reel_click = 0.07 / speed
			Sfx.play("reel", global_position, -8.0)
	else:
		tension -= 0.9 * delta
		reel_dist += pull * 1.5 * delta
		stamina = min(stamina + delta * 0.015, 1.0)
	tension = clamp(tension, 0.0, 1.05)
	stamina = clamp(stamina, 0.0, 1.0)
	var flat := bobber - global_position
	flat.y = 0
	var dir := flat.normalized() if flat.length() > 0.1 else -global_transform.basis.z
	bobber = global_position + dir * reel_dist
	bobber.y = DB.WATER_LEVEL - 0.1
	if thrashing:
		bobber += Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2))
	_splash_t -= delta
	if _splash_t <= 0.0 and lvl:
		_splash_t = 0.25 if thrashing else 0.6
		lvl.fx_burst.rpc(bobber, Color(0.85, 0.95, 1.0), 6 if not thrashing else 14, 3.0)
	if tension >= 1.0:
		Sfx.play("snap", global_position)
		_toast_local("SNAP! The line broke. Let go when it's thrashing!")
		_reset_rod()
		return
	if reel_dist > 55.0 * float(rod.cast):
		_toast_local("It got away...")
		_reset_rod()
		return
	var shallow: bool = lvl != null and lvl.floor_height(bobber.x, bobber.z) > -1.4
	if reel_dist < 2.5 or shallow:
		_land(false)
	elif Input.is_action_just_pressed("secondary") and (tired or reel_dist < 10.0):
		_land(true)


func _land(yank: bool) -> void:
	var fwd := -global_transform.basis.z
	fwd.y = 0
	var to := global_position + fwd.normalized() * (2.2 if yank else 3.2) + Vector3.UP * 0.5
	request_catch.rpc_id(1, hooked, _hooked_size, bobber + Vector3.DOWN * 0.6, to, yank)
	Sfx.play("splash", bobber, 3.0)
	_swing = 1.0
	_reset_rod()


func _reset_rod() -> void:
	rod_state = Rod.RETURNING if rod_state in [Rod.FLYING, Rod.WAITING, Rod.BITE, Rod.REELING] else Rod.IDLE
	thrashing = false
	tension = 0.0
	_reel_heat = 0.0
	reel_boost = 0.0
	hooked = ""
	net_bobber_state = rod_state


func _draw_line() -> void:
	var im := line_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	var st := rod_state if is_local() else net_bobber_state
	var bpos := bobber if is_local() else net_bobber
	var show := st != Rod.IDLE and st != Rod.CHARGING and (is_local() or net_item == "rod")
	bobber_mesh.visible = show
	if not show:
		return
	bobber_mesh.global_position = bpos
	var a := _rod_tip()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var sag := 0.0 if st == Rod.REELING else clampf(a.distance_to(bpos) * 0.06, 0.0, 1.5)
	for i in 13:
		var t := i / 12.0
		var p := a.lerp(bpos, t) + Vector3.DOWN * sin(t * PI) * sag
		im.surface_add_vertex(p)
	im.surface_end()


# --- Combat ---------------------------------------------------------------------

func _melee(item: String) -> void:
	var w: Dictionary = DB.WEAPONS[item]
	_cooldown = float(w.cooldown)
	_swing = 1.0
	Sfx.play("swing", global_position)
	var from := camera.global_position
	var fwd := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var offsets := [Vector3.ZERO, Vector3(0.25, 0, 0), Vector3(-0.25, 0, 0), Vector3(0, 0.25, 0), Vector3(0, -0.3, 0)]
	for o in offsets:
		var dir: Vector3 = (fwd + camera.global_transform.basis * o * 0.6).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * float(w.range), 1 | 2 | 4, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var col: Object = hit.collider
		if col is Player and col.downed:
			slap_revive.rpc_id(1, col.peer_id)
			Sfx.play("slap", hit.position, 4.0)
			return
		if col is Zombie:
			var knock: float = w.knock
			var impulse := fwd * knock + Vector3.UP * knock * 0.35
			var flags := {"melee": true, "slap": item == "fists", "homerun": item == "bat"}
			if col.is_head_shape(hit.shape):
				flags["headshot"] = true
			request_hit.rpc_id(1, col.name, float(w.damage) * (1.5 if flags.has("headshot") else 1.0), impulse, flags, hit.position)
			Sfx.play("slap" if item == "fists" else "hit", hit.position)
			_level().fx_burst(hit.position, Color(0.45, 0.75, 0.2), 6, 3.0)
			add_shake(0.15)
			return


func _shoot(item: String) -> void:
	var w: Dictionary = DB.WEAPONS[item]
	if int(ammo.get(item, 0)) <= 0:
		_start_reload()
		return
	ammo[item] -= 1
	_cooldown = float(w.cooldown)
	_recoil = 1.0 if item != "smg" else 0.4
	add_shake(0.25 if item == "shotgun" else 0.08)
	var sound := "shotgun" if item == "shotgun" else ("harpoon" if item == "harpoon" else "shot")
	Sfx.play(sound, global_position)
	var lvl := _level()
	var from := camera.global_position
	var muzzle: Vector3 = vm_item.to_global(ItemModels.muzzle(item)) if vm_item else from
	var basis := camera.global_transform.basis
	var space := get_world_3d().direct_space_state
	var hits := {}  # zombie name -> {damage, impulse, flags, pos}
	for i in int(w.pellets):
		var spread: float = w.spread
		var dir := (-basis.z + basis.x * _rng.randf_range(-spread, spread) + basis.y * _rng.randf_range(-spread, spread)).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 150.0, 1 | 4, [get_rid()])
		var hit := space.intersect_ray(q)
		var end: Vector3 = hit.position if not hit.is_empty() else from + dir * 150.0
		lvl.draw_tracer(muzzle, end)
		lvl.fx_tracer.rpc(muzzle, end)
		if hit.is_empty():
			continue
		var col: Object = hit.collider
		if col is Zombie:
			var key: String = col.name
			var head_hit: bool = col.is_head_shape(hit.shape)
			var dmg: float = float(w.damage) * (2.0 if head_hit else 1.0)
			if not hits.has(key):
				hits[key] = {"damage": 0.0, "impulse": Vector3.ZERO, "flags": {}, "pos": hit.position}
			hits[key].damage += dmg
			hits[key].impulse += dir * float(w.knock)
			if head_hit:
				hits[key].flags["headshot"] = true
			if from.distance_to(hit.position) > 25.0:
				hits[key].flags["longshot"] = true
			if item == "harpoon":
				hits[key].flags["harpoon"] = true
			lvl.fx_burst(hit.position, Color(0.45, 0.75, 0.2), 4, 3.0)
		else:
			lvl.fx_burst(hit.position, Color(0.7, 0.65, 0.55), 3, 2.0)
	for key in hits:
		var h: Dictionary = hits[key]
		request_hit.rpc_id(1, key, h.damage, h.impulse, h.flags, h.pos)
	_remote_sound.rpc(sound)
	if ammo[item] <= 0:
		_start_reload()


func _start_reload() -> void:
	var item := current_item()
	if DB.WEAPONS[item].kind != "gun" or reload_t > 0.0 or int(ammo.get(item, 0)) >= int(DB.WEAPONS[item].mag):
		return
	reload_t = float(DB.WEAPONS[item].reload)
	Sfx.play("reload", global_position)


func _throw(item: String) -> void:
	var w: Dictionary = DB.WEAPONS[item]
	_cooldown = float(w.cooldown)
	_swing = 1.0
	var fwd := -camera.global_transform.basis.z
	request_throw.rpc_id(1, camera.global_position + fwd * 0.8, fwd * 16.0 + Vector3.UP * 4.0 + velocity * 0.5)


@rpc("any_peer", "call_remote", "unreliable")
func _remote_sound(sound: String) -> void:
	Sfx.play(sound, global_position + Vector3.UP * 1.5)


# --- Interaction ------------------------------------------------------------------

func _look_hit() -> Dictionary:
	if camera == null:
		return {}
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 3.4
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4 | 8, [get_rid()])
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit


func _update_prompt() -> void:
	prompt = ""
	_look_target = null
	var hit := _look_hit()
	var col: Object = hit.get("collider")
	if holding != "":
		if col is Area3D and col.get_meta("interact", "") == "grinder":
			prompt = "[E] Sell corpse"
		elif col is Area3D and col.get_meta("interact", "") == "slot":
			prompt = "[E] Gamble corpse at the Lucky Brain"
		else:
			prompt = "[Click] Throw   [E/Q] Drop"
		_look_target = col
		return
	if col == null:
		if current_item() == "rod":
			match rod_state:
				Rod.IDLE:
					prompt = "[Right-click] Hold to cast, release to throw"
				Rod.WAITING:
					prompt = "Waiting for a bite...   [Left-click] Reel in   [Right-click] Cancel"
		return
	_look_target = col
	if col is Area3D and col.has_meta("interact"):
		var kind: String = col.get_meta("interact")
		match kind:
			"grinder":
				prompt = "Brain Bank: carry or throw corpses in to sell"
			"slot":
				prompt = "Lucky Brain: bring a corpse to gamble"
			"chum":
				if Game.boss_alive:
					prompt = "The boss is already here!"
				elif Game.has_bait:
					prompt = "[E] Pour Boss Bait (summons the boss!)"
				else:
					prompt = "Chum bucket: buy Boss Bait from Doc first"
			_:
				prompt = "[E] " + str(col.get_meta("prompt"))
	elif col is Zombie and col.is_dead():
		prompt = "[E] Grab %s corpse" % col.data.name if col.size <= 2.0 and not col.boss else "Too heavy to carry - smack it into the Brain Bank!"
	elif col is Player and col.downed:
		prompt = "[E / Slap] Slap %s awake!" % Net.player_name(col.peer_id)


func _interact() -> void:
	var col := _look_target
	if holding != "":
		if col is Area3D and col.get_meta("interact", "") == "grinder":
			request_sell_held.rpc_id(1)
		elif col is Area3D and col.get_meta("interact", "") == "slot":
			request_gamble_held.rpc_id(1)
		else:
			_release(Vector3.ZERO)
		return
	if col == null:
		return
	if col is Area3D and col.has_meta("interact"):
		var hud := get_tree().get_first_node_in_group("hud")
		match col.get_meta("interact"):
			"shop":
				if hud:
					hud.open_shop()
			"boat":
				if hud:
					hud.open_travel()
			"wardrobe":
				var idx: int = Game.hats.find(Game.local_hat)
				var next: String = Game.hats[(idx + 1) % Game.hats.size()]
				Game.set_local_hat(next)
				_toast_local("Wearing: %s  (%d/%d hats found)" % [DB.HAT_NAMES[next], Game.hats.size(), DB.HATS.size()])
				Sfx.play("click")
			"chum":
				request_chum.rpc_id(1)
	elif col is Zombie and col.is_dead():
		request_grab.rpc_id(1, col.name)
	elif col is Player and col.downed:
		slap_revive.rpc_id(1, col.peer_id)
		Sfx.play("slap", col.global_position, 4.0)
		_swing = 1.0


func _release(throw_vel: Vector3) -> void:
	holding = ""
	request_release.rpc_id(1, throw_vel)


func _toast_local(text: String) -> void:
	Game.toast_received.emit(text)


func _level() -> Level:
	var n := get_parent()
	while n and not (n is Level):
		n = n.get_parent()
	return n as Level


# --- RPCs to the host --------------------------------------------------------------

func _from_owner() -> bool:
	return Net.is_host() and multiplayer.get_remote_sender_id() == peer_id


@rpc("any_peer", "call_local", "reliable")
func request_hit(target: String, damage: float, impulse: Vector3, flags: Dictionary, hit_pos: Vector3) -> void:
	if not _from_owner() or downed:
		return
	var z := _level().entities.get_node_or_null(target) as Zombie
	if z:
		z.take_hit(min(damage, 400.0), impulse.limit_length(80.0), flags, peer_id, hit_pos)


@rpc("any_peer", "call_local", "reliable")
func request_throw(pos: Vector3, vel: Vector3) -> void:
	if not _from_owner() or downed or "dynamite" not in Game.owned:
		return
	_level().spawn_projectile("dynamite", pos, vel.limit_length(30.0), peer_id)


@rpc("any_peer", "call_local", "reliable")
func request_catch(type: String, size: float, from: Vector3, to: Vector3, yank: bool) -> void:
	if not _from_owner() or not DB.ZOMBIES.has(type) or DB.ZOMBIES[type].get("boss", false):
		return
	var lvl := _level()
	var t := 1.6 if yank else 1.25
	var target := to + (Vector3.UP * 1.5 if yank else Vector3.ZERO)
	var z := lvl.spawn_zombie(type, from, Level.lob_velocity(from, target, t), clampf(size, 0.6, 1.5))
	Game.event("catch", 1, {"tier": int(DB.ZOMBIES[type].tier)})
	lvl.fx_burst.rpc(from + Vector3.UP * 0.5, Color(0.85, 0.95, 1.0), 30, 6.0)
	lvl.fx_sound.rpc("splash", from)
	var rare: bool = DB.ZOMBIES[type].get("rare", false)
	Game.toast.rpc("%s reeled in a %s%s" % [Net.player_name(peer_id), z.display_name(), "!!! (RARE)" if rare else "!"])
	if yank:
		lvl.fx_popup.rpc(from + Vector3.UP * 2.0, "YANK!", Color(0.6, 0.9, 1.0), 80)


@rpc("any_peer", "call_local", "reliable")
func request_grab(target: String) -> void:
	if not _from_owner() or downed:
		return
	var z := _level().entities.get_node_or_null(target) as Zombie
	if z and z.global_position.distance_to(global_position) < 7.0 and z.try_grab(peer_id):
		_grab_ok.rpc_id(peer_id, target)


@rpc("any_peer", "call_local", "reliable")
func _grab_ok(target: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	holding = target
	net_hold = camera.global_position - camera.global_transform.basis.z * 2.0
	Sfx.play("squelch", global_position, -4.0)


func _held_zombie() -> Zombie:
	for z in _level().get_zombies():
		if z.holder == peer_id:
			return z
	return null


@rpc("any_peer", "call_local", "reliable")
func request_release(throw_vel: Vector3) -> void:
	if not _from_owner():
		return
	var z := _held_zombie()
	if z:
		z.release_hold(throw_vel.limit_length(25.0))


@rpc("any_peer", "call_local", "reliable")
func request_sell_held() -> void:
	if not _from_owner():
		return
	var z := _held_zombie()
	if z:
		_level().sell(z, peer_id)
	_clear_holding.rpc_id(peer_id)


@rpc("any_peer", "call_local", "reliable")
func request_gamble_held() -> void:
	if not _from_owner():
		return
	var z := _held_zombie()
	if z:
		_level().gamble(z, peer_id)
	_clear_holding.rpc_id(peer_id)


@rpc("any_peer", "call_local", "reliable")
func _clear_holding() -> void:
	if multiplayer.get_remote_sender_id() == 1:
		holding = ""


@rpc("any_peer", "call_local", "reliable")
func request_chum() -> void:
	if _from_owner():
		_level().summon_boss(peer_id)


## Sent by the slapper (on their own node) with the downed player's peer id.
@rpc("any_peer", "call_local", "reliable")
func slap_revive(target_peer: int) -> void:
	if not Net.is_host():
		return
	var slapper := multiplayer.get_remote_sender_id()
	var p := _level().get_player(target_peer)
	if p == null or not p.downed or p.gull_incoming or slapper == target_peer:
		return
	p._slaps += 1
	_level().fx_popup.rpc(p.global_position + Vector3.UP * 1.2, "SLAP! %d/%d" % [p._slaps, REVIVE_SLAPS], Color(1.0, 0.6, 0.5), 70)
	_level().fx_sound.rpc("slap", p.global_position)
	if p._slaps >= REVIVE_SLAPS:
		p.host_revive(40.0)
		Game.toast.rpc("%s slapped %s back to life!" % [Net.player_name(slapper), Net.player_name(target_peer)])


# --- Health (host-authoritative) -----------------------------------------------

func host_damage(amount: float, knock: Vector3) -> void:
	if not Net.is_host() or downed or gull_incoming:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		downed = true
		_slaps = 0
		var z := _held_zombie()
		if z:
			z.release_hold()
		Game.toast.rpc("%s is DOWN! Slap them awake!" % Net.player_name(peer_id))
	_set_health.rpc(hp, downed, gull_incoming)
	_apply_knock.rpc_id(peer_id, knock)


func host_revive(new_hp: float) -> void:
	hp = new_hp
	downed = false
	gull_incoming = false
	_slaps = 0
	_set_health.rpc(hp, downed, false)


@rpc("any_peer", "call_local", "reliable")
func _set_health(new_hp: float, is_downed: bool, gull: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var was_downed := downed
	if new_hp < hp and is_local():
		add_shake(0.35)
		Sfx.play("hurt")
	hp = new_hp
	downed = is_downed
	if not gull:
		gull_incoming = false
		gull_dropped = false
	if downed and not was_downed and is_local():
		holding = ""
		_reset_rod()


@rpc("any_peer", "call_local", "reliable")
func _apply_knock(v: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	velocity += v


func carried_by_gull(pos: Vector3) -> void:
	gull_incoming = true
	global_position = pos
	velocity = Vector3.ZERO


func gull_finished() -> void:
	velocity = Vector3.ZERO
	_gull_done.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _gull_done() -> void:
	if not _from_owner():
		return
	var bill: int = min(int(Game.money * 0.1), 500)
	Game.add_money(-bill)
	host_revive(35.0)
	Game.toast.rpc("Mr. Squawks dumped %s at Doc's. Hospital bill: %s" % [Net.player_name(peer_id), DB.format_money(bill)])
