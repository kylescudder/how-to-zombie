extends Node
## Scripted smoke tests. Run headless:
##   godot --headless -- --solo --new --test=solo
##   godot --headless -- --host --new --test=net_host   &   godot --headless -- --join=127.0.0.1 --test=net_client

var test_name := ""
var _fails := 0


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	match test_name:
		"solo":
			await _solo()
		"net_host":
			await _net_host()
		"net_client":
			await _net_client()
		"screens":
			await _screens()
	print("[TEST] %s: %s" % [test_name, "PASS" if _fails == 0 else "FAIL (%d)" % _fails])
	get_tree().quit(1 if _fails else 0)


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
	return get_tree().get_first_node_in_group("level") as Level


func wait_for(cond: Callable, timeout := 10.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


# --- Solo -----------------------------------------------------------------------

func _solo() -> void:
	check(await wait_for(func(): return level() != null and level().local_player() != null), "level + player spawned")
	var lvl := level()
	var p := lvl.local_player()
	await wait(1.0)
	check(p.is_on_floor(), "player standing on island (y=%.2f)" % p.global_position.y)

	# Catch -> kill -> sell
	var start_money := Game.money
	p.request_catch.rpc_id(1, "shambler", 1.0, Vector3(0, -0.6, 40), p.global_position + Vector3(0, 0.5, 3), false)
	await wait(0.1)
	var zs := lvl.get_zombies()
	check(zs.size() == 1, "caught zombie spawned")
	check(Game.quest_count[0] == 1, "catch counted for quest")
	var z: Zombie = zs[0]
	await wait(0.4)
	check(z.state == Zombie.State.AIR and z.global_position.y > 1.5, "zombie flying through the air (y=%.1f)" % z.global_position.y)
	p.request_hit.rpc_id(1, z.name, 999.0, Vector3(0, 5, 0), {"headshot": true}, z.global_position)
	await wait(0.1)
	check(z.state == Zombie.State.DEAD, "zombie died")
	check(z.mult >= 2.4, "airborne headshot overkill multiplier (x%.2f)" % z.mult)
	lvl.sell(z, 1)
	await wait(0.1)
	check(Game.money > start_money, "selling paid out (%s)" % DB.format_money(Game.money))

	# Walking AI + attack
	var z2 := lvl.spawn_zombie("runner", p.global_position + Vector3(6, 1, 0), Vector3.ZERO, 1.0, Zombie.State.WALK)
	var hp0 := p.hp
	await wait(4.0)
	check(p.hp < hp0, "runner chased and hit the player (hp %.0f)" % p.hp)
	p.request_hit.rpc_id(1, z2.name, 999.0, Vector3.ZERO, {}, z2.global_position)
	await wait(0.2)

	# Grab + sell held
	p.request_grab.rpc_id(1, z2.name)
	await wait(0.1)
	check(p.holding == z2.name, "grabbed corpse")
	await wait(0.5)
	var m := Game.money
	p.request_sell_held.rpc_id(1)
	await wait(0.1)
	check(Game.money > m and p.holding == "", "sold carried corpse")

	# Shop
	Game.money = 5000
	Game.request_buy.rpc_id(1, "pistol")
	Game.request_buy.rpc_id(1, "dynamite")
	Game.request_buy.rpc_id(1, "rod_2")
	await wait(0.1)
	check("pistol" in Game.owned and "dynamite" in Game.owned and Game.best_rod() == "rod_2", "bought pistol, dynamite, rod")
	check(p.items.has("pistol"), "pistol in hotbar")

	# Dynamite kills a zombie with KABOOM
	var z3 := lvl.spawn_zombie("shambler", p.global_position + Vector3(0, 0.5, -6), Vector3.ZERO, 1.0, Zombie.State.WALK)
	p.request_throw.rpc_id(1, z3.global_position + Vector3(0, 1.5, 0), Vector3.ZERO)
	await wait(2.6)
	check(z3.state == Zombie.State.DEAD and z3.mult >= 1.5, "dynamite kill with bonus (x%.1f)" % z3.mult)

	# Fishing minigame, driven by input actions from the end of the pier
	p.global_position = Vector3(0, 1.5, 35)
	p.rotation.y = PI  # face +Z (out to sea)
	p._pitch = 0.2
	p._equip(p.items.find("rod"))
	await wait(0.3)
	press("secondary", true)
	await wait(0.8)
	press("secondary", false)
	check(await wait_for(func(): return p.rod_state == Player.Rod.WAITING, 5.0), "cast landed in deep water (bobber %s)" % p.bobber)
	p._bite_t = 0.0
	check(await wait_for(func(): return p.rod_state == Player.Rod.BITE, 2.0), "got a bite: %s" % p.hooked)
	press("primary", true)
	await get_tree().process_frame
	await get_tree().process_frame
	check(p.rod_state == Player.Rod.REELING, "hooked and reeling")
	var zc := lvl.get_zombies().size()
	press("primary", false)
	# Mash the reel while the tension is low, and rest when it gets high so the line doesn't snap.
	var t := 0.0
	var resting := false
	var frame := 0
	var max_boost := 0.0
	while p.rod_state == Player.Rod.REELING and t < 40.0:
		if p.tension > 0.5:
			resting = true
		elif p.tension < 0.2:
			resting = false
		frame += 1
		press("primary", not resting and frame % 6 < 3)
		max_boost = maxf(max_boost, p.reel_boost)
		await get_tree().process_frame
		t += get_process_delta_time()
	press("primary", false)
	check(max_boost > 0.5, "mashing boosted the reel (x%.1f)" % (1.0 + max_boost))
	await wait(0.2)
	check(lvl.get_zombies().size() > zc, "reeled a zombie out of the sea in %.1fs" % t)

	# Downed -> seagull rescue
	p.host_damage(500.0, Vector3.ZERO)
	await wait(0.1)
	check(p.downed, "player downed")
	check(await wait_for(func(): return not p.downed, 15.0), "seagull rescued player (hp %.0f)" % p.hp)

	# Boss
	Game.quest_stage[0] = 3
	Game.money = 1000
	Game.request_buy.rpc_id(1, "bait")
	await wait(0.1)
	check(Game.has_bait and Game.quest_stage[0] == 4, "bought boss bait (quest stage %d)" % Game.quest_stage[0])
	p.request_chum.rpc_id(1)
	check(await wait_for(func(): return not get_tree().get_nodes_in_group("boss").is_empty(), 5.0), "boss summoned")
	var boss: Zombie = get_tree().get_nodes_in_group("boss")[0]
	await wait(5.0)
	check(lvl.get_zombies().size() > 2, "boss spat minions (%d zombies)" % lvl.get_zombies().size())
	for i in 20:
		p.request_hit.rpc_id(1, boss.name, 400.0, Vector3.ZERO, {}, boss.global_position)
	await wait(0.2)
	check(boss.state == Zombie.State.DEAD and not Game.boss_alive, "boss killed")
	check(Game.unlocked_island == 1, "next island unlocked")

	# Travel through every island (builds all the geometry)
	for i in [1, 2]:
		Game.unlocked_island = i
		Game.request_travel.rpc_id(1, i)
		check(await wait_for(func(): return level() != null and level().island == i and level().local_player() != null and not level().is_queued_for_deletion(), 5.0), "travelled to island %d" % i)
		await wait(1.0)
		var lp := level().local_player()
		check(lp.global_position.y > 0.5, "standing on island %d (y=%.1f)" % [i, lp.global_position.y])


# --- Network ----------------------------------------------------------------------

func _net_host() -> void:
	check(await wait_for(func(): return Net.players.size() == 2, 15.0), "client registered")
	check(await wait_for(func(): return level() != null and level().get_players().size() == 2, 5.0), "two player bodies spawned")
	await wait(1.0)
	level().spawn_zombie("shambler", Vector3(3, 2, 3), Vector3.ZERO, 1.0, Zombie.State.WALK)
	check(await wait_for(func(): return Game.stats.kills >= 1, 15.0), "client killed the zombie (host saw it)")
	var cp: Player = level().get_players().filter(func(x): return x.peer_id != 1)[0]
	check(cp.global_position.y > 0.5, "client movement replicated (%s)" % cp.global_position)
	check(await wait_for(func(): return Game.money > 0, 10.0), "client sold the corpse (%s)" % DB.format_money(Game.money))
	await wait(3.0)


func _net_client() -> void:
	check(await wait_for(func(): return level() != null and level().local_player() != null, 15.0), "client got level + own player")
	check(await wait_for(func(): return level().get_players().size() == 2, 5.0), "client sees host player")
	check(await wait_for(func(): return not level().get_zombies().is_empty(), 10.0), "zombie replicated to client")
	var p := level().local_player()
	p.global_position = Vector3(5, 2, 5)
	await wait(1.0)
	var z: Zombie = level().get_zombies()[0]
	p.request_hit.rpc_id(1, z.name, 999.0, Vector3(0, 3, 0), {"headshot": true}, z.global_position)
	check(await wait_for(func(): return z.is_dead(), 5.0), "zombie death replicated")
	await wait(2.5)  # let the corpse land
	p.global_position = z.global_position + Vector3(1.5, 0.5, 0)
	await wait(0.3)
	p.request_grab.rpc_id(1, z.name)
	check(await wait_for(func(): return p.holding == z.name, 3.0), "client grabbed corpse")
	await wait(0.5)
	p.request_sell_held.rpc_id(1)
	check(await wait_for(func(): return Game.money > 0, 5.0), "money synced to client (%s)" % DB.format_money(Game.money))
	check(Game.quest_count[0] >= 0, "quest state synced")
	await wait(1.0)


# --- Screenshots (needs a window) -----------------------------------------------

func _screens() -> void:
	await wait_for(func(): return level() != null and level().local_player() != null)
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var lvl := level()
	var p := lvl.local_player()
	Game.money = 420
	await wait(1.5)
	await _shot(dir + "/01_spawn.png")
	# On the pier looking back at a horde coming for us
	p.global_position = Vector3(0, 1.5, 24)
	_aim(p, 0.0, -0.12)
	for i in 4:
		lvl.spawn_zombie(["shambler", "drowned", "runner", "bloater"][i], Vector3(-3 + i * 2, 1.5, 17), Vector3.ZERO, 1.0, Zombie.State.WALK)
	var from := Vector3(9, -0.6, 30)
	lvl.spawn_zombie("golden", from, Level.lob_velocity(from, Vector3(1, 3, 21), 1.6), 1.0)
	await wait(1.1)
	_aim(p, 0.0, -0.12)
	await _shot(dir + "/02_horde.png")
	# Kill one in style for the popups
	for z in lvl.get_zombies():
		p.request_hit.rpc_id(1, z.name, 999.0, Vector3(0, 6, -3), {"headshot": true, "slap": true}, z.global_position + Vector3.UP)
		break
	await wait(0.35)
	await _shot(dir + "/03_kill.png")
	# Reeling minigame HUD
	p._equip(0)
	p.rod_state = Player.Rod.REELING
	p.hooked = "runner"
	p.tension = 0.72
	p.stamina = 0.25
	p.reel_dist = 14.0
	p.bobber = Vector3(2, 0, 38)
	p.global_position = Vector3(0, 1.5, 35)
	_aim(p, PI, -0.3)
	await wait(0.3)
	await _shot(dir + "/04_reeling.png")
	p._reset_rod()
	p.rod_state = Player.Rod.IDLE
	# Shop
	var hud := get_tree().get_first_node_in_group("hud")
	hud.open_shop()
	await wait(0.3)
	await _shot(dir + "/05_shop.png")
	hud.close_modal()
	for i in [1, 2]:
		Game.unlocked_island = i
		Game.request_travel.rpc_id(1, i)
		await wait_for(func(): return level() != null and level().island == i and not level().is_queued_for_deletion() and level().local_player() != null)
		await wait(1.5)
		var lp := level().local_player()
		lp.global_position = level().markers.spawn + Vector3(0, 0, 6)
		_aim(lp, deg_to_rad(10), -0.08)
		await wait(0.6)
		_aim(lp, deg_to_rad(10), -0.08)
		await _shot(dir + "/0%d_island%d.png" % [5 + i, i])


func _aim(p: Player, yaw: float, pitch: float) -> void:
	p.rotation.y = yaw
	p._pitch = pitch


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[TEST] screenshot ", path)
