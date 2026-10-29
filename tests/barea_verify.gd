extends RefCounted
## Barea City: the metropolis, its roadblocks and alarms, and the Yellow Sticker idol story.
var test: Node
var level: Level

func run(owner: Node) -> void:
	test = owner
	AudioServer.set_bus_mute(0, true)
	level = test.get_tree().get_first_node_in_group("level") as Level
	test.check(level != null and level.open_world, "open world loaded")
	if level == null: return
	var me := level.local_survivor()
	test.check(OpenWorld.ISLANDS[0].name == "Barea City" and OpenWorld.land_index(me.global_position) == 0, "the squad starts on Barea City")
	var blocks: Array = level.markers.city_blocks
	test.check(blocks.size() >= 120, "Barea is a big city (%d blocks)" % blocks.size())
	var xs := blocks.map(func(b): return b.x)
	var zs := blocks.map(func(b): return b.z)
	test.check(xs.max() - xs.min() > 700.0 and zs.max() - zs.min() > 600.0, "city spans %.0f x %.0f m" % [xs.max() - xs.min(), zs.max() - zs.min()])
	test.check(level.markers.roadblocks.size() >= 40, "army roadblocks across the streets (%d)" % level.markers.roadblocks.size())
	test.check(level.markers.alarm_cars.size() >= 25, "alarmed cars parked around town (%d)" % level.markers.alarm_cars.size())
	test.check(level.npcs.size() == Story.NPCS.size(), "%d survivors to talk to" % level.npcs.size())
	test.check(level.markers.idol != Vector3.INF and level._idol.visible, "the Yellow Sticker idol waits on its shrine")
	test.check(level.barea_stage() == "arrive", "story starts on arrival")
	level.director.set_process(false)
	for i in level.all_infected(): i.queue_free()

	# Roadblocks stop cars but people squeeze through the gap.
	var rb: Dictionary = level.markers.roadblocks[level.markers.roadblocks.size() / 2]
	var across: Vector3 = rb.axis
	var through := Vector3(across.z, 0, across.x)  # perpendicular: the way traffic runs
	var car := level.vehicles()[0] as TeamVehicle
	car.global_position = rb.pos - through * 14.0 + Vector3.UP * 0.2
	car.rotation.y = atan2(-through.x, -through.z)
	car.seats = PackedInt32Array([me.slot, -1, -1, -1])
	car._send_t = 1000
	for k in 60:
		car.drive(me.slot, 1.0, 0.0, false)
		await test.wait(0.05)
	var crossed: bool = (car.global_position - rb.pos).dot(through) > 1.5
	test.check(not crossed, "a car can't drive through a roadblock")
	car.seats = PackedInt32Array([-1, -1, -1, -1])
	car.global_position = OpenWorld.camp(0) + Vector3(-8, 0.3, 0)
	await test.wait(0.2)
	me.global_position = rb.gap - through * 3.0 + Vector3.UP * 0.3
	me.velocity = Vector3.ZERO
	me.aim(atan2(-through.x, -through.z), 0.0)
	await test.wait(0.2)
	Input.action_press("move_forward")
	await test.wait(1.6)
	Input.action_release("move_forward")
	test.check((me.global_position - rb.pos).dot(through) > 1.0, "on foot you squeeze through the gap")

	# Ramming an alarmed car sets it off and calls a horde.
	level.director.set_process(true)
	level.director.relax_t = 9999.0
	level.director.wander_t = 9999.0
	await test.wait(0.5)
	var alarm_i := 0
	var alarm_body: Node3D = null
	for n in level.find_children("*", "StaticBody3D", true, false):
		if n.has_meta("alarm"):
			var p: Vector3 = (n as Node3D).global_position
			var clear := true
			for d: float in [6.0, 10.0, 14.0]:
				if not level.nav.walkable_at(p + (n as Node3D).global_transform.basis.z * d): clear = false
			if clear:
				alarm_body = n
				alarm_i = int(n.get_meta("alarm"))
				break
	test.check(alarm_body != null, "found an alarmed car with room to ram it")
	if alarm_body:
		var fwd := alarm_body.global_transform.basis.z
		me.global_position = alarm_body.global_position + fwd * 20.0 + Vector3(2, 0.3, 0)
		car.global_position = alarm_body.global_position + fwd * 12.0 + Vector3.UP * 0.2
		car.rotation.y = atan2(fwd.x, fwd.z)
		car.seats = PackedInt32Array([me.slot, -1, -1, -1])
		for k in 50:
			car.drive(me.slot, 1.0, 0.0, false)
			await test.wait(0.05)
			if level._alarms_used.has(alarm_i): break
		test.check(level._alarms_used.has(alarm_i), "ramming an alarmed car sets it off")
		test.check(await test.wait_for(func(): return level.count_commons() >= 8, 8.0), "the alarm draws a horde (%d)" % level.count_commons())
		car.seats = PackedInt32Array([-1, -1, -1, -1])
		car.global_position = OpenWorld.camp(0) + Vector3(-8, 0.3, 0)
	level.director.set_process(false)
	for i in level.all_infected(): i.queue_free()

	# Talk to Captain Marla on the harbour.
	var marla := level.npc("marla")
	me.global_position = marla.global_position + marla.global_transform.basis.z * 1.8 + Vector3.UP * 0.3
	await test.wait(0.2)
	var hud := test.get_tree().get_first_node_in_group("hud") as HUD
	hud.talk(level, "marla")
	await test.wait(0.3)
	test.check(hud._talk_panel.visible and hud._talk_text.text.contains("Barea"), "Marla tells her story")
	test.check(level.barea_stage() == "hunt", "talking reveals the idol's whereabouts")
	for k in Story.npc("marla").lines.size():
		hud.talk(level, "marla")
	test.check(not hud._talk_panel.visible, "conversation ends after the last line")

	# Take the idol: high alert.
	me.global_position = level.markers.idol + Vector3(2.5, -2.3, 0)
	for s: Survivor in level.get_survivors():
		if s.bot: s.global_position = me.global_position + Vector3(1.5, 0, s.slot * 1.2)
	level.director.set_process(true)
	await test.wait(0.3)
	level.request_idol.rpc_id(1, me.slot)
	await test.wait(0.3)
	test.check(level.barea_stage() == "alert" and level.director.city_alert, "taking the idol puts the city on high alert")
	test.check(not level._idol.visible, "the idol is gone from its shrine")
	var peak := 0
	var first_id := level._next_id
	var t := 0.0
	while t < 20.0:
		await test.get_tree().process_frame
		t += test.get_process_delta_time()
		peak = maxi(peak, level.count_commons())
		if me.incapped: me.host_revive()
		me.hp = 100.0
	var sent := level._next_id - first_id
	test.check(sent >= 35, "nonstop hordes while on alert (%d infected sent in 20 s, %d at once)" % [sent, peak])

	# Escape by boat.
	var boat: TeamVehicle = null
	for v: TeamVehicle in level.vehicles():
		if v.kind == "boat" and v.global_position.distance_to(OpenWorld.dock(0)) < 60.0:
			boat = v
	test.check(boat != null, "Barea has a boat at the harbour")
	me.global_position = boat.global_position + Vector3(0, 0.6, 2)
	boat.request_enter(me.slot)
	await test.wait(0.2)
	test.check(level.vehicle_for_slot(me.slot) == boat, "boarded the boat")
	test.check(level.barea_stage() == "alert", "still on alert while moored")
	boat.global_position = OpenWorld.dock(0) + Vector3(160, -0.45, 0)
	boat.net_pos = boat.global_position
	test.check(await test.wait_for(func(): return level.barea_stage() == "escaped", 3.0), "sailing away escapes Barea City")
	test.check(not level.director.city_alert, "the alert ends once you're away")


## Screenshots: tools/godot -- --solo --test=barea_shots
func shots(owner: Node) -> void:
	test = owner
	AudioServer.set_bus_mute(0, true)
	level = test.get_tree().get_first_node_in_group("level") as Level
	var dir := ProjectSettings.globalize_path("res://screenshots/barea")
	DirAccess.make_dir_recursive_absolute(dir)
	var me := level.local_survivor()
	level.director.set_process(false)
	await test.wait(5.5)  # let the banner fade
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.far = 4000.0
	cam.fov = 70.0
	# 1. Skyline from the harbour
	var dock := OpenWorld.dock(0)
	cam.global_position = dock + Vector3(60, 45, 120)
	cam.look_at(level.markers.city_blocks[level.markers.city_blocks.size() / 2] + Vector3.UP * 40, Vector3.UP)
	cam.current = true
	await _snap(dir + "/01_skyline.png")
	# 2. Aerial over downtown
	cam.global_position = OpenWorld.camp(0) + Vector3(-150, 260, 300)
	cam.look_at(OpenWorld.camp(0) + Vector3(-480, 0, 0), Vector3.UP)
	await _snap(dir + "/02_aerial.png")
	cam.current = false
	me.camera.current = true
	# 3. Street level on the avenue
	var avenue := OpenWorld.camp(0) + Vector3(-300, 0.3, 0)
	me.global_position = avenue
	me.aim(PI * 0.5, 0.12)
	await test.wait(0.6)
	await _snap(dir + "/03_street.png")
	# 4. A roadblock
	var rb: Dictionary = level.markers.roadblocks[7]
	var through := Vector3(rb.axis.z, 0, rb.axis.x)
	me.global_position = rb.pos - through * 9.0 + Vector3.UP * 0.3
	me.aim(atan2(-through.x, -through.z), -0.05)
	await test.wait(0.6)
	await _snap(dir + "/04_roadblock.png")
	# 5. The Megamart shrine and the idol
	me.global_position = level.markers.idol + Vector3(9, -2.3, 0)
	test.aim_at(me, level.markers.idol)
	await test.wait(0.6)
	await _snap(dir + "/05_megamart.png")
	me.global_position = level.markers.idol + Vector3(2.6, -2.3, 0.4)
	test.aim_at(me, level.markers.idol)
	await test.wait(0.6)
	await _snap(dir + "/06_idol.png")
	# 7. Talking to Dev at the petrol station
	var dev := level.npc("dev")
	me.global_position = dev.global_position + dev.global_transform.basis.z * 2.2 + Vector3.UP * 0.3
	test.aim_at(me, dev.global_position + Vector3.UP * 1.6)
	await test.wait(0.4)
	var hud := test.get_tree().get_first_node_in_group("hud") as HUD
	hud.talk(level, "dev")
	hud.talk(level, "dev")
	await test.wait(0.4)
	await _snap(dir + "/07_npc.png")
	hud._end_talk()
	# 8. High alert on the avenue
	me.global_position = avenue + Vector3(-60, 0, 0)
	level.director.set_process(true)
	Game.story.barea = "alert"
	level.director.city_alert = true
	for k in 3:
		level.director.spawn_mob(16, false)
	var near: Array = []
	for k in 40:
		await test.wait(0.25)
		me.hp = 100.0
		near = level.all_infected().filter(func(i): return not i.is_dead() and i.global_position.distance_to(me.global_position) < 22.0 and level.line_of_sight(me.eye_position(), i.global_position + Vector3.UP))
		if near.size() >= 5: break
	if not near.is_empty():
		test.aim_at(me, near[0].global_position + Vector3.UP)
	await test.wait(0.05)
	await _snap(dir + "/08_alert.png")
	# 9. World map
	hud.open_world_map(level)
	await test.wait(0.3)
	await _snap(dir + "/09_map.png")
	hud.close_modal()


func _snap(path: String) -> void:
	await test._shot(path)
