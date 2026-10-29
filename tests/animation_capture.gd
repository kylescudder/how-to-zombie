extends Node
## Reproducible footage of the real game. Run with --fixed-fps 20 -- --solo --test=animations.
const FPS := 20
var runner: Node
var p: Survivor
var lvl: Level
var base := Vector3.ZERO
var dir := ""
var first_person := true
var camera_pose := Transform3D.IDENTITY
var spectator: Camera3D


func run(test: Node) -> void:
	AudioServer.set_bus_mute(0, true)
	runner = test
	await runner.wait_for(func(): return runner.me() != null)
	p = runner.me()
	lvl = runner.level()
	dir = ProjectSettings.globalize_path("res://screenshots/animations/frames")
	DirAccess.make_dir_recursive_absolute(dir)
	runner.calm()
	lvl.request_door.rpc_id(1, 0)
	base = runner.ahead(30)
	for mate: Survivor in lvl.get_survivors():
		if mate.bot:
			mate.brain = null
			mate.in_move = Vector2.ZERO
			runner.place(mate, lvl.markers.spawns[mate.slot])
	await equip("rifle")
	await runner.wait(5.2)
	if "--pistol-only" in OS.get_cmdline_user_args():
		await equip("pistol")
		p.inv.secondary.mag = 1
		await record("reload-pistol", 2.5, func(f):
			if f == 5: runner.press("reload", true)
			if f == 7: runner.press("reload", false))
		runner.check(p.weapon_id() == "pistol" and int(p.inv.secondary.mag) == 15, "single-pistol clip reloads the single M9")
		return
	if "--care-only" in OS.get_cmdline_user_args():
		await characters(true)
		return
	if "--third-only" in OS.get_cmdline_user_args():
		await equip("pump_shotgun")
		await record("09-shotgun-pump", 2.2, func(f):
			if f == 7: runner.press("primary", true)
			if f == 9: runner.press("primary", false))
		await characters()
		await infected()
		await environment()
		return
	await record("01-idle-breathing", 4.0)
	await record("02-walk-bob", 3.0, func(f):
		if f == 0:
			runner.press("walk", true)
			runner.press("move_forward", true))
	await record("03-run-bob", 3.0, func(f):
		if f == 0:
			runner.press("move_forward", true))
	await record("04-strafe-look-sway", 3.5, func(f):
		p.aim(PI + sin(f * 0.055) * 0.25, sin(f * 0.08) * 0.07)
		if f == 0: runner.press("move_right", true)
		if f == 28:
			runner.press("move_right", false)
			runner.press("move_left", true))
	await record("05-jump-and-landing", 2.5, func(f):
		if f == 8: runner.press("jump", true)
		if f == 10: runner.press("jump", false))
	await record("06-aim-transition", 3.0, func(f):
		if f == 8: runner.press("aim", true)
		if f == 40: runner.press("aim", false))
	await record("07-rifle-fire", 2.5, func(f):
		if f == 8: runner.press("primary", true)
		if f == 30: runner.press("primary", false))
	await record("08-inspect", 4.0, func(f):
		if f == 5: runner.press("inspect", true)
		if f == 7: runner.press("inspect", false))
	for id: String in DB.GUN_PROFILES:
		await equip(id)
		var slot := p.cur
		p.inv[slot].mag = 1
		p._sync_inv()
		var seconds := float(p.current_weapon().reload) + 1.1
		await record("reload-" + id, seconds, func(f):
			if f == 5: runner.press("reload", true)
			if f == 7: runner.press("reload", false))
		runner.check(int(p.inv[slot].mag) == int(p.current_weapon().mag), "captured actual " + id + " reload and ammo transfer")
	await equip("pump_shotgun")
	await record("09-shotgun-pump", 2.2, func(f):
		if f == 7: runner.press("primary", true)
		if f == 9: runner.press("primary", false))
	await equip("rifle")
	await record("10-weapon-draw", 3.0, func(f):
		if f == 8: runner.press("slot_2", true)
		if f == 10: runner.press("slot_2", false)
		if f == 32: runner.press("slot_1", true)
		if f == 34: runner.press("slot_1", false))
	await record("11-shove", 2.0, func(f):
		if f == 8: runner.press("secondary", true)
		if f == 10: runner.press("secondary", false))
	await equip("axe")
	await record("12-melee-swing", 2.0, func(f):
		if f == 7: runner.press("primary", true)
		if f == 9: runner.press("primary", false))
	await characters()
	await infected()
	await environment()
	print("[ANIMATION] captured every clip at %d fps" % FPS)


func equip(id: String) -> void:
	reset_input()
	runner.place(p, base)
	p.aim(PI, 0)
	if id == "pistol":
		p.inv.secondary = {}  # Stage a single pistol rather than combining two pickups.
	p.receive_item.rpc_id(p.peer_id, id, {})
	p.select(String(DB.weapon(id).slot))
	p.reload_t = 0
	await runner.wait(0.6)


func reset_input() -> void:
	for action in ["primary", "secondary", "aim", "reload", "inspect", "walk", "jump", "move_left", "move_right", "move_forward", "move_back", "slot_1", "slot_2"]:
		runner.press(action, false)


func record(name: String, seconds: float, step := Callable()) -> void:
	if first_person:
		runner.place(p, base)
		p.aim(PI, 0)
	var path := dir.path_join(name)
	DirAccess.make_dir_recursive_absolute(path)
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".png"):
			DirAccess.remove_absolute(path.path_join(file))
	for frame in ceili(seconds * FPS):
		if step.is_valid(): step.call(frame)
		await get_tree().process_frame
		await RenderingServer.frame_pre_draw
		if not first_person:
			spectator.global_transform = camera_pose
			p.viewmodel.hide()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(800, 450, Image.INTERPOLATE_LANCZOS)
		img.save_png(path.path_join("%04d.png" % frame))
	reset_input()
	print("[ANIMATION] %s: %d frames" % [name, ceili(seconds * FPS)])
	await runner.wait(0.25)


func watch(target: Vector3) -> void:
	if spectator == null:
		spectator = Camera3D.new()
		spectator.fov = 65.0
		lvl.add_child(spectator)
		spectator.current = true
		var fill := OmniLight3D.new()
		fill.light_energy = 2.0
		fill.omni_range = 10.0
		spectator.add_child(fill)
	spectator.global_position = target + Vector3(2.8, 1.7, 3.5)
	spectator.look_at(target + Vector3.UP * 1.1)
	camera_pose = spectator.global_transform
	p.viewmodel.hide()
	p.ui_open = true
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	hud.set_process(false)
	hud.visible = false


func characters(care_only := false) -> void:
	first_person = false
	reset_input()
	runner.place(p, base - Vector3(5, 0, 0))
	var bot: Survivor = lvl.get_survivor_by_slot(1)
	runner.place(bot, base)
	bot.aim(0.0, 0.0)
	bot.receive_item.rpc_id(bot.peer_id, "rifle", {})
	await runner.wait(0.5)
	for pickup: Pickup in lvl.get_pickups():
		if pickup.global_position.distance_to(base) < 7:
			pickup.queue_free()
	watch(base)
	if not care_only:
		await record("13-survivor-idle", 4.0)
		await record("14-survivor-movement", 3.5, func(f):
			bot.in_move = Vector2(0.65 if f < 35 else -0.65, 0))
		bot.in_move = Vector2.ZERO
		runner.place(bot, base)
		bot.inv.primary.mag = 1
		await record("15-survivor-reload", 3.8, func(f):
			bot.in_reload = f == 5)
	bot.receive_item.rpc_id(bot.peer_id, "medkit", {})
	bot.select("medkit")
	bot.hp = 45.0
	await record("16-survivor-first-aid", 5.8, func(f):
		if f == 5:
			bot.in_fire = true
			bot._start_action("heal_self", bot.name))
	bot.in_fire = false
	runner.check(bot.hp > 80 and not bot.inv.medkit, "first-aid clip records a completed heal")
	var patient: Survivor = lvl.get_survivor_by_slot(2)
	runner.place(patient, base + Vector3(0, 0, 1.2))
	patient.host_damage(150.0)
	await record("17-survivor-revive", 5.8, func(f):
		if f == 5:
			bot.in_use = true
			bot._start_action("revive", patient.name))
	bot.in_use = false
	runner.check(not patient.incapped, "revive clip records a completed teammate revive")
	for mate: Survivor in lvl.get_survivors():
		if mate.bot:
			runner.place(mate, lvl.markers.spawns[mate.slot])


func infected() -> void:
	var zombie := lvl.spawn_infected("common", base, false)
	zombie.set_physics_process(false)
	zombie.rotation.y = 0.0
	watch(base)
	await record("18-infected-idle", 3.5)
	await record("19-infected-run-and-swipe", 3.0, func(f):
		zombie.velocity = Vector3(0, 0, 5)
		zombie.net_anim = Infected.A.ATTACK if f in [15, 35] else Infected.A.RUN)
	zombie.velocity = Vector3.ZERO
	zombie.net_anim = Infected.A.STAGGER
	await record("20-infected-stagger", 2.0)
	zombie.net_anim = Infected.A.IDLE
	await record("25-infected-collapse", 2.5, func(f):
		if f == 8:
			zombie.set_physics_process(true)
			zombie.take_hit(1000, false, Vector3.FORWARD, p.slot))
	zombie.queue_free()
	await runner.wait(0.1)
	var witch := lvl.spawn_infected("witch", base, false)
	witch.set_physics_process(false)
	witch.rotation.y = 0.0
	witch.net_anim = Infected.A.SIT
	await record("21-witch-crying", 3.5)
	witch.queue_free()
	await runner.wait(0.1)
	var tank := lvl.spawn_infected("tank", base, false)
	tank.set_physics_process(false)
	tank.rotation.y = 0.0
	watch(base + Vector3(0, 0.3, 0))
	await record("22-tank-idle-and-swipe", 3.5, func(f):
		tank.net_anim = Infected.A.ATTACK if f in [30, 50] else Infected.A.IDLE)
	tank.queue_free()


func environment() -> void:
	var door: Door = lvl.doors[0]
	var center: Vector3 = door.global_position
	watch(center + Vector3(0, 0, 1.5))
	await record("23-safe-room-door", 3.0, func(f):
		if f == 5: lvl.request_door.rpc_id(1, 0)
		if f == 35: lvl.request_door.rpc_id(1, 0))
	var pickup: Pickup = lvl.get_pickups().filter(func(k): return k.item == "medkit")[0]
	watch(pickup.global_position - Vector3(1, 0, 1))
	spectator.global_position = pickup.global_position + Vector3(0.9, 0.55, 0.8)
	spectator.look_at(pickup.global_position)
	camera_pose = spectator.global_transform
	await record("24-supply-idle", 3.5)
