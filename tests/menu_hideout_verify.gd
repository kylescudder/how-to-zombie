extends RefCounted
func run(test: Node) -> void:
	AudioServer.set_bus_mute(0,true)
	var scene := test.get_tree().current_scene
	var menu: MainMenu=scene.menu
	await test.wait(0.3)
	test.check(menu.visible and menu.hideout._characters.size()==5,"title screen contains four survivors and a zombie")
	test.check(not menu._quip.visible,"no discovery prompt appears on arrival")
	var stage := menu.hideout
	for id in ["radio","survivor1","zombie"]:
		var old_text: String=menu._quip.text
		var point: Vector3=stage._picks[id]
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		event.position=stage.camera.unproject_position(point)*stage.size/Vector2(stage.world.size)
		stage._gui_input(event)
		test.check(menu._quip.text!=old_text,"actual 3D ray click reacts to %s"%id)
	var primary := menu.find_children("*","Button",true,false).filter(func(b): return b.has_meta("main_action")).map(func(b): return b.text)
	test.check(primary==["Host Game","Join Game","Settings","Quit","Credits","Customise"],"title offers exactly the six requested actions")
	var buttons := menu.find_children("*","Button",true,false)
	for button: Button in buttons:
		if button.text=="Join Game": button.pressed.emit()
	test.check(menu.friends.visible,"friends action reveals Steam and LAN sheet")
	for button: Button in buttons:
		if button.text=="Host Game": button.pressed.emit()
	test.check(menu.host_sheet.visible and not menu.friends.visible,"Host and Join have separate destinations")
	if DisplayServer.get_name()!="headless":
		await test.wait(0.1)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/menu-hideout/04-host.png"))
	for button: Button in buttons:
		if button.text=="Credits": button.pressed.emit()
	test.check(menu.credits_sheet.visible and not menu.host_sheet.visible,"Credits opens its own sheet")
	if DisplayServer.get_name()!="headless":
		await test.wait(0.1)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/menu-hideout/05-credits.png"))
	for button: Button in buttons:
		if button.text=="Customise": button.pressed.emit()
	test.check(menu.customise_sheet.visible,"Customise opens profile controls")
	if DisplayServer.get_name()!="headless":
		await test.wait(0.1)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/menu-hideout/06-customise.png"))
	for button: Button in buttons:
		if button.text=="Customise crosshair": button.pressed.emit()
	var crosshair := test.get_tree().get_first_node_in_group("settings_panel") as SettingsPanel
	test.check(crosshair!=null and crosshair.tabs.current_tab==2,"Customise opens working crosshair controls")
	if crosshair: crosshair.finish()
	await test.wait(0.05)
	for button: Button in buttons:
		if button.text=="Join Game": button.pressed.emit()
	menu.ip_edit.text=" "
	for button: Button in buttons:
		if button.text=="Join LAN": button.pressed.emit()
	test.check(menu.status_label.text.contains("IP address") and not Net.in_session(),"empty LAN address is rejected without starting a connection")
	menu.ip_edit.text="127.0.0.1"
	if DisplayServer.get_name()!="headless":
		await test.wait(0.2)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/menu-hideout/02-friends.png"))
	var cancel := InputEventAction.new()
	cancel.action="ui_cancel"
	cancel.pressed=true
	menu._unhandled_input(cancel)
	test.check(not menu.friends.visible,"Escape dismisses the friends sheet")
	for button: Button in buttons:
		if button.text=="Settings": button.pressed.emit()
	var settings := test.get_tree().get_first_node_in_group("settings_panel") as SettingsPanel
	test.check(settings!=null,"settings opens from redesigned title screen")
	if settings: settings.finish()
	menu._process(6.0)
	test.check(not menu._quip.visible,"discovered dialogue fades away without a persistent card")
	menu.status_label.text=""
	if DisplayServer.get_name()!="headless":
		await test.wait(0.3)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/menu-hideout/01-hideout.png"))
		DisplayServer.window_set_size(Vector2i(1280,720))
		await test.wait(0.3)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/menu-hideout/03-720p.png"))
	for button: Button in buttons:
		if button.text=="Start solo": button.pressed.emit()
	test.check(await test.wait_for(func(): return scene.world.get_child_count()>0 and scene.world.get_child(0).local_survivor()!=null,40),"Host Game solo option starts an actual solo world")
	await test.wait(0.2)
	test.check(not menu.visible and stage.world.render_target_update_mode==SubViewport.UPDATE_DISABLED,"hideout rendering stops during gameplay")
	Net.leave("")
	await test.wait(0.2)
	test.check(menu.visible and stage.world.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"leaving the session restores the living title screen")
