extends Node
## Real runtime ground meshes, followed by their placement in the generated city.
func run(runner: Node) -> void:
	AudioServer.set_bus_mute(0,true)
	var folder := "res://screenshots/ground-detail/3d/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var vp := SubViewport.new()
	vp.size = Vector2i(1400,900)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var stage := Node3D.new()
	vp.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16,0.21,0.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.80,0.87,1)
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	stage.add_child(sun)
	Build.paint = "paving"
	Build.box(stage,Vector3(5,0.18,4),Color(0.57,0.55,0.48),Vector3(0,-0.09,0))
	Build.paint = ""
	var detail := GroundDetail.new()
	detail.add("broken_paving",Vector3.ZERO,1.5,0.4)
	for i in 7:
		detail.add("grass",Vector3(-1.5+i*0.48,0,-0.95),1.0+(i%3)*0.3,i*1.3)
	for i in 5:
		detail.add("stone",Vector3(-1.2+i*0.55,0,0.9),0.7+i*0.15,i)
	detail.flush(stage)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.position = Vector3(3.2,2.4,4.3)
	cam.fov = 48
	cam.look_at(Vector3(0,0.1,0))
	for i in 5:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	runner.check(vp.get_texture().get_image().save_png(folder+"01-runtime-meshes.png") == OK,"captured ground meshes")
	vp.queue_free()
	var level: Level = runner.level()
	runner.calm()
	var city_cam := Camera3D.new()
	level.add_child(city_cam)
	city_cam.current = true
	var block: Vector3 = level.markers.city_blocks[0]
	city_cam.position = block + Vector3(-11,1.4,29)
	city_cam.look_at(block + Vector3(-14,0.18,25))
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	hud.visible = false
	await runner.wait(0.3)
	await RenderingServer.frame_post_draw
	runner.check(get_viewport().get_texture().get_image().save_png(folder+"02-city-kerb.png") == OK,"captured actual city kerb")
