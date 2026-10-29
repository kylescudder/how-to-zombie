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
	test.check(blocks.size() >= 450, "Barea is a big city (%d blocks)" % blocks.size())
	var xs := blocks.map(func(b): return b.x)
	var zs := blocks.map(func(b): return b.z)
	test.check(xs.max() - xs.min() > 1500.0 and zs.max() - zs.min() > 1300.0, "city spans %.0f x %.0f m" % [xs.max() - xs.min(), zs.max() - zs.min()])
	test.check(level.markers.roadblocks.size() >= 150, "army roadblocks across the streets (%d)" % level.markers.roadblocks.size())
	test.check(level.markers.alarm_cars.size() >= 60, "alarmed cars parked around town (%d)" % level.markers.alarm_cars.size())
	test.check(level.npcs.size() == Story.NPCS.size(), "%d survivors to talk to" % level.npcs.size())
	test.check(level.markers.idol != Vector3.INF and level._idol.visible, "the Yellow Sticker idol waits on its shrine")
	test.check(level.barea_stage() == "arrive", "story starts on arrival")
	level.director.set_process(false)
	for i in level.all_infected(): i.queue_free()

	# Every roadblock gap is clear for a survivor-sized capsule.
	var probe := CapsuleShape3D.new()
	probe.radius = 0.38
	probe.height = 1.6
	var blocked := 0
	for r: Dictionary in level.markers.roadblocks:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = probe
		q.collision_mask = 1
		q.transform = Transform3D(Basis.IDENTITY, r.gap + Vector3.UP * 1.0)
		if not level.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			blocked += 1
	test.check(blocked == 0, "every roadblock leaves a clear gap on foot (%d blocked of %d)" % [blocked, level.markers.roadblocks.size()])
	# Roadblocks stop cars but people squeeze through the gap.
	var rb: Dictionary = level.markers.roadblocks[level.markers.roadblocks.size() / 2]
	var across: Vector3 = rb.axis
	var through := Vector3(across.z, 0, across.x)  # perpendicular: the way traffic runs
	var car: TeamVehicle = level.vehicles().filter(func(v): return v.kind == "car")[0]
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

	# Act 1: talk to Captain Marla on the harbour.
	var marla := level.npc("marla")
	me.global_position = marla.global_position + marla.global_transform.basis.z * 1.8 + Vector3.UP * 0.3
	await test.wait(0.2)
	var hud := test.get_tree().get_first_node_in_group("hud") as HUD
	hud.talk(level, "marla")
	await test.wait(0.3)
	test.check(hud._talk_panel.visible and hud._talk_text.text.contains("Barea"), "Marla tells her story")
	test.check(level.barea_stage() == "keys", "Act 2 begins: get the keys")
	for k in Story.npc("marla").lines.size():
		hud.talk(level, "marla")
	test.check(not hud._talk_panel.visible, "conversation ends after the last line")
	test.check(not level.npc("marla_ferry").visible, "Marla isn't at the ferry terminal yet")

	# Scale: each act is in its own district. Walk the whole route with every lock open.
	for lock: Dictionary in [level.markers.sub_gate, level.markers.shutter]:
		level.nav.set_open(lock.rect, true)
	var legs := [["harbour", OpenWorld.camp(0)], ["Police HQ keys", level.markers.keys], ["Substation 4 breaker", level.markers.breaker], ["Megamart idol", level.markers.idol - Vector3.UP * 2.6], ["old ferry terminal", level.markers.ferry_terminal]]
	var total := 0.0
	var ok := true
	for k in range(1, legs.size()):
		var route := level.nav.path(legs[k - 1][1], legs[k][1])
		var leg := 0.0
		for q in range(1, route.size()):
			leg += route[q - 1].distance_to(route[q])
		ok = ok and not route.is_empty()
		total += leg
		print("[BAREA] %s -> %s: %.0f m" % [legs[k - 1][0], legs[k][0], leg])
	var pure := total / Survivor.RUN
	print("[BAREA] whole route %.0f m: %.1f min of nonstop running, plus %.1f min of hold-outs" % [total, pure / 60.0, (Story.LOCKDOWN_TIME + Story.POWER_TIME) / 60.0])
	test.check(ok, "every act is reachable on foot")
	test.check(total > 3500.0, "the story route is long (%.1f km)" % (total / 1000.0))
	level._apply_story()  # put the locks back
	test.check(not level.nav.walkable(level.markers.sub_gate.rect.position) and not level.nav.walkable(level.markers.shutter.rect.position), "substation gate and Megamart shutter start locked")

	# The Megamart is indoors, and shuttered until the power's back.
	var space := level.get_world_3d().direct_space_state
	var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(level.markers.idol, level.markers.idol + Vector3.UP * 30, 1))
	test.check(not up.is_empty() and up.position.y < 12.0, "the idol's shrine is indoors (roof at %.1f m)" % (up.position.y if not up.is_empty() else -1.0))
	me.global_position = level.markers.idol + Vector3(2.5, -2.3, 0)
	await test.wait(0.2)
	level.request_idol.rpc_id(1, me.slot)
	await test.wait(0.2)
	test.check(level.barea_stage() == "keys", "no idol before the power's back on")

	# Act 2: Police HQ keys, with a holding-cell alarm hold-out.
	level.director.set_process(true)
	level.director.relax_t = 9999.0
	level.director.wander_t = 9999.0
	me.global_position = level.markers.keys + Vector3(1.5, -0.9, 0)
	for s: Survivor in level.get_survivors():
		if s.bot: s.global_position = me.global_position + Vector3(2.0, 0, s.slot * 1.2)
	await test.wait(0.3)
	level.request_breaker.rpc_id(1, me.slot)
	level.request_keys.rpc_id(1, me.slot)
	await test.wait(0.3)
	test.check(level.barea_stage() == "power" and level.event_left() > 50.0, "taking the keys sets off a %d s alarm" % int(level.event_left()))
	test.check(level.nav.walkable(level.markers.sub_gate.rect.position), "the keys unlock Substation 4's gate")
	test.check(await test.wait_for(func(): return level.count_commons() >= 8, 15.0), "the alarm brings a horde (%d)" % level.count_commons())
	level.director.crescendo_t = 0.05
	test.check(await test.wait_for(func(): return level.event_left() == 0.0, 3.0), "the alarm hold-out ends")
	for i in level.all_infected(): i.queue_free()

	# Act 3: the substation breaker, with a 90 s power-up hold-out.
	me.global_position = level.markers.breaker + Vector3(1.5, -0.9, 0)
	for s: Survivor in level.get_survivors():
		if s.bot: s.global_position = me.global_position + Vector3(2.0, 0, s.slot * 1.2)
	await test.wait(0.3)
	level.request_breaker.rpc_id(1, me.slot)
	await test.wait(0.3)
	test.check(level.event_left() > 80.0 and level.barea_stage() == "power", "throwing the breaker starts a %d s hold-out" % int(level.event_left()))
	test.check(await test.wait_for(func(): return level.count_commons() >= 8, 15.0), "the substation draws a horde (%d)" % level.count_commons())
	level.director.crescendo_t = 0.05
	test.check(await test.wait_for(func(): return level.barea_stage() == "megamart", 3.0), "the grid comes back: Act 4")
	test.check(level.nav.walkable(level.markers.shutter.rect.position), "the Megamart shutters roll up")
	level.director.set_process(false)
	for i in level.all_infected(): i.queue_free()

	# The discounted rifle: cheap, powerful, misfires, and goes off after 5 minutes.
	var deal: Pickup = null
	for k: Pickup in level.get_pickups():
		if k.item == "reduced_rifle":
			deal = k
	test.check(deal != null, "a reduced rifle is on the stand inside the Megamart")
	test.check(deal != null and up.position.y > deal.global_position.y, "the deal is indoors too")
	var w := Game.gun_stats(me.slot, "reduced_rifle")
	var normal := Game.gun_stats(me.slot, "rifle")
	test.check(float(w.dmg) >= float(normal.dmg) * 3.0 and int(w.price) < 100, "super powerful (%d dmg vs %d) and cheap (%d credits)" % [w.dmg, normal.dmg, w.price])
	if deal:
		var before := Game.credits(me.slot)
		me.global_position = deal.global_position + Vector3(1.2, -0.7, 0)
		await test.wait(0.2)
		level.request_pickup.rpc_id(1, deal.name, me.slot)
		test.check(await test.wait_for(func(): return me.weapon_id("primary") == "reduced_rifle", 2.0), "bought the reduced rifle")
		test.check(Game.credits(me.slot) == before - int(w.price), "it cost %d credits" % int(w.price))
		test.check(absf(float(me.inv.primary.expire) - 300.0) < 2.0, "use-by timer: 5 minutes")
		me.select("primary")
		await test.wait(0.5)
		var misfires := 0
		for k in 200:
			me.inv.primary.mag = 30
			me._cooldown = 0.0
			var shots := int(me.net_fire)
			me._fire(Game.gun_stats(me.slot, "reduced_rifle"))
			if me.net_fire == shots: misfires += 1
		test.check(misfires > 3 and misfires < 40, "it randomly misfires (%d of 200 trigger pulls)" % misfires)
		me.inv.primary.expire = 0.5
		await test.wait(0.8)
		test.check(me.weapon_id("primary") == "", "it falls apart when the 5 minutes are up")

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
	test.check(me.carrying_idol(), "%s carries the idol" % me.short_name())
	# Carrier goes down: the idol drops; a teammate can pick it up.
	me.host_damage(500.0)
	await test.wait(0.3)
	test.check(int(Game.story.idol_carrier) == -1 and level._idol.visible, "the idol drops when its carrier goes down")
	me.host_revive()
	await test.wait(0.2)
	me.global_position = level._idol.global_position + Vector3(1.0, -0.6, 0)
	await test.wait(0.2)
	level.request_idol.rpc_id(1, me.slot)
	await test.wait(0.2)
	test.check(me.carrying_idol() and not level._idol.visible, "picked the idol back up")
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

	test.check(level.npc("marla_ferry").visible, "Marla has moved to the old ferry terminal")
	# The harbour boats won't do: Marla's at the ferry terminal.
	var harbour_boat: TeamVehicle = null
	var ferry: TeamVehicle = null
	for v: TeamVehicle in level.vehicles():
		if v.kind == "boat" and v.global_position.distance_to(OpenWorld.dock(0)) < 60.0:
			harbour_boat = v
		if v.ferry:
			ferry = v
	test.check(ferry != null and ferry.global_position.distance_to(level.markers.ferry_terminal) < 160.0, "Marla's ferry is moored at the terminal")
	me.global_position = harbour_boat.global_position + Vector3(0, 0.6, 2)
	harbour_boat.request_enter(me.slot)
	await test.wait(0.2)
	harbour_boat.global_position = OpenWorld.dock(0) + Vector3(160, -0.45, 0)
	harbour_boat.net_pos = harbour_boat.global_position
	await test.wait(1.0)
	test.check(level.barea_stage() == "alert", "sailing off in a harbour boat doesn't count")
	harbour_boat.request_exit(me.slot)
	harbour_boat.seats = PackedInt32Array([-1, -1, -1, -1])
	me.global_position = ferry.global_position + Vector3(0, 0.6, 2)
	ferry.request_enter(me.slot)
	await test.wait(0.2)
	test.check(level.vehicle_for_slot(me.slot) == ferry, "boarded Marla's ferry")
	test.check(level.barea_stage() == "alert", "still on alert while moored")
	# Actually sail it out: it must not be stuck on the beach shelf.
	var moored := ferry.global_position
	ferry._send_t = 1000
	for k in 80:
		ferry.drive(me.slot, 1.0, 0.0, false)
		await test.wait(0.05)
	test.check(ferry.global_position.distance_to(moored) > 25.0, "Marla's ferry sails away from the pier (%.0f m)" % ferry.global_position.distance_to(moored))
	ferry.global_position = level.markers.ferry_terminal + Vector3(-360, -0.45, 0)
	ferry.net_pos = ferry.global_position
	test.check(await test.wait_for(func(): return level.barea_stage() == "escaped", 3.0), "sailing away on the ferry escapes Barea City")
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
	cam.global_position = OpenWorld.camp(0) + Vector3(-200, 520, 700)
	cam.look_at(OpenWorld.camp(0) + Vector3(-950, 0, -100), Vector3.UP)
	await _snap(dir + "/02_aerial.png")
	cam.current = false
	me.camera.current = true
	# 2b. Each act's landmark
	cam.current = false
	me.camera.current = true
	for shot: Array in [["13_police_keys", level.markers.keys, Vector3(12, -0.9, 6)], ["14_substation", level.markers.breaker, Vector3(30, 0.3, 14)], ["15_megamart_shutter", level.markers.idol, Vector3(48, -2.3, 10)], ["16_ferry_terminal", level.markers.ferry_terminal + Vector3(-125, 0, 9), Vector3(118, 0.3, -2)]]:
		var target: Vector3 = shot[1]
		var c := level.nav.nearest_walkable(target + shot[2], 8)
		me.global_position = level.nav.center(c) + Vector3.UP * 0.3
		test.aim_at(me, target + Vector3.UP * 1.0)
		await test.wait(0.7)
		await _snap(dir + "/%s.png" % shot[0])
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
	# 5. Walking into the Megamart, 6. the idol up close
	var door: Vector3 = level.markers.idol + Vector3(36.0, -2.3, 0)
	me.global_position = door
	test.aim_at(me, level.markers.idol + Vector3(0, -1.0, 0))
	await test.wait(0.6)
	await _snap(dir + "/05_megamart.png")
	me.global_position = level.markers.idol + Vector3(3.0, -2.3, 0.6)
	test.aim_at(me, level.markers.idol)
	await test.wait(0.6)
	await _snap(dir + "/06_idol.png")
	# The reduced rifle on its stand, then in hand
	var deal: Pickup = null
	for k: Pickup in level.get_pickups():
		if k.item == "reduced_rifle": deal = k
	if deal:
		me.global_position = deal.global_position + Vector3(1.6, -0.7, 0.6)
		test.aim_at(me, deal.global_position)
		await test.wait(0.5)
		await _snap(dir + "/10_deal_stand.png")
		level.request_pickup.rpc_id(1, deal.name, me.slot)
		await test.wait(0.4)
		me.select("primary")
		me.aim(PI * 0.5, 0.0)
		await test.wait(1.2)
		await _snap(dir + "/11_reduced_rifle.png")
	# A teammate carrying the idol on their back
	var bot: Survivor = level.get_survivors().filter(func(x): return x.bot)[0]
	bot.set_physics_process(false)
	bot.global_position = door + Vector3(-6, 0, 0)
	bot.rotation.y = PI * 0.5
	Game.story.idol_carrier = bot.slot
	me.global_position = bot.global_position + Vector3(-3.2, 0, 1.2)
	test.aim_at(me, bot.global_position + Vector3.UP * 1.3)
	await test.wait(0.6)
	await _snap(dir + "/12_carrier.png")
	Game.story.idol_carrier = -1
	bot.set_physics_process(true)
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
	# 9. World map, mid-story (Act 3 marker showing)
	Game.story.barea = "power"
	hud.open_world_map(level)
	await test.wait(0.3)
	await _snap(dir + "/09_map.png")
	hud.close_modal()


func _snap(path: String) -> void:
	await test._shot(path)
