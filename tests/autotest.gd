extends Node
## Scripted end-to-end tests. Run headless:
##   tools/godot --headless -- --solo --linear --test=solo     (also: campaign, soak)
##   tools/godot --headless --fixed-fps 60 -- --solo --test=world   (also: world_horde)
##   tools/godot --headless -- --host --linear --test=net_host   &   tools/godot --headless -- --join=127.0.0.1 --linear --test=net_client
##   Network tests must run in real time (no --fixed-fps), or the host gives up before the client connects.
##   tools/godot -- --solo --test=screens        (needs a window; writes screenshots/)

var test_name := ""
var _fails := 0


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	match test_name:
		"world_net_host", "world_net_client":
			await _suite("res://tests/world_network.gd").new().run(self,test_name=="world_net_host")
		"world":
			await _suite("res://tests/world_verify.gd").new().run(self)
		"barea_shots":
			await _suite("res://tests/barea_verify.gd").new().shots(self)
		"barea":
			await _suite("res://tests/barea_verify.gd").new().run(self)
		"world_horde":
			await _suite("res://tests/world_horde.gd").new().run(self)
		"settings":
			await _suite("res://tests/settings_verify.gd").new().run(self)
		"art_hitbox":
			await _art_hitbox()
		"art_models":
			var art: Node = _suite("res://tests/art_capture.gd").new()
			add_child(art)
			await art.run(self)
		"solo":
			await _solo()
		"animations":
			var capture: Node = _suite("res://tests/animation_capture.gd").new()
			add_child(capture)
			await capture.run(self)
		"animation_verify":
			await _animation_verify()
		"guns":
			await _guns()
		"gun_screens":
			await _gun_screens()
		"campaign":
			await _campaign()
		"soak":
			await _soak()
		"net_host":
			await _net_host()
		"net_client":
			await _net_client()
		"screens":
			await _screens()
		"menu":
			await wait(1.5)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
			await _shot(ProjectSettings.globalize_path("res://screenshots/00_menu.png"))
	print("[TEST] %s: %s" % [test_name, "PASS" if _fails == 0 else "FAIL (%d)" % _fails])
	get_tree().quit(1 if _fails else 0)


## Loads a test suite at run time, so a broken suite fails the run instead of hanging it.
func _suite(path: String) -> Object:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		print("[TEST] could not load %s" % path)
		get_tree().quit(2)
		return null
	return script


func check(cond: bool, what: String) -> void:
	print("[TEST]   %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		_fails += 1


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func press(action: String, on: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = on
	Input.parse_input_event(ev)


func level() -> Level:
	var l := get_tree().get_first_node_in_group("level") as Level
	return l if l and not l.is_queued_for_deletion() else null


func me() -> Survivor:
	return level().local_survivor() if level() else null


func wait_for(cond: Callable, timeout := 10.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func clear_infected() -> void:
	for i in level().all_infected():
		i.queue_free()
	level().director.pending.clear()


func calm() -> void:
	var d := level().director
	d.relax_t = 9999.0
	d.wander_t = 9999.0
	d.tank_at = -1.0
	clear_infected()


func aim_at(s: Survivor, p: Vector3) -> void:
	var to := p - s.eye_position()
	s.aim(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func place(s: Survivor, p: Vector3) -> void:
	s.global_position = p
	s.velocity = Vector3.ZERO
	s.net_pos = p


func room_pickup(lvl: Level, item: String) -> Pickup:
	for k: Pickup in lvl.get_pickups():
		if (k.item == item or (item == "primary" and DB.weapon(k.item).slot == "primary")) and lvl.in_start_room(k.global_position):
			return k
	return null


func total_kills() -> int:
	var n := 0
	for st in Game.stats:
		n += int(st.kills)
	return n


func ahead(dist: float) -> Vector3:
	## A walkable spot `dist` metres along the map from the start room.
	var lvl := level()
	var z := lvl.start_z() + dist
	var best: Vector3 = lvl.markers.path[0]
	for path_pt in lvl.markers.path:
		if path_pt.z <= z:
			best = path_pt
	var c := lvl.nav.nearest_walkable(Vector3(best.x + 0.5, 0, z), 12)
	return lvl.nav.center(c) + Vector3.UP * 0.2 if c.x >= 0 else lvl.markers.spawns[0]


# --- Solo: every core mechanic ------------------------------------------------------------

func _solo() -> void:
	check(await wait_for(func(): return level() != null and me() != null, 10.0), "chapter loaded with our survivor")
	var lvl := level()
	var p := me()
	check(lvl.get_survivors().size() == 4, "four survivors (%d)" % lvl.get_survivors().size())
	check(lvl.get_survivors().filter(func(s): return s.bot).size() == 3, "three of them are bots")
	check(lvl.in_start_room(p.global_position), "we start in the safe room")
	check(p.weapon_id("secondary") == "pistol", "everyone starts with a pistol")
	check(lvl.get_pickups().size() >= 8, "safe room is stocked (%d pickups)" % lvl.get_pickups().size())
	check(lvl.nav.walk.count(1) > 2000, "nav grid built (%d walkable cells)" % lvl.nav.walk.count(1))
	await wait(1.0)
	check(p.is_on_floor(), "standing on the floor (y=%.2f)" % p.global_position.y)

	# Pick up an SMG and a medkit from the table
	var smg: Pickup = room_pickup(lvl, "primary")
	place(p, smg.global_position + Vector3(0.8, 0.1, 0))
	await wait(0.2)
	lvl.request_pickup.rpc_id(1, smg.name, p.slot)
	check(await wait_for(func(): return p.weapon_id("primary") != "", 2.0), "picked up a primary weapon (%s)" % p.weapon_id("primary"))
	for k in lvl.get_pickups():
		if not is_instance_valid(k) or k.is_queued_for_deletion():
			continue
		if k.item == "medkit" and not p.inv.medkit and lvl.in_start_room(k.global_position):
			place(p, k.global_position + Vector3(0.8, 0.1, 0))
			lvl.request_pickup.rpc_id(1, k.name, p.slot)
			await wait(0.1)
	check(await wait_for(func(): return p.inv.medkit, 2.0), "picked up a first aid kit")
	await wait(4.0)
	var armed := lvl.get_survivors().filter(func(s): return s.bot and not s.inv.primary.is_empty()).size()
	check(armed >= 2, "bots grabbed primaries from the table (%d/3)" % armed)

	# Leave the safe room -> the Director wakes up and starts populating the map
	check(not lvl.director.active, "director waits while we're in the safe room")
	lvl.request_door.rpc_id(1, 0)
	check(await wait_for(func(): return lvl.doors[0].open, 2.0), "start door opened")
	place(p, ahead(18.0))
	check(await wait_for(func(): return lvl.director.active, 3.0), "director active once we leave")
	check(await wait_for(func(): return lvl.count_commons() > 0, 20.0), "wandering infected spawned ahead (%d)" % lvl.count_commons())

	# Shoot a common
	calm()
	await wait(0.3)
	p.select("primary")
	await wait(0.5)
	# Bots can fire immediately after spawn, so record the score before yielding.
	var kills := total_kills()
	var z := lvl.spawn_infected("common", p.global_position - p.global_transform.basis.z * 7.0, false)
	await wait(0.1)
	aim_at(p, z.global_position + Vector3.UP * 1.3)
	press("primary", true)
	var killed := await wait_for(func(): return not is_instance_valid(z) or z.is_dead(), 3.0)
	press("primary", false)
	check(killed, "shot a common dead")
	check(total_kills() > kills, "kill counted")

	# Shove (bots parked out of the way so they don't shoot it first)
	for b: Survivor in lvl.get_survivors().filter(func(s): return s.bot):
		b.set_physics_process(false)
		b.global_position = p.global_position + Vector3(0, 0.2, 12)
	await wait(0.3)
	var z2 := lvl.spawn_infected("common", p.global_position - p.global_transform.basis.z * 1.4, false)
	await wait(0.15)
	press("secondary", true)
	await get_tree().process_frame
	await get_tree().process_frame
	press("secondary", false)
	check(await wait_for(func(): return is_instance_valid(z2) and z2.net_anim == Infected.A.STAGGER, 1.0), "shove staggers a common")
	for b: Survivor in lvl.get_survivors().filter(func(s): return s.bot):
		b.set_physics_process(true)
		b.global_position = p.global_position + Vector3(1.5, 0.2, 1.5)
	await wait(1.5)
	clear_infected()

	# Get hurt -> incapped -> a bot revives us
	await wait(0.3)
	p.host_damage(150.0)
	await wait(0.1)
	check(p.incapped and p.incap_count == 1, "incapacitated at 0 hp")
	check(await wait_for(func(): return not p.incapped, 25.0), "a bot revived us")
	check(p.total_hp() >= 25.0 and p.temp_hp > 0.0, "revived on temporary health (%.0f)" % p.total_hp())

	# Medkit heal
	p.select("medkit")
	await wait(0.4)
	var before := p.hp
	press("primary", true)
	check(await wait_for(func(): return p.hp > before + 30.0, 7.0), "first aid kit healed us (%.0f -> %.0f)" % [before, p.hp])
	press("primary", false)
	check(p.incap_count == 0 and not p.inv.medkit, "medkit used up and incap count reset")

	# Hunter pins us, a bot saves us
	calm()
	for b in lvl.get_survivors().filter(func(s): return s.bot):
		place(b, p.global_position + Vector3(1.5, 0.2, 1.5))
	var hunter := lvl.spawn_infected("hunter", p.global_position + Vector3(0, 0.2, -6), true)
	await wait(0.2)
	hunter._special = "pin"
	hunter.target_name = p.name
	p.host_pin(hunter.name, "hunter")
	check(p.pinned_by == hunter.name and not p.able(), "hunter pinned us")
	check(await wait_for(func(): return p.pinned_by == "", 15.0), "a bot got the hunter off us")
	await wait(0.5)

	# Smoker grabs us
	clear_infected()
	var sm := lvl.spawn_infected("smoker", p.global_position - p.global_transform.basis.z * 10.0 + Vector3.UP * 0.2, true)
	await wait(0.3)
	sm._ability_cd = 0.0
	sm.target_name = p.name
	check(await wait_for(func(): return p.pin_type == "smoker", 4.0), "smoker grabbed us with its tongue")
	check(await wait_for(func(): return p.pinned_by == "", 15.0), "freed from the smoker")
	await wait(0.5)

	# Boomer bile -> horde
	clear_infected()
	lvl.director.relax_t = 0.0
	var boomer := lvl.spawn_infected("boomer", p.global_position + Vector3(0, 0.2, -2.5), true)
	await wait(0.2)
	boomer.take_hit(999.0, false, Vector3.ZERO, p.slot)
	await wait(0.2)
	check(p.biled > 0.0, "boomer exploded and biled us")
	check(await wait_for(func(): return lvl.count_commons() >= 8, 8.0), "bile called a horde (%d)" % lvl.count_commons())
	calm()
	p.biled = 0.0
	p.set_biled.rpc(0.0)

	# Pipe bomb lures and kills
	await wait(0.5)
	var ks := 0
	for st in Game.stats:
		ks += int(st.kills)
	var bomb_at := p.global_position - p.global_transform.basis.z * 6.0
	var lured: Array = []
	for i in 6:
		var c := lvl.nav.nearest_walkable(bomb_at + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)), 4)
		if c.x >= 0:
			lured.append(lvl.spawn_infected("common", lvl.nav.center(c), false))
	lvl.spawn_projectile("pipe_bomb", bomb_at + Vector3.UP * 0.5, Vector3.ZERO, p.slot)
	await wait(1.5)
	check(lvl.director.lure_pos != Vector3.INF, "pipe bomb is luring the horde")
	await wait(6.5)
	var ks2 := 0
	for st in Game.stats:
		ks2 += int(st.kills)
	check(lured.all(func(z3): return not is_instance_valid(z3) or z3.is_dead()), "pipe bomb blew up the horde (%d kills)" % (ks2 - ks))

	# Molotov fire burns infected
	clear_infected()
	var burner := lvl.spawn_infected("common", p.global_position - p.global_transform.basis.z * 6.0, false)
	await wait(0.1)
	lvl.spawn_projectile("fire", burner.global_position, Vector3.ZERO, p.slot)
	check(await wait_for(func(): return not is_instance_valid(burner) or burner.is_dead(), 5.0), "molotov fire burned an infected")
	await wait(0.2)
	for x in lvl.entities.get_children():
		if x is Projectile:
			x.queue_free()

	# Tank
	clear_infected()
	lvl.director.spawn_tank()
	check(await wait_for(func(): return lvl.all_infected().any(func(i): return i.is_tank()), 3.0), "the director sent a Tank")
	var tank: Infected = lvl.all_infected().filter(func(i): return i.is_tank())[0]
	check(is_equal_approx(tank.max_hp, float(Game.diff().tank_hp)), "tank health matches difficulty (%d)" % tank.max_hp)
	for i in 30:
		lvl.request_hit.rpc_id(1, tank.name, 200.0, false, tank.global_position, Vector3.FORWARD, p.slot)
	await wait(0.2)
	check(tank.is_dead() and not lvl.director.tank_alive, "tank killed")

	# Witch: shoot her and she takes us down
	clear_infected()
	p.host_heal()
	await wait(0.2)
	var witch := lvl.spawn_infected("witch", p.global_position - p.global_transform.basis.z * 8.0, false)
	await wait(0.3)
	check(witch.net_anim == Infected.A.SIT, "witch sits crying")
	lvl.request_hit.rpc_id(1, witch.name, 10.0, false, witch.global_position, Vector3.FORWARD, p.slot)
	await wait(0.1)
	check(witch.alert and witch.target_name == p.name, "shooting the witch startles her")
	check(await wait_for(func(): return p.incapped or p.dead, 6.0), "the witch took us down")
	clear_infected()
	await wait(0.5)

	# Team wipe -> mission failed -> chapter restarts
	for s in lvl.get_survivors():
		s.host_damage(400.0)
		s.host_damage(400.0)
	check(await wait_for(func(): return Game.phase == "failed", 3.0), "mission failed when everyone's down")
	var old_id := lvl.get_instance_id()
	check(await wait_for(func(): return level() != null and level().get_instance_id() != old_id and me() != null, 12.0), "chapter restarted")
	check(Game.phase == "playing" and me() != null and me().able(), "fresh start after the restart")


# --- Campaign: play through every chapter's ending -----------------------------------------

func _campaign() -> void:
	check(await wait_for(func(): return level() != null and me() != null, 10.0), "chapter 1 loaded")
	var lvl := level()
	var p := me()
	var smg: Pickup = room_pickup(lvl, "primary")
	lvl.request_pickup.rpc_id(1, smg.name, p.slot)
	await wait(0.5)
	check(await wait_for(func(): return p.weapon_id("primary") != "", 2.0), "armed")
	var gun := p.weapon_id("primary")
	check(_connected(lvl, _end_point(lvl)), "chapter 1: start and end safe rooms are connected")
	await _finish_chapter_via_saferoom()
	check(await wait_for(func(): return level() != null and level().chapter == 1 and me() != null, 15.0), "chapter 2 loaded")
	check(me().weapon_id("primary") == gun, "inventory carried into the next chapter (%s)" % gun)
	lvl = level()
	calm()
	lvl.request_door.rpc_id(1, 0)
	check(not lvl.nav.walkable(lvl.markers.gate.rect.position), "gate blocks the way while closed")
	check(not _connected(lvl, _end_point(lvl)), "can't reach the end safe room with the gate shut")
	lvl.request_button.rpc_id(1)
	await wait(0.3)
	check(lvl.gate_opening and lvl.director.crescendo_t > 0.0, "gate button starts the crescendo")
	place(me(), lvl.markers.button + Vector3(1.5, -1.0, -1.5))
	lvl.director.relax_t = 0.0
	lvl.director.wander_t = 0.0
	lvl.director.crescendo_wave = 0.0
	check(await wait_for(func(): return lvl.count_commons() > 5, 15.0), "crescendo hordes are coming (%d)" % lvl.count_commons())
	lvl.director.crescendo_t = 0.1
	check(await wait_for(func(): return lvl.gate_open, 3.0), "gate opens when the crescendo ends")
	check(_connected(lvl, _end_point(lvl)), "chapter 2 connected end to end once the gate is open")
	await _finish_chapter_via_saferoom()
	check(await wait_for(func(): return level() != null and level().chapter == 2 and me() != null, 15.0), "finale chapter loaded")
	lvl = level()
	calm()
	var rz: Rect2 = lvl.markers.rescue_zone
	check(_connected(lvl, Vector3(rz.get_center().x, 0, rz.get_center().y)), "finale: start connects to the pier")
	lvl.request_door.rpc_id(1, 0)
	for s in lvl.get_survivors():
		place(s, lvl.markers.radio + Vector3((s.slot - 1.5) * 1.2, -0.9, -2.0))
	await wait(0.5)
	lvl.request_radio.rpc_id(1)
	await wait(0.3)
	check(lvl.radio_used and lvl.director.finale_stage == 0, "radio starts the finale")
	lvl.director.relax_t = 0.0
	check(await wait_for(func(): return lvl.count_commons() > 5, 12.0), "finale horde wave (%d)" % lvl.count_commons())
	lvl.director.finale_stage = DB.FINALE.size() - 1
	lvl.director._enter_stage()
	await wait(0.3)
	check(lvl.rescue_ready, "rescue boat on its way")
	lvl._boat_t = 1.0
	calm()
	for s in lvl.get_survivors():
		place(s, Vector3(rz.get_center().x + (s.slot - 1.5) * 1.2, 0.3, rz.get_center().y))
	check(await wait_for(func(): return Game.phase == "victory", 4.0), "everyone on the pier -> RESCUED")


func _end_point(lvl: Level) -> Vector3:
	var r: Rect2 = lvl.markers.end_room
	return Vector3(r.get_center().x, 0, r.get_center().y)


func _connected(lvl: Level, to: Vector3) -> bool:
	for d in lvl.doors:
		lvl.nav.set_open(d.cells, true)
	var f := NavGrid.Flow.new(lvl.nav)
	f.max_dist = 100000
	f.start([lvl.nav.cell_of(lvl.markers.spawns[0])])
	while not f.step(1000000):
		pass
	for d in lvl.doors:
		lvl.nav.set_open(d.cells, d.open)
	return f.distance_at(to) > 0


func _finish_chapter_via_saferoom() -> void:
	var lvl := level()
	calm()
	var r: Rect2 = lvl.markers.end_room
	for s in lvl.get_survivors():
		place(s, Vector3(r.get_center().x + (s.slot - 1.5) * 1.3, 0.3, r.get_center().y + 1.5))
	await wait(0.4)
	var end_door: Door = lvl.doors.filter(func(d): return d.kind == "end")[0]
	lvl.request_door.rpc_id(1, end_door.index)
	check(await wait_for(func(): return Game.phase == "complete", 3.0), "closing the safe room door completes chapter %d" % (lvl.chapter + 1))


# --- Soak: let the Director run a chapter with bots and check nothing breaks ----------------

func _soak() -> void:
	check(await wait_for(func(): return level() != null and me() != null, 10.0), "loaded")
	var lvl := level()
	lvl.request_door.rpc_id(1, 0)
	var p := me()
	place(p, ahead(25.0))
	lvl.director.mob_t = 1.0
	lvl.director.special_t = 2.0
	var t0 := Time.get_ticks_msec()
	var frames := 0
	var worst := 0.0
	var peak := 0
	while Time.get_ticks_msec() - t0 < 40000:
		await get_tree().process_frame
		frames += 1
		if frames > 30:
			worst = maxf(worst, get_process_delta_time())
		peak = maxi(peak, lvl.all_infected().size())
		if p.incapped or p.pinned_by != "":
			p.host_unpin()
			p.host_revive()
		p.hp = 100.0
		if Game.phase != "playing":
			break
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("[TEST]   %d frames in %.1fs (%.0f fps), worst frame %.0f ms, peak infected %d" % [frames, secs, frames / secs, worst * 1000.0, peak])
	check(peak >= 15, "director produced a real horde (peak %d infected)" % peak)
	check(frames / secs > 30.0, "host keeps up (%.0f fps headless)" % (frames / secs))
	var kills := 0
	for st in Game.stats:
		kills += int(st.kills)
	check(kills > 10, "the team (mostly bots) killed %d infected" % kills)


# --- Network ----------------------------------------------------------------------------------

func _net_host() -> void:
	check(await wait_for(func(): return Net.players.size() == 2, 15.0), "client registered")
	check(await wait_for(func(): return level() != null and level().get_survivors().filter(func(s): return not s.bot).size() == 2, 5.0), "client took over a bot")
	var lvl := level()
	var cs: Survivor = lvl.get_survivors().filter(func(s): return not s.bot and s.peer_id != 1)[0]
	place(me(), lvl.markers.benches[0] + Vector3(-1.3, -0.9, 0))
	check(lvl.get_survivors().size() == 4, "still four survivors")
	await wait(1.0)
	calm()
	await wait(0.5)
	var c := lvl.nav.nearest_walkable(cs.global_position + Vector3(0, 0, 3), 6)
	lvl.spawn_infected("common", lvl.nav.center(c), false)
	check(await wait_for(func(): return Game.stats[cs.slot].kills >= 1, 15.0), "client's kill counted on the host")
	check(await wait_for(func(): return cs.net_inv.get("primary", {}).has("id"), 10.0), "client's pickup replicated to the host")
	check(await wait_for(func(): return Game.gun_upgrades(cs.slot, String(cs.net_inv.primary.id)).get("optic", 0) == 1, 10.0), "client upgrade authorized and stored on host")
	check(Game.credits(cs.slot) == 295, "host charged client optic after kill reward")
	check(await wait_for(func(): return cs.net_reload > 0.15, 5.0), "client reload animation progress replicated to host")
	check(await wait_for(func(): return cs.net_reload < 0.0, 5.0), "client reload animation completes on host")
	check(Game.gun_upgrades(0, "pistol").is_empty(), "client cannot upgrade host weapons")
	await wait(0.5)
	cs.host_damage(150.0)
	check(cs.incapped, "client survivor incapped by host")
	await wait(3.0)


func _net_client() -> void:
	check(await wait_for(func(): return level() != null and me() != null, 15.0), "client got the level and its own survivor")
	var lvl := level()
	var p := me()
	check(p.slot == 1 and not p.bot, "we play survivor slot 1 (%s)" % p.short_name())
	check(await wait_for(func(): return lvl.get_survivors().size() == 4, 5.0), "client sees all four survivors")
	# The host clears the map, then spawns one infected right next to us.
	check(await wait_for(func(): return lvl.all_infected().any(func(i): return i.global_position.distance_to(p.global_position) < 8.0), 15.0), "infected replicated to client")
	var z: Infected
	for i: Infected in lvl.all_infected():
		if z == null or i.global_position.distance_to(p.global_position) < z.global_position.distance_to(p.global_position):
			z = i
	lvl.request_hit.rpc_id(1, z.name, 999.0, true, z.global_position, Vector3.FORWARD, p.slot)
	check(await wait_for(func(): return not is_instance_valid(z) or z.is_dead(), 5.0), "infected death replicated")
	var pk: Array = lvl.get_pickups().filter(func(k): return k.item in ["smg", "pump_shotgun"] and lvl.in_start_room(k.global_position))
	place(p, pk[0].global_position + Vector3(0.6, 0.2, 0))
	await wait(0.3)
	lvl.request_pickup.rpc_id(1, pk[0].name, p.slot)
	check(await wait_for(func(): return p.weapon_id("primary") != "", 4.0), "picked up a weapon over the network")
	place(p, lvl.markers.benches[0] + Vector3(-1.3, -0.9, 0))
	await wait(0.5)
	lvl.request_upgrade.rpc_id(1, 0, "pistol", "optic")
	lvl.request_upgrade.rpc_id(1, p.slot, p.weapon_id("primary"), "optic")
	check(await wait_for(func(): return p.current_weapon().get("optic", false), 5.0), "purchased optic replicated to client gunplay")
	check(Game.credits(p.slot) == 295, "client sees host-owned wallet after purchase")
	p.inv.primary.mag = 1
	p._sync_inv()
	press("reload", true)
	await wait(0.1)
	press("reload", false)
	check(p.reload_t > 0, "client starts reload for teammate animation")
	check(await wait_for(func(): return p.incapped, 25.0), "host's damage reached us (incapped)")
	await wait(1.0)


# --- Screenshots (needs a window) ---------------------------------------------------------------

func _screens() -> void:
	await wait_for(func(): return level() != null and me() != null)
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var lvl := level()
	var p := me()
	await wait(1.5)
	aim_at(p, p.global_position + Vector3(-3, 1.0, 3))
	await wait(0.3)
	await _shot(dir + "/01_saferoom.png")
	lvl.request_door.rpc_id(1, 0)
	calm()
	var smg: Pickup = room_pickup(lvl, "primary")
	lvl.request_pickup.rpc_id(1, smg.name, p.slot)
	place(p, ahead(30.0))
	await wait(0.5)
	p.select("primary")
	for i in 14:
		var c := lvl.nav.nearest_walkable(p.global_position + Vector3(randf_range(-5, 5), 0, randf_range(12, 22)), 5)
		if c.x >= 0:
			lvl.spawn_infected("common", lvl.nav.center(c), true)
	for b in lvl.get_survivors().filter(func(s): return s.bot):
		place(b, p.global_position + Vector3((b.slot - 2) * 1.6, 0.2, -1.5))
	await wait(1.0)
	aim_at(p, p.global_position + Vector3(0, 1.0, 12))
	await wait(0.05)
	await _shot(dir + "/02_horde.png")
	await wait(1.5)
	aim_at(p, p.global_position + Vector3(0, 1.0, 8))
	await _shot(dir + "/03_fight.png")
	calm()
	var tank := lvl.spawn_infected("tank", p.global_position + Vector3(2, 0.2, 9), false)
	await wait(0.4)
	tank._ability_cd = 99.0
	aim_at(p, tank.global_position + Vector3.UP * 1.5)
	await wait(0.3)
	await _shot(dir + "/04_tank.png")
	calm()
	p.host_damage(200.0)
	await wait(0.6)
	await _shot(dir + "/05_incapped.png")
	p.host_revive()
	for ch in [1, 2]:
		Game.goto_chapter(ch)
		await wait_for(func(): return level() != null and level().chapter == ch and me() != null)
		await wait(1.5)
		var l2 := level()
		var me2 := me()
		l2.director.relax_t = 9999.0
		place(me2, ahead(40.0 if ch == 1 else 60.0))
		await wait(0.4)
		aim_at(me2, me2.global_position + Vector3(0, 1.4, 10))
		await wait(0.3)
		await _shot(dir + "/0%d_chapter%d.png" % [5 + ch, ch + 1])


func _shot(path: String) -> void:
	# Keep Godot from importing every screenshot as a project asset.
	var ignore := ProjectSettings.globalize_path("res://screenshots/.gdignore")
	if not FileAccess.file_exists(ignore):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
		FileAccess.open(ignore, FileAccess.WRITE)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[TEST] screenshot ", path)


# Gunsmith integration: use the real interaction ray and shop buttons.
func _guns() -> void:
	check(await wait_for(func(): return me() != null), "survivor ready")
	var p := me()
	var lvl := level()
	calm()
	check(lvl.markers.benches.size() == 2, "both safe rooms have gunsmith benches")
	var bench: Vector3 = lvl.markers.benches[0]
	place(p, bench + Vector3(-1.3, -0.9, 0))
	aim_at(p, bench)
	await wait(0.3)
	check(p.prompt.contains("Gunsmith"), "look ray finds the gunsmith")
	press("interact", true)
	await wait(0.1)
	press("interact", false)
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	check(hud.modal_kind == "gunsmith", "E opens the gunsmith")
	await wait(0.3)
	check(Game.credits(p.slot) == 500, "start with 500 credits")
	var button := hud.modal.find_child("Buy_power", true, false) as Button
	check(button != null and not button.disabled, "affordable upgrade is available")
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button.get_global_rect().get_center()
	click.global_position = click.position
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	get_viewport().push_input(release, true)
	check(await wait_for(func(): return Game.gun_stats(p.slot, "pistol").dmg > 36.0), "shop purchase raises equipped pistol damage")
	check(Game.credits(p.slot) == 320, "purchase charges exactly once")
	check(is_equal_approx(p.current_weapon().dmg, 43.2), "gunplay uses purchased damage")
	check(is_equal_approx(Game.gun_stats(p.slot, "smg").dmg, 20.0), "pistol upgrade does not change SMG")
	check(is_equal_approx(Game.gun_stats(1, "pistol").dmg, 36.0), "another survivor keeps stock stats")
	lvl.request_upgrade.rpc_id(1, p.slot, "pistol", "power")
	check(Game.credits(p.slot) == 320, "insufficient funds cannot buy tier two")
	lvl.request_upgrade.rpc_id(1, p.slot, "rifle", "optic")
	check(Game.credits(p.slot) == 320, "cannot buy for a gun not carried")
	lvl.request_upgrade.rpc_id(1, p.slot, "pistol", "optic")
	check(Game.credits(p.slot) == 100 and p.current_weapon().optic, "optic installed and paid for")
	lvl.request_upgrade.rpc_id(1, p.slot, "pistol", "optic")
	check(Game.credits(p.slot) == 100, "max-tier optic cannot charge again")
	hud.close_modal()
	await wait(0.2)
	press("aim", true)
	await wait(0.35)
	check(p.aim_blend > 0.95 and p.camera.fov < Settings.fov - 20, "aim input gives magnified optic view")
	var aim_spread := p.spread
	press("aim", false)
	await wait(0.4)
	check(p.camera.fov > Settings.fov - 0.1 and p.spread > aim_spread, "releasing aim restores field of view and hip grouping")
	place(p, ahead(15))
	lvl.request_upgrade.rpc_id(1, p.slot, "pistol", "handling")
	check(Game.credits(p.slot) == 100, "purchase away from a bench is rejected")
	# The actual kill path awards credits; avoid interference from bots.
	var z := lvl.spawn_infected("common", ahead(35), false)
	z.take_hit(1000, false, Vector3.FORWARD, p.slot)
	check(Game.credits(p.slot) == 115, "common kill awards 15 credits")
	var special := lvl.spawn_infected("hunter", ahead(45), false)
	special.take_hit(1000, false, Vector3.FORWARD, p.slot)
	check(Game.credits(p.slot) == 190, "special kill awards 75 credits")
	place(p, bench + Vector3(-1.3, -0.9, 0))
	lvl.request_upgrade.rpc_id(1, p.slot, "pistol", "magazine")
	check(p.current_weapon().mag == 19 and int(p.inv.secondary.mag) == 15, "extended mag increases capacity without creating ammo")
	p.inv.secondary.mag = 1
	p.select("secondary")
	press("reload", true)
	await wait(0.1)
	press("reload", false)
	check(await wait_for(func(): return int(p.inv.secondary.mag) == 19, 3.0), "reload fills the upgraded magazine")
	# Fire through the actual input + hitscan path, with squad AI held for a clean measurement.
	for mate: Survivor in lvl.get_survivors():
		if mate.bot:
			mate.set_process(false)
			mate.set_physics_process(false)
	clear_infected()
	await wait(0.2)
	place(p, ahead(30))
	var target := lvl.spawn_infected("hunter", ahead(35), false)
	target.set_physics_process(false)
	await wait(0.2)
	aim_at(p, target.global_position + Vector3.UP * 0.8)
	await wait(0.1)
	press("primary", true)
	await wait(0.1)
	press("primary", false)
	check(is_equal_approx(target.hp, 206.8), "a fired upgraded pistol round deals 43.2 torso damage")
	target.take_hit(1000, false, Vector3.FORWARD, p.slot)
	var reward_target := lvl.spawn_infected("hunter", ahead(45), false)
	reward_target.take_hit(1000, false, Vector3.FORWARD, p.slot)
	place(p, bench + Vector3(-1.3, -0.9, 0))
	lvl.request_upgrade.rpc_id(1, p.slot, "pistol", "handling")
	check(is_equal_approx(p.current_weapon().reload, 1.232) and p.current_weapon().recoil < 0.012 and p.current_weapon().spread < 1.2, "tuned action improves reload, recoil and spread in gunplay")
	# Carry upgrade ownership across a chapter transition.
	var credits := Game.credits(p.slot)
	var survivor_slot := p.slot
	Game.goto_chapter(1)
	check(await wait_for(func(): return level() != null and level().chapter == 1 and me() != null), "next chapter loaded")
	check(Game.credits(survivor_slot) == credits and Game.gun_stats(survivor_slot, "pistol").optic, "credits and gun-specific upgrades survive chapter change")
	check(level().markers.benches.size() == 2, "warehouse safe rooms have benches")


func _gun_screens() -> void:
	await wait_for(func(): return me() != null)
	var dir := ProjectSettings.globalize_path("res://screenshots/guns/720p" if "--small" in OS.get_cmdline_user_args() else "res://screenshots/guns")
	DirAccess.make_dir_recursive_absolute(dir)
	var p := me()
	calm()
	var bench: Vector3 = level().markers.benches[0]
	place(p, bench + Vector3(-1.6, -0.9, 0))
	aim_at(p, bench)
	for mate: Survivor in level().get_survivors():
		if mate.bot:
			place(mate, level().markers.spawns[mate.slot])
			mate.set_physics_process(false)
	await wait(5.5)
	check(p.prompt.contains("Gunsmith"), "bench visible and interactable")
	await _shot(dir + "/01-bench.png")
	p.receive_item.rpc_id(p.peer_id, "rifle", {})
	await wait(0.2)
	press("interact", true)
	await wait(0.1)
	press("interact", false)
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	check(hud.modal_kind == "gunsmith", "gunsmith opened through E")
	await wait(0.5)
	await _shot(dir + "/02-gunsmith.png")
	level().request_upgrade.rpc_id(1, p.slot, "rifle", "optic")
	level().request_upgrade.rpc_id(1, p.slot, "rifle", "power")
	await wait(0.5)
	await _shot(dir + "/03-upgraded.png")
	hud.close_modal()
	level().request_door.rpc_id(1, 0)
	place(p, ahead(25))
	aim_at(p, p.global_position + Vector3(0, 1.62, 40))
	await wait(0.5)
	await _shot(dir + "/04-rifle.png")
	press("aim", true)
	await wait(0.4)
	await _shot(dir + "/05-optic-aim.png")
	press("aim", false)
	# Every platform, same real in-game gunsmith preview.
	place(p, bench + Vector3(-1.3, -0.9, 0))
	hud.open_gunsmith(p)
	await wait(0.3)
	var panel: ArsenalPanel
	for child in hud.modal.find_children("*", "", true, false):
		if child is ArsenalPanel:
			panel = child
	for id: String in DB.GUN_PROFILES:
		panel.selected = id
		await wait(0.2)
		await _shot(dir + "/model-" + id + ".png")
	hud.close_modal()


func _animation_verify() -> void:
	await wait_for(func(): return me() != null)
	calm()
	var p := me()
	p.receive_item.rpc_id(p.peer_id, "rifle", {})
	await wait(0.5)
	var rest := p.viewmodel.transform
	await wait(0.3)
	check(not p.viewmodel.transform.is_equal_approx(rest), "idle breathing moves the gun without input")
	p.inv.primary.mag = 1
	p.inv.primary.reserve = 6
	press("reload", true)
	await wait(0.1)
	press("reload", false)
	check(p.reload_t > 0 and p.net_reload >= 0, "reload starts and publishes its progress")
	await wait(0.7)
	var mag := p.vm_item.get_node("Magazine") as Node3D
	check(mag.position.y < -0.1, "reload actually removes the magazine")
	check(int(p.inv.primary.mag) == 1, "visual magazine removal cannot grant ammo early")
	check(await wait_for(func(): return p.reload_t <= 0, 3.0), "reload completes")
	await wait(0.1)
	check(int(p.inv.primary.mag) == 7 and int(p.inv.primary.reserve) == 0, "reload transfers only the six available rounds")
	check(mag.position.is_equal_approx(Vector3.ZERO), "magazine returns to its seated position")
	press("inspect", true)
	await wait(0.1)
	press("inspect", false)
	check(p.net_inspect, "inspect key starts the inspection animation")
	press("aim", true)
	await wait(0.2)
	press("aim", false)
	check(not p.net_inspect and p.aim_blend > 0.5, "aim cancels inspect immediately")
	p.inv.primary.mag = 1
	p.inv.primary.reserve = 20
	press("reload", true)
	await wait(0.2)
	press("reload", false)
	p.select("secondary")
	await wait(0.1)
	check(p.reload_t == 0 and p.net_reload < 0 and int(p.inv.primary.mag) == 1, "weapon switch cancels reload without creating ammo")
	p.receive_item.rpc_id(p.peer_id, "pump_shotgun", {})
	await wait(0.5)
	var fore := p.vm_item.get_node("ForeEnd") as Node3D
	press("primary", true)
	await wait(0.1)
	press("primary", false)
	check(await wait_for(func(): return fore.position.z > 0.05, 0.6), "firing cycles the pump fore-end")
	await wait(0.6)
	check(absf(fore.position.z) < 0.001, "pump returns forward after cycling")


func _art_hitbox() -> void:
	await wait_for(func(): return me() != null)
	calm()
	var p := me()
	for mate: Survivor in level().get_survivors():
		if mate.bot:
			mate.set_process(false)
			mate.set_physics_process(false)
	place(p,ahead(30))
	var target := level().spawn_infected("common",ahead(36),false)
	target.rotation.y = PI
	target.set_physics_process(false)
	await wait(0.25)
	var eye := target.model.head.global_position + target.global_basis * Vector3(0,0.35,0.24)
	aim_at(p,eye)
	await wait(0.15)
	var shots := p.net_fire
	var heads := int(Game.stats[p.slot].headshots)
	press("primary",true)
	await wait(0.1)
	press("primary",false)
	check(target.is_dead() and p.net_fire == shots+1,"one pistol shot at the new visible eye hits and kills")
	check(int(Game.stats[p.slot].headshots) == heads+1,"new rounded head registers a headshot")
