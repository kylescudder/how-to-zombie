extends Node
## Root of the game. Holds the menu, HUD and the World container that the host fills with
## the current island via a MultiplayerSpawner (so clients always see the same island).
##
## Command line (after `--`): --solo | --host | --join=<ip>   --new   --test=<name>

var world: Node
var level_spawner: MultiplayerSpawner
var hud: HUD
var menu: MainMenu
var _level_counter := 0


func _ready() -> void:
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
	Game.travel_requested.connect(_load_island)
	_handle_cmdline()


func _spawn_level(data: Dictionary) -> Node:
	var lvl := Level.new()
	lvl.setup(int(data.island))
	lvl.name = data.name
	return lvl


func _on_session_started() -> void:
	menu.visible = false
	hud.set_active(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Net.is_host():
		_load_island(Game.island)
		Game.mark_dirty()


func _load_island(idx: int) -> void:
	if not Net.is_host():
		return
	for c in world.get_children():
		c.queue_free()
	_level_counter += 1
	level_spawner.spawn({"island": idx, "name": "Level%d_%d" % [idx, _level_counter]})
	Game.toast.rpc("Welcome to %s" % DB.ISLANDS[idx].name)


func _on_session_ended(reason: String) -> void:
	for c in world.get_children():
		c.queue_free()
	hud.set_active(false)
	menu.show_menu(reason)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Net.in_session() and Net.is_host():
		Game.save_game()


func _handle_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var fresh := "--new" in args
	for a in args:
		if a.begins_with("--test="):
			var t: Node = load("res://tests/autotest.gd").new()
			t.name = "AutoTest"
			t.set("test_name", a.trim_prefix("--test="))
			add_child(t)
	if "--solo" in args or "--host" in args:
		Game.reset()
		if not fresh:
			Game.load_game()
		if "--solo" in args:
			Net.start_solo()
		else:
			Net.host_enet()
	for a in args:
		if a.begins_with("--join="):
			Game.reset()
			Net.join_enet(a.trim_prefix("--join="))
