extends Node
## Player preferences + input map (built in code so it's easy to read and edit).

const PATH := "user://settings.cfg"

var player_name := "Survivor"
var mouse_sensitivity := 0.0025
var master_volume := 0.8
var fov := 80.0

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"reload": [KEY_R],
	"drop": [KEY_Q],
	"pause": [KEY_ESCAPE],
	"scoreboard": [KEY_TAB],
	"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5],
	"slot_6": [KEY_6], "slot_7": [KEY_7], "slot_8": [KEY_8], "slot_9": [KEY_9], "slot_10": [KEY_0],
}
const MOUSE_ACTIONS := {
	"primary": MOUSE_BUTTON_LEFT,
	"secondary": MOUSE_BUTTON_RIGHT,
	"next_slot": MOUSE_BUTTON_WHEEL_DOWN,
	"prev_slot": MOUSE_BUTTON_WHEEL_UP,
}
const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A, "interact": JOY_BUTTON_X, "reload": JOY_BUTTON_Y, "pause": JOY_BUTTON_START,
	"next_slot": JOY_BUTTON_RIGHT_SHOULDER, "prev_slot": JOY_BUTTON_LEFT_SHOULDER, "sprint": JOY_BUTTON_LEFT_STICK,
	"drop": JOY_BUTTON_B, "scoreboard": JOY_BUTTON_BACK,
}


func _ready() -> void:
	_build_input_map()
	load_settings()
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
	_pad_axis("secondary", JOY_AXIS_TRIGGER_LEFT, 1.0)
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
	apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fov", fov)
	cfg.save(PATH)
	apply()


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(max(master_volume, 0.0001)))
