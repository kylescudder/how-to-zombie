extends RefCounted
## Runs without a level: tools/godot --headless -- --solo --test=deaths
const MIN_CLIPS := 16
const TYPES := ["common", "boomer", "hunter", "smoker", "spitter", "tank", "witch"]
const SPOTS := ["front", "back", "side"]


func run(test: Node) -> void:
	_library(test)
	_reachable(test)
	await _bodies(test)
	await _in_game(test)


func _library(test: Node) -> void:
	for type: String in TYPES:
		test.check(DeathClips.for_type(type).size() >= MIN_CLIPS, "%s has %d deaths" % [type, DeathClips.for_type(type).size()])
	var broken: Array = []
	for id: String in DeathClips.ids():
		var last := 0.0
		for key: Array in DeathClips.CLIPS[id]["keys"]:
			if float(key[0]) <= last or String(key[1]) not in ["in", "out", "io"]:
				broken.append(id)
			last = float(key[0])
			for channel: String in key[2]:
				if channel not in DeathClips.CHANNELS:
					broken.append("%s.%s" % [id, channel])
		for mirror: bool in [false, true]:
			var code := DeathClips.encode(id, mirror)
			if DeathClips.decode(code).id != id:
				broken.append(id + " round trip")
	test.check(broken.is_empty(), "every clip is well formed %s" % [broken])


## Each clip has to be something the game can actually roll, or it might as well not exist.
func _reachable(test: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for type: String in TYPES:
		var seen := {}
		var mirrored := 0
		for i in 6000:
			var kind: String = ["bullet", "bullet", "melee", "blast", "fire"][i % 5]
			var angle := rng.randf() * TAU
			var push := Vector3(sin(angle), 0, cos(angle)) if kind != "fire" else Vector3.ZERO
			var code := DeathClips.pick(type, kind, kind == "bullet" and rng.randf() < 0.4, push, rng)
			seen[code >> 1] = true
			mirrored += code & 1
		var missing := DeathClips.for_type(type).filter(func(id): return not seen.has(DeathClips.ids().find(id)))
		test.check(missing.is_empty(), "%s can roll every clip %s" % [type, missing])
		test.check(mirrored > 1500 and mirrored < 4500, "%s dies to both sides" % type)
	var wrong := 0
	for i in 400:
		var push := Vector3(-1 if i % 2 == 0 else 1, 0, 0)
		var code := DeathClips.pick("common", "bullet", false, push, rng)
		if DeathClips.CLIPS[DeathClips.ids()[code >> 1]].hit == "side" and (code & 1 == 1) != (push.x < 0.0):
			wrong += 1
	test.check(wrong == 0, "side hits fall the way they were pushed")
	var back_id: String = DeathClips.ids()[DeathClips.pick("common", "bullet", false, Vector3(0, 0, -1), rng) >> 1]
	test.check(DeathClips.CLIPS[back_id].hit in ["front", "any"], "a shot from the front throws the body back, got %s" % back_id)


## Plays every clip on real bodies: nothing may sink through the floor or be left hovering.
func _bodies(test: Node) -> void:
	var holder := Node3D.new()
	test.add_child(holder)
	var sunk: Array = []
	var floating: Array = []
	var propped: Array = []
	var through: Array = []
	for type: String in TYPES:
		for id: String in DeathClips.for_type(type):
			for mirror: bool in [false, true]:
				var model := CharacterModel.new()
				holder.add_child(model)
				model.setup_infected(type, 42)
				if type != "tank":
					model.scale = Vector3.ONE * float(DB.INFECTED[type].size)
				model.animate(0.1, 0.0)
				var clip := DeathClips.compiled(id, mirror)
				model.play_death(clip)
				var air := 0.0
				while model.step_death(1.0 / 30.0):
					air = float((clip["keys"][-1].pose[12] as Vector3).y)
					if model.position.y < -3.0:
						sunk.append(id)
						break
				if absf(model._ground_gap() - air) > 0.01:
					floating.append("%s/%s" % [type, id])
				for limb: Node3D in model._limb_ends:
					if model._lowest(model._limb_ends[limb]) < -0.02:
						through.append("%s/%s" % [type, id])
				# Stiff limbs can hold a corpse up, and the floor snap hides it by lifting the body.
				# Wide bodies get more room: on their side the hips sit half a body width up.
				var slack: float = model.hips.global_position.y / absf(model.global_basis.get_scale().y)
				if slack > {"tank": 0.95, "boomer": 0.72}.get(type, 0.5) and not DeathClips.CLIPS[id].get("upright", false):
					propped.append("%s/%s%s %.2f" % [type, id, "~" if mirror else "", slack])
				model.free()
	test.check(sunk.is_empty(), "no body sinks through the floor %s" % [sunk])
	test.check(floating.is_empty(), "every body ends resting on the floor %s" % [floating])
	test.check(through.is_empty(), "no limb ends up through the floor %s" % [through])
	test.check(propped.is_empty(), "no corpse is propped up on a limb %s" % [propped])
	holder.free()
	await test.get_tree().process_frame


## Real kills through the host's damage path, on the real floor.
func _in_game(test: Node) -> void:
	await test.wait_for(func(): return test.me() != null)
	var lvl: Level = test.level()
	test.calm()
	var spot: Vector3 = test.ahead(30)
	var walker := lvl.spawn_infected("common", spot, false)
	await test.wait(0.3)
	walker.rotation.y = 0.0
	var ground := walker.global_position.y
	walker.take_hit(99999.0, false, Vector3(0, 0, -1), -1, "bullet")
	test.check(walker.net_death >= 0 and walker.is_dead(), "a kill rolls a death clip")
	test.check(DeathClips.CLIPS[DeathClips.decode(walker.net_death).id].hit in ["front", "any"], "a frontal kill gets a frontal clip")
	await test.wait(3.0)
	test.check(walker.model.hips.global_position.y - ground < 0.6, "the body ended up on the ground, hips %.2f" % (walker.model.hips.global_position.y - ground))
	test.check(walker.collision_layer == 0, "bullets pass over the body")
	var leaper := lvl.spawn_infected("hunter", spot + Vector3(4, 3, 0), false)
	await test.wait(0.1)
	leaper.take_hit(99999.0, false, Vector3.FORWARD, -1, "bullet")
	var start := leaper.global_position.y
	test.check(await test.wait_for(func(): return leaper.is_on_floor(), 3.0), "a hunter killed mid-air falls to the floor")
	test.check(leaper.global_position.y < start - 1.5, "and it really dropped, %.1f to %.1f" % [start, leaper.global_position.y])
	test.check(leaper.net_pos.distance_to(leaper.global_position) < 0.05, "clients are told where the body landed")
	var id := walker.name
	test.check(await test.wait_for(func(): return lvl.get_infected(id) == null, 12.0), "corpses are still cleaned up")
	_cost(test, lvl)


func _cost(test: Node, lvl: Level) -> void:
	var body := lvl.spawn_infected("tank", test.ahead(30), false)
	var clip := DeathClips.compiled("tank_knee_thud", false)
	body.set_process(false)
	var from := Time.get_ticks_usec()
	for i in 200:
		if i % 40 == 0:
			body.model.play_death(clip)
		body.model.step_death(1.0 / 60.0)
	print("[TEST]   one dying body costs %d us a frame" % ((Time.get_ticks_usec() - from) / 200))
