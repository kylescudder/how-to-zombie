extends RefCounted
## Scripted demo clips of driving and moving on foot, for recording with Godot's Movie Maker.
## Only uses the public controls (drive(), input actions, in_move), so it plays the same on older builds.
##   tools/godot --fixed-fps 60 --resolution 1280x720 --write-movie out/frame.png -- --solo --test=handling_demo --clip=drive
## Clips: drive, trackside, boat, on_foot, teammate.
var test: Node
var level: Level
var me: Survivor
var cam: Camera3D

func run(owner: Node) -> void:
	test = owner
	level = test.get_tree().get_first_node_in_group("level") as Level
	if not level or not level.open_world: return
	level.director.set_process(false)
	for infected in level.all_infected(): infected.queue_free()
	test.get_tree().current_scene.hud.visible = false
	# Recordings use a fixed mix, whatever the player's saved volumes are (not saved back).
	for pair in [["Master", 0.8], ["Effects", 0.8], ["Weapons", 1.0], ["Vehicles", 1.0], ["Environment", 1.0], ["Music", 0.25], ["Voice", 0.7]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus >= 0:
			AudioServer.set_bus_mute(bus, false)
			AudioServer.set_bus_volume_db(bus, linear_to_db(pair[1]))
	me = level.local_survivor()
	var clip := "drive"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="): clip = arg.trim_prefix("--clip=")
	var field := _ground(Vector3(OpenWorld.ISLANDS[3].center.x, 0, OpenWorld.ISLANDS[3].center.y))
	# Everyone else stands well out of the way, idle.
	for mate: Survivor in level.get_survivors():
		if mate.bot:
			mate.brain = null
			mate.in_move = Vector2.ZERO
			mate.global_position = field + Vector3(-300, 1, mate.slot * 3)
	await test.wait(0.5)
	match clip:
		"drive": await _drive(field)
		"trackside": await _trackside(field)
		"boat": await _boat()
		"on_foot": await _on_foot(field)
		"teammate": await _teammate(field)

func _ground(p: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 80, p - Vector3.UP * 80, 1)
	var hit := level.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position if not hit.is_empty() else p

func _car() -> TeamVehicle:
	return level.vehicles().filter(func(v): return v.kind == "car")[0]

func _seat(vehicle: TeamVehicle, at: Vector3, yaw: float) -> void:
	vehicle.global_position = at
	vehicle.rotation.y = yaw
	vehicle.seats = PackedInt32Array([me.slot, -1, -1, -1])
	vehicle._send_t = 1000  # the script drives, not the keyboard

## Plays (seconds, throttle, steer, brake) steps, calling hook(step_index) as each begins.
func _script(vehicle: TeamVehicle, steps: Array, hook := Callable()) -> void:
	for i in steps.size():
		var step: Array = steps[i]
		if hook.is_valid(): hook.call(i)
		var frames := int(float(step[0]) * Engine.physics_ticks_per_second)
		for f in frames:
			vehicle.drive(me.slot, step[1], step[2], step[3])
			if cam and cam.current: _track(vehicle)
			await test.get_tree().physics_frame

## A camera car running alongside on a fixed world-space offset, eased so the subject drifts in frame.
var _side := Vector3.ZERO
func _track(vehicle: TeamVehicle) -> void:
	var goal := vehicle.global_position + _side
	cam.global_position = cam.global_position.lerp(goal, 1.0 - exp(-4.0 / Engine.physics_ticks_per_second))
	cam.look_at(vehicle.global_position + Vector3.UP * 0.7)

func _wall(at: Vector3, yaw: float) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14, 2.4, 1.2)
	shape.shape = box
	wall.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.52, 0.48)
	bm.material = mat
	mesh.mesh = bm
	wall.add_child(mesh)
	level.add_child(wall)
	wall.global_position = at + Vector3.UP * 1.2
	wall.rotation.y = yaw

func _drive(field: Vector3) -> void:
	var car := _car()
	_seat(car, field + Vector3(-60, 0.4, 60), 0.0)
	await test.wait(0.6)
	var steps := [
		[1.0, 0, 0, false],     # idle
		[4.0, 1, 0, false],     # pull away through the gears
		[1.6, 1, 1, false],     # right-hander
		[1.0, 1, 0, false],
		[1.6, 1, -1, false],    # left-hander
		[1.2, 1, 0, false],
		[1.5, 0, 1, true],      # brake and turn: the tail steps out
		[1.2, 0, 0, true],
		[3.8, 1, 0, false],     # straight into a wall
		[1.8, 0, 0, true],
	]
	await _script(car, steps, func(i):
		if i == 8: _wall(car.global_position - car.global_transform.basis.z * 28, car.rotation.y))

func _trackside(field: Vector3) -> void:
	var car := _car()
	var road := field + Vector3(40, 0, 40)
	_seat(car, road + Vector3(0, 0.4, 0), 0.0)
	# Front three-quarter, off the right flank: wheels, roll and dive all read from here.
	_side = Vector3(6.5, 1.4, -4.0)
	cam = Camera3D.new()
	level.add_child(cam)
	cam.global_position = car.global_position + _side
	cam.current = true
	await test.wait(0.4)
	var steps := [
		[0.6, 0, 0, false],
		[3.0, 1, 0, false],     # build speed towards the camera
		[0.7, 1, -1, false],    # flick left
		[0.7, 1, 1, false],     # and right as it passes
		[1.6, 0, 0, true],      # brake hard: nose dives
		[1.5, 0.6, 1, false],   # pull away turning
		[1.5, 0, 0, true],
	]
	await _script(car, steps)

func _boat() -> void:
	var boat: TeamVehicle = level.vehicles().filter(func(v): return v.kind == "boat")[0]
	_seat(boat, OpenWorld.dock(0) + Vector3(60, -0.45, 10), -PI / 2)
	await test.wait(0.6)
	var steps := [
		[1.0, 0, 0, false],
		[4.0, 1, 0, false],     # up onto the plane
		[3.0, 1, 1, false],     # long right turn
		[2.5, 1, -1, false],    # swing back left
		[2.5, 0, 0, false],     # cut the throttle and coast
	]
	await _script(boat, steps)

## Holds input actions for a while, optionally turning the view at a steady rate (rad/s).
func _hold(actions: Array, seconds: float, turn := 0.0) -> void:
	for a in actions: Input.action_press(a)
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for f in frames:
		if turn != 0.0: me.aim(me.rotation.y + turn / Engine.physics_ticks_per_second, me._pitch)
		await test.get_tree().physics_frame
	for a in actions: Input.action_release(a)

func _on_foot(field: Vector3) -> void:
	var spot := field + Vector3(30, 0, -40)
	# A loading platform to run off the edge of.
	var deck := StaticBody3D.new()
	deck.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 1.6, 6)
	shape.shape = box
	deck.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.25)
	bm.material = mat
	mesh.mesh = bm
	deck.add_child(mesh)
	level.add_child(deck)
	deck.global_position = spot + Vector3.UP * 0.8
	me.global_position = spot + Vector3(0, 1.7, 1.5)
	me.velocity = Vector3.ZERO
	me.aim(0.0, -0.12)
	await test.wait(1.0)
	await _hold(["move_forward"], 3.0, 0.15)          # run off the platform and keep going
	await _hold([], 1.0)                              # let go
	await _hold(["move_right"], 1.4)                  # strafe
	await _hold(["move_left"], 1.4)
	await _hold([], 0.5)
	Input.action_press("move_forward")
	for k in 2:
		await _hold([], 0.6)
		await _hold(["jump"], 0.05)
		await _hold([], 0.9)
	Input.action_release("move_forward")
	await _hold([], 0.6)
	await _hold(["move_forward", "walk"], 2.2, -0.3)  # walking pace
	await _hold([], 1.0)

func _teammate(field: Vector3) -> void:
	var mate: Survivor = level.get_survivors().filter(func(s): return s.bot)[0]
	var spot := field + Vector3(-30, 0, -30)
	mate.global_position = spot + Vector3.UP * 0.2
	mate.rotation.y = 0.0
	me.global_position = spot + Vector3(-60, 1, 0)
	cam = Camera3D.new()
	level.add_child(cam)
	cam.current = true
	await test.wait(0.6)
	var plan := [
		[1.0, Vector2.ZERO, false, false],
		[2.6, Vector2(0, -1), false, false],   # run
		[1.0, Vector2.ZERO, false, false],
		[2.0, Vector2(1, 0), false, false],    # strafe right
		[2.0, Vector2(0, 1), false, false],    # back-pedal
		[2.0, Vector2(-1, 0), false, false],   # strafe left
		[2.4, Vector2(0, -1), true, false],    # walk
		[2.2, Vector2(0, -1), false, true],    # crouch-walk
		[1.0, Vector2.ZERO, false, false],
	]
	var orbit := 0.6
	for step in plan:
		var frames := int(float(step[0]) * Engine.physics_ticks_per_second)
		for f in frames:
			mate.in_move = step[1]
			mate.in_walk = step[2]
			mate.in_crouch = step[3]
			orbit += 0.35 / Engine.physics_ticks_per_second
			var focus := mate.global_position + Vector3.UP * 1.0
			cam.global_position = focus + Vector3(sin(orbit) * 5.5, 0.9, cos(orbit) * 5.5)
			cam.look_at(focus)
			await test.get_tree().physics_frame
	mate.in_move = Vector2.ZERO
