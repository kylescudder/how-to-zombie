extends RefCounted
## --test=loading --solo (windowed, so the first-frame stall and the capture are real).
func run(test: Node) -> void:
	var main: Node = test.get_tree().current_scene
	var screen: LoadingScreen = main.loading
	test.check(not main.menu.visible,"menu is hidden behind it")
	await test.wait_for(func(): return not screen.active,20.0)
	test.check(not screen.active,"loading screen finishes")
	test.check(screen.reports>=20,"screen was up for the world build, with real progress (%d reports)"%screen.reports)
	test.check(screen.shown_ms<6000,"a full island loads in under 6 s (%d ms)"%screen.shown_ms)
	test.check(test.me()!=null,"player exists by the time it lifts")
	await test.wait(0.5)
	test.check(not screen.visible,"loading screen is gone after its fade")
	var worst := 0.0
	for frame in 90:
		await test.get_tree().process_frame
		worst = maxf(worst,test.get_process_delta_time())
	print("[TEST] worst frame after reveal: %.0f ms"%(worst*1000.0))
	if DisplayServer.get_name()!="headless":
		test.check(worst<0.25,"no stall moved to the first seconds of play")
		await RenderingServer.frame_post_draw
		test.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/loading/in-game.png"))
	screen.begin()
	await test.get_tree().process_frame
	screen.cancel()
	test.check(not screen.visible and not screen.active,"cancel drops the screen for a dead session")
	if DisplayServer.get_name()!="headless":
		screen.begin()
		screen.set_process(false)
		for stage in LoadingScreen.STAGES.size():
			var progress := 0.1+stage*0.2
			await test.wait(0.1)
			LoadingScreen.report(progress,stage)
			await RenderingServer.frame_post_draw
			test.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/loading/stage-%d.png"%stage))
		screen.cancel()
