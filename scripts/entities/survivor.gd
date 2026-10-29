class_name Survivor
extends CharacterBody3D
## One of the four survivors, played by a person (their peer owns it) or a bot (the host owns
## it and a BotBrain fills in the inputs). Movement, aim, shooting and inventory run on the
## owner so they feel instant; health, incaps, pins and revives are decided by the host.

const RUN := 5.4
const WALK_SPEED := 2.6
const CROUCH := 2.2
const LIMP := 0.8  # speed multiplier under 40 hp
const JUMP := 5.6
const GRAVITY := 16.0
const SHOVE_COOLDOWN := 0.7

var slot := 0
var peer_id := 1
var bot := false
var brain: BotBrain

# Replicated from the owner (Sync)
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0
var net_weapon := "pistol"
var net_crouch := false
var net_light := true
var net_fire := 0      # increments per shot, so others play muzzle flashes / sounds
var net_shove := 0     # increments per shove
var net_action := ""   # "revive:S1", "heal:S2", "heal_self"
var net_action_t := 0.0
var net_inv := {}
var net_reload := -1.0
var net_reload_rounds := 1
var net_aim := 0.0
var net_inspect := false

# Host-decided (pushed with _health)
var hp := DB.MAX_HP
var temp_hp := 0.0
var incapped := false
var incap_count := 0
var dead := false
var pinned_by := ""   # infected node name
var pin_type := ""    # hunter / smoker
var biled := 0.0      # seconds of bile left (owner + host count it down)

# Owner-only state
var inv := {"primary": {}, "secondary": {"id": "pistol", "mag": 15}, "throwable": "", "medkit": false, "pills": false}
var cur := "secondary"
var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var viewmodel: Node3D
var vm_item: Node3D
var body_model: CharacterModel
var body_item: Node3D
var name_label: Label3D
var glow: ShaderMaterial
static var _glow: Shader
var ui_open := false
var prompt := ""
var reload_t := 0.0
var _reload_duration := 1.0
var _shot_age := 10.0
var _motion := WeaponMotion.new()
var _vm_grip: Node3D
var _vm_support: Node3D
var action_t := 0.0
var action_target := ""
var spread := 0.0
var _cooldown := 0.0
var _shove_cd := 0.0
var _swing := 0.0
var _recoil := 0.0
var _shake := 0.0
var _pitch := 0.0
var _bob_t := 0.0
var _vm_key := ""
var _body_key := ""
var _knock := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _last_fire := 0
var _last_shove := 0
var _flash_t := 0.0
var _muzzle_flash: OmniLight3D
var _hurt_flash := 0.0
var _look_target: Object
var _step_t := 0.0

# Inputs (filled by the local player or a BotBrain each frame)
var in_move := Vector2.ZERO
var in_jump := false
var _was_riding := false
var _aim_latched := false
var _crouch_latched := false
var in_crouch := false
var in_walk := false
var in_aim := false
var aim_blend := 0.0
var in_fire := false
var in_fire_pressed := false
var in_alt_pressed := false  # shove, or "give / heal teammate" with heal items
var in_alt := false
var in_use := false
var in_use_pressed := false
var in_reload := false
var in_slot := ""


func setup(d: Dictionary) -> void:
	slot = int(d.slot)
	bot = bool(d.get("bot", false))
	peer_id = 1 if bot else int(d.peer)
	position = d.pos
	net_pos = d.pos
	rotation.y = float(d.get("yaw", 0.0))
	net_yaw = rotation.y
	var st: Dictionary = d.get("state", {})
	if st.has("hp"):
		hp = float(st.hp)
		temp_hp = float(st.get("temp", 0.0))
		incap_count = int(st.get("incaps", 0))
	if st.has("inv") and not (st.inv as Dictionary).is_empty():
		inv = (st.inv as Dictionary).duplicate(true)
	net_inv = inv.duplicate(true)
	set_multiplayer_authority(peer_id, true)


func _init() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_yaw", "net_pitch", "net_weapon", "net_crouch", "net_light", "net_fire", "net_shove", "net_action", "net_action_t", "net_inv", "net_reload", "net_reload_rounds", "net_aim", "net_inspect"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		var always: bool = prop in ["net_pos", "net_yaw", "net_pitch", "net_reload", "net_aim"]
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS if always else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


func is_local() -> bool:
	return is_multiplayer_authority()


func is_me() -> bool:
	return not bot and peer_id == multiplayer.get_unique_id()


func display_name() -> String:
	var n: String = DB.SURVIVORS[slot].name
	if bot:
		return n
	return n if Net.player_name(peer_id) == "" else "%s (%s)" % [n, Net.player_name(peer_id)]


func short_name() -> String:
	return DB.SURVIVORS[slot].name


func level() -> Level:
	return get_parent().get_parent() as Level


func _ready() -> void:
	add_to_group("survivors")
	_rng.randomize()
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 32
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	body_model = CharacterModel.new()
	add_child(body_model)
	body_model.setup_survivor(slot)

	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	flashlight = SpotLight3D.new()
	flashlight.light_energy = 3.2
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 24.0
	flashlight.spot_attenuation = 0.8
	flashlight.light_color = Color(1.0, 0.96, 0.85)
	flashlight.position = Vector3(0.25, -0.15, -0.2)
	head.add_child(flashlight)

	_muzzle_flash = OmniLight3D.new()
	_muzzle_flash.light_color = Color(1.0, 0.75, 0.35)
	_muzzle_flash.omni_range = 7.0
	_muzzle_flash.light_energy = 0.0
	_muzzle_flash.position = Vector3(0.2, -0.1, -0.9)
	head.add_child(_muzzle_flash)

	if is_me():
		camera = Camera3D.new()
		camera.fov = Settings.fov
		camera.near = 0.05
		head.add_child(camera)
		camera.current = true
		viewmodel = Node3D.new()
		camera.add_child(viewmodel)
		_vm_grip = _make_view_hand(false)
		_vm_support = _make_view_hand(true)
		var bounce := OmniLight3D.new()
		bounce.position = Vector3(-0.15, 0.10, 0.10)
		bounce.omni_range = 1.2
		bounce.light_energy = 0.55
		bounce.light_color = Color(0.8, 0.86, 1.0)
		camera.add_child(bounce)
		body_model.visible = false
		flashlight.shadow_enabled = true
	else:
		name_label = Label3D.new()
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.no_depth_test = true
		name_label.fixed_size = true
		name_label.pixel_size = 0.0012
		name_label.font_size = 26
		name_label.outline_size = 8
		name_label.position.y = 2.3
		add_child(name_label)
		# Teammates glow through walls (only where something's in the way), like L4D.
		glow = ShaderMaterial.new()
		glow.shader = _glow_shader()
		glow.set_shader_parameter("color", Color(0.35, 0.6, 1.0, 0.55))
		for mi in body_model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = glow
	if bot and Net.is_host():
		brain = BotBrain.new()
		brain.survivor = self


static func _glow_shader() -> Shader:
	if _glow:
		return _glow
	_glow = Shader.new()
	_glow.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 color : source_color = vec4(0.35, 0.6, 1.0, 0.55);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
float lin(float d, vec2 uv, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}
void fragment() {
	float scene = lin(texture(depth_tex, SCREEN_UV).r, SCREEN_UV, INV_PROJECTION_MATRIX);
	float me = lin(FRAGCOORD.z, SCREEN_UV, INV_PROJECTION_MATRIX);
	if (me < scene + 0.9) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
"""
	return _glow


# --- Inventory helpers ---------------------------------------------------------------

func weapon_id(s := "") -> String:
	var sl := cur if s == "" else s
	match sl:
		"primary", "secondary":
			return String(inv[sl].get("id", ""))
		"throwable":
			return String(inv.throwable)
		"medkit":
			return "medkit" if inv.medkit else ""
		"pills":
			return "pills" if inv.pills else ""
	return ""


func has_slot(s: String) -> bool:
	return weapon_id(s) != ""


func current_weapon() -> Dictionary:
	return Game.gun_stats(slot, weapon_id())


func select(s: String) -> void:
	if s == cur or not has_slot(s):
		return
	cur = s
	net_weapon = weapon_id()
	_motion.equip = 1.0
	_motion.inspect = 0.0
	net_reload = -1.0
	reload_t = 0.0
	_cancel_action()
	_cooldown = maxf(_cooldown, 0.35)
	_swing = 0.6


func _best_slot() -> String:
	for s in ["primary", "secondary"]:
		if has_slot(s):
			return s
	return "secondary"


func able() -> bool:
	return not dead and not incapped and pinned_by == ""


func total_hp() -> float:
	return hp + temp_hp


func black_and_white() -> bool:
	return incap_count >= DB.MAX_INCAPS and not incapped


# --- Frame ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var transport := level().vehicle_for_slot(slot)
	if transport:
		_was_riding = true
		collision_layer = 0
		collision_mask = 0
		var seat := Array(transport.seats).find(slot)
		global_position = transport.seat_position(seat)
		rotation.y = transport.rotation.y
		velocity = Vector3.ZERO
		net_pos = global_position
		net_yaw = rotation.y
		in_fire = false
		in_fire_pressed = false
		in_use_pressed = false
		in_alt_pressed = false
		in_reload = false
		in_slot = ""
		in_aim = false
		if is_me(): transport.local_controls(self,delta)
		if Net.is_host(): _host_tick(delta)
		return
	if _was_riding:
		_was_riding = false
		collision_layer = 2
		collision_mask = 1|2|4|32
		if camera:
			camera.position = Vector3.ZERO
			camera.rotation = Vector3.ZERO
	if is_local():
		_gather_input(delta)
		_local_move(delta)
		net_pos = global_position
		net_yaw = rotation.y
		net_pitch = _pitch
	else:
		global_position = global_position.lerp(net_pos, clampf(delta * 15.0, 0.0, 1.0))
		if global_position.distance_to(net_pos) > 4.0:
			global_position = net_pos
		rotation.y = lerp_angle(rotation.y, net_yaw, clampf(delta * 15.0, 0.0, 1.0))
		head.rotation.x = net_pitch
	if Net.is_host():
		_host_tick(delta)


func _gather_input(delta: float) -> void:
	if bot:
		var pulses := [in_fire_pressed, in_alt_pressed, in_use_pressed, in_reload, in_slot]
		if brain:
			brain.think(delta)
		in_fire_pressed = in_fire_pressed or pulses[0]
		in_alt_pressed = in_alt_pressed or pulses[1]
		in_use_pressed = in_use_pressed or pulses[2]
		in_reload = in_reload or pulses[3]
		if in_slot == "": in_slot = pulses[4]
		return
	var free := not ui_open
	in_move = Input.get_vector("move_left", "move_right", "move_forward", "move_back") if free else Vector2.ZERO
	in_jump = free and Input.is_action_just_pressed("jump")
	if free and Input.is_action_just_pressed("crouch"): _crouch_latched = not _crouch_latched
	if free and Input.is_action_just_pressed("aim"): _aim_latched = not _aim_latched
	if not free:
		_aim_latched = false
		_crouch_latched = false
	in_crouch = free and (_crouch_latched if Settings.toggle_crouch else Input.is_action_pressed("crouch"))
	in_walk = free and Input.is_action_pressed("walk")
	in_aim = free and (_aim_latched if Settings.toggle_aim else Input.is_action_pressed("aim"))
	in_fire = free and Input.is_action_pressed("primary")
	in_fire_pressed = free and (in_fire_pressed or Input.is_action_just_pressed("primary"))
	in_alt = free and Input.is_action_pressed("secondary")
	in_alt_pressed = free and (in_alt_pressed or Input.is_action_just_pressed("secondary"))
	in_use = free and Input.is_action_pressed("interact")
	in_use_pressed = free and (in_use_pressed or Input.is_action_just_pressed("interact"))
	in_reload = free and (in_reload or Input.is_action_just_pressed("reload"))
	if not free:
		in_slot = ""
	if free:
		for i in 5:
			if Input.is_action_just_pressed("slot_%d" % (i + 1)):
				in_slot = DB.SLOTS[i]
		if Input.is_action_just_pressed("next_slot") or Input.is_action_just_pressed("prev_slot"):
			var order: Array = DB.SLOTS.filter(func(s): return has_slot(s))
			var i := order.find(cur)
			var step := 1 if Input.is_action_just_pressed("next_slot") else -1
			in_slot = order[posmod(i + step, order.size())] if not order.is_empty() else ""
		if Input.is_action_just_pressed("inspect") and able() and reload_t <= 0.0 and action_t <= 0.0:
			_motion.inspect = 3.2
		if Input.is_action_just_pressed("flashlight"):
			net_light = not net_light
			Sfx.play("click")
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", Settings.controller_deadzone) * Settings.controller_sensitivity * lerpf(1.0, Settings.aim_sensitivity, aim_blend)
		look.y *= -1.0 if Settings.invert_look else 1.0
		rotation.y -= look.x * delta * 3.0 / lerpf(1.0, float(current_weapon().get("zoom", 1.0)), aim_blend)
		_pitch = clampf(_pitch - look.y * delta * 2.4 / lerpf(1.0, float(current_weapon().get("zoom", 1.0)), aim_blend), -1.5, 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if not is_me() or ui_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := Settings.mouse_sensitivity * lerpf(1.0, Settings.aim_sensitivity, aim_blend) * (0.5 if incapped else 1.0) / lerpf(1.0, float(current_weapon().get("zoom", 1.0)), aim_blend)
		rotation.y -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens * (-1.0 if Settings.invert_look else 1.0), -1.5, 1.5)


func aim(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = clampf(pitch, -1.5, 1.5)


func _local_move(delta: float) -> void:
	head.rotation.x = _pitch
	var crouch := in_crouch and able()
	net_crouch = crouch
	var eye := 0.55 if incapped or dead else (1.05 if crouch else 1.62)
	head.position.y = lerpf(head.position.y, eye, clampf(delta * 10.0, 0.0, 1.0))
	var speed := RUN
	if crouch:
		speed = CROUCH
	elif in_walk:
		speed = WALK_SPEED
	if total_hp() < 40.0:
		speed *= LIMP
	if biled > 0.0:
		biled -= delta
	if action_t > 0.0 or not able():
		speed = 0.0
	var dir := global_transform.basis * Vector3(in_move.x, 0, in_move.y)
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.y -= GRAVITY * delta
	if is_on_floor() and in_jump and able() and action_t <= 0.0:
		velocity.y = JUMP
	var accel := 14.0 if is_on_floor() else 3.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * RUN * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * RUN * delta)
	# Smoker drag: pulled toward whoever has the tongue on us.
	if pin_type == "smoker":
		var sm := level().get_infected(pinned_by)
		if sm:
			var to := sm.global_position - global_position
			to.y = 0
			if to.length() > 1.4:
				var pull := to.normalized() * 3.2
				velocity.x = pull.x
				velocity.z = pull.z
			else:
				velocity.x = 0
				velocity.z = 0
	elif pin_type == "hunter":
		velocity.x = 0
		velocity.z = 0
	if _knock.length() > 0.1:
		velocity += _knock
		_knock = Vector3.ZERO
	move_and_slide()
	if level().open_world and global_position.y < -0.9 and OpenWorld.land_index(global_position) < 0:
		global_position.y = -0.9
		velocity.y = 0
		velocity.x *= 0.8
		velocity.z *= 0.8
	if global_position.y < -8.0:
		global_position = level().respawn_point(self)
		velocity = Vector3.ZERO
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 0.5:
		_bob_t += delta * hs * 1.6
		_step_t -= delta * hs
		if _step_t <= 0.0 and is_me():
			_step_t = 2.2
	if camera:
		camera.position = Vector3(0, Settings.head_bob * sin(_bob_t * 2.0) * 0.022 * minf(hs / RUN, 1.0) * (1.0 - aim_blend * 0.9), 0) + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.12 * Settings.camera_shake
		var tilt := 0.0
		if incapped:
			tilt = 0.25
		camera.rotation.z = lerpf(camera.rotation.z, tilt, clampf(delta * 4.0, 0.0, 1.0))
	_shake = maxf(_shake - delta * 2.5, 0.0)


func _process(delta: float) -> void:
	_animate_frame(delta)
	# Physics may tick several times before a rendered frame. Consume one-shot inputs once.
	if is_local():
		net_weapon = weapon_id() if not dead and pinned_by == "" else ""
		in_fire_pressed = false
		in_alt_pressed = false
		in_use_pressed = false
		in_reload = false
		in_slot = ""


func _animate_frame(delta: float) -> void:
	_shot_age += delta
	_animate_body(delta)
	if not is_local():
		_remote_effects(delta)
		return
	var transport := level().vehicle_for_slot(slot)
	if viewmodel: viewmodel.visible = transport == null
	if transport:
		_cancel_action()
		reload_t = 0
		net_reload = -1
		if camera:
			camera.global_position = transport.to_global(Vector3(0,4.5,9 if transport.kind=="car" else 12))
			camera.look_at(transport.global_position+Vector3.UP*1.2)
		prompt = "WASD drive • Space brake • E exit when stopped" if transport.seats[0]==slot else "Riding with squad • E exit when stopped"
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_shove_cd = maxf(_shove_cd - delta, 0.0)
	_swing = maxf(_swing - delta * 4.0, 0.0)
	_recoil = maxf(_recoil - delta * float(current_weapon().get("recovery", 7.0)), 0.0)
	_flash_t = maxf(_flash_t - delta, 0.0)
	_muzzle_flash.light_energy = 3.0 if _flash_t > 0.0 else 0.0
	flashlight.visible = net_light and not dead
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	var w := current_weapon()
	var aiming: bool = in_aim and able() and not ui_open and w.get("kind", "") == "gun" and reload_t <= 0.0 and action_t <= 0.0
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 8.0)
	if camera and not dead:
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(Settings.fov) * 0.5) / lerpf(1.0, float(w.get("zoom", 1.0)), aim_blend)))
	spread = lerpf(spread, _target_spread(w), clampf(delta * 8.0, 0.0, 1.0))
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()
	net_reload = clampf(1.0 - reload_t / _reload_duration, 0.0, 1.0) if reload_t > 0 else -1.0
	net_aim = aim_blend
	if in_fire or in_alt or in_use or in_aim or reload_t > 0 or action_t > 0 or not able() or ui_open:
		_motion.inspect = 0.0
	net_inspect = _motion.inspect > 0
	_update_viewmodel(delta)
	_update_prompt()
	if dead:
		_spectate()
		return
	if not has_slot(cur):
		cur = _best_slot()
	if in_slot != "" and able():
		select(in_slot)
	w = current_weapon()
	if incapped:
		# Pistols only while down.
		if cur != "secondary":
			cur = "secondary"
		if DB.weapon(weapon_id("secondary")).kind == "gun":
			_gun_input(Game.gun_stats(slot, weapon_id("secondary")))
		return
	if pinned_by != "":
		_cancel_action()
		return
	if _channel(delta):
		return
	if in_use_pressed:
		_interact()
	if in_alt_pressed and _shove_cd <= 0.0 and not (cur in ["medkit", "pills"]):
		_shove()
	match String(w.get("kind", "")):
		"gun":
			_gun_input(w)
		"melee":
			if in_fire and _cooldown <= 0.0:
				_melee(w)
		"throw":
			if in_fire_pressed and _cooldown <= 0.0:
				_throw(weapon_id())
		"heal":
			_heal_input()


var spectating: Survivor


## Dead: watch a living teammate over their shoulder. Click to switch who.
func _spectate() -> void:
	if camera == null:
		return
	var alive: Array = level().get_survivors().filter(func(s): return not s.dead and s != self)
	if alive.is_empty():
		return
	if spectating == null or not is_instance_valid(spectating) or spectating.dead or in_fire_pressed:
		var i := alive.find(spectating)
		spectating = alive[(i + 1) % alive.size()]
	camera.top_level = true
	var b := Basis.from_euler(Vector3(spectating.net_pitch * 0.5 - 0.25, spectating.rotation.y, 0))
	var target := spectating.global_position + Vector3.UP * 1.9 + b * Vector3(0.6, 0.3, 2.6)
	camera.global_transform = Transform3D(b, camera.global_position.lerp(target, 0.2))


func _target_spread(w: Dictionary) -> float:
	var base: float = w.get("spread", 1.0)
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5
	if net_crouch:
		base *= 0.6
	if moving:
		base *= 1.8
	if not is_on_floor():
		base *= 2.5
	base *= lerpf(1.0, 0.22 if w.get("optic", false) else 0.45, aim_blend)
	return base + _recoil * 4.0


# --- Guns -----------------------------------------------------------------------------

func _gun_input(w: Dictionary) -> void:
	var s := cur
	var slot_inv: Dictionary = inv[s]
	if in_reload and reload_t <= 0.0:
		_start_reload()
	var want: bool = in_fire if w.auto else in_fire_pressed
	if want and _cooldown <= 0.0 and reload_t <= 0.0:
		if int(slot_inv.get("mag", 0)) <= 0:
			if in_fire_pressed:
				Sfx.play("empty", global_position)
			_start_reload()
			return
		_fire(w)


func _start_reload() -> void:
	var w := current_weapon()
	if w.get("kind", "") != "gun":
		return
	var si: Dictionary = inv[cur]
	var reserve := int(si.get("reserve", -1))
	if int(si.mag) >= int(w.mag) or reserve == 0:
		return
	_reload_duration = float(w.reload)
	net_reload_rounds = maxi(1, int(w.mag) - int(si.mag))
	reload_t = _reload_duration
	_motion.inspect = 0.0
	_cancel_action()
	Sfx.play("reload", global_position, -4.0)


func _finish_reload() -> void:
	var w := current_weapon()
	if w.get("kind", "") != "gun":
		return
	var si: Dictionary = inv[cur]
	var need := int(w.mag) - int(si.mag)
	var reserve := int(si.get("reserve", -1))
	if reserve < 0:
		si.mag = int(w.mag)
	else:
		var take := mini(need, reserve)
		si.mag = int(si.mag) + take
		si.reserve = reserve - take
	_sync_inv()


func _fire(w: Dictionary) -> void:
	var si: Dictionary = inv[cur]
	_shot_age = 0.0
	si.mag = int(si.mag) - 1
	_cooldown = float(w.rof)
	_recoil = minf(_recoil + float(w.get("recoil", 0.012)) * 12.0, 1.0)
	_flash_t = 0.05
	net_fire += 1
	_last_fire = net_fire
	Sfx.play(w.sound, global_position + Vector3.UP * 1.5, -2.0 if is_me() else 0.0)
	if w.sound == "shotgun" and not w.auto:
		get_tree().create_timer(0.35).timeout.connect(func(): Sfx.play("pump", global_position, -6.0))
	var origin := eye_position()
	var basis_ := eye_basis()
	var tip := _muzzle_world()
	var hits := {}  # infected name -> [dmg, headshot, hit_pos]
	for p in int(w.pellets):
		var sp := deg_to_rad(spread) * 0.5
		var dir := (basis_ * Vector3(_rng.randf_range(-1, 1) * sp, _rng.randf_range(-1, 1) * sp, -1.0)).normalized()
		var end := _trace(origin, dir, 90.0, float(w.dmg), int(w.pierce), hits)
		if p < 3 or _rng.randf() < 0.3:
			level().fx_tracer_local(tip, end)
	for n in hits:
		var h: Array = hits[n]
		level().request_hit.rpc_id(1, n, h[0], h[1], h[2], -basis_.z, slot)
	_pitch = clampf(_pitch + float(w.get("recoil", 0.012)) * lerpf(1.0, 0.65, aim_blend) * (1.0 if not bot else 0.0), -1.5, 1.5)
	add_shake(0.15 if int(w.pellets) > 1 else 0.05)
	if Net.is_host():
		level().make_noise(global_position, 30.0)
	if int(si.mag) <= 0:
		_start_reload()
	_sync_inv()


## Hitscan through infected (up to `pierce` of them). Survivors and alarm cars get hit too.
func _trace(origin: Vector3, dir: Vector3, dist: float, dmg: float, pierce: int, hits: Dictionary) -> Vector3:
	var exclude: Array[RID] = [get_rid()]
	var from := origin
	var end := origin + dir * dist
	var space := get_world_3d().direct_space_state
	for i in pierce + 2:
		var q := PhysicsRayQueryParameters3D.create(from, end, 1 | 2 | 4, exclude)
		var r := space.intersect_ray(q)
		if r.is_empty():
			return end
		var col: Object = r.collider
		if col is Infected:
			var inf := col as Infected
			if not inf.is_dead():
				var head_hit: bool = inf.is_headshot(r.position)
				var prev: Array = hits.get(inf.name, [0.0, false, r.position])
				var effective_range := float(current_weapon().get("range", 90.0))
				var falloff := clampf(effective_range / maxf(origin.distance_to(r.position), effective_range), 0.25, 1.0)
				hits[inf.name] = [prev[0] + dmg * falloff, prev[1] or head_hit, r.position]
				level().fx_blood_local(r.position, dir)
				pierce -= 1
				if pierce <= 0:
					return r.position
			exclude.append(r.rid)
			from = r.position + dir * 0.05
			continue
		if col is Survivor:
			var sv := col as Survivor
			if sv != self and not sv.dead:
				level().request_ff.rpc_id(1, sv.name, dmg, slot)
			return r.position
		if col is Node and (col as Node).has_meta("alarm"):
			level().request_alarm.rpc_id(1, int((col as Node).get_meta("alarm")))
		level().fx_spark_local(r.position, r.normal)
		return r.position
	return end


func eye_position() -> Vector3:
	return head.global_position


func eye_basis() -> Basis:
	return Basis.from_euler(Vector3(_pitch if is_local() else net_pitch, rotation.y, 0))


func _muzzle_world() -> Vector3:
	if vm_item and is_me():
		return vm_item.global_transform * ItemModels.muzzle(weapon_id())
	if body_item:
		return body_item.global_transform * ItemModels.muzzle(weapon_id())
	return eye_position()


# --- Melee, shove, throwables ------------------------------------------------------------

func _melee(w: Dictionary) -> void:
	_cooldown = float(w.rof)
	_swing = 1.0
	Sfx.play("swing", global_position + Vector3.UP * 1.4)
	net_shove += 1
	var hits := _cone_targets(float(w.range), float(w.arc))
	for inf in hits.slice(0, 4):
		level().request_hit.rpc_id(1, inf.name, float(w.dmg), false, inf.global_position + Vector3.UP * 1.2, -eye_basis().z, slot)
		level().fx_blood_local(inf.global_position + Vector3.UP * 1.2, -eye_basis().z)
	if not hits.is_empty():
		Sfx.play("hit", global_position)
		add_shake(0.12)
	if Net.is_host():
		level().make_noise(global_position, 10.0)


func _shove() -> void:
	_shove_cd = SHOVE_COOLDOWN
	_swing = 1.0
	net_shove += 1
	_last_shove = net_shove
	Sfx.play("shove", global_position + Vector3.UP * 1.4)
	var names: Array = []
	for inf in _cone_targets(2.2, 100.0):
		names.append(String(inf.name))
	# Shoving a pinned teammate (or whoever's on them) frees them.
	var mates: Array = []
	for s: Survivor in level().get_survivors():
		if s != self and s.pinned_by != "" and s.global_position.distance_to(global_position) < 2.4:
			mates.append(String(s.name))
	level().request_shove.rpc_id(1, names, mates, -eye_basis().z, slot)


func _cone_targets(reach: float, arc_deg: float) -> Array:
	var out: Array = []
	var fwd := -eye_basis().z
	fwd.y = 0
	fwd = fwd.normalized()
	var me := global_position
	for inf: Infected in level().all_infected():
		if inf.is_dead():
			continue
		var to: Vector3 = inf.global_position - me
		to.y = 0
		var d := to.length()
		if d > reach * inf.reach_scale() or d < 0.01:
			continue
		if rad_to_deg(fwd.angle_to(to / d)) <= arc_deg * 0.5 or d < 0.8:
			out.append(inf)
	out.sort_custom(func(a, b): return a.global_position.distance_to(me) < b.global_position.distance_to(me))
	return out


func _throw(id: String) -> void:
	_cooldown = 1.0
	_swing = 1.0
	inv.throwable = ""
	_sync_inv()
	var dir := -eye_basis().z
	var from := eye_position() + dir * 0.6
	level().request_throw.rpc_id(1, id, from, dir * 17.0 + Vector3.UP * 3.5, slot)
	Sfx.play("swing", global_position)
	cur = _best_slot()


# --- Healing and reviving (channels) --------------------------------------------------------

func _heal_input() -> void:
	var id := weapon_id()
	if id == "pills":
		if in_fire_pressed and hp + temp_hp < DB.MAX_HP:
			inv.pills = false
			_sync_inv()
			level().request_pills.rpc_id(1, name)
			Sfx.play("pills", global_position)
			cur = _best_slot()
		elif in_alt_pressed:
			var mate := _facing_mate(2.5)
			if mate and not mate.net_inv.get("pills", false):
				inv.pills = false
				_sync_inv()
				level().request_give.rpc_id(1, mate.name, "pills")
				cur = _best_slot()
	elif id == "medkit":
		if in_fire and hp < DB.MAX_HP - 1.0:
			_start_action("heal_self", name)
		elif in_alt:
			var mate := _facing_mate(2.2)
			if mate and not mate.incapped and mate.hp < DB.MAX_HP - 1.0:
				_start_action("heal", mate.name)


func _facing_mate(reach: float) -> Survivor:
	var best: Survivor
	var fwd := -eye_basis().z
	for s: Survivor in level().get_survivors():
		if s == self or s.dead:
			continue
		var to: Vector3 = s.global_position + Vector3.UP - eye_position()
		if to.length() < reach and fwd.angle_to(to.normalized()) < 0.6:
			best = s
	return best


func _start_action(kind: String, target: String) -> void:
	if action_t > 0.0 and net_action.begins_with(kind):
		return
	action_t = DB.HEAL_TIME if kind != "revive" else DB.REVIVE_TIME
	action_target = target
	net_action = "%s:%s" % [kind, target]
	net_action_t = 0.0
	if kind != "revive":
		Sfx.play("heal", global_position)


func _cancel_action() -> void:
	action_t = 0.0
	action_target = ""
	net_action = ""
	net_action_t = 0.0


## Runs an in-progress heal/revive. Returns true while it's blocking other actions.
func _channel(delta: float) -> bool:
	if action_t <= 0.0:
		return false
	var kind := net_action.get_slice(":", 0)
	var holding := in_use if kind == "revive" else (in_fire if kind == "heal_self" else in_alt)
	var target := level().get_survivor(action_target)
	var valid := target != null and not target.dead
	if valid and kind == "revive":
		valid = target.incapped and target.global_position.distance_to(global_position) < 2.6
	if valid and kind == "heal":
		valid = target.global_position.distance_to(global_position) < 2.6 and not target.incapped
	if not holding or not valid:
		_cancel_action()
		return false
	action_t -= delta
	var total := DB.REVIVE_TIME if kind == "revive" else DB.HEAL_TIME
	net_action_t = 1.0 - action_t / total
	if action_t <= 0.0:
		match kind:
			"revive":
				level().request_revive.rpc_id(1, action_target, slot)
			"heal_self", "heal":
				inv.medkit = false
				_sync_inv()
				level().request_heal.rpc_id(1, action_target, slot)
				cur = _best_slot()
		_cancel_action()
	return true


# --- Interaction -----------------------------------------------------------------------------

func _look_hit() -> Dictionary:
	var from := eye_position()
	var to := from - eye_basis().z * 2.6
	var excluded: Array[RID] = [get_rid()]
	# Revive prompts are handled by proximity; standing teammates must not block a workbench.
	for mate: Survivor in level().get_survivors():
		if mate != self:
			excluded.append(mate.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 8, excluded)
	q.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(q)


func _update_prompt() -> void:
	prompt = ""
	_look_target = null
	if dead or incapped or pinned_by != "":
		return
	var col: Object = _look_hit().get("collider")
	# Downed teammates nearby take priority even if we're not looking right at them.
	for s: Survivor in level().get_survivors():
		if s != self and s.incapped and not s.dead and s.global_position.distance_to(global_position) < 2.4:
			_look_target = s
			prompt = "Hold [E] to revive %s" % s.short_name()
			return
	for transport: TeamVehicle in level().vehicles():
		if transport.global_position.distance_to(global_position) < (6.5 if transport.kind=="boat" else 3.8):
			_look_target = transport
			prompt = "[E] Board squad %s (%d/4)" % [transport.kind, 4-Array(transport.seats).count(-1)]
			return
	if col == null:
		return
	_look_target = col
	if col is Area3D and col.has_meta("interact"):
		var kind: String = col.get_meta("interact")
		match kind:
			"pickup":
				var p := col.get_parent() as Pickup
				if p:
					prompt = "[E] " + p.prompt_for(self)
			"door":
				var d := col.get_parent() as Door
				if d:
					prompt = "[E] " + ("Close door" if d.open else "Open door")
			_:
				prompt = "[E] " + str(col.get_meta("prompt"))


func _interact() -> void:
	var t := _look_target
	if t is TeamVehicle:
		t.request_enter.rpc_id(1,slot)
		return
	if t is Survivor and (t as Survivor).incapped:
		_start_action("revive", (t as Survivor).name)
		return
	if not (t is Area3D) or not t.has_meta("interact"):
		return
	match String(t.get_meta("interact")):
		"pickup":
			var p := t.get_parent() as Pickup
			if p:
				level().request_pickup.rpc_id(1, p.name, slot)
		"gunsmith":
			var hud := get_tree().get_first_node_in_group("hud") as HUD
			if hud and level().at_gunsmith(self):
				hud.open_gunsmith(self)
		"ammo":
			_refill_ammo()
		"door":
			var d := t.get_parent() as Door
			if d:
				level().request_door.rpc_id(1, d.index)
		"button":
			level().request_button.rpc_id(1)
		"radio":
			level().request_radio.rpc_id(1)


func _refill_ammo() -> void:
	if inv.primary.is_empty():
		return
	var w := DB.weapon(inv.primary.id)
	inv.primary.reserve = int(w.reserve)
	_sync_inv()
	Sfx.play("pickup", global_position)
	if is_me():
		level().toast_local("Ammo refilled")


## Owner: the host says we got an item.
@rpc("any_peer", "call_local", "reliable")
func receive_item(id: String, extra: Dictionary) -> void:
	if not _from_host() or not is_local():
		return
	var w := DB.weapon(id)
	var dropped := ""
	var dropped_extra := {}
	match String(w.slot):
		"primary":
			if not inv.primary.is_empty():
				dropped = inv.primary.id
				dropped_extra = inv.primary.duplicate()
			inv.primary = {"id": id, "mag": int(extra.get("mag", w.mag)), "reserve": int(extra.get("reserve", w.reserve))}
			cur = "primary"
		"secondary":
			var old := String(inv.secondary.get("id", ""))
			if id == "pistol" and old == "pistol":
				id = "dual_pistols"
				w = DB.weapon(id)
			elif old != "" and old != "pistol":
				dropped = old
			if w.kind == "gun":
				inv.secondary = {"id": id, "mag": int(w.mag)}
			else:
				inv.secondary = {"id": id}
			cur = "secondary"
		"throwable":
			if inv.throwable != "":
				dropped = inv.throwable
			inv.throwable = id
		"medkit":
			inv.medkit = true
		"pills":
			inv.pills = true
	Sfx.play("pickup", global_position)
	_sync_inv()
	if dropped != "":
		level().request_drop.rpc_id(1, dropped, global_position + Vector3.UP * 0.4 - eye_basis().z * 0.6, dropped_extra)


func _sync_inv() -> void:
	net_inv = inv.duplicate(true)
	net_weapon = weapon_id()


# --- Host side --------------------------------------------------------------------------------

func _host_tick(delta: float) -> void:
	if dead:
		return
	if temp_hp > 0.0:
		temp_hp = maxf(temp_hp - DB.TEMP_DECAY * delta, 0.0)
	if incapped and pinned_by == "":
		hp -= delta * 1.0  # bleeding out
		if hp <= 0.0:
			_die()
			return
	if biled > 0.0:
		biled -= delta
	# Health only needs to reach clients now and then unless it changes suddenly.
	_health_timer -= delta
	if _health_timer <= 0.0:
		_health_timer = 0.5
		_push_health()


var _health_timer := 0.0


func host_damage(amount: float, from_dir := Vector3.ZERO, source := "") -> void:
	if not Net.is_host() or dead or amount <= 0.0:
		return
	if incapped:
		hp -= amount
		if hp <= 0.0:
			_die()
			return
	else:
		var from_temp := minf(temp_hp, amount)
		temp_hp -= from_temp
		hp -= amount - from_temp
		if hp <= 0.0:
			_incap()
	Game.add_stat(slot, "damage", int(amount))
	_push_health()
	_hurt.rpc(from_dir, source)


func _incap() -> void:
	if incap_count >= DB.MAX_INCAPS:
		_die()
		return
	incapped = true
	incap_count += 1
	hp = DB.INCAP_HP
	temp_hp = 0.0
	Game.add_stat(slot, "incaps")
	level().fx_sound.rpc("incap", global_position)
	Game.toast.rpc("%s is down!" % short_name(), Color(1.0, 0.4, 0.3))


func _die() -> void:
	dead = true
	incapped = false
	hp = 0.0
	temp_hp = 0.0
	pinned_by = ""
	pin_type = ""
	Game.toast.rpc("%s died" % short_name(), Color(1.0, 0.25, 0.2))
	level().fx_sound.rpc("incap", global_position)
	_push_health()


func host_revive() -> void:
	if not incapped or dead:
		return
	incapped = false
	hp = 1.0
	temp_hp = DB.REVIVED_HP - 1.0
	_push_health()
	if black_and_white():
		Game.toast.rpc("%s is black and white! One more down and they're dead." % short_name(), Color(0.85, 0.85, 0.85))


func host_heal() -> void:
	if dead or incapped:
		return
	hp = minf(hp + (DB.MAX_HP - hp) * 0.8, DB.MAX_HP)
	temp_hp = 0.0
	incap_count = 0
	_push_health()


func host_pills() -> void:
	if dead or incapped:
		return
	temp_hp = minf(temp_hp + 50.0, DB.MAX_HP - hp)
	_push_health()


func host_pin(by: String, type: String) -> void:
	pinned_by = by
	pin_type = type
	_cancel_action_remote.rpc()
	_push_health()


func host_unpin() -> void:
	if pinned_by == "":
		return
	pinned_by = ""
	pin_type = ""
	_push_health()


func host_knock(impulse: Vector3) -> void:
	_knock_rpc.rpc(impulse)


func _push_health() -> void:
	_health.rpc(hp, temp_hp, incapped, incap_count, dead, pinned_by, pin_type, biled)


@rpc("any_peer", "call_local", "reliable")
func _health(h: float, t: float, inc: bool, ic: int, d: bool, pb: String, pt: String, bl: float) -> void:
	if not _from_host():
		return
	var was_inc := incapped
	hp = h
	temp_hp = t
	incapped = inc
	incap_count = ic
	dead = d
	pinned_by = pb
	pin_type = pt
	if not Net.is_host():
		biled = bl
	if inc and not was_inc and is_local():
		_cancel_action()
		reload_t = 0.0


@rpc("any_peer", "call_local", "reliable")
func _hurt(_from_dir: Vector3, _source: String) -> void:
	if not _from_host():
		return
	_hurt_flash = 0.35
	if is_me():
		add_shake(0.25)
		Sfx.play("hurt", Vector3.INF, -4.0)


@rpc("any_peer", "call_local", "reliable")
func _cancel_action_remote() -> void:
	if _from_host() and is_local():
		_cancel_action()
		reload_t = 0.0


@rpc("any_peer", "call_local", "reliable")
func _knock_rpc(impulse: Vector3) -> void:
	if _from_host() and is_local():
		_knock = impulse
		add_shake(0.6)


@rpc("any_peer", "call_local", "reliable")
func set_biled(t: float) -> void:
	if _from_host():
		biled = t


## Host-decided RPCs are "any_peer" (the owner is the authority, not the host), so check.
func _from_host() -> bool:
	return multiplayer.get_remote_sender_id() == 1


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func respawn_state() -> Dictionary:
	## What this survivor carries into the next chapter.
	if dead:
		return {"hp": DB.RESPAWN_HP, "temp": 0.0, "incaps": 0, "inv": {}}
	return {"hp": maxf(hp if not incapped else DB.RESPAWN_HP * 0.5, 1.0), "temp": temp_hp, "incaps": 0 if not incapped else 1, "inv": net_inv.duplicate(true)}


# --- Visuals -----------------------------------------------------------------------------------

func _animate_body(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length() if is_local() else Vector2(net_pos.x - global_position.x, net_pos.z - global_position.z).length() * 15.0
	var pose := ""
	if level().vehicle_for_slot(slot)!=null:
		pose = "crouch"
	elif dead or incapped or pin_type == "hunter":
		pose = "down"
	elif net_crouch:
		pose = "crouch"
	elif net_action.begins_with("revive"):
		pose = "revive"
	elif net_action.begins_with("heal"):
		pose = "heal"
	elif net_reload >= 0:
		pose = "reload"
	elif net_inspect:
		pose = "inspect"
	elif DB.weapon(net_weapon).get("kind", "") == "gun":
		pose = "aim" if net_aim > 0.5 or _shot_age < 0.15 else "ready"
	body_model.animate(delta, minf(hs, 6.0), _swing, pose, net_reload, net_action_t, exp(-_shot_age * 20.0))
	var transport := level().vehicle_for_slot(slot)
	body_model.visible = not is_me() and (transport==null or transport.kind=="boat")
	body_model.position.y = -0.45 if transport else 0.0
	var upgrades := Game.gun_upgrades(slot, net_weapon)
	var key := (net_weapon + str(upgrades.hash())) if not dead else ""
	if key != _body_key:
		_body_key = key
		if body_item:
			body_item.queue_free()
			body_item = null
		if key != "":
			body_item = ItemModels.make(net_weapon, upgrades)
			body_model.hand_r.add_child(body_item)
			body_item.rotation_degrees = Vector3(-90, 0, 0)
	WeaponMotion.animate_parts(body_item, net_weapon, net_reload, _shot_age, net_reload_rounds)
	if body_item:
		body_item.visible = not net_action.begins_with("revive")
	if name_label:
		name_label.text = DB.SURVIVORS[slot].name + ("" if not incapped else "  [DOWN]")
		name_label.modulate = Color(1.0, 0.35, 0.3) if incapped or pinned_by != "" else DB.SURVIVORS[slot].ui
		name_label.visible = not dead and transport==null
	if glow:
		var gc := Color(1.0, 0.3, 0.2, 0.7) if (incapped or pinned_by != "") else (Color(0.35, 0.6, 1.0, 0.55) if not dead else Color(0, 0, 0, 0))
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_to(global_position) < 4.0:
			gc.a = 0.0
		glow.set_shader_parameter("color", gc)
	flashlight.visible = net_light and not dead


func _remote_effects(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	_swing = maxf(_swing - delta * 4.0, 0.0)
	if net_fire != _last_fire:
		_last_fire = net_fire
		_shot_age = 0.0
		_flash_t = 0.05
		var w := DB.weapon(net_weapon)
		if w.has("sound"):
			Sfx.play(w.sound, global_position + Vector3.UP * 1.5)
		if Net.is_host():
			level().make_noise(global_position, 30.0)
	if net_shove != _last_shove:
		_last_shove = net_shove
		_swing = 1.0
	_muzzle_flash.light_energy = 3.0 if _flash_t > 0.0 else 0.0


func _update_viewmodel(delta: float) -> void:
	if viewmodel == null:
		return
	var id := weapon_id() if not dead else ""
	if pinned_by != "":
		id = ""
	var upgrades := Game.gun_upgrades(slot, id)
	var key := id + str(upgrades.hash())
	if key != _vm_key:
		_vm_key = key
		_motion.equip = 1.0
		if vm_item:
			vm_item.queue_free()
			vm_item = null
		net_weapon = id
		if id != "":
			vm_item = ItemModels.make(id, upgrades)
			viewmodel.add_child(vm_item)
	var heal := sin(action_t * 8.0) * 0.012 if action_t > 0.0 else 0.0
	var pose := _motion.sample(delta, id, velocity, is_on_floor(), rotation.y, _pitch, aim_blend, _shot_age, net_reload, net_reload_rounds)
	viewmodel.rotation = pose.rotation + Vector3(-_swing * 0.85, _swing * 0.6, -_swing * 0.35)
	var hip := Vector3(0.25, -0.22, -0.40)
	var ads := Vector3(0, -GunModels.sight_height(id, upgrades), -0.28)
	viewmodel.position = hip.lerp(ads, aim_blend) + pose.position + Vector3(0, heal, 0)
	WeaponMotion.animate_parts(vm_item, id, net_reload, _shot_age, net_reload_rounds, pose)
	if _vm_grip:
		_vm_grip.visible = id != "" and id != "dual_pistols"
		_vm_grip.position = Vector3(0.005, -0.065, 0.04)
		_vm_grip.rotation = Vector3(0.15, 0, -0.15)
		_vm_support.visible = id != "" and id != "dual_pistols"
		_vm_support.position = pose.support
		_vm_support.rotation = Vector3(-0.3, 0.25, -0.5 if net_reload >= 0 else 0.2)
	viewmodel.visible = not dead and pinned_by == ""


func _make_view_hand(left: bool) -> Node3D:
	var hand := Node3D.new()
	hand.name = "SupportHand" if left else "GripHand"
	viewmodel.add_child(hand)
	var skin: Color = DB.SURVIVORS[slot].skin
	var shirt: Color = DB.SURVIVORS[slot].shirt
	Build.box(hand, Vector3(0.065, 0.065, 0.10), skin)
	for i in 4:
		Build.box(hand, Vector3(0.014, 0.048, 0.038), skin.darkened(0.08), Vector3(-0.025 + i * 0.017, -0.035, -0.035), Vector3(-20, 0, 0))
	Build.box(hand, Vector3(0.025, 0.04, 0.06), skin, Vector3(-0.04 if left else 0.04, 0.005, -0.01), Vector3(0, 0, 25))
	Build.box(hand, Vector3(0.082, 0.085, 0.19), shirt, Vector3(0, -0.035, 0.13), Vector3(-12, 0, 0))
	return hand


@rpc("any_peer", "call_local", "unreliable")
func confirm_hit() -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]: return
	if is_me():
		var hud := get_tree().current_scene.get("hud") as HUD
		if hud: hud.confirm_hit()
