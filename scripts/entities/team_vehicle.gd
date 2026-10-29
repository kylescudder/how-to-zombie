class_name TeamVehicle
extends CharacterBody3D
## Host simulates vehicles and seat ownership; clients send clamped driver controls only.
var kind := "car"
var ferry := false  # Marla's boat at Barea's old ferry terminal (the escape boat)
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_speed := 0.0
var seats := PackedInt32Array([-1,-1,-1,-1])
var _throttle := 0.0
var _steer := 0.0
var _brake := true
var _input_age := 0.0
var _send_t := 0.0
var _speed := 0.0
var _wheels: Array[Node3D] = []
var last_exit := {}

func setup(data: Dictionary) -> void:
	kind = data.type
	ferry = bool(data.get("ferry", false))
	position = data.pos
	net_pos = position
	rotation.y = float(data.yaw)
	net_yaw = rotation.y

func _init() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for property in ["net_pos", "net_yaw", "net_speed", "seats"]:
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
	box.size = Vector3(2.1,1.4,4.5) if kind=="car" else Vector3(3,0.65,6)
	shape.shape = box
	shape.position.y = 0.85 if kind=="car" else 0.3
	add_child(shape)
	if kind == "car":
		StreetArt.car(self,Color(0.74,0.34,0.16))
		Build.box(self,Vector3(1.6,0.12,1.4),Color(0.18,0.22,0.22),Vector3(0,1.82,0.1))
		Build.label(self,"SQUAD 04",Vector3(0,2.2,0),20,Color(1,0.88,0.62))
	else:
		ArtShapes.loft(self,[Vector4(-0.15,0.1,0.1,0),Vector4(0,1.15,2.8,0),Vector4(0.65,1.55,3.25,0),Vector4(0.8,1.5,3.1,0)],Color(0.84,0.73,0.47))
		Build.box(self,Vector3(2.4,0.14,4.7),Color(0.39,0.50,0.46),Vector3(0,0.82,0))
		for z in [-0.9,0.8]: Build.box(self,Vector3(2.4,0.45,0.6),Color(0.67,0.28,0.18),Vector3(0,1.03,z))
		Build.box(self,Vector3(0.7,0.8,0.6),Color(0.25,0.35,0.35),Vector3(-0.65,1.22,-1.7))
		Build.box(self,Vector3(0.9,0.8,0.5),Color(0.17,0.22,0.23),Vector3(0,0.65,3))
		Build.label(self,"MARLA'S FERRY" if ferry else "SQUAD BOAT",Vector3(0,1.9,0),20,Color(1,0.9,0.7))

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
		var driver := survivor_at(0)
		var throttle := _throttle if driver and _input_age<0.5 else 0.0
		var braking := _brake or driver==null or _input_age>=0.5
		var top_speed := 23.0 if kind=="car" else 17.0
		_speed = move_toward(_speed,throttle*top_speed,delta*(15 if braking else 6))
		if braking: _speed=move_toward(_speed,0,delta*20)
		rotation.y -= _steer * clampf(_speed/7,-1,1) * delta * (1.35 if kind=="car" else 0.85)
		var desired := -global_transform.basis.z*_speed
		var next := global_position+desired*delta
		var allowed := absf(next.x)<OpenWorld.EXTENT-20 and absf(next.z)<OpenWorld.EXTENT-20
		if kind=="car": allowed = allowed and OpenWorld.land_index(next,8)>=0
		else: allowed = allowed and OpenWorld.land_index(next,-2)<0
		if not allowed:
			_speed=0
			desired=Vector3.ZERO
		velocity=desired
		if kind=="car": velocity.y=-5
		move_and_slide()
		# Ramming an alarmed car sets it off, just like shooting it.
		for k in get_slide_collision_count():
			var hit := get_slide_collision(k).get_collider()
			if hit is Node and (hit as Node).has_meta("alarm") and absf(_speed) > 3.0:
				level().request_alarm(int((hit as Node).get_meta("alarm")))
		if kind=="boat": global_position.y=-0.45
		if get_slide_collision_count()>0 and Vector2(velocity.x,velocity.z).length()<absf(_speed)*0.4: _speed*=0.6
		net_pos=global_position
		net_yaw=rotation.y
		net_speed=_speed
	else:
		global_position=global_position.lerp(net_pos,1-exp(-delta*12))
		rotation.y=lerp_angle(rotation.y,net_yaw,1-exp(-delta*12))

func local_controls(survivor: Survivor, delta: float) -> void:
	if Input.is_action_just_pressed("interact") and not survivor.ui_open: request_exit.rpc_id(1,survivor.slot)
	if seats[0]!=survivor.slot: return
	_send_t-=delta
	if _send_t<=0:
		_send_t=0.05
		var move := Input.get_vector("move_left","move_right","move_forward","move_back") if not survivor.ui_open else Vector2.ZERO
		drive.rpc_id(1,survivor.slot,-move.y,move.x,survivor.ui_open or Input.is_action_pressed("jump"))
