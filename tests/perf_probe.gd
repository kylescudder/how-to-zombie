extends RefCounted
## Prints how long the world took to build and frame times in Barea (needs a window for render cost).
func run(test: Node) -> void:
	var level := test.get_tree().get_first_node_in_group("level") as Level
	level.director.set_process(false)
	var me := level.local_survivor()
	var nodes := level.get_node("Geometry").get_child_count()
	print("[PERF] blocks=%d nodes=%d nav=%dx%d" % [level.markers.city_blocks.size(), nodes, level.nav.w, level.nav.h])
	for spot: Vector3 in [OpenWorld.camp(0) + Vector3(-300, 0.3, 0), Vector3(OpenWorld.ISLANDS[0].center.x + 60, 0.3, OpenWorld.ISLANDS[0].center.y)]:
		me.global_position = level.nav.center(level.nav.nearest_walkable(spot, 10)) + Vector3.UP * 0.3
		for yaw: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			me.aim(yaw, 0.05)
			await test.wait(0.3)
			var worst := 0.0
			var total := 0.0
			for k in 60:
				await test.get_tree().process_frame
				var d := test.get_process_delta_time()
				total += d
				worst = maxf(worst, d)
			print("[PERF] at %s yaw %d: avg %.1f ms, worst %.1f ms, draw calls %d" % [spot.round(), int(rad_to_deg(yaw)), total / 60.0 * 1000.0, worst * 1000.0, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
