extends RefCounted
func run(test: Node) -> void:
	test.process_mode = Node.PROCESS_MODE_ALWAYS
	await test.wait_for(func(): return test.level() != null and test.level().get_node_or_null("ArrivalCutscene") != null, 30)
	await test.wait_for(func(): return test.level().get_node("ArrivalCutscene").started, 30)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	await test.wait_for(func(): return not test.get_tree().paused)
	space = InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	Input.parse_input_event(space)
	var boat: TeamVehicle = test.level().vehicle_for_slot(test.me().slot)
	var hull := boat.get_child(1) as CollisionShape3D
	# Look up the physical hull without depending on child ordering.
	for child in boat.get_children():
		if child is CollisionShape3D:
			hull = child
	test.check(hull.shape.size.x >= 6 and hull.shape.size.z >= 16, "ferry has a full-sized hull and deck")
	await test.wait(0.2)
	test.check(test.me().camera.global_position.distance_to(test.me().head.global_position) < 0.1, "passenger camera remains at first-person eye height")

	test.check(boat.helm_slot == -1, "Captain Marla owns the helm by default")
	var toward_island: Vector3 = test.level().markers.ferry_terminal - boat.global_position
	toward_island.y = 0
	test.check((-boat.global_basis.z).dot(toward_island.normalized()) > 0.99, "barge and passenger view face the island")
	test.check(FerryDeck.HELM.z > FerryDeck.start(0).z and FerryDeck.HELM.z > FerryDeck.start(3).z, "helm is behind all passenger starting positions")
	var captain: StoryNPC = test.level().npc("marla_ferry")
	test.check(captain.global_position.distance_to(boat.to_global(FerryDeck.HELM)) < 0.1, "captain is physically at the helm")
	var origin := boat.global_position
	var feet: Vector3 = test.me().global_position
	test.me().aim(boat.rotation.y, 0)
	Input.action_press("move_back")
	await test.wait(1.4)
	Input.action_release("move_back")
	await test.wait(0.1)
	test.check(test.me().global_position.distance_to(feet) > 3, "passenger WASD walks on deck")
	test.check(boat.global_position.distance_to(origin) < 0.2, "passenger movement cannot steer the ferry")
	test.check(test.me().global_position.distance_to(boat.to_global(FerryDeck.HELM)) < 2.4, "passenger can walk up to the captain")
	Input.action_press("interact")
	await test.wait(0.1)
	Input.action_release("interact")
	test.check(boat.helm_slot == test.me().slot, "E at the helm replaces the captain with exactly one human driver")
	test.check(captain.global_position.distance_to(boat.to_global(FerryDeck.CAPTAIN_REST)) < 0.1, "captain steps aside when replaced")
	Input.action_press("move_forward")
	await test.wait(1.5)
	Input.action_release("move_forward")
	test.check(boat.global_position.distance_to(origin) > 2, "helm driver WASD moves the ferry")
	test.check(test.me().camera.global_position.distance_to(test.me().head.global_position) < 0.1, "driver keeps the same first-person camera")
	Input.action_press("interact")
	await test.wait(0.15)
	Input.action_release("interact")
	test.check(boat.helm_slot == -1, "E hands the helm back to Captain Marla")
	await test.wait(1.5)
	test.check(absf(boat.net_speed) < 0.1, "captain safely holds the ferry after taking control back")
	var bots: Array = test.level().get_survivors().filter(func(s: Survivor): return s.bot and s.slot in boat.seats)
	test.check(not bots.is_empty(), "bot teammates start aboard the ferry")
	await test.wait(1.0)
	test.check(bots.all(func(s: Survivor): return s.slot in boat.seats), "bots stay aboard while a human is still on the ferry")
	boat.global_position = test.level().markers.ferry_boat.pos
	boat.request_exit(test.me().slot)
	await test.wait_for(func(): return test.level().vehicle_for_slot(test.me().slot) == null, 3)
	test.check(test.level().vehicle_for_slot(test.me().slot) == null, "human disembarks at the berth")
	await test.wait_for(func(): return bots.all(func(s: Survivor): return test.level().vehicle_for_slot(s.slot) == null), 3)
	test.check(bots.all(func(s: Survivor): return test.level().vehicle_for_slot(s.slot) == null), "bots follow the humans ashore once nobody human is aboard")

func network(test: Node, host: bool) -> void:
	test.process_mode = Node.PROCESS_MODE_ALWAYS
	await test.wait_for(func(): return test.level() != null and test.level().get_node_or_null("ArrivalCutscene") != null, 40)
	await test.wait_for(func(): return test.level().get_node("ArrivalCutscene").started and Net.players.size() == 2, 40)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	await test.wait_for(func(): return not test.get_tree().paused, 15)
	space = InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	Input.parse_input_event(space)
	var boat: TeamVehicle = test.level().vehicle_for_slot(test.me().slot)
	var origin := boat.global_position
	var host_slot := Net.slot_of(1)
	test.me().aim(boat.rotation.y, 0)
	Input.action_press("move_back")
	await test.wait(1.4)
	Input.action_release("move_back")
	await test.wait(0.2)
	if host:
		Input.action_press("interact")
		await test.wait(0.15)
		Input.action_release("interact")
		test.check(boat.helm_slot == host_slot, "host takes the single helm")
		await test.wait(4)
		test.check(boat.helm_slot == host_slot, "second player cannot displace the active human driver")
		test.check(boat.global_position.distance_to(origin) < 0.2, "remote passenger steering input is rejected")
		Input.action_press("interact")
		await test.wait(0.15)
		Input.action_release("interact")
		await test.wait_for(func(): return boat.helm_slot >= 0 and boat.helm_slot != host_slot, 15)
		test.check(boat.helm_slot >= 0 and boat.helm_slot != host_slot, "client takeover replicates to host after captain regains control")
		await test.wait_for(func(): return test.multiplayer.get_peers().is_empty(), 15)
	else:
		await test.wait_for(func(): return boat.helm_slot == host_slot, 15)
		test.check(boat.helm_slot == host_slot, "host helm ownership replicates to client")
		Input.action_press("interact")
		await test.wait(0.15)
		Input.action_release("interact")
		boat.drive.rpc_id(1, test.me().slot, 1, 1, false)
		await test.wait(0.3)
		test.check(boat.helm_slot == host_slot, "client cannot steal helm from another human")
		test.check(absf(boat.net_speed) < 0.1, "non-driver cannot send steering commands")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			test.get_viewport().get_texture().get_image().save_png("res://screenshots/ferry/passenger.png")
		await test.wait_for(func(): return boat.helm_slot == -1, 15)
		Input.action_press("interact")
		await test.wait(0.2)
		Input.action_release("interact")
		test.check(boat.helm_slot == test.me().slot, "remote client can replace the NPC captain")
		Input.action_press("move_forward")
		await test.wait(1.5)
		Input.action_release("move_forward")
		test.check(boat.global_position.distance_to(origin) > 1.5, "remote helm controls move the shared ferry")
		test.check(test.me().camera.global_position.distance_to(test.me().head.global_position) < 0.1, "remote driver stays in first person")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			test.get_viewport().get_texture().get_image().save_png("res://screenshots/ferry/driver.png")
		Net.leave()
	await test.wait(0.2)
