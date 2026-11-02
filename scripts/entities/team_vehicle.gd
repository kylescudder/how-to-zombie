class_name TeamVehicle
extends CharacterBody3D
## Host simulates vehicles and seat ownership; clients send clamped driver controls only.
## Handling is arcade but physical: the nose turns through a bicycle model, the velocity lags behind it
## and tyre grip pulls it back in line, so hard corners and the handbrake slide. Every peer then reads the
## resulting motion to pitch and roll the body on its springs, spin the wheels and rev the engine.

## Per-kind handling. Speeds in m/s, rates in m/s² (or rad/s for yaw). Tyres (or the hull) push back
## harder the further they slide, by `bite` per m/s of slip, up to `grip`: so corners carry a little slip angle.
const HANDLING := {
	"car": {"top": 24.0, "reverse": 8.0, "engine": 9.5, "brake": 17.0, "coast": 1.6, "drag": 0.0022,
		"grip": 21.0, "slide_grip": 5.5, "bite": 12.0, "steer": 0.58, "steer_fast": 0.13, "yaw_response": 7.0},
	"boat": {"top": 17.0, "reverse": 5.0, "engine": 5.0, "brake": 7.0, "coast": 0.9, "drag": 0.004,
		"grip": 8.0, "slide_grip": 3.0, "bite": 2.5, "steer": 0.55, "steer_fast": 0.3, "yaw_response": 2.4},
}
const WATERLINE := -0.45

var kind := "car"
var model := ""
var ferry := false  # Marla's boat at Barea's old ferry terminal (the escape boat)
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_speed := 0.0
var net_steer := 0.0  # front wheel angle, radians
var net_bump := 0.0   # running total of impact speed; peers jolt by the difference
var seats := PackedInt32Array([-1,-1,-1,-1])
var _throttle := 0.0
var _steer := 0.0
var _brake := true
var _input_age := 0.0
var _send_t := 0.0
var _speed := 0.0      # along the nose (+ forwards)
var _slip := 0.0       # sideways (+ to the right): the slide tyres haven't caught yet
var _yaw_rate := 0.0
var _vy := 0.0
var _steer_now := 0.0  # steering input after the wheel has turned towards it
var _gas := 0.0        # throttle after the pedal has travelled
var _wheels: Array[Node3D] = []
var last_exit := {}
# Presentation, on every peer.
var _body: Node3D       # the sprung part: everything but the wheels
var _pivot := 0.5
var _wheel_r := 0.33
var _wheelbase := 2.6
var _spin := 0.0
var _seen_bump := 0.0
var _last_pos := Vector3.INF
var _last_yaw := 0.0
var _vis_vel := Vector3.ZERO   # local frame, smoothed
var _vis_acc := Vector3.ZERO   # local frame, smoothed
var _vis_yaw_rate := 0.0
var _pitch := 0.0
var _pitch_v := 0.0
var _roll := 0.0
var _roll_v := 0.0
var _heave := 0.0
var _heave_v := 0.0
var _clock := 0.0
var _jolt := 0.0
var _revs := 0.0
var _engine: EngineVoice
var _skid: AudioStreamPlayer3D
var _cam_pos := Vector3.ZERO
var _cam_yaw := 0.0
var _cam_frame := -10

func setup(data: Dictionary) -> void:
	kind = data.type
	model = data.get("model",VehicleCatalog.CAMP_MODELS[0])
	ferry = bool(data.get("ferry", false))
	position = data.pos
	net_pos = position
	rotation.y = float(data.yaw)
	net_yaw = rotation.y

func _init() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for property in ["net_pos", "net_yaw", "net_speed", "net_steer", "net_bump", "seats"]:
		var path := NodePath(".:"+property)
		cfg.add_property(path)
		cfg.property_set_spawn(path,true)
		cfg.property_set_replication_mode(path,SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.replication_interval = 1.0/20
	add_child(sync)

func _ready() -> void:
	add_to_group("team_vehicles")
	collision_layer = 32
	collision_mask = 1 | 32
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var spec := VehicleCatalog.find(model)
	box.size = Vector3(spec.wid+0.2,1.4,spec.len+0.1) if kind=="car" else Vector3(3,0.65,6)
	shape.shape = box
	# Flush with the tyre bottoms (the model's y=0), so the car rests on its wheels rather than in the road.
	shape.position.y = box.size.y*0.5 if kind=="car" else 0.3
	add_child(shape)
	# The body hangs from a pivot at axle height, so it pitches and rolls about its springs, not the road.
	_pivot = spec.r if kind=="car" else 0.5
	_wheel_r = spec.r
	_body = Node3D.new()
	_body.name = "Body"
	_body.position.y = _pivot
	add_child(_body)
	var shell := Node3D.new()
	shell.position.y = -_pivot
	_body.add_child(shell)
	if kind == "car":
		VehicleKit.build(shell,model,Color(0,0,0,0),true)
		_wheels = VehicleKit.build_wheels(self,model)
		_wheelbase = maxf(float(spec.ax_r)-float(spec.ax_f),1.8)
		Build.label(shell,"SQUAD 04",Vector3(0,spec.roof+0.75,0),20,Color(1,0.88,0.62))
	else:
		ArtShapes.loft(shell,[Vector4(-0.15,0.1,0.1,0),Vector4(0,1.15,2.8,0),Vector4(0.65,1.55,3.25,0),Vector4(0.8,1.5,3.1,0)],Color(0.84,0.73,0.47))
		Build.box(shell,Vector3(2.4,0.14,4.7),Color(0.39,0.50,0.46),Vector3(0,0.82,0))
		for z in [-0.9,0.8]: Build.box(shell,Vector3(2.4,0.45,0.6),Color(0.67,0.28,0.18),Vector3(0,1.03,z))
		Build.box(shell,Vector3(0.7,0.8,0.6),Color(0.25,0.35,0.35),Vector3(-0.65,1.22,-1.7))
		Build.box(shell,Vector3(0.9,0.8,0.5),Color(0.17,0.22,0.23),Vector3(0,0.65,3))
		Build.label(shell,"MARLA'S FERRY" if ferry else "SQUAD BOAT",Vector3(0,1.9,0),20,Color(1,0.9,0.7))
		_wheelbase = 3.4
	if DisplayServer.get_name() != "headless":
		_engine = EngineVoice.new(kind)
		_engine.position.y = 0.8
		add_child(_engine)
	if kind == "car": _skid = _loop_player("skid_loop")
	_last_pos = global_position
	_last_yaw = rotation.y

func _loop_player(sound: String) -> AudioStreamPlayer3D:
	var stream := Sfx.stream(sound)
	if stream == null: return null  # headless: nothing synthesised
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "Vehicles"
	player.unit_size = 8.0
	player.max_distance = 110.0
	player.volume_db = -80.0
	player.position.y = 0.8
	add_child(player)
	return player

func level() -> Level:
	return get_parent().get_parent() as Level

func survivor_at(index: int) -> Survivor:
	return level().get_survivor_by_slot(seats[index]) if seats[index] >= 0 else null

func seat_position(index: int) -> Vector3:
	return to_global(Vector3(-0.55 if index%2==0 else 0.55,0.6 if kind=="car" else 0.85,-0.5 if index<2 else 0.85))

func _owns(slot: int) -> bool:
	if not Net.is_host(): return false
	var survivor := level().get_survivor_by_slot(slot)
	var sender := multiplayer.get_remote_sender_id()
	return survivor != null and (sender == survivor.peer_id or sender == 0 or sender == 1 and survivor.bot)

@rpc("any_peer","call_local","reliable")
func request_enter(slot: int) -> void:
	if not _owns(slot): return
	var survivor := level().get_survivor_by_slot(slot)
	if not survivor.able() or absf(_speed)>2 or survivor.global_position.distance_to(global_position)>7: return
	if level().vehicle_for_slot(slot) != null: return
	var index := Array(seats).find(-1)
	if index < 0: return
	seats[index] = slot
	if index == 0:
		_throttle = 0
		_steer = 0
		_brake = true
		# Nearby bots ride with the squad; human players choose their own seats.
		for mate: Survivor in level().get_survivors():
			if mate.bot and mate.able() and mate.global_position.distance_to(global_position)<22 and level().vehicle_for_slot(mate.slot)==null:
				var free := Array(seats).find(-1)
				if free>=0: seats[free]=mate.slot

func exit_point(slot: int) -> Vector3:
	var index := Array(seats).find(slot)
	if index<0: return Vector3.INF
	for offset in [Vector3(-3,0,0),Vector3(3,0,0),Vector3(0,0,-5),Vector3(0,0,5),Vector3(-5,0,0),Vector3(5,0,0),Vector3(5,0,-5),Vector3(-5,0,-5),Vector3(5,0,5),Vector3(-5,0,5)]:
		var point := to_global(offset)
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*3,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y<0.8: continue
		point = hit.position+Vector3.UP*0.12
		if point.y < -0.1 or point.y > 1.2: continue
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.45
		capsule.height = 1.8
		var overlap := PhysicsShapeQueryParameters3D.new()
		overlap.shape = capsule
		overlap.transform.origin = point+Vector3.UP*0.95
		overlap.collision_mask = 1|2|32
		overlap.exclude = [get_rid()]
		var occupied := false
		for mate: Survivor in level().get_survivors():
			if mate.slot!=slot and not mate.slot in seats and mate.global_position.distance_to(point)<1.1: occupied=true
		if not occupied and get_world_3d().direct_space_state.intersect_shape(overlap).is_empty(): return point
	return Vector3.INF

@rpc("any_peer","call_local","reliable")
func request_exit(slot: int) -> void:
	if not _owns(slot) or absf(_speed)>2: return
	_exit(slot)

func _exit(slot: int) -> void:
	var point := exit_point(slot)
	if point == Vector3.INF: return
	var index := Array(seats).find(slot)
	seats[index] = -1
	last_exit[slot] = point
	place_rider.rpc(slot,point)
	if index == 0:
		_throttle=0
		_brake=true
		for other in seats.duplicate():
			var mate := level().get_survivor_by_slot(other)
			if mate and mate.bot: _exit(other)

@rpc("authority","call_local","reliable")
func place_rider(slot: int, point: Vector3) -> void:
	var survivor := level().get_survivor_by_slot(slot)
	if survivor:
		survivor.global_position = point
		survivor.net_pos = point
		survivor.velocity = Vector3.ZERO

@rpc("any_peer","call_local","unreliable_ordered")
func drive(slot: int, throttle: float, steer: float, brake: bool) -> void:
	if not _owns(slot) or seats[0]!=slot or not is_finite(throttle) or not is_finite(steer): return
	_throttle=clampf(throttle,-1,1)
	_steer=clampf(steer,-1,1)
	_brake=brake
	_input_age=0

func _physics_process(delta: float) -> void:
	if Net.is_host():
		_input_age+=delta
		for index in 4:
			var rider := survivor_at(index)
			if seats[index]>=0 and (rider==null or not rider.able()):
				if rider: place_rider.rpc(rider.slot,global_position+Vector3(4,0.2,0))
				seats[index]=-1
		_simulate(delta)
		net_pos=global_position
		net_yaw=rotation.y
		net_speed=_speed
		net_steer=-_steer_now*_steer_limit()
	else:
		global_position=global_position.lerp(net_pos,1-exp(-delta*12))
		rotation.y=lerp_angle(rotation.y,net_yaw,1-exp(-delta*12))
	_present(delta)

func _steer_limit() -> float:
	var h: Dictionary = HANDLING[kind]
	return lerpf(h.steer,h.steer_fast,clampf(absf(_speed)/h.top,0,1))

func _simulate(delta: float) -> void:
	var h: Dictionary = HANDLING[kind]
	var driver := survivor_at(0)
	var live := driver != null and _input_age < 0.5
	var throttle := _throttle if live else 0.0
	var braking := _brake or not live
	# Pedals and the wheel take a moment to travel, so taps don't snap the car around.
	_gas = move_toward(_gas,throttle,delta*(5.0 if absf(throttle)>absf(_gas) else 8.0))
	var steer_goal := _steer if live else 0.0
	var winding := absf(steer_goal)>absf(_steer_now) and steer_goal*_steer_now>=0.0  # turning in, not unwinding
	_steer_now = move_toward(_steer_now,steer_goal,delta*(3.2 if winding else 6.0))
	# Longitudinal: engine pull fades towards top speed; opposite throttle brakes before it reverses.
	var accel := 0.0
	if _gas > 0.01:
		if _speed < -0.5: accel = h.brake*0.6*_gas
		else: accel = h.engine*_gas*maxf(0.0,1.0-pow(maxf(_speed,0.0)/h.top,2))
	elif _gas < -0.01:
		if _speed > 0.5: accel = h.brake*0.6*_gas
		else: accel = h.engine*0.7*_gas*maxf(0.0,1.0-pow(minf(_speed,0.0)/h.reverse,2))
	var resist: float = h.coast*(1.0 if absf(_gas)<0.01 else 0.3)+h.drag*_speed*_speed
	if braking: resist += h.brake
	_speed += accel*delta
	_speed = move_toward(_speed,0.0,resist*delta)
	_speed = clampf(_speed,-h.reverse*1.05,h.top*1.05)
	# Yaw: bicycle model, capped by what the tyres can hold, then eased in so the body has inertia.
	# Boats turn on prop wash even when nearly stopped.
	var turn_speed := _speed if kind=="car" else _speed+_gas*2.5
	var steer_angle := _steer_now*_steer_limit()
	var yaw_goal := -turn_speed*tan(steer_angle)/_wheelbase
	var hold: float = h.grip*(1.25 if braking and kind=="car" else 1.0)
	yaw_goal = clampf(yaw_goal,-hold/maxf(absf(_speed),4.0),hold/maxf(absf(_speed),4.0))
	if braking and kind=="car" and absf(_speed) > 6.0: yaw_goal *= 1.35  # handbrake: the tail steps out
	_yaw_rate = lerpf(_yaw_rate,yaw_goal,1.0-exp(-delta*float(h.yaw_response)))
	var turn := _yaw_rate*delta
	rotation.y += turn
	# The velocity doesn't turn with the nose; re-express it in the new heading and let grip pull it in line.
	var fwd := _speed*cos(turn)-_slip*sin(turn)
	var side := _slip*cos(turn)+_speed*sin(turn)
	_speed = fwd
	var grip: float = h.slide_grip if braking and absf(_speed) > 4.0 else h.grip
	if kind == "car" and absf(side) > 3.5: grip *= 0.6  # once it's sliding, it keeps sliding a little
	_slip = move_toward(side,0.0,minf(absf(side)*h.bite,grip)*delta)
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var desired := forward*_speed+right*_slip
	var next := global_position+desired*delta
	var allowed := absf(next.x)<OpenWorld.EXTENT-20 and absf(next.z)<OpenWorld.EXTENT-20
	if kind=="car": allowed = allowed and OpenWorld.land_index(next,8)>=0
	else: allowed = allowed and OpenWorld.land_index(next,-2)<0
	if not allowed:
		# The coast (or the map edge) behaves like a soft wall: bump back off it.
		_bump(absf(_speed)+absf(_slip))
		_speed *= -0.2
		_slip *= 0.3
		desired = Vector3.ZERO
	if kind=="car":
		_vy = -1.0 if is_on_floor() else _vy-22.0*delta
	else:
		_vy = 0.0
	velocity = desired+Vector3.UP*_vy
	move_and_slide()
	var flat := Vector3(velocity.x,0,velocity.z)
	var impact := 0.0
	var torque := 0.0
	for k in get_slide_collision_count():
		var hit := get_slide_collision(k)
		var collider := hit.get_collider()
		# Ramming an alarmed car sets it off, just like shooting it.
		if collider is Node and (collider as Node).has_meta("alarm") and absf(_speed) > 3.0:
			level().request_alarm(int((collider as Node).get_meta("alarm")))
		var normal := hit.get_normal()
		if absf(normal.y) > 0.7: continue  # floor, not a wall
		normal = Vector3(normal.x,0,normal.z).normalized()
		var into := -desired.dot(normal)
		if into > impact:
			impact = into
			# Off-centre hits twist the car about its middle.
			var arm := hit.get_position()-global_position
			torque = arm.cross(normal).y*into
	if impact > 0.5 and desired.length() > 0.1:
		# Keep the slide along the wall, lose some of it to scraping, and bounce back a little on hard hits.
		var normal_out := (flat-desired).normalized() if (flat-desired).length() > 0.01 else -desired.normalized()
		flat = flat*clampf(1.0-impact*0.04,0.55,1.0)+normal_out*impact*(0.25 if impact > 4.0 else 0.0)
		_yaw_rate = clampf(_yaw_rate+torque*0.05,-2.5,2.5)
		_speed = flat.dot(forward)
		_slip = flat.dot(right)
		if impact > 3.0: _bump(impact)
	if kind=="boat": global_position.y=WATERLINE

## Host only: record an impact for every peer to feel and hear.
func _bump(size: float) -> void:
	if size < 3.0: return
	net_bump += size

## Every peer: read how the vehicle is actually moving and act it out on the springs, wheels and engine.
func _present(delta: float) -> void:
	_clock += delta
	if _last_pos == Vector3.INF: _last_pos = global_position
	var moved := (global_position-_last_pos)/maxf(delta,0.0001)
	if moved.length() > 60.0: moved = Vector3.ZERO  # teleports and spawns
	var local := global_transform.basis.inverse()*moved
	var yaw_rate := angle_difference(_last_yaw,rotation.y)/maxf(delta,0.0001)
	_last_pos = global_position
	_last_yaw = rotation.y
	var before := _vis_vel
	_vis_vel = _vis_vel.lerp(local,1.0-exp(-delta*14.0))
	_vis_acc = _vis_acc.lerp((_vis_vel-before)/maxf(delta,0.0001),1.0-exp(-delta*10.0))
	_vis_yaw_rate = lerpf(_vis_yaw_rate,yaw_rate,1.0-exp(-delta*10.0))
	var forward_speed := -_vis_vel.z
	var lateral_g := _vis_yaw_rate*forward_speed
	var top: float = HANDLING[kind].top
	# Impacts arrive as a growing total, so late joiners and dropped packets don't replay old crashes.
	if net_bump > _seen_bump:
		var size := net_bump-_seen_bump
		_seen_bump = net_bump
		if size < 40.0:
			_pitch_v += clampf(size*0.05,0,0.9)*(-signf(forward_speed) if absf(forward_speed)>0.5 else 1.0)
			_heave_v += clampf(size*0.03,0,0.5)
			_roll_v += randf_range(-1,1)*clampf(size*0.03,0,0.5)
			_jolt = clampf(_jolt+size*0.06,0,1.2)
			Sfx.play("crash",global_position+Vector3.UP,clampf(-14.0+size*1.2,-14.0,4.0),clampf(1.2-size*0.02,0.75,1.2))
	_jolt = maxf(_jolt-delta*2.5,0)
	var pitch_goal: float
	var roll_goal: float
	var heave_goal := 0.0
	if kind == "car":
		# Squat under power, dive under braking, lean out of corners; a little road buzz at speed.
		pitch_goal = clampf(-_vis_acc.z*0.0045,-0.05,0.05)
		roll_goal = clampf(-lateral_g*0.0042,-0.065,0.065)
		var buzz := clampf(absf(forward_speed)/top,0,1)
		heave_goal = (sin(_clock*19.0)*0.6+sin(_clock*31.7)*0.4)*0.006*buzz
	else:
		# Boats ride up onto the plane with speed, lean into turns and rock on the swell.
		var plane := clampf(forward_speed/top,0,1)
		pitch_goal = plane*0.07-sin(plane*PI)*0.02+clampf(-_vis_acc.z*0.01,-0.05,0.05)+sin(_clock*1.1+global_position.x*0.05)*0.025
		roll_goal = clampf(lateral_g*0.012,-0.14,0.14)+sin(_clock*0.8+global_position.z*0.04)*0.03
		heave_goal = sin(_clock*1.3+global_position.x*0.07)*0.09+sin(_clock*2.3)*0.03+plane*0.12
	# Under-damped springs, so weight shifts overshoot and settle instead of easing.
	_pitch_v += ((pitch_goal-_pitch)*130.0-_pitch_v*13.0)*delta
	_roll_v += ((roll_goal-_roll)*110.0-_roll_v*11.0)*delta
	_heave_v += ((heave_goal-_heave)*160.0-_heave_v*14.0)*delta
	_pitch += _pitch_v*delta
	_roll += _roll_v*delta
	_heave += _heave_v*delta
	_body.rotation = Vector3(_pitch,0,_roll)
	_body.position.y = _pivot+_heave
	# Wheels roll at road speed and the fronts follow the replicated steering angle.
	_spin = fposmod(_spin-forward_speed*delta/_wheel_r,TAU)
	for wheel in _wheels:
		wheel.rotation = Vector3(_spin,net_steer if wheel.get_meta("front") else 0.0,0)
	_engine_sound(delta,forward_speed,absf(_vis_vel.x))

func _engine_sound(delta: float, forward_speed: float, slide: float) -> void:
	var occupied := Array(seats).any(func(s): return s >= 0)
	var top: float = HANDLING[kind].top
	var speed := absf(forward_speed)
	# A five-speed box: revs climb through each gear and drop at the change.
	var revs := 0.0
	if kind == "car":
		var gears := [0.0,0.17,0.34,0.54,0.76,1.05]
		var frac := speed/top
		var gear := 1
		while gear < gears.size()-1 and frac > gears[gear]: gear += 1
		revs = inverse_lerp(gears[gear-1]*0.55,gears[gear],frac)
	else:
		revs = speed/top
	var load := clampf(-_vis_acc.z/6.0,0,1)
	_revs = lerpf(_revs,clampf(revs,0,1),1.0-exp(-delta*(6.0 if revs > _revs else 9.0)))
	if _engine:
		var volume := -80.0
		if occupied: volume = -6.0+_revs*3.0+load*2.0
		_engine.volume_db = lerpf(_engine.volume_db,volume,1.0-exp(-delta*(8.0 if occupied else 3.0)))
		# Keep clear of the limiter: cruising sits mid-range and only a hard pull nears redline.
		_engine.revs = _revs*0.75+load*0.1
		_engine.load = load
		if volume > -79.0 and not _engine.playing: _engine.play()
		elif _engine.volume_db < -70.0 and _engine.playing and not occupied: _engine.stop()
	if _skid:
		var squeal := clampf((slide-2.5)/5.0,0,1) if is_on_floor() or not Net.is_host() else 0.0
		_skid.volume_db = lerpf(-45.0,-13.0,squeal)
		_skid.pitch_scale = 0.95+squeal*0.1
		if squeal > 0.02 and not _skid.playing: _skid.play()
		elif squeal <= 0.02 and _skid.playing: _skid.stop()

## The chase camera for whoever's aboard: trails the heading with a lag, pulls back and widens with speed,
## shakes on impacts and keeps out of walls.
func chase_camera(cam: Camera3D, delta: float) -> void:
	var top: float = HANDLING[kind].top
	var pace := clampf(absf(_vis_vel.z)/top,0,1)
	var frame := Engine.get_process_frames()
	var fresh := frame-_cam_frame > 2
	_cam_frame = frame
	if fresh: _cam_yaw = rotation.y
	# Reversing keeps the camera behind, not swinging round to the bumper.
	_cam_yaw = lerp_angle(_cam_yaw,rotation.y,1.0-exp(-delta*(2.6+pace*1.5)))
	var dist := (8.5 if kind=="car" else 12.0)+pace*2.0
	var height := (3.4 if kind=="car" else 4.8)+pace*0.4
	var focus := global_position+Vector3.UP*1.3
	var goal := global_position+Basis(Vector3.UP,_cam_yaw)*Vector3(0,height,dist)
	var ray := PhysicsRayQueryParameters3D.create(focus,goal,1)
	ray.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): goal = hit.position+(focus-goal).normalized()*0.4
	_cam_pos = goal if fresh else _cam_pos.lerp(goal,1.0-exp(-delta*9.0))
	var shake := Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*_jolt*0.25*Settings.camera_shake
	cam.global_position = _cam_pos+shake
	cam.look_at(focus-Basis(Vector3.UP,_cam_yaw).z*clampf(_vis_vel.z*-0.35,-2,7))
	cam.rotate_object_local(Vector3.BACK,-_roll*0.35)
	cam.fov = lerpf(cam.fov,Settings.fov+pace*12.0,1.0-exp(-delta*4.0))

func local_controls(survivor: Survivor, delta: float) -> void:
	if Input.is_action_just_pressed("interact") and not survivor.ui_open: request_exit.rpc_id(1,survivor.slot)
	if seats[0]!=survivor.slot: return
	_send_t-=delta
	if _send_t<=0:
		_send_t=0.05
		var move := Input.get_vector("move_left","move_right","move_forward","move_back") if not survivor.ui_open else Vector2.ZERO
		drive.rpc_id(1,survivor.slot,-move.y,move.x,survivor.ui_open or Input.is_action_pressed("jump"))
