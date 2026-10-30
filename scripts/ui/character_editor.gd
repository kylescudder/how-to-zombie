class_name CharacterEditor
extends CanvasLayer
## Draft changes stay in the preview; only an owned look can be equipped.
signal closed
var draft := {}
var category := "hair"
var choices: VBoxContainer
var info: Label
var progress: Label
var equip_button: Button
var preview: SubViewport
var camera: Camera3D
var actor: CharacterModel
var stage: Node3D
var _angle := 0.0
var _dragging := false
var _face_view := true
var _detail_view := false
var _design: Control
var _saved := false
const PAPER := Color(0.91,0.87,0.76)
const INK := Color(0.12,0.18,0.17)
const GOLD := Color(0.78,0.65,0.39)

func _ready() -> void:
	layer=110
	add_to_group("character_editor")
	draft=Wardrobe.equipped.duplicate()
	var bg := ColorRect.new()
	bg.color=Color(0.065,0.11,0.105,0.99)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_design=Control.new()
	_design.theme=get_tree().current_scene.menu._theme()
	add_child(_design)
	_design.add_child(_label("Make yourself at home.",Vector2(55,35),38))
	progress=_label("",Vector2(820,50),20)
	_design.add_child(progress)
	var done := _button("Done",finish)
	done.position=Vector2(1370,35)
	done.size=Vector2(170,50)
	_design.add_child(done)
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(45,115)
	scroll.size=Vector2(250,650)
	_design.add_child(scroll)
	var parts := VBoxContainer.new()
	parts.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parts.add_theme_constant_override("separation",7)
	scroll.add_child(parts)
	for part: String in CosmeticCatalog.OPTIONS:
		if part in ["hair","earrings","tshirts"]:
			var label := Label.new()
			label.text={"hair":"FACE","earrings":"ACCESSORIES","tshirts":"CLOTHING"}[part]
			label.add_theme_color_override("font_color",GOLD)
			label.add_theme_font_size_override("font_size",15)
			parts.add_child(label)
		var button := _button(_title(part),func(): choose_category(part))
		button.set_meta("category",part)
		parts.add_child(button)
	var container := SubViewportContainer.new()
	container.position=Vector2(320,120)
	container.size=Vector2(600,640)
	container.stretch=true
	_design.add_child(container)
	preview=SubViewport.new()
	preview.size=Vector2i(600,640)
	preview.own_world_3d=true
	preview.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.add_child(preview)
	stage=Node3D.new()
	preview.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("233a38")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(0.85,0.89,0.92)
	environment.environment.ambient_light_energy=0.65
	stage.add_child(environment)
	for pos in [Vector3(3,4,4),Vector3(-3,2,-2)]:
		var light := DirectionalLight3D.new()
		stage.add_child(light)
		light.position=pos
		light.look_at(Vector3(0,1,0))
		light.light_energy=1.3
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.02
	stage.add_child(camera)
	camera.current=true
	container.gui_input.connect(_preview_input)
	var controls := HBoxContainer.new()
	controls.position=Vector2(330,775)
	controls.size=Vector2(580,45)
	controls.add_theme_constant_override("separation",12)
	_design.add_child(controls)
	controls.add_child(_button("↶",func(): _angle-=0.45))
	controls.add_child(_button("Face",func(): _face_view=true; _detail_view=false; _frame()))
	controls.add_child(_button("Full body",func(): _face_view=false; _detail_view=false; _frame()))
	controls.add_child(_button("↷",func(): _angle+=0.45))
	choices=VBoxContainer.new()
	choices.position=Vector2(965,120)
	choices.custom_minimum_size=Vector2(575,0)
	choices.add_theme_constant_override("separation",10)
	_design.add_child(choices)
	info=_label("",Vector2(965,665),18)
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	info.size=Vector2(575,70)
	_design.add_child(info)
	equip_button=_button("Wear this look",apply)
	equip_button.position=Vector2(965,755)
	equip_button.size=Vector2(575,58)
	_design.add_child(equip_button)
	var cancel := _button("Reset to equipped",func(): draft=Wardrobe.equipped.duplicate(); refresh())
	cancel.position=Vector2(965,825)
	cancel.size=Vector2(575,45)
	_design.add_child(cancel)
	_design.add_child(_label("Cosmetics only • Common 5 XP / Special 25 / Revive 40 / Escape 250",Vector2(45,852),16))
	Wardrobe.changed.connect(refresh)
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _title(part: String) -> String:
	return {"hair_colour":"Hair colour","facial_hair":"Facial hair","skin":"Skin tone","tshirts":"T-shirts","outfits":"Full outfits"}.get(part,part.capitalize())

func _label(text: String, pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text=text
	label.position=pos
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",PAPER)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text=text
	button.custom_minimum_size.y=42
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",18)
	button.pressed.connect(callback)
	return button

func choose_category(part: String) -> void:
	category=part
	_face_view=part in CosmeticCatalog.FACE or part in ["earrings","glasses"]
	_detail_view=part in ["watches","necklaces","shoes"]
	refresh()

func select_option(index: int) -> void:
	draft[category]=index
	_saved=false
	refresh()

func refresh() -> void:
	if not is_instance_valid(choices): return
	for child in choices.get_children(): choices.remove_child(child); child.queue_free()
	var title := Label.new()
	title.text=_title(category)
	title.add_theme_font_size_override("font_size",28)
	choices.add_child(title)
	for index in 8:
		var owned := CosmeticCatalog.unlocked(category,index,Wardrobe.xp)
		var text: String=CosmeticCatalog.OPTIONS[category][index]
		if not owned: text+="  ·  %d XP"%CosmeticCatalog.requirement(category,index)
		elif draft[category]==index: text+="  ✓"
		var button := _button(text,func(): select_option(index))
		button.set_meta("option",index)
		if draft[category]==index: button.add_theme_stylebox_override("normal",UIKit.box(Color("57664d"),4,1,GOLD))
		if not owned: button.add_theme_color_override("font_color",Color("929f8d"))
		choices.add_child(button)
	progress.text="%d wardrobe XP · earn clothing by playing"%Wardrobe.xp
	var safe := CosmeticCatalog.normalise(draft,Wardrobe.xp)
	var can_equip := safe==draft
	equip_button.disabled=not can_equip
	info.text="Face choices are free. Clothing unlocks automatically with wardrobe XP."
	if not can_equip: info.text="Preview only. Earn the required XP before wearing locked items."
	elif draft.outfits>0: info.text="Full outfit replaces clothing pieces. Your separate selections are kept."
	if _saved and can_equip and draft==Wardrobe.equipped: info.text="Look saved. Ready for your next game."
	if actor:
		stage.remove_child(actor)
		actor.queue_free()
	actor=CharacterModel.new()
	stage.add_child(actor)
	actor.setup_custom(draft)
	actor._time=1.0  # Start portrait previews between blinks.
	_frame()

func _frame() -> void:
	if not actor: return
	camera.size=1.08 if _face_view else 2.8
	var target := Vector3(0,1.95 if _face_view else 1.05,0)
	if _detail_view:
		camera.size=0.72 if category!="necklaces" else 1.0
		target=actor.global_transform*{"watches":Vector3(-0.36,0.88,0.16),"necklaces":Vector3(0,1.28,0.23),"shoes":Vector3(0,0.14,0.10)}[category]
	camera.position=target+Vector3(0,0.08,4)
	camera.look_at(target)

func _process(delta: float) -> void:
	if actor:
		actor.animate(delta,0,0,"idle")
		actor.rotation.y=_angle
		if _detail_view: _frame()

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: _dragging=event.pressed
	if event is InputEventMouseMotion and _dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT: _angle+=event.relative.x*0.01

func apply() -> void:
	if Wardrobe.equip(draft):
		_saved=true
		refresh()
	else: info.text="That look could not be saved. Check unlocks and try again."

func finish() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()

func _layout() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	var factor := minf(dimensions.x/1600.0,dimensions.y/900.0)
	_design.scale=Vector2.ONE*factor
	_design.position=(dimensions-Vector2(1600,900)*factor)*0.5
