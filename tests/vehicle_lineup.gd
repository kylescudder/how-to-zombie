extends RefCounted
## Renders every catalog vehicle from the runtime builder, front and rear, into cards and per-type sheets.
##   tools/godot --fixed-fps 20 -- --solo --test=vehicle_lineup    (needs a window; writes screenshots/vehicles/)
const CARD := Vector2i(640,400)
const THUMB := Vector2i(176,110)
const COLUMNS := 5

func run(test: Node) -> void:
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/vehicles/cards"))
	var viewport := SubViewport.new()
	viewport.size=CARD
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_8X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	test.add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.60,0.74,0.73)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(0.78,0.84,0.92)
	environment.environment.ambient_light_energy=0.62
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.rotation_degrees=Vector3(-52,28,0)
	sun.light_color=Color(1,0.94,0.82)
	sun.light_energy=1.5
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=120
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	var fill := DirectionalLight3D.new()
	root.add_child(fill)
	fill.rotation_degrees=Vector3(-20,200,0)
	fill.light_energy=0.45
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size=Vector2(160,160)
	ground.mesh=plane
	var surface := Build.paint
	Build.paint="none"
	ground.material_override=Build.mat(Color(0.46,0.47,0.45))
	Build.paint=surface
	root.add_child(ground)
	var camera := Camera3D.new()
	camera.fov=22
	camera.near=0.5
	camera.far=300
	root.add_child(camera)
	camera.current=true
	var name_label := _caption(viewport,18,Vector2(14,10))
	var type_label := _caption(viewport,13,Vector2(14,36))
	var star := _caption(viewport,14,Vector2(14,56))
	for kind: Dictionary in VehicleCatalog.TYPES:
		var sheet := Image.create(CARD.x*COLUMNS,CARD.y*2,false,Image.FORMAT_RGB8)
		for index in kind.models.size():
			var id := "%s_%02d" % [kind.id,index+1]
			var data := VehicleCatalog.find(id)
			var holder := Node3D.new()
			root.add_child(holder)
			var mesh := VehicleKit.build(holder,id)
			var bounds := mesh.get_aabb()
			var center := bounds.get_center()
			var reach := maxf(bounds.size.z*0.92,bounds.size.y*1.5)
			var dist := reach/(2*tan(deg_to_rad(camera.fov*0.5)))*1.12
			camera.v_offset=reach*0.05
			name_label.text=""
			type_label.text=""
			star.text=""
			camera.global_position=center+Vector3(-0.72,0.3,1).normalized()*dist
			camera.look_at(center)
			await test.wait(0.06)
			await RenderingServer.frame_post_draw
			var rear := viewport.get_texture().get_image()
			rear.convert(Image.FORMAT_RGB8)
			rear.resize(THUMB.x,THUMB.y,Image.INTERPOLATE_LANCZOS)
			name_label.text="%02d  %s" % [index+1,data.name]
			type_label.text="%s  ·  %.1f m  ·  %s" % [data.type,data.len,id]
			star.text="★ Recommended" if id in VehicleCatalog.PICKS else ""
			camera.global_position=center+Vector3(0.72,0.3,-1).normalized()*dist
			camera.look_at(center)
			await test.wait(0.06)
			await RenderingServer.frame_post_draw
			var card := viewport.get_texture().get_image()
			card.convert(Image.FORMAT_RGB8)
			var frame := Image.create(THUMB.x+4,THUMB.y+4,false,Image.FORMAT_RGB8)
			frame.fill(Color(0.95,0.93,0.86))
			card.blit_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),Vector2i(CARD.x-frame.get_size().x-10,10))
			card.blit_rect(rear,Rect2i(Vector2i.ZERO,THUMB),Vector2i(CARD.x-THUMB.x-12,12))
			var saved := card.save_jpg(ProjectSettings.globalize_path("res://screenshots/vehicles/cards/%s.jpg"%id),0.9)
			test.check(saved==OK,"captured %s"%id)
			sheet.blit_rect(card,Rect2i(Vector2i.ZERO,CARD),Vector2i(index%COLUMNS*CARD.x,index/COLUMNS*CARD.y))
			holder.queue_free()
		sheet.resize(CARD.x*COLUMNS/2,CARD.y,Image.INTERPOLATE_LANCZOS)
		sheet.save_jpg(ProjectSettings.globalize_path("res://screenshots/vehicles/%s.jpg"%kind.id),0.86)
	viewport.queue_free()

func _caption(viewport: SubViewport, size: int, pos: Vector2) -> Label:
	var label := Label.new()
	label.position=pos
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color(1,0.98,0.9))
	label.add_theme_color_override("font_outline_color",Color(0.05,0.07,0.08))
	label.add_theme_constant_override("outline_size",5)
	viewport.add_child(label)
	return label
