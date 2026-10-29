extends Node
## Same runtime models as gameplay, rendered in a neutral inspection stage.
var runner: Node
var vp: SubViewport
var stage: Node3D
var cam: Camera3D
var folder := ""

func run(test: Node) -> void:
	AudioServer.set_bus_mute(0, true)
	runner = test
	folder = ProjectSettings.globalize_path("res://screenshots/art-pass/" + ("before" if "--before" in OS.get_cmdline_user_args() else "after"))
	DirAccess.make_dir_recursive_absolute(folder)
	vp = SubViewport.new()
	vp.size = Vector2i(1200, 1000)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	stage = Node3D.new()
	vp.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.20, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.73, 0.81, 0.85)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_color = Color(1.0, 0.88, 0.71)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2, 2, 3)
	fill.light_color = Color(0.65, 0.84, 1)
	fill.light_energy = 1.8
	stage.add_child(fill)
	Build.cyl(stage, 2.2, 2.2, 0.12, Color(0.19, 0.29, 0.30), Vector3(0, -0.08, 0), Vector3.ZERO, 64)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.65
	cam.position = Vector3(3, 2.1, 5)
	stage.add_child(cam)
	cam.look_at(Vector3(0, 1.05, 0))
	var gus := CharacterModel.new()
	gus.setup_survivor(0)
	await inspect("01-survivor-gus", gus, true)
	var zombie := CharacterModel.new()
	zombie.setup_infected("common", 27)
	await inspect("02-common-infected", zombie, true)
	cam.size = 1.25
	cam.position = Vector3(1.6, 1.6, 0.7)
	cam.look_at_from_position(cam.position, Vector3(0, 1.0, -0.23))
	await inspect("03-m590-shotgun", ItemModels.make("pump_shotgun"), false)
	if "--before" not in OS.get_cmdline_user_args():
		cam.size = 7.4
		cam.position = Vector3(6,4.6,9)
		cam.look_at(Vector3(0,2.25,0))
		Build.box(stage,Vector3(12,0.12,9),Color(0.39,0.43,0.37),Vector3(0,-0.16,0))
		var kit := Node3D.new()
		StreetArt.corner(kit,Vector3.ZERO)
		await inspect("05-street-corner",kit,false)
		await gameplay()

func inspect(name: String, model: Node3D, character: bool) -> void:
	var pivot := Node3D.new()
	stage.add_child(pivot)
	pivot.add_child(model)
	if name == "03-m590-shotgun":
		pivot.position = Vector3(0,1,-0.23)
		model.position.z = 0.23
	pivot.rotation.y = -0.25
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	if "--before" not in OS.get_cmdline_user_args():
		var frames := folder.path_join("frames/" + name)
		DirAccess.make_dir_recursive_absolute(frames)
		for f in 72:
			pivot.rotation.y = -0.25 + TAU * float(f) / 72
			if character:
				(model as CharacterModel).animate(0.05, 0.0)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := vp.get_texture().get_image()
			image.resize(600, 500, Image.INTERPOLATE_LANCZOS)
			image.save_png(frames.path_join("%04d.png" % f))
		model.rotation.y = 0
		var pos := model.position
		model.position = Vector3.ZERO
		_export(model, name)
		model.position = pos
	pivot.queue_free()
	await get_tree().process_frame
	print("[ART] captured ", name)

func _export(model: Node3D, name: String) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_scene(model, state)
	runner.check(result == OK, "GLTF accepts " + name)
	if result == OK:
		var path := folder.path_join(name + ".glb")
		runner.check(document.write_to_filesystem(state, path) == OK, "exported actual model " + name)

func gameplay() -> void:
	await runner.wait_for(func(): return runner.me() != null)
	var p: Survivor = runner.me()
	var lvl: Level = runner.level()
	runner.calm()
	lvl.request_door.rpc_id(1, 0)
	var base: Vector3 = runner.ahead(30)
	runner.place(p, base)
	p.aim(PI, 0)
	p.receive_item.rpc_id(p.peer_id, "pump_shotgun", {})
	for mate: Survivor in lvl.get_survivors():
		if mate.bot:
			mate.brain = null
			runner.place(mate, base + Vector3(-4 + mate.slot*2, 0, 5))
	await runner.wait(1)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("04-in-game.png"))
	print("[ART] captured in-game")
	var camera := Camera3D.new()
	camera.fov = 52
	lvl.add_child(camera)
	camera.current = true
	camera.global_position = lvl.markers.art_corner + Vector3(-8,3.7,5)
	camera.look_at(lvl.markers.art_corner + Vector3(-0.5,1.8,0))
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	hud.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("06-street-in-game.png"))
