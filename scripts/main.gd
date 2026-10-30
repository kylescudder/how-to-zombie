extends Node
## Root of the game. Holds the menu, HUD and the World container that the host fills with
## the current chapter via a MultiplayerSpawner (so clients always load the same map).
##
## Command line (after `--`): --solo | --host | --join=<ip>   --chapter=N   --difficulty=N   --test=<name>

var world: Node
var level_spawner: MultiplayerSpawner
var hud: HUD
var menu: MainMenu
var _level_counter := 0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test="):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/test-profiles"))
			Wardrobe.storage_path="res://screenshots/test-profiles/%s.cfg"%argument.trim_prefix("--test=").replace("/","_")
			Wardrobe.xp=0
			Wardrobe.equipped=CosmeticCatalog.defaults()
	if "--test=wardrobe" in OS.get_cmdline_user_args() or "--test=menu_hideout" in OS.get_cmdline_user_args() or "--test=city_pacing" in OS.get_cmdline_user_args() or "--test=settings" in OS.get_cmdline_user_args() or Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--test=world")): AudioServer.set_bus_mute(0, true)
	if "--test=wardrobe_net_host" in OS.get_cmdline_user_args():
		Wardrobe.xp=4000
		Wardrobe.equipped.hair=2
		Wardrobe.equipped.jackets=1
	if "--test=wardrobe_net_client" in OS.get_cmdline_user_args():
		Wardrobe.xp=4000
		Wardrobe.equipped.hair=6
		Wardrobe.equipped.outfits=2
	world = Node.new()
	world.name = "World"
	add_child(world)
	level_spawner = MultiplayerSpawner.new()
	level_spawner.name = "LevelSpawner"
	add_child(level_spawner)
	level_spawner.spawn_path = NodePath("../World")
	level_spawner.spawn_function = _spawn_level

	hud = HUD.new()
	add_child(hud)
	menu = MainMenu.new()
	add_child(menu)
	menu.show_menu()

	Net.session_started.connect(_on_session_started)
	Net.session_ended.connect(_on_session_ended)
	Game.chapter_requested.connect(_load_chapter)
	_handle_cmdline()


func _spawn_level(data: Dictionary) -> Node:
	var lvl := Level.new()
	lvl.setup(data)
	lvl.name = data.name
	return lvl


func _on_session_started() -> void:
	menu.visible = false
	hud.set_active(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Net.is_host():
		Game.goto_chapter(Game.chapter)


func _load_chapter(idx: int) -> void:
	if not Net.is_host():
		return
	for c in world.get_children():
		c.queue_free()
	_level_counter += 1
	# Wait a frame so the old level (and its node names) are gone everywhere first.
	await get_tree().process_frame
	level_spawner.spawn({"chapter": idx, "open_world": Game.open_world, "name": "Chapter%d_%d" % [idx, _level_counter]})


func _on_session_ended(reason: String) -> void:
	for c in world.get_children():
		c.queue_free()
	hud.set_active(false)
	menu.show_menu(reason)


func _handle_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	Game.open_world = not "--linear" in args
	for a in args:
		if a.begins_with("--test="):
			var t: Node = load("res://tests/autotest.gd").new()
			t.name = "AutoTest"
			t.set("test_name", a.trim_prefix("--test="))
			add_child(t)
		elif a.begins_with("--difficulty="):
			Game.difficulty = int(a.trim_prefix("--difficulty="))
	var start := 0
	for a in args:
		if a.begins_with("--chapter="):
			start = int(a.trim_prefix("--chapter=")) - 1
	if "--solo" in args or "--host" in args:
		Game.reset(clampi(start, 0, DB.CHAPTERS.size() - 1))
		if "--solo" in args:
			Net.start_solo()
		else:
			Net.host_enet()
	for a in args:
		if a.begins_with("--join="):
			Net.join_enet(a.trim_prefix("--join="))
