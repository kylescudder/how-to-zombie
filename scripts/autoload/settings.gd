extends Node
## Player preferences + input map (built in code so it's easy to read and edit).

const PATH := "user://settings.cfg"

var player_name := "Survivor"
var mouse_sensitivity := 0.0025
var master_volume := 0.8
var fov := 80.0
var aim_sensitivity := 1.0
var controller_sensitivity := 1.0
var controller_deadzone := 0.25
var invert_look := false
var toggle_aim := false
var toggle_crouch := false
var camera_shake := 1.0
var head_bob := 1.0
var weapon_sway := 1.0
var hit_flashes := 1.0
var crosshair_color := Color.WHITE
var crosshair_size := 1.0
var crosshair_opacity := 0.85
var hit_markers := true
var hit_marker_sound := true
var effects_volume := 1.0
var music_volume := 1.0
var voice_volume := 1.0
var window_mode := 0
var resolution := Vector2i(1600, 900)
var vsync := true
var fps_cap := 0
var graphics_quality := 2
var bindings: Dictionary = {}
var pending_display: Array = []
var _applied_display: Array = []
const PREFS := ["player_name", "mouse_sensitivity", "master_volume", "fov", "aim_sensitivity", "controller_sensitivity", "controller_deadzone", "invert_look", "toggle_aim", "toggle_crouch", "camera_shake", "head_bob", "weapon_sway", "hit_flashes", "crosshair_color", "crosshair_size", "crosshair_opacity", "hit_markers", "hit_marker_sound", "effects_volume", "music_volume", "voice_volume", "window_mode", "resolution", "vsync", "fps_cap", "graphics_quality", "bindings"]

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"walk": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"interact": [KEY_E],
	"reload": [KEY_R],
	"inspect": [KEY_I],
	"secondary": [KEY_V],
	"flashlight": [KEY_F],
	"pause": [KEY_ESCAPE],
	"world_map": [KEY_M],
	"scoreboard": [KEY_TAB],
	"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5],
}
const MOUSE_ACTIONS := {
	"primary": MOUSE_BUTTON_LEFT,
	"aim": MOUSE_BUTTON_RIGHT,
	"next_slot": MOUSE_BUTTON_WHEEL_DOWN,
	"prev_slot": MOUSE_BUTTON_WHEEL_UP,
}
const PAD_BUTTONS := {
	"world_map": JOY_BUTTON_DPAD_RIGHT, "inspect": JOY_BUTTON_DPAD_LEFT, "secondary": JOY_BUTTON_RIGHT_STICK, "jump": JOY_BUTTON_A, "interact": JOY_BUTTON_X, "reload": JOY_BUTTON_Y, "pause": JOY_BUTTON_START,
	"next_slot": JOY_BUTTON_RIGHT_SHOULDER, "prev_slot": JOY_BUTTON_LEFT_SHOULDER, "walk": JOY_BUTTON_LEFT_STICK,
	"crouch": JOY_BUTTON_B, "scoreboard": JOY_BUTTON_BACK, "flashlight": JOY_BUTTON_DPAD_UP,
}


func _ready() -> void:
	_build_input_map()
	load_settings()
	apply()
	if player_name == "Survivor":
		player_name = "Survivor%d" % (randi() % 900 + 100)


func _build_input_map() -> void:
	for action in ACTIONS:
		_ensure(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE_ACTIONS:
		_ensure(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_ACTIONS[action]
		InputMap.action_add_event(action, mb)
	for action in PAD_BUTTONS:
		_ensure(action)
		var jb := InputEventJoypadButton.new()
		jb.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, jb)
	# Triggers + sticks
	_pad_axis("primary", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		_ensure(a)
	_pad_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


func _pad_axis(action: String, axis: JoyAxis, dir: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	player_name = cfg.get_value("player", "name", player_name)
	mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	fov = cfg.get_value("video", "fov", fov)
	for key in PREFS:
		set(key, cfg.get_value("preferences", key, get(key)))
	apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fov", fov)
	for key in PREFS:
		cfg.set_value("preferences", key, get(key))
	if not pending_display.is_empty():
		cfg.set_value("preferences", "window_mode", pending_display[0])
		cfg.set_value("preferences", "resolution", pending_display[1])
	cfg.save(PATH)
	apply()


func apply() -> void:
	for bus in ["Effects", "Music", "Voice"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	for pair in [["Master", master_volume], ["Effects", effects_volume], ["Music", music_volume], ["Voice", voice_volume]]:
		var index := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(pair[1]), 0.0001)))
		# Preserve capture mute on Master; volume zero is an actual mute on child buses.
		if index != 0: AudioServer.set_bus_mute(index, float(pair[1]) <= 0)
	Engine.max_fps = fps_cap
	for action in InputMap.get_actions():
		InputMap.action_set_deadzone(action, controller_deadzone)
	apply_bindings()
	if DisplayServer.get_name() != "headless" and _applied_display != [window_mode, resolution, vsync]:
		_applied_display = [window_mode, resolution, vsync]
		DisplayServer.window_set_mode([DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN][clampi(window_mode, 0, 2)])
		if window_mode == 0: DisplayServer.window_set_size(resolution)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var viewport := get_viewport()
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(graphics_quality, 0, 2)]
	viewport.scaling_3d_scale = [0.65, 0.85, 1.0][clampi(graphics_quality, 0, 2)]


func apply_bindings() -> void:
	for action in bindings:
		if not InputMap.has_action(action): continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
				InputMap.action_erase_event(action, event)
		for data in bindings[action]:
			var event: InputEvent
			match data.kind:
				"key":
					event = InputEventKey.new()
					event.physical_keycode = int(data.code)
				"mouse":
					event = InputEventMouseButton.new()
					event.button_index = int(data.code)
				"pad":
					event = InputEventJoypadButton.new()
					event.button_index = int(data.code)
			if event: InputMap.action_add_event(action, event)


func rebind(action: String, event: InputEvent) -> void:
	var kind := "key" if event is InputEventKey else ("mouse" if event is InputEventMouseButton else "pad")
	var code: int = event.physical_keycode if kind == "key" else event.button_index
	var data: Array = bindings.get(action, [])
	if data.is_empty():
		for existing in InputMap.action_get_events(action):
			if existing is InputEventKey: data.append({"kind": "key", "code": existing.physical_keycode})
			elif existing is InputEventMouseButton: data.append({"kind": "mouse", "code": existing.button_index})
			elif existing is InputEventJoypadButton: data.append({"kind": "pad", "code": existing.button_index})
	data = data.filter(func(item): return item.kind != kind)
	data.append({"kind": kind, "code": code})
	bindings[action] = data
	save_settings()


func reset_bindings() -> void:
	bindings.clear()
	for action in InputMap.get_actions():
		if not action.begins_with("ui_"): InputMap.action_erase_events(action)
	_build_input_map()
	save_settings()
