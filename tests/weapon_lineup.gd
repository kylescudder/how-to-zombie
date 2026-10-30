extends RefCounted
func run(test: Node) -> void:
	AudioServer.set_bus_mute(0,true)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(960,600)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	test.add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.09,0.13,0.15)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(0.8,0.86,0.92)
	environment.environment.ambient_light_energy=0.7
	root.add_child(environment)
	for pos in [Vector3(2,3,1),Vector3(-2,1,-2)]:
		var light := DirectionalLight3D.new()
		root.add_child(light)
		light.position=pos
		light.look_at(Vector3.ZERO)
		light.light_energy=1.6
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.01
	root.add_child(camera)
	camera.current=true
	for id: String in DB.GUN_PROFILES:
		var gun := GunModels.make(id)
		root.add_child(gun)
		var bounds := AABB()
		var first := true
		for item: MeshInstance3D in gun.find_children("*","MeshInstance3D",true,false):
			var box := item.global_transform*item.get_aabb()
			if first: bounds=box; first=false
			else: bounds=bounds.merge(box)
		var center := bounds.get_center()
		camera.size=maxf(maxf(bounds.size.x,bounds.size.z)*1.1,bounds.size.y*2.8)
		camera.global_position=center+Vector3(1,0.42,0.65)*2
		camera.look_at(center)
		await test.wait(0.12)
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://screenshots/weapon-lineup/%s.png"%id)
		var result := viewport.get_texture().get_image().save_png(path)
		test.check(result==OK,"captured current %s model"%id)
		gun.queue_free()
		await test.wait(0.05)
	viewport.queue_free()
