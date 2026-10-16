class_name MainMenu
extends CanvasLayer
## Title screen: solo, Steam friends hosting, LAN host/join.

var status_label: Label
var name_edit: LineEdit
var ip_edit: LineEdit
var continue_check: CheckBox
var _bg: ColorRect
var _t := 0.0


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	add_child(root)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float w = sin(uv.x * 12.0 + TIME * 1.5) * 0.015 + sin(uv.x * 31.0 - TIME * 2.3) * 0.006;
	vec3 sky = mix(vec3(0.98, 0.62, 0.45), vec3(0.3, 0.45, 0.85), smoothstep(0.65, 0.0, uv.y));
	vec3 sea = mix(vec3(0.15, 0.45, 0.5), vec3(0.05, 0.18, 0.25), (uv.y - 0.62) * 2.5);
	float horizon = step(0.62 + w, uv.y);
	vec3 c = mix(sky, sea, horizon);
	float sun = smoothstep(0.13, 0.12, distance(uv * vec2(1.8, 1.0), vec2(1.35, 0.55)));
	c = mix(c, vec3(1.0, 0.9, 0.6), sun * (1.0 - horizon));
	float hand = step(0.6, uv.y) * (1.0 - step(0.66, uv.y)) * step(abs(uv.x - 0.22 + sin(TIME) * 0.01), 0.012);
	c = mix(c, vec3(0.45, 0.65, 0.35), hand);
	COLOR = vec4(c, 1.0);
}
"""
	_bg.material = sm
	root.add_child(_bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-330, -380)
	center.custom_minimum_size = Vector2(660, 0)
	center.add_theme_constant_override("separation", 10)
	root.add_child(center)

	var title := UIKit.label("HOW TO ZOMBIE", 92, Color(0.6, 0.95, 0.35))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.2, 0.05))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	var sub := UIKit.label("fish them up. beat them down. sell them to Doc.", 22, Color(1, 1, 1, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var steam_txt := "Steam: logged in as %s" % SteamService.persona_name if SteamService.available else "Steam unavailable: %s" % SteamService.init_error
	var sl := UIKit.label(steam_txt, 16, UIKit.ACCENT if SteamService.available else Color(0.9, 0.7, 0.5))
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)

	var name_row := HBoxContainer.new()
	name_row.add_child(UIKit.label("Name", 20))
	name_edit = LineEdit.new()
	name_edit.text = Settings.player_name
	name_edit.max_length = 24
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.editable = not SteamService.available
	name_row.add_child(name_edit)
	v.add_child(name_row)

	continue_check = CheckBox.new()
	continue_check.text = "Continue saved island (when hosting)"
	continue_check.button_pressed = Game.has_save()
	continue_check.disabled = not Game.has_save()
	v.add_child(continue_check)

	v.add_child(UIKit.button("Play Solo", func():
		_prep_host()
		Net.start_solo(), 28))
	var steam_btn := UIKit.button("Host Steam Game (friends can join)", func():
		_prep_host()
		Net.host_steam(), 26)
	steam_btn.disabled = not SteamService.available
	v.add_child(steam_btn)
	var hint := UIKit.label("Friends join via your Steam profile > Join Game, or invite them from the pause menu.", 15, Color(0.8, 0.85, 0.9))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)

	var lan := HBoxContainer.new()
	lan.add_theme_constant_override("separation", 8)
	lan.add_child(UIKit.button("Host LAN", func():
		_prep_host()
		Net.host_enet(), 20))
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan.add_child(ip_edit)
	lan.add_child(UIKit.button("Join LAN", func():
		_prep_client()
		Net.join_enet(ip_edit.text.strip_edges()), 20))
	v.add_child(lan)
	v.add_child(UIKit.button("Quit", func(): get_tree().quit(), 20))

	status_label = UIKit.label("", 20, UIKit.GOLD)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(status_label)

	Net.status.connect(func(t): status_label.text = t)


func show_menu(reason := "") -> void:
	visible = true
	status_label.text = reason
	continue_check.disabled = not Game.has_save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _save_name() -> void:
	var n := name_edit.text.strip_edges()
	if n != "":
		Settings.player_name = n
		Settings.save_settings()


func _prep_host() -> void:
	_save_name()
	Game.reset()
	if continue_check.button_pressed:
		Game.load_game()


func _prep_client() -> void:
	_save_name()
	Game.reset()
