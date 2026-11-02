extends RefCounted
## Cars and people move with weight: momentum, grip, springs and footfalls rather than gliding.
## Runs on a bare test slab high above an island, so nothing in the world gets in the way.
##   tools/godot --headless --fixed-fps 60 -- --solo --test=handling
## With a window it also writes screenshots/handling/ from a trackside camera.
var test: Node
var _cam: Camera3D
var level: Level

func run(owner: Node) -> void:
	test = owner
	AudioServer.set_bus_mute(0, true)
	level = test.get_tree().get_first_node_in_group("level") as Level
	test.check(level != null and level.open_world, "default session is one open world")
	if not level or not level.open_world: return
	level.director.set_process(false)
	for infected in level.all_infected(): infected.queue_free()
	var center: Vector2 = OpenWorld.ISLANDS[3].center
	var origin := Vector3(center.x, 60, center.y)
	var slab := StaticBody3D.new()
	slab.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	slab.add_child(shape)
	level.add_child(slab)
	slab.global_position = origin - Vector3.UP * 0.5
	await test.wait(0.1)
	var me := level.local_survivor()
	for mate: Survivor in level.get_survivors():
		if mate.bot: mate.global_position = origin + Vector3(-150, 0.1, mate.slot * 2)
	await _car(me, origin)
	await _on_foot(me, origin)
	slab.queue_free()

func _car(me: Survivor, origin: Vector3) -> void:
	var car: TeamVehicle = level.vehicles().filter(func(v): return v.kind == "car")[0]
	car.global_position = origin + Vector3(0, 0.3, 120)
	car.rotation.y = 0.0
	car._speed = 0.0
	car._slip = 0.0
	car._yaw_rate = 0.0
	car.seats = PackedInt32Array([me.slot, -1, -1, -1])
	car._send_t = 1000
	await test.wait(0.5)
	var start := car.global_position
	await _drive(car, me, 1, 0, false, 0.25)
	test.check(car._speed > 0.5 and car._speed < 4.0, "car pulls away over time instead of snapping to speed (%.1f m/s after 0.25 s)" % car._speed)
	var squat := 0.0
	var spun := false
	var wheel: Node3D = car._wheels[2] if car._wheels.size() > 2 else null
	var wheel_angle := wheel.rotation.x if wheel else 0.0
	for k in 50:
		await _drive(car, me, 1, 0, false, 0.05)
		squat = maxf(squat, car._body.rotation.x)
		if wheel and absf(wheel.rotation.x - wheel_angle) > 0.01: spun = true
	test.check(car._speed > 15.0, "car builds real speed under throttle (%.1f m/s)" % car._speed)
	await _shot(car, "01-pulling-away", Vector3(4.5, 1.2, -3))
	test.check(squat > 0.004, "body squats back under power (%.3f rad)" % squat)
	test.check(car._wheels.size() >= 4 and spun, "wheels are separate and roll with the road")
	test.check(car.global_position.distance_to(start) > 20.0, "car travels forward")
	# Steering turns the front wheels, and the nose leads the velocity through a fast corner.
	var slid := 0.0
	var roll := 0.0
	for k in 16:
		await _drive(car, me, 1, 1, false, 0.05)
		slid = maxf(slid, absf(car._slip))
		roll = maxf(roll, car._body.rotation.z)
	await _shot(car, "02-cornering", Vector3(0, 1.4, -9))
	test.check(car.net_steer < -0.05, "front wheels steer right with right input")
	test.check(car._wheels[0].rotation.y < -0.05 and is_zero_approx(car._wheels[2].rotation.y), "only the front axle steers")
	test.check(slid > 0.05, "tyres scrub sideways through a fast corner (%.2f m/s)" % slid)
	test.check(roll > 0.004, "body rolls out of a right-hander (%.3f rad)" % roll)
	# Brake hard while turning: the tail lets go.
	var drift := 0.0
	var dive := 0.0
	for k in 14:
		await _drive(car, me, 0, 1, true, 0.05)
		drift = maxf(drift, absf(car._slip))
		dive = minf(dive, car._body.rotation.x)
	await _shot(car, "03-handbrake", Vector3(-7, 3, -6))
	test.check(drift > 1.5, "handbrake turn slides the car (%.1f m/s sideways)" % drift)
	test.check(dive < -0.004, "nose dives under braking (%.3f rad)" % dive)
	await _drive(car, me, 0, 0, true, 2.0)
	test.check(absf(car._speed) < 0.5 and absf(car._slip) < 0.5, "car comes to rest on the brake")
	# Hitting a wall stops the car with a jolt everyone can feel.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(20, 4, 1)
	ws.shape = wb
	wall.add_child(ws)
	level.add_child(wall)
	wall.global_position = car.global_position - car.global_transform.basis.z * 14 + Vector3.UP * 2
	wall.rotation.y = car.rotation.y  # square on: a glancing blow just scrapes along it
	var bump := car.net_bump
	for k in 50:
		await _drive(car, me, 1, 0, false, 0.05)
		if car.net_bump > bump: break
	test.check(car.net_bump > bump, "a hard hit registers as an impact")
	await _drive(car, me, 0, 0, true, 0.3)
	test.check((car.global_position - wall.global_position).dot(car.global_transform.basis.z) > 0.0, "the wall holds")
	wall.queue_free()
	car.seats = PackedInt32Array([-1, -1, -1, -1])
	car.global_position = OpenWorld.camp(0) + Vector3(-8, 0.3, 0)
	await test.wait(0.2)

## A still from a camera placed relative to the car (its local frame), while the sim keeps running.
func _shot(car: TeamVehicle, name: String, offset: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	if _cam == null:
		_cam = Camera3D.new()
		level.add_child(_cam)
	_cam.global_position = car.to_global(offset)
	_cam.look_at(car.global_position + Vector3.UP * 0.6)
	_cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/handling"))
	await test._shot(ProjectSettings.globalize_path("res://screenshots/handling/%s.png" % name))
	_cam.current = false
	level.local_survivor().camera.current = true

func _drive(car: TeamVehicle, me: Survivor, throttle: float, steer: float, brake: bool, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		car.drive(me.slot, throttle, steer, brake)
		await test.get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second

func _on_foot(me: Survivor, origin: Vector3) -> void:
	me.global_position = origin + Vector3(0, 0.1, 0)
	me.velocity = Vector3.ZERO
	me.aim(0.0, 0.0)
	await test.wait(0.5)
	Input.action_press("move_forward")
	await test.get_tree().physics_frame
	await test.get_tree().physics_frame
	var early := Vector2(me.velocity.x, me.velocity.z).length()
	await test.wait(0.5)
	var full := Vector2(me.velocity.x, me.velocity.z).length()
	Input.action_release("move_forward")
	await test.get_tree().physics_frame
	await test.get_tree().physics_frame
	var after := Vector2(me.velocity.x, me.velocity.z).length()
	test.check(early > 0.2 and early < Survivor.RUN * 0.5, "a run builds up from a standstill (%.2f m/s after two ticks)" % early)
	test.check(full > Survivor.RUN * 0.95, "full run speed within half a second (%.2f m/s)" % full)
	test.check(after > 1.0 and after < full, "letting go skids to a stop instead of halting dead (%.2f m/s)" % after)
	await test.wait(0.6)
	test.check(Vector2(me.velocity.x, me.velocity.z).length() < 0.05, "and then stands still")
	# A drop lands in the knees: the camera sinks and springs back.
	me.global_position = origin + Vector3(0, 2.5, 0)
	me.velocity = Vector3.ZERO
	var dip := 0.0
	for k in 90:
		await test.get_tree().physics_frame
		dip = minf(dip, me._dip)
	test.check(dip < -0.04, "landing a drop dips the camera (%.3f m)" % dip)
	test.check(absf(me._dip) < 0.01, "and it recovers")
	# The head bob dips at footfalls rather than floating.
	Input.action_press("move_forward")
	var low := 0.0
	var high := 0.0
	for k in 60:
		await test.get_tree().physics_frame
		low = minf(low, me.camera.position.y)
		high = maxf(high, me.camera.position.y)
	Input.action_release("move_forward")
	test.check(high - low > 0.012 * Settings.head_bob, "head bob has real travel while running (%.3f m)" % (high - low))
