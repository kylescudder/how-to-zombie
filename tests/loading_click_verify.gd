extends RefCounted
## --test=loading_click (windowed): the path players take. Clicks Start solo from the menu and
## checks what is actually on screen at the moment the blocking level build starts.
var _draws := 0
var _shot: Image


func _count_draw() -> void:
	_draws += 1


func _capture(_level: Node) -> void:
	if _shot == null:
		_shot = _viewport.get_texture().get_image()
		_draws_at_build = _draws


var _viewport: Viewport
var _draws_at_build := -1


## Real mouse events, so the press lands where a player's does in the frame.
func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)


func run(test: Node) -> void:
	var main: Node = test.get_tree().current_scene
	_viewport = test.get_viewport()
	await test.wait(1.0)
	RenderingServer.frame_post_draw.connect(_count_draw)
	main.world.child_entered_tree.connect(_capture)
	for button: Button in main.menu.find_children("*","Button",true,false):
		if button.text=="Host Game": button.pressed.emit()
	await test.wait(0.3)
	_draws = 0
	for button: Button in main.menu.find_children("*","Button",true,false):
		if button.text=="Start solo": _click(button.get_global_rect().get_center())
	test.check(await test.wait_for(func(): return main.loading.active,5.0),"clicking Start solo brings the loading screen up")
	test.check(await test.wait_for(func(): return not main.loading.active,20.0),"loading finishes")
	RenderingServer.frame_post_draw.disconnect(_count_draw)
	test.check(_draws_at_build>=1,"loading screen reached the display before the level build began (%d frames)"%_draws_at_build)
	if _shot:
		_shot.save_png(ProjectSettings.globalize_path("res://screenshots/loading/at-build-start.png"))
		var corner := _shot.get_pixel(_shot.get_width()-20,20)
		test.check(corner.to_html(false).substr(0,2)==LoadingScreen.INK.to_html(false).substr(0,2),"screen shows the loading card when the build starts (%s)"%corner)
