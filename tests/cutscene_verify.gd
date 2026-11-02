extends RefCounted
## Actual opening-world integration plus deterministic camera/vote checks.
func run(test: Node) -> void:
	test.process_mode = Node.PROCESS_MODE_ALWAYS
	await test.wait_for(func(): return test.level() != null and test.level().get_node_or_null("ArrivalCutscene") != null, 30)
	var level: Level = test.level()
	var intro = level.get_node("ArrivalCutscene")
	await test.wait_for(func(): return intro.started, 30)
	test.check(intro.started and test.get_tree().paused, "opening starts after readiness and freezes gameplay")
	var boat := level.vehicle_for_slot(test.me().slot)
	test.check(boat != null and boat.ferry, "player starts aboard the ferry")
	for survivor in level.get_survivors():
		test.check(level.vehicle_for_slot(survivor.slot) == boat, "squad slot %d starts on the same boat" % survivor.slot)
		test.check(survivor.global_position.distance_to(boat.seat_position(survivor.slot)) < 0.2, "slot %d is placed in its seat" % survivor.slot)
	test.check(not test.get_tree().current_scene.hud.visible, "HUD hidden during cinema")
	var eye: Transform3D = test.me().camera.global_transform
	var city: Vector3 = level.markers.idol
	var safe := true
	for frame in 221:
		var seconds := frame / 20.0
		var pose: Transform3D = intro.arrival_pose(seconds, city, eye)
		if seconds < 4:
			safe = safe and pose.origin.y >= 199
		else:
			safe = safe and Vector2(pose.origin.x, pose.origin.z).distance_to(Vector2(eye.origin.x, eye.origin.z)) < 0.01
	test.check(safe, "entire final path stays above skyline until over boat, then descends vertically")
	test.check(intro.arrival_pose(11, city, eye).is_equal_approx(eye), "final shot meets exact player eye position and rotation")
	test.check(intro.crowd.size() >= 20, "city shot is populated with roaming infected")
	var positions: Array[Vector3] = []
	for infected: Infected in intro.crowd:
		positions.append(infected.global_position)
	await test.wait(0.8)
	var moved := 0
	for i in intro.crowd.size():
		if intro.crowd[i].global_position.distance_to(positions[i]) > 0.15:
			moved += 1
	test.check(moved >= 10, "infected roam while survivors and gameplay remain paused (%d moving)" % moved)
	var visible_roamers := 0
	for actor in intro.crowd:
		var head: Vector3 = actor.global_position + Vector3.UP
		if not intro.camera.is_position_in_frustum(head):
			continue
		var sight := PhysicsRayQueryParameters3D.create(intro.camera.global_position, head, 1)
		if level.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			visible_roamers += 1
	test.check(visible_roamers >= 8, "opening city camera can see roaming infected beyond buildings (%d visible)" % visible_roamers)
	var actors: Array[Infected] = intro.crowd.duplicate()
	press_space()
	await test.wait_for(func(): return not test.get_tree().paused, 2)
	test.check(not is_instance_valid(intro) or intro.ending, "solo Space vote skips without requiring bots")
	await test.get_tree().process_frame
	test.check(not test.get_tree().paused and test.get_tree().current_scene.hud.visible, "skip restores gameplay and HUD")
	test.check(test.me().camera.current, "skip restores player's camera")
	var restored := true
	for actor in actors:
		if is_instance_valid(actor):
			restored = restored and actor.process_mode == Node.PROCESS_MODE_INHERIT
	test.check(restored, "roamers return to normal gameplay processing after cutscene skip")
	test.check(Game.story.get("intro_done", false), "intro plays once per session (wipe restarts and late joiners skip it)")
	intro = load("res://scripts/world/arrival_cutscene.gd").new()
	intro.name = "NaturalFinishCheck"
	level.add_child(intro)
	intro._begin(24.99)
	intro._process(0.02)
	test.check(intro.ending and not test.get_tree().paused, "natural completion restores gameplay")
	await test.get_tree().process_frame

func press_space() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = false
	Input.parse_input_event(event)

func network(test: Node, host: bool) -> void:
	test.process_mode = Node.PROCESS_MODE_ALWAYS
	await test.wait_for(func(): return test.level() != null and test.level().get_node_or_null("ArrivalCutscene") != null, 45)
	var intro = test.level().get_node("ArrivalCutscene")
	await test.wait_for(func(): return intro.started and intro.human_peers().size() == 2, 45)
	test.check(intro.started and intro.human_peers().size() == 2, "two live human peers are in the cutscene")
	if host:
		press_space()
		press_space()
		await test.wait(0.4)
		test.check(is_instance_valid(intro) and not intro.ending, "host's Space alone does not skip")
		await test.wait_for(func(): return not test.get_tree().paused, 15)
	else:
		await test.wait_for(func(): return intro.votes.has(1), 15)
		test.check(intro.votes.has(1) and not intro.votes.has(Net.my_id()), "host vote replicates to client while client remains waiting")
		test.check("READY" in intro.skip_status.text and "WAITING" in intro.skip_status.text, "client displays who still needs to skip")
		var roamers: Array = test.level().all_infected().filter(func(i): return i.intro_roamer)
		test.check(roamers.size() >= 20, "city crowd replicates to the client")
		var before: Array[Vector3] = []
		for infected in roamers:
			before.append(infected.global_position)
		await test.wait(0.4)
		var moving := 0
		for i in roamers.size():
			if roamers[i].global_position.distance_to(before[i]) > 0.05:
				moving += 1
		test.check(moving >= 5, "client sees live roaming while gameplay is paused")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			test.get_viewport().get_texture().get_image().save_png("res://screenshots/cutscene-revision/skip-votes.png")
		await test.wait(1.0)
		press_space()
		await test.wait_for(func(): return not test.get_tree().paused, 15)
	test.check(not test.get_tree().paused, "unanimous live Space votes restore gameplay")
	test.check(test.me().camera.current, "live skip restores player camera")
	if host:
		await test.wait_for(func(): return test.multiplayer.get_peers().is_empty(), 10)
	else:
		Net.leave()
	await test.wait(0.2)
