extends RefCounted
func _check_nose(test: Node, actor: CharacterModel, label: String) -> void:
	var nose := actor.head.get_node("Nose") as MeshInstance3D
	var nostrils := nose.find_children("Nostril*","MeshInstance3D",false,false)
	var touching := nostrils.size()==2
	for marker: MeshInstance3D in nostrils:
		if absf(marker.position.length()-0.5)>0.05: touching=false
	test.check(touching,"nostrils sit on the nose surface for %s"%label)
	var initial: Array[Vector3] = []
	for marker: MeshInstance3D in nostrils: initial.append(nose.to_local(marker.global_position))
	nose.rotate_x(0.3)
	nose.scale*=1.2
	var following := nostrils.size()==2
	for index in nostrils.size():
		if not nose.to_local(nostrils[index].global_position).is_equal_approx(initial[index]): following=false
	test.check(following,"nostrils stay attached when %s tilts and scales"%label)


func run(test: Node) -> void:
	AudioServer.set_bus_mute(0,true)
	for index in 8:
		var actor := CharacterModel.new()
		test.add_child(actor)
		var look := CosmeticCatalog.defaults()
		look.nose=index
		actor.setup_custom(look)
		_check_nose(test,actor,CosmeticCatalog.OPTIONS.nose[index])
		actor.free()
	var survivor := CharacterModel.new()
	test.add_child(survivor)
	survivor.setup_survivor(0)
	_check_nose(test,survivor,"preset survivor")
	survivor.free()
	var npc := CharacterModel.new()
	test.add_child(npc)
	npc.setup_npc(Color("c98f6b"),Color("566b55"),Color("3c4048"),"cap",Color("3d2c22"))
	_check_nose(test,npc,"story NPC")
	npc.free()
	if DisplayServer.get_name()!="headless":
		var editor := CharacterEditor.new()
		test.get_tree().current_scene.menu.add_child(editor)
		await test.wait(0.1)
		editor.choose_category("nose")
		editor._angle=PI*0.5
		var folder := "before" if "--before" in OS.get_cmdline_user_args() else "after"
		for index in 8:
			editor.select_option(index)
			await test.wait(0.1)
			var target: Vector3=editor.actor.head.to_global(Vector3(0,0.25,0.14))
			editor.camera.size=0.72
			editor.camera.position=target+Vector3(0,0.05,3)
			editor.camera.look_at(target)
			await RenderingServer.frame_post_draw
			editor.preview.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/nose-fix/%s/nose-%d.png"%[folder,index]))
		editor.finish()
