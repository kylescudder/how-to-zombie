extends RefCounted

func run(test: Node, host: bool) -> void:
	AudioServer.set_bus_mute(0,true)
	if host:
		var ready: bool = await test.wait_for(func(): return Net.players.size()>1,30)
		test.check(ready,"second peer joined open world")
	else:
		test.check(await test.wait_for(func(): return Net.in_session() and test.get_tree().get_first_node_in_group("level")!=null,30),"client received open-world level")
	var level := test.get_tree().get_first_node_in_group("level") as Level
	if not level: return
	test.check(await test.wait_for(func(): return level.vehicles().size()==11 and level.local_survivor()!=null,20),"ten vehicles and local survivor replicated")
	if host: level.director.set_process(false)
	var car := level.vehicles()[0] as TeamVehicle
	var me := level.local_survivor()
	if host:
		test.check(await test.wait_for(func(): return car.seats[0]>=0,20),"host received remote boarding request")
		var driver := level.get_survivor_by_slot(car.seats[0])
		test.check(driver!=null and driver.peer_id!=1,"remote player owns driver seat")
		me.global_position=car.global_position+Vector3(3,0.1,0)
		car.request_enter(me.slot)
		test.check(me.slot in car.seats,"host joins remote driver's passenger seat")
		var start := car.global_position
		test.check(await test.wait_for(func(): return car.global_position.distance_to(start)>12,15),"host physics responds to remote driving inputs")
		test.check(me.global_position.distance_to(car.seat_position(Array(car.seats).find(me.slot)))<1,"host passenger moves with remote driver")
		test.check(await test.wait_for(func(): return car.seats[0]==-1,20),"remote driver exits after stopping")
		car.request_exit(me.slot)
		await test.wait(0.1)
		test.check(level.vehicle_for_slot(me.slot)==null,"host passenger safely exits shared vehicle")
		await test.wait(2)
	else:
		me.global_position=car.global_position+Vector3(3,0.1,0)
		await test.wait(0.6)
		car.request_enter.rpc_id(1,0)
		await test.wait(0.3)
		test.check(not 0 in car.seats,"client cannot board as another peer's survivor")
		car.request_enter.rpc_id(1,me.slot)
		test.check(await test.wait_for(func(): return car.seats[0]==me.slot,10),"client receives authoritative seat ownership")
		await test.wait(2)
		var start := car.global_position
		Input.action_press("move_forward")
		await test.wait(3)
		Input.action_release("move_forward")
		test.check(car.global_position.distance_to(start)>12,"client sees replicated vehicle movement")
		Input.action_press("jump")
		await test.wait(2)
		Input.action_release("jump")
		car.request_exit.rpc_id(1,me.slot)
		test.check(await test.wait_for(func(): return not me.slot in car.seats,10),"client receives safe disembark and cleared seat")
		await test.wait(0.1)
		test.check(me.collision_layer==2,"client restores on-foot collision after exit")
		await test.wait(1)
	await _story(test, level, host)


## Barea's story over the network: the client talks and takes the idol; everyone sees it.
func _story(test: Node, level: Level, host: bool) -> void:
	var me := level.local_survivor()
	if host:
		test.check(await test.wait_for(func(): return level.barea_stage() == "keys", 20), "host sees the client's conversation start Act 2")
		test.check(await test.wait_for(func(): return level.barea_stage() == "power" and level.event_left() > 0.0, 20), "client taking the keys starts the host's alarm hold-out")
		await test.wait(3)
	else:
		test.check(await test.wait_for(func(): return level.npcs.size() == Story.NPCS.size(), 10), "client builds the story NPCs")
		var hud := test.get_tree().get_first_node_in_group("hud") as HUD
		var marla := level.npc("marla")
		me.global_position = marla.global_position + marla.global_transform.basis.z * 1.8 + Vector3.UP * 0.3
		await test.wait(0.5)
		hud.talk(level, "marla")
		test.check(await test.wait_for(func(): return level.barea_stage() == "keys", 5), "client's story stage synced after talking")
		level.request_keys.rpc_id(1, me.slot)
		await test.wait(0.5)
		test.check(level.barea_stage() == "keys", "host refuses the keys from across the city")
		me.global_position = level.markers.keys + Vector3(1.5, -0.9, 0)
		await test.wait(0.8)
		level.request_keys.rpc_id(1, me.slot)
		test.check(await test.wait_for(func(): return level.barea_stage() == "power", 5), "client takes the keys; Act 3 everywhere")
		test.check(await test.wait_for(func(): return level.event_left() > 30.0, 5), "client sees the hold-out countdown (%d s)" % int(level.event_left()))
		test.check(await test.wait_for(func(): return level.nav.walkable(level.markers.sub_gate.rect.position), 5), "substation gate opens for the client too")
		await test.wait(1)
