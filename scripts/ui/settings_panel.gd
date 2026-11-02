class_name SettingsPanel
extends CanvasLayer
## Shared live preferences. Display changes roll back unless explicitly confirmed.
signal closed
var tabs: TabContainer
var _binding := ""
var _bind_button: Button
var _display_before: Array = []
var _confirm: Button
var _remaining := 0.0
var _help_title: Label
var _help_text: Label
var _crosshair_preview: Control
const PAPER := Color(0.91,0.87,0.76)
const INK := Color(0.16,0.22,0.19)

func _ready() -> void:
	add_to_group("settings_panel")
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.065,0.105,0.095,0.99)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 32)
	margin.theme = UIKit.field_theme()
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("Settings", 36, PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UIKit.button("Done / Esc", finish, 20))
	column.add_child(_label("Changes save automatically. Display changes require confirmation.", 17))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := HBoxContainer.new()
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",24)
	column.add_child(content)
	tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	_build_notes(content)
	var controls := page("Controls")
	slider(controls, "Mouse sensitivity", "mouse_sensitivity", 0.0005, 0.008, 0.0001)
	slider(controls, "Aim sensitivity multiplier", "aim_sensitivity", 0.1, 2.0, 0.05)
	slider(controls, "Controller sensitivity", "controller_sensitivity", 0.1, 3.0, 0.05)
	slider(controls, "Controller dead zone", "controller_deadzone", 0.05, 0.5, 0.01)
	toggle(controls, "Invert vertical look", "invert_look")
	toggle(controls, "Toggle aim", "toggle_aim")
	toggle(controls, "Toggle crouch", "toggle_crouch")
	controls.add_child(_label("Rebind: click an action, then press a key, mouse button or controller button. Esc cancels.\nStick axes and triggers retain their defaults. Reused buttons may trigger multiple actions.", 16))
	controls.add_child(UIKit.button("Restore default bindings", func():
		Settings.reset_bindings()
		refresh_bindings(), 18))
	var actions: Array = Settings.ACTIONS.keys()
	actions.append_array(Settings.MOUSE_ACTIONS.keys())
	for action in actions:
		var button := UIKit.button("", func(): pass, 18)
		button.set_meta("action", action)
		button.pressed.connect(func():
			_binding = action
			_bind_button = button
			button.text = "Press input for %s… (Esc cancels)" % action)
		controls.add_child(button)
	refresh_bindings()
	var comfort := page("Comfort")
	for pair in [["Camera shake", "camera_shake"], ["Head bob", "head_bob"], ["Weapon sway and bob", "weapon_sway"], ["Damage flash intensity", "hit_flashes"], ["Film grain and vignette", "film_grain"]]:
		slider(comfort, pair[0], pair[1], 0, 1, 0.05)
	comfort.add_child(_label("These adjust cosmetic motion. Weapon recoil, spread and reload timing stay consistent.", 17))
	var cross := page("Crosshair")
	var color := ColorPickerButton.new()
	color.custom_minimum_size = Vector2(90,40)
	color.tooltip_text="Choose crosshair colour"
	color.size_flags_horizontal = Control.SIZE_SHRINK_END
	color.color = Settings.crosshair_color
	color.color_changed.connect(func(value): Settings.crosshair_color = value; Settings.save_settings())
	var colour_row := row(cross,"Crosshair colour")
	var colour_space := Control.new()
	colour_space.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	colour_row.add_child(colour_space)
	colour_row.add_child(color)
	slider(cross, "Crosshair size", "crosshair_size", 0.5, 3, 0.1)
	slider(cross, "Crosshair opacity", "crosshair_opacity", 0, 1, 0.05)
	toggle(cross, "Visual hit markers", "hit_markers")
	toggle(cross, "Hit marker sound", "hit_marker_sound")
	var audio := page("Audio")
	for pair in [["Master", "master_volume"], ["Effects", "effects_volume"], ["Music", "music_volume"], ["Voice", "voice_volume"]]:
		slider(audio, pair[0], pair[1], 0, 1, 0.05)
	audio.add_child(_label("Voice controls character vocal effects. Voice chat is not implemented yet.", 17))
	var display := page("Display")
	slider(display, "Field of view", "fov", 60, 110, 1)
	choice(display, "Window mode", "window_mode", ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"], [0, 1, 2], true)
	choice(display, "Window resolution", "resolution", ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"], [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)], true)
	toggle(display, "VSync", "vsync")
	choice(display, "FPS cap", "fps_cap", ["Unlimited", "30", "60", "90", "120", "144", "165", "240"], [0,30,60,90,120,144,165,240])
	choice(display, "Graphics quality", "graphics_quality", ["Low — 65% render, no MSAA", "Medium — 85% render, 2× MSAA", "High — native render, 4× MSAA"], [0,1,2])
	display.add_child(_label("Fullscreen uses your display resolution; the resolution option applies to windowed mode.", 17))
	_confirm = UIKit.button("", func():
		_display_before.clear()
		Settings.pending_display.clear()
		_remaining = 0
		_confirm.hide()
		Settings.save_settings(), 20)
	_confirm.hide()
	display.add_child(_confirm)
	tabs.tab_changed.connect(_tab_help)
	_tab_help(tabs.current_tab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	return box

func row(parent: Control, title: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	parent.add_child(box)
	box.custom_minimum_size.y=58
	box.mouse_entered.connect(func(): _setting_help(title))
	var label := _label(title, 19)
	label.custom_minimum_size.x = 285
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	box.add_child(label)
	return box

func slider(parent: Control, title: String, key: String, lo: float, hi: float, step: float) -> void:
	var box := row(parent, title)
	var control := HSlider.new()
	control.min_value = lo
	control.max_value = hi
	control.step = step
	control.value = Settings.get(key)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size=Vector2(120,32)
	control.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	control.focus_entered.connect(func(): _setting_help(title))
	box.add_child(control)
	var value := _label(str(snappedf(control.value, 0.0001)), 18)
	value.custom_minimum_size.x = 90
	value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	box.add_child(value)
	control.value_changed.connect(func(x):
		Settings.set(key, x)
		value.text = str(snappedf(x, 0.0001))
		Settings.save_settings())

func toggle(parent: Control, title: String, key: String) -> void:
	var box := row(parent,title)
	var space := Control.new()
	space.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_child(space)
	var button := CheckButton.new()
	button.text="On" if Settings.get(key) else "Off"
	button.custom_minimum_size.x=110
	button.button_pressed = Settings.get(key)
	button.focus_entered.connect(func(): _setting_help(title))
	button.toggled.connect(func(value):
		Settings.set(key,value)
		button.text="On" if value else "Off"
		Settings.save_settings())
	box.add_child(button)

func choice(parent: Control, title: String, key: String, labels: Array, values: Array, confirm := false) -> void:
	var box := row(parent, title)
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label in labels: pick.add_item(label)
	pick.select(maxi(values.find(Settings.get(key)), 0))
	box.add_child(pick)
	pick.item_selected.connect(func(index):
		if confirm and _display_before.is_empty():
			_display_before = [Settings.window_mode, Settings.resolution]
			Settings.pending_display = _display_before.duplicate()
		Settings.set(key, values[index])
		Settings.apply()
		if confirm:
			_remaining = 15
			_confirm.show()
		else: Settings.save_settings())

func refresh_bindings() -> void:
	for button in find_children("*", "Button", true, false):
		if not button.has_meta("action"): continue
		var action: String = button.get_meta("action")
		var names: Array[String] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey: names.append(OS.get_keycode_string(event.physical_keycode))
			elif event is InputEventMouseButton:
				names.append({1: "Left mouse", 2: "Right mouse", 3: "Middle mouse", 4: "Wheel up", 5: "Wheel down"}.get(event.button_index, "Mouse %d" % event.button_index))
			elif event is InputEventJoypadButton:
				names.append({0: "A / Cross", 1: "B / Circle", 2: "X / Square", 3: "Y / Triangle", 4: "Back", 6: "Start", 7: "Left stick click", 8: "Right stick click", 9: "LB / L1", 10: "RB / R1", 11: "D-pad up", 13: "D-pad left"}.get(event.button_index, "Controller %d" % event.button_index))
			elif event is InputEventJoypadMotion:
				var axis: String = {0: "Left stick", 1: "Left stick", 2: "Right stick", 3: "Right stick", 4: "LT / L2", 5: "RT / R2"}.get(event.axis, "Stick")
				if event.axis < 4: axis += (" left" if event.axis_value < 0 else " right") if event.axis % 2 == 0 else (" up" if event.axis_value < 0 else " down")
				names.append(axis)
		button.text = "%s:  %s" % [action.capitalize(), ", ".join(names)]

func _input(event: InputEvent) -> void:
	if _binding != "":
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_binding = ""
			refresh_bindings()
		elif (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed and not event.is_echo():
			Settings.rebind(_binding, event)
			_binding = ""
			refresh_bindings()
		else: return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()

func _process(delta: float) -> void:
	if _crosshair_preview: _crosshair_preview.queue_redraw()
	if _remaining <= 0: return
	_remaining -= delta
	_confirm.text = "Keep display changes (%ds)" % ceili(_remaining)
	if _remaining <= 0: rollback()

func rollback() -> void:
	if _display_before.is_empty(): return
	Settings.window_mode = _display_before[0]
	Settings.resolution = _display_before[1]
	_display_before.clear()
	Settings.pending_display.clear()
	_remaining = 0
	_confirm.hide()
	Settings.save_settings()
	# Rebuild selected values after a revert.
	var replacement := SettingsPanel.new()
	replacement.closed.connect(func(): closed.emit())
	get_parent().add_child(replacement)
	queue_free()

func finish() -> void:
	if not _display_before.is_empty():
		Settings.window_mode = _display_before[0]
		Settings.resolution = _display_before[1]
	Settings.pending_display.clear()
	Settings.save_settings()
	closed.emit()
	queue_free()


func _label(text: String, size := 20, color := PAPER) -> Label:
	var label := Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func _build_notes(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x=275
	panel.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel",UIKit.box(PAPER,4,1,Color(0.65,0.59,0.40)))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	panel.add_child(column)
	_help_title=_label("Your kit",25,INK)
	_help_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_help_title.custom_minimum_size.x=235
	column.add_child(_help_title)
	_help_text=_label("",18,INK)
	_help_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_help_text.custom_minimum_size=Vector2(235,135)
	column.add_child(_help_text)
	_crosshair_preview=Control.new()
	_crosshair_preview.custom_minimum_size=Vector2(235,170)
	_crosshair_preview.draw.connect(func():
		var rect := Rect2(Vector2.ZERO,_crosshair_preview.size)
		_crosshair_preview.draw_style_box(UIKit.box(Color(0.13,0.23,0.22),3),rect)
		var center := rect.get_center()
		var color := Color(Settings.crosshair_color,Settings.crosshair_opacity)
		var scale := Settings.crosshair_size
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			_crosshair_preview.draw_line(center+direction*8*scale,center+direction*17*scale,color,2)
		_crosshair_preview.draw_circle(center,1.5*scale,color))
	column.add_child(_crosshair_preview)
	var saved := _label("Saved as you go.",16,Color(0.36,0.40,0.31))
	column.add_child(saved)

func _tab_help(index: int) -> void:
	var notes := [
		["Make it yours","Tune movement and aim, then scroll down to change bindings. Mouse and controller controls can be set independently."],
		["Steady hands","Turn down extra motion and damage flashes to keep the action comfortable. Weapon behaviour stays consistent."],
		["A clear sightline","Choose a colour and size that stand out against the world. The preview below updates as you adjust your crosshair."],
		["Listen closely","Balance effects, music and character voices. Voice chat is not available yet."],
		["Set the scene","Adjust your view and performance. Window and resolution changes give you fifteen seconds to confirm before reverting."],
	]
	_help_title.text=notes[index][0]
	_help_text.text=notes[index][1]
	_crosshair_preview.visible=index==2

func _setting_help(title: String) -> void:
	var tips := {
		"Mouse sensitivity":"How quickly the view turns with your mouse.",
		"Aim sensitivity multiplier":"Fine-tune turning speed while aiming down sights. Regular mouse sensitivity stays the same.",
		"Controller dead zone":"Ignore small stick movements to reduce drift.",
		"Toggle aim":"Aim once to raise your weapon; aim again to lower it. Turn off to hold the button instead.",
		"Toggle crouch":"Crouch once to stay low; crouch again to stand. Turn off for hold-to-crouch.",
		"Crosshair colour":"Click the colour swatch to choose a colour. Check its contrast in the live preview.",
		"Crosshair size":"Adjust the size of the crosshair without changing weapon spread.",
		"Crosshair opacity":"Make the crosshair more solid or more transparent.",
		"Field of view":"A wider view shows more of your surroundings. Aiming still uses the weapon's zoom.",
		"Window resolution":"Applies in windowed mode. Fullscreen uses your display resolution.",
		"VSync":"Synchronise frames with the display to reduce tearing.",
	}
	if tips.has(title):
		_help_title.text=title
		_help_text.text=tips[title]
