extends RefCounted
var test: Node
var level: Level

func run(owner: Node) -> void:
	test=owner
	AudioServer.set_bus_mute(0,true)
	level=test.get_tree().get_first_node_in_group("level") as Level
	test.check(level!=null and level.open_world,"default session is one open world")
	if not level or not level.open_world: return
	level.director.set_process(false)
	for infected in level.all_infected(): infected.queue_free()
	await test.wait(0.1)
	test.check(level.vehicles().size()==11,"five cars, five boats and Marla's ferry spawned in shared world")
	test.check(level.nav.w==OpenWorld.GRID and is_equal_approx(level.nav.cell_size,4),"3 km navigation uses bounded 4 m grid")
	for index in 5:
		var base := OpenWorld.camp(index)
		test.check(OpenWorld.land_index(base)==index and level.nav.walkable_at(base),"region %d has reachable camp" % index)
		var ray := PhysicsRayQueryParameters3D.create(base+Vector3.UP*5,base-Vector3.UP*5,1)
		test.check(not level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"region %d has real collidable terrain" % index)
	test.check(level.nav.path(OpenWorld.camp(0),OpenWorld.camp(1)).is_empty(),"AI cannot walk across the sea")
	var me := level.local_survivor()
	if "--capture-only" in OS.get_cmdline_user_args():
		await capture(me)
		return
	var car := level.vehicles()[0] as TeamVehicle
	me.global_position=car.global_position+Vector3(3,0.1,0)
	for mate: Survivor in level.get_survivors():
		if mate.bot: mate.global_position=car.global_position+Vector3(4,0.1,mate.slot)
	car.request_enter(me.slot)
	await test.wait(0.1)
	test.check(Array(car.seats).count(-1)==0,"driver and three nearby bots board four distinct seats")
	var start := car.global_position
	Input.action_press("move_forward")
	await test.wait(3)
	Input.action_release("move_forward")
	test.check(car.global_position.distance_to(start)>12,"real driver input moves car on road")
	car.request_exit(me.slot)
	test.check(me.slot in car.seats,"moving vehicle refuses unsafe exit")
	Input.action_press("jump")
	await test.wait(2)
	Input.action_release("jump")
	car.request_exit(me.slot)
	await test.wait(0.15)
	test.check(level.vehicle_for_slot(me.slot)==null,"stopped car allows safe disembark")
	test.check(Array(car.seats).count(-1)==4,"bots disembark with driver")
	var boat := level.vehicles()[1] as TeamVehicle
	me.global_position=OpenWorld.dock(0)+Vector3(28,0.15,6)
	for mate: Survivor in level.get_survivors():
		if mate.bot: mate.global_position=me.global_position+Vector3(0,0,mate.slot*0.4)
	boat.request_enter(me.slot)
	await test.wait(0.15)
	test.check(level.vehicle_for_slot(me.slot)==boat,"squad boards boat from harbour pier")
	boat.request_exit(me.slot)
	await test.wait(0.1)
	test.check(level.vehicle_for_slot(me.slot)==null,"boat gangway allows safe exit onto pier")
	me.global_position=OpenWorld.dock(0)+Vector3(28,0.15,6)
	boat.request_enter(me.slot)
	await test.wait(0.1)
	# Real continuous physics journey around Rustwater's south coast to its east dock.
	boat._send_t=1000
	var finish: Vector3 = OpenWorld.dock(1)+Vector3(31,-0.45,10)
	for point in [Vector3(-200,-0.45,-160),Vector3(1250,-0.45,-160),Vector3(1250,-0.45,-890),finish]:
		await drive_to(boat,me.slot,point)
	boat.drive(me.slot,0,0,true)
	await test.wait(2)
	test.check(boat.global_position.distance_to(finish)<16,"boat travelled between islands without loading a new level")
	boat.request_exit(me.slot)
	await test.wait(0.15)
	test.check(level.vehicle_for_slot(me.slot)==null,"squad disembarks at destination harbour")
	test.check(OpenWorld.land_index(me.global_position, -35)==1,"player arrives on Rustwater's pier")
	test.check(test.get_tree().get_first_node_in_group("level")==level and Game.phase=="playing","same session continues with no chapter completion")
	# Coast restriction for land vehicles.
	car.global_position=OpenWorld.dock(0)+Vector3(0,0,20)
	car.rotation.y=-PI/2
	car.seats=PackedInt32Array([me.slot,-1,-1,-1])
	car._speed=22
	car.drive(me.slot,1,0,false)
	await test.wait(0.15)
	test.check(OpenWorld.land_index(car.global_position,0)>=0,"car cannot drive into deep sea")
	car.seats=PackedInt32Array([-1,-1,-1,-1])
	car._speed=0
	me.global_position=OpenWorld.camp(0)+Vector3.UP*0.1
	if DisplayServer.get_name()!="headless": await capture(me)

func drive_to(vehicle: TeamVehicle, slot: int, goal: Vector3) -> void:
	var elapsed := 0.0
	while vehicle.global_position.distance_to(goal)>1.8 and elapsed<160:
		var delta := goal-vehicle.global_position
		var target := atan2(-delta.x,-delta.z)
		var error := angle_difference(vehicle.rotation.y,target)
		var throttle := minf(0.55 if absf(error)>0.45 else 1.0,clampf(delta.length()/25.0,0.12,1.0))
		vehicle.drive(slot,throttle,clampf(-error*2,-1,1),false)
		await test.wait(0.05)
		elapsed+=0.05
	test.check(vehicle.global_position.distance_to(goal)<9,"boat reaches route waypoint")

func capture(me: Survivor) -> void:
	var scene := test.get_tree().current_scene
	await test.wait(0.3)
	scene.hud.open_world_map(level)
	await test.wait(0.2)
	await test._shot(ProjectSettings.globalize_path("res://screenshots/open-world/01-world-map.png"))
	scene.hud.close_modal()
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.current=true
	camera.far=6000
	for index in 5:
		var center: Vector2=OpenWorld.ISLANDS[index].center
		camera.global_position=Vector3(center.x+210,160,center.y+240)
		camera.look_at(Vector3(center.x,0,center.y))
		await test.wait(0.2)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/open-world/region-%d.png" % index))
	camera.global_position=Vector3(1400,1800,1400)
	camera.look_at(Vector3.ZERO)
	await test.wait(0.2)
	await test._shot(ProjectSettings.globalize_path("res://screenshots/open-world/02-archipelago.png"))
	camera.queue_free()
	me.camera.current=true
	var car := level.vehicles()[0] as TeamVehicle
	car.global_position=OpenWorld.camp(0)+Vector3(-8,0.1,0)
	me.global_position=car.global_position+Vector3(3,0.1,0)
	car.request_enter(me.slot)
	await test.wait(0.3)
	await test._shot(ProjectSettings.globalize_path("res://screenshots/open-world/03-driving.png"))
