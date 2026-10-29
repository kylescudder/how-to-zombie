class_name MainMenu
extends CanvasLayer
## Title screen: campaign + difficulty, solo with bots, Steam friends hosting, LAN host/join.

var status_label: Label
var name_edit: LineEdit
var ip_edit: LineEdit
var chapter_pick: OptionButton
var diff_pick: OptionButton
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
	// Night sky, a red moon, and a city skyline of blocks with the odd lit window.
	vec3 sky = mix(vec3(0.16, 0.04, 0.05), vec3(0.02, 0.02, 0.05), smoothstep(0.75, 0.0, uv.y));
	float moon = smoothstep(0.09, 0.085, distance(uv * vec2(1.8, 1.0), vec2(1.32, 0.28)));
	vec3 c = mix(sky, vec3(0.85, 0.3, 0.2), moon);
	float bx = floor(uv.x * 22.0);
	float h = 0.55 + fract(sin(bx * 12.9898) * 43758.5453) * 0.25;
	float building = step(h, uv.y);
	vec2 win = fract(vec2(uv.x * 22.0 * 4.0, uv.y * 40.0));
	float lit = step(0.93, fract(sin(dot(floor(vec2(uv.x * 88.0, uv.y * 40.0)), vec2(12.9898, 78.233))) * 43758.5453));
	float flicker = 0.7 + 0.3 * sin(TIME * 3.0 + bx);
	vec3 bc = vec3(0.03, 0.03, 0.04) + vec3(0.9, 0.6, 0.25) * lit * step(0.3, win.x) * step(0.3, win.y) * flicker;
	c = mix(c, bc, building);
	c += vec3(0.25, 0.05, 0.03) * smoothstep(0.5, 1.0, uv.y) * (0.5 + 0.5 * sin(TIME * 0.7));
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

	var title := UIKit.label("HOW TO ZOMBIE", 92, Color(0.85, 0.15, 0.1))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	var sub := UIKit.label("4 survivors. 5 islands. One open world.  %s" % DB.CAMPAIGN_NAME, 22, Color(1, 1, 1, 0.9))
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

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	opts.add_child(UIKit.label("World", 20))
	chapter_pick = OptionButton.new()
	chapter_pick.add_item("Dead Low Tide — Archipelago", 0)
	chapter_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts.add_child(chapter_pick)
	opts.add_child(UIKit.label("Difficulty", 20))
	diff_pick = OptionButton.new()
	for i in DB.DIFFICULTIES.size():
		diff_pick.add_item(DB.DIFFICULTIES[i].name, i)
	diff_pick.select(1)
	opts.add_child(diff_pick)
	v.add_child(opts)

	v.add_child(UIKit.button("Play Solo (with bots)", func():
		_prep_host()
		Net.start_solo(), 28))
	var steam_btn := UIKit.button("Host Steam Game (friends can join)", func():
		_prep_host()
		Net.host_steam(), 26)
	steam_btn.disabled = not SteamService.available
	v.add_child(steam_btn)
	var hint := UIKit.label("Friends join via your Steam profile > Join Game, or invite them from the pause menu. They take over a bot.", 15, Color(0.8, 0.85, 0.9))
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
	v.add_child(UIKit.button("Settings", func(): add_child(SettingsPanel.new()), 20))
	v.add_child(UIKit.button("Quit", func(): get_tree().quit(), 20))

	status_label = UIKit.label("", 20, UIKit.GOLD)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(status_label)

	Net.status.connect(func(t): status_label.text = t)


func show_menu(reason := "") -> void:
	visible = true
	status_label.text = reason
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _save_name() -> void:
	var n := name_edit.text.strip_edges()
	if n != "":
		Settings.player_name = n
		Settings.save_settings()


func _prep_host() -> void:
	_save_name()
	Game.open_world = true
	Game.reset(0)
	Game.difficulty = diff_pick.get_selected_id()


func _prep_client() -> void:
	_save_name()
	Game.reset()
