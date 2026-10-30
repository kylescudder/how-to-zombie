extends RefCounted
## HUD-free gameplay frames, used as backgrounds for UI mock-ups (screenshots/clean/).
func run(test: Node) -> void:
	var level := test.get_tree().get_first_node_in_group("level") as Level
	var dir := ProjectSettings.globalize_path("res://screenshots/clean")
	DirAccess.make_dir_recursive_absolute(dir)
	var hud := test.get_tree().get_first_node_in_group("hud") as HUD
	level.director.set_process(false)
	var me := level.local_survivor()
	await test.wait(5.5)
	hud.visible = false
	var shots := [
		["street", OpenWorld.camp(0) + Vector3(-420, 0.3, 0), PI * 0.5, 0.05, 14],
		["megamart", level.markers.idol + Vector3(30, -2.3, 2), PI * 0.5, -0.02, 0],
		["roadblock", Vector3.INF, 0.0, 0.0, 6],
	]
	for s: Array in shots:
		var pos: Vector3 = s[1]
		var yaw: float = s[2]
		if s[0] == "roadblock":
			var rb: Dictionary = level.markers.roadblocks[11]
			var through := Vector3(rb.axis.z, 0, rb.axis.x)
			pos = rb.pos - through * 10.0 + Vector3.UP * 0.3
			yaw = atan2(-through.x, -through.z)
		me.global_position = level.nav.center(level.nav.nearest_walkable(pos, 8)) + Vector3.UP * 0.3 if s[0] != "megamart" else pos
		me.aim(yaw, s[3])
		for i in level.all_infected(): i.queue_free()
		await test.wait(0.3)
		var fwd := -me.eye_basis().z
		for k in int(s[4]):
			var c := level.nav.nearest_walkable(me.global_position + fwd * (12.0 + k * 0.9) + me.eye_basis().x * randf_range(-5, 5), 4)
			if c.x >= 0:
				level.spawn_infected("common", level.nav.center(c), true)
		me.select("primary")
		await test.wait(1.2)
		me.aim(yaw, s[3])
		await test.wait(0.05)
		await test._shot(dir + "/%s.png" % s[0])
