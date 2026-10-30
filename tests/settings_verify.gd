extends RefCounted

func run(test: Node) -> void:
	AudioServer.set_bus_mute(0, true)
	var original := {}
	for key in Settings.PREFS: original[key] = Settings.get(key)
	original.bindings = Settings.bindings.duplicate(true)
	var scene := test.get_tree().current_scene
	for button in scene.menu.find_children("*", "Button", true, false):
		if button.text == "Settings": button.pressed.emit()
	var panel := test.get_tree().get_first_node_in_group("settings_panel") as SettingsPanel
	test.check(panel != null, "main menu Settings button opens shared screen")
	await test.wait(0.1)
	test.check(panel.tabs.get_tab_count() == 5, "five settings tabs open in actual game")
	var button_style := panel.tabs.get_theme_stylebox("normal","Button") as StyleBoxFlat
	test.check(button_style!=null and button_style.bg_color.g>=button_style.bg_color.r and button_style.bg_color.r<0.5,"settings uses the field-kit palette rather than legacy red")
	panel.tabs.current_tab=2
	test.check(panel._crosshair_preview.visible,"crosshair tab shows the live preview")
	var colour := panel.tabs.get_child(2).find_children("*","ColorPickerButton",true,false)[0]
	colour.color_changed.emit(Color(0.3,0.7,0.5))
	Settings.load_settings()
	test.check(Settings.crosshair_color.is_equal_approx(Color(0.3,0.7,0.5)),"crosshair picker saves the preview colour")
	var markers := panel.tabs.get_child(2).find_children("*","CheckButton",true,false)[0]
	markers.button_pressed=false
	test.check(not Settings.hit_markers and markers.text=="Off","compact switch updates its value and state label")
	panel.tabs.current_tab=0
	var sliders := panel.find_children("*", "HSlider", true, false)
	sliders[1].value = 0.65
	Settings.load_settings()
	test.check(is_equal_approx(Settings.aim_sensitivity, 0.65), "slider changes persist and reload")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	Settings.rebind("reload", key)
	Settings.load_settings()
	test.check(InputMap.action_has_event("reload", key), "saved reload binding restores physical key")
	var pad_preserved := false
	for event in InputMap.action_get_events("reload"):
		if event is InputEventJoypadButton: pad_preserved = true
	test.check(pad_preserved, "keyboard rebinding preserves controller binding")
	Settings.reset_bindings()
	key.physical_keycode = KEY_R
	test.check(InputMap.action_has_event("reload", key), "restore defaults restores reload key")
	Settings.effects_volume = 0
	Settings.music_volume = 0.4
	Settings.voice_volume = 0.7
	Settings.apply()
	test.check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "effects zero mutes effects bus")
	test.check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.4), "music channel independent")
	test.check(Sfx.sound_bus("witch_cry") == "Voice" and Sfx.sound_bus("horde_music") == "Music" and Sfx.sound_bus("rifle") == "Effects", "sounds route to correct buses")
	Settings.fps_cap = 120
	Settings.graphics_quality = 0
	Settings.apply()
	test.check(Engine.max_fps == 120 and test.get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "FPS cap and graphics affect renderer")
	panel.finish()
	await test.wait(0.05)
	var me: Survivor = test.get_tree().get_first_node_in_group("level").local_survivor()
	Settings.toggle_aim = true
	Input.action_press("aim")
	await test.wait(0.05)
	Input.action_release("aim")
	await test.wait(0.05)
	test.check(me.in_aim, "toggle aim stays on after release")
	me.ui_open = true
	me._gather_input(0.016)
	test.check(not me.in_aim, "opening UI clears aim latch")
	me.ui_open = false
	Settings.toggle_crouch = true
	Input.action_press("crouch")
	await test.wait(0.05)
	Input.action_release("crouch")
	await test.wait(0.05)
	test.check(me.in_crouch, "toggle crouch stays on after release")
	Settings.invert_look = true
	Settings.aim_sensitivity = 0.5
	me.aim_blend = 1
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0, 10)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var pitch_before: float = me._pitch
	me._unhandled_input(motion)
	if DisplayServer.get_name() != "headless": test.check(me._pitch > pitch_before, "invert look reverses mouse vertical movement")
	Settings.head_bob = 0
	Settings.camera_shake = 0
	me.add_shake(1)
	await test.wait(0.05)
	test.check(me.camera.position.is_zero_approx(), "zero comfort sliders remove camera bob and shake")
	scene.hud.confirm_hit()
	test.check(scene.hud._hit_t > 0, "confirmed hit activates visual marker timer")
	panel = SettingsPanel.new()
	scene.add_child(panel)
	await test.wait(0.05)
	# Exercise display selection through the actual UI, then timeout rollback.
	panel.tabs.current_tab = 4
	var choices := panel.tabs.get_child(4).find_children("*", "OptionButton", true, false)
	var old_mode := Settings.window_mode
	choices[0].item_selected.emit(1)
	test.check(not Settings.pending_display.is_empty(), "display changes require confirmation")
	panel._process(16.0)
	await test.wait(0.05)
	test.check(Settings.window_mode == old_mode and Settings.pending_display.is_empty(), "timeout restores previous display settings")
	for current in test.get_tree().get_nodes_in_group("settings_panel"): current.finish()
	await test.wait(0.1)
	for name in original: Settings.set(name, original[name])
	Settings.reset_bindings()
	Settings.bindings = original.bindings
	Settings.save_settings()
	scene.hud.open_pause()
	for button in scene.hud.modal.find_children("*", "Button", true, false):
		if button.text == "Settings": button.pressed.emit()
	var pause_panel := test.get_tree().get_first_node_in_group("settings_panel") as SettingsPanel
	test.check(pause_panel != null, "pause menu Settings button opens shared screen")
	if pause_panel: pause_panel.finish()
	scene.hud.close_modal()
	await test.wait(0.05)
	# Native screenshots: exact delivered UI at 1600x900 and 1280x720.
	if DisplayServer.get_name() != "headless":
		panel = SettingsPanel.new()
		scene.add_child(panel)
		await test.wait(0.2)
		for index in 5:
			panel.tabs.current_tab = index
			await test.wait(0.15)
			await test._shot(ProjectSettings.globalize_path("res://screenshots/settings/%02d-settings.png" % index))
		DisplayServer.window_set_size(Vector2i(1280,720))
		await test.wait(0.2)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/settings/05-settings-720p.png"))
		panel.finish()
		scene.hud.set_active(false)
		scene.menu.show_menu()
		DisplayServer.window_set_size(Vector2i(1600,900))
		await test.wait(0.2)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/settings/06-main-menu.png"))
