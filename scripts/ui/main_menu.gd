class_name MainMenu
extends CanvasLayer
## A survivor hideout with a field-notes launcher and optional multiplayer sheet.
var status_label: Label
var name_edit: LineEdit
var ip_edit: LineEdit
var diff_pick: OptionButton
var hideout: MenuHideout
var friends: PanelContainer
var host_sheet: PanelContainer
var credits_sheet: PanelContainer
var customise_sheet: PanelContainer
var _sheets: Array[PanelContainer] = []
var _design: Control
var _quip: Label
var _quip_left := 0.0
const INK := Color(0.15,0.21,0.19)
const PAPER := Color(0.91,0.87,0.76)
const GOLD := Color(0.78,0.65,0.39)

func _ready() -> void:
	layer=20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hideout=MenuHideout.new()
	hideout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(hideout)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader=Shader.new()
	material.shader.code="shader_type canvas_item; void fragment(){COLOR=vec4(vec3(0.075,0.12,0.12),1.0-smoothstep(0.22,0.65,UV.x));}"
	shade.material=material
	root.add_child(shade)
	_design=Control.new()
	_design.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_design.theme=_theme()
	root.add_child(_design)
	var menu := VBoxContainer.new()
	menu.position=Vector2(72,60)
	menu.custom_minimum_size=Vector2(465,0)
	menu.add_theme_constant_override("separation",12)
	_design.add_child(menu)
	menu.add_child(_label("DEAD LOW TIDE  /  A CO-OP MISADVENTURE",15,GOLD))
	var title := _label("HOW TO\nZOMBIE",80,PAPER)
	title.add_theme_constant_override("line_spacing",-12)
	menu.add_child(title)
	menu.add_child(_label("Four friends. Five islands. Questionable decisions.",17,PAPER))
	var gap := Control.new()
	gap.custom_minimum_size.y=15
	menu.add_child(gap)
	for entry in [
		["Host Game",func(): _show_sheet(host_sheet)],
		["Join Game",func(): _show_sheet(friends)],
		["Settings",func(): add_child(SettingsPanel.new())],
		["Quit",func(): get_tree().quit()],
		["Credits",func(): _show_sheet(credits_sheet)],
		["Customise",func(): _show_sheet(customise_sheet)],
	]:
		var button := _button(entry[0],entry[1],entry[0]=="Host Game")
		button.set_meta("main_action",true)
		menu.add_child(button)
	var steam := _label("Steam connected · invites available" if SteamService.available else "Solo & LAN ready · Steam offline",14,Color(0.69,0.76,0.66))
	menu.add_child(steam)
	status_label=_label("",16,Color(1,0.71,0.52))
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y=45
	menu.add_child(status_label)
	_quip=_label("",20,PAPER)
	_quip.position=Vector2(920,740)
	_quip.custom_minimum_size=Vector2(580,80)
	_quip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_quip.add_theme_constant_override("outline_size",4)
	_quip.add_theme_color_override("font_outline_color",INK)
	_quip.hide()
	_design.add_child(_quip)
	hideout.discovered.connect(func(message):
		_quip.text=message
		_quip_left=5.0
		_quip.show())
	_build_destinations()
	Net.status.connect(func(message): status_label.text=message)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names=PackedStringArray(["Avenir Next","DejaVu Sans","sans-serif"])
	font.font_weight=600
	theme.default_font=font
	theme.default_font_size=20
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,UIKit.box(Color(0.20,0.28,0.26,0.95),4,1,Color(0.46,0.52,0.42)))
		theme.set_stylebox("hover",type,UIKit.box(Color(0.32,0.40,0.32),4,1,GOLD))
		theme.set_stylebox("pressed",type,UIKit.box(INK,4,1,PAPER))
		theme.set_stylebox("focus",type,UIKit.box(Color(0,0,0,0),4,2,GOLD))
		theme.set_stylebox("disabled",type,UIKit.box(Color(0.18,0.23,0.22),4))
		theme.set_color("font_color",type,PAPER)
		theme.set_color("font_disabled_color",type,Color(0.48,0.53,0.49))
	theme.set_stylebox("normal","LineEdit",UIKit.box(Color(0.12,0.19,0.18),4,1,Color(0.35,0.43,0.37)))
	theme.set_color("font_color","LineEdit",PAPER)
	theme.set_color("font_uneditable_color","LineEdit",PAPER)
	theme.set_stylebox("panel","PopupMenu",UIKit.box(INK,4,1,GOLD))
	theme.set_color("font_color","PopupMenu",PAPER)
	return theme

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, action: Callable, primary := false, _hint := "") -> Button:
	var button := Button.new()
	button.text=text
	button.custom_minimum_size.y=58 if primary else 48
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",26 if primary else 21)
	if primary:
		button.add_theme_stylebox_override("normal",UIKit.box(GOLD,4))
		button.add_theme_color_override("font_color",INK)
	button.pressed.connect(func(): Sfx.play("click"); action.call())
	button.mouse_entered.connect(func():
		var tween := create_tween()
		tween.tween_property(button,"modulate",Color(1.12,1.08,0.96),0.12))
	button.mouse_exited.connect(func(): create_tween().tween_property(button,"modulate",Color.WHITE,0.16))
	return button

func _sheet(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position=Vector2(650,150)
	panel.custom_minimum_size=Vector2(820,0)
	panel.add_theme_stylebox_override("panel",UIKit.box(INK,6,1,GOLD))
	_design.add_child(panel)
	_sheets.append(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var label := _label(title,34,PAPER)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var close := _button("Close",func(): panel.hide())
	close.size_flags_horizontal=Control.SIZE_SHRINK_END
	close.custom_minimum_size.x=110
	heading.add_child(close)
	panel.hide()
	return column

func _show_sheet(panel: PanelContainer) -> void:
	for sheet in _sheets: sheet.hide()
	status_label.text=""
	panel.show()

func _build_destinations() -> void:
	var host := _sheet("Host Game")
	host_sheet=host.get_parent()
	host.add_child(_label("Choose your difficulty and how the squad connects.",18,PAPER))
	var difficulty := HBoxContainer.new()
	host.add_child(difficulty)
	difficulty.add_child(_label("Difficulty  ",18,GOLD))
	diff_pick=OptionButton.new()
	for index in DB.DIFFICULTIES.size(): diff_pick.add_item(DB.DIFFICULTIES[index].name,index)
	diff_pick.select(1)
	diff_pick.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	difficulty.add_child(diff_pick)
	host.add_child(_button("Start solo",func(): _prep_host(); Net.start_solo(),true))
	host.add_child(_label("Solo fills your squad with three bots.",16,PAPER))
	var steam := _button("Host Steam game",func(): _prep_host(); Net.host_steam())
	steam.disabled=not SteamService.available
	host.add_child(steam)
	host.add_child(_button("Host LAN",func(): _prep_host(); Net.host_enet()))
	if not SteamService.available: host.add_child(_label("Steam offline. Solo and LAN are available.",16,GOLD))

	var join := _sheet("Join Game")
	friends=join.get_parent()
	join.add_child(_label("Join a Steam friend through their profile or invite.
Already have a lobby ID? Enter it below.",18,PAPER))
	var steam_row := HBoxContainer.new()
	steam_row.add_theme_constant_override("separation",12)
	join.add_child(steam_row)
	var lobby := LineEdit.new()
	lobby.placeholder_text="Steam lobby ID"
	lobby.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	steam_row.add_child(lobby)
	var join_steam := _button("Join Steam",func():
		var value := lobby.text.strip_edges()
		if not value.is_valid_int() or value.to_int()<=0:
			status_label.text="Enter a valid Steam lobby ID."
			return
		_prep_client()
		Net.join_steam(value.to_int()))
	join_steam.disabled=not SteamService.available
	steam_row.add_child(join_steam)
	join.add_child(_label("Join over LAN",23,PAPER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	join.add_child(row)
	ip_edit=LineEdit.new()
	ip_edit.placeholder_text="Host IP address"
	ip_edit.text="127.0.0.1"
	ip_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(ip_edit)
	row.add_child(_button("Join LAN",func():
		var address := ip_edit.text.strip_edges()
		if address=="":
			status_label.text="Enter the host's IP address first."
			return
		_prep_client()
		Net.join_enet(address)))

	var credits := _sheet("Credits")
	credits_sheet=credits.get_parent()
	credits.add_child(_label("How to Zombie · Dead Low Tide",25,PAPER))
	credits.add_child(_label("Engine
Godot Engine",20,PAPER))
	credits.add_child(_label("Steam integration
GodotSteam / Steamworks",20,PAPER))
	credits.add_child(_label("Art & sound
Procedural characters, environments and weapons
Synthesised sound effects",20,PAPER))
	credits.add_child(_label("And your squad. Thanks for surviving.",20,GOLD))

	var custom := _sheet("Customise")
	customise_sheet=custom.get_parent()
	custom.add_child(_label("Your survivor, outfit and aiming reticle.",18,PAPER))
	custom.add_child(_button("Character & wardrobe",func(): add_child(CharacterEditor.new()),true))
	custom.add_child(_label("Survivor name",18,GOLD))
	name_edit=LineEdit.new()
	name_edit.text=SteamService.persona_name if SteamService.available else Settings.player_name
	name_edit.max_length=24
	name_edit.editable=not SteamService.available
	custom.add_child(name_edit)
	if SteamService.available: custom.add_child(_label("Your Steam display name is used while connected.",16,PAPER))
	custom.add_child(_button("Save name",func():
		if name_edit.text.strip_edges()=="":
			status_label.text="Enter a survivor name first."
			return
		_save_name()
		status_label.text="Survivor name saved."))
	custom.add_child(_button("Customise crosshair",func():
		var settings := SettingsPanel.new()
		add_child(settings)
		settings.tabs.current_tab=2))

func _layout() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	var factor := minf(dimensions.x/1600.0,dimensions.y/900.0)
	_design.scale=Vector2.ONE*factor
	_design.position=(dimensions-Vector2(1600,900)*factor)*0.5

func _process(delta: float) -> void:
	_quip_left=maxf(0,_quip_left-delta)
	if _quip_left<=0: _quip.hide()
	if hideout: hideout.set_active(visible)

func show_menu(reason := "") -> void:
	visible=true
	for sheet in _sheets: sheet.hide()
	_quip.hide()
	_quip_left=0
	status_label.text=reason
	hideout.set_active(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _save_name() -> void:
	var name := name_edit.text.strip_edges()
	if name!="":
		Settings.player_name=name
		Settings.save_settings()

func _prep_host() -> void:
	_save_name()
	Game.open_world=true
	Game.reset(0)
	Game.difficulty=diff_pick.get_selected_id()

func _prep_client() -> void:
	_save_name()
	Game.reset()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not get_tree().has_group("settings_panel") and event.is_action_pressed("ui_cancel"):
		for sheet in _sheets: sheet.hide()
		get_viewport().set_input_as_handled()
