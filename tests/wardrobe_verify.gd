extends RefCounted
func run(test: Node) -> void:
	AudioServer.set_bus_mute(0,true)
	if not FileAccess.file_exists("res://scripts/data/cosmetic_catalog.gd"):
		test.check(false,"appearance catalogue exists")
		return
	var catalog = load("res://scripts/data/cosmetic_catalog.gd")
	for part in ["hair","hair_colour","brows","eyes","nose","mouth","facial_hair"]:
		test.check(catalog.OPTIONS[part].size()==8,"eight choices for %s"%part)
	var profile = Wardrobe.get_script().new()
	profile.storage_path="res://screenshots/wardrobe/profile-test.cfg"
	var chosen: Dictionary = catalog.defaults()
	chosen.hair=6
	chosen.hair_colour=4
	chosen.glasses=1
	test.check(not profile.equip(chosen),"locked clothing cannot be equipped")
	profile.add_xp(50)
	test.check(profile.equip(chosen),"earned XP unlocks and equips a cosmetic")
	var restored = Wardrobe.get_script().new()
	restored.storage_path=profile.storage_path
	restored.load_profile()
	test.check(restored.xp==50 and restored.equipped==chosen,"appearance and earned unlocks survive loading a new profile")
	var bad: Dictionary = catalog.normalise({"hair":999,"eyes":"wrong","glasses":7,"unknown":42},0)
	test.check(bad.hair==7 and bad.eyes==0 and bad.glasses==0 and not bad.has("unknown"),"invalid profile fields and locked items are normalised")
	profile.free()
	restored.free()
	# Inspect actual generated geometry, not the selection metadata.
	for part: String in catalog.OPTIONS:
		var fingerprints := {}
		for index in 8:
			var actor := CharacterModel.new()
			test.add_child(actor)
			var look: Dictionary = catalog.defaults()
			look[part]=index
			actor.setup_custom(look)
			var values: Array = []
			for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
				values.append([mesh.transform,mesh.mesh.get_aabb(),mesh.material_override.albedo_color])
			fingerprints[str(values).sha256_text()]=true
			actor.free()
		await test.wait(0.01)
		test.check(fingerprints.size()==8,"all eight %s choices create visibly distinct model data"%part)
	var old_xp: int=Wardrobe.xp
	var old_look: Dictionary=Wardrobe.equipped.duplicate()
	var menu: MainMenu=test.get_tree().current_scene.menu
	for button: Button in menu.find_children("*","Button",true,false):
		if button.text=="Customise": button.pressed.emit()
	for button: Button in menu.find_children("*","Button",true,false):
		if button.text=="Character & wardrobe": button.pressed.emit()
	var editor := test.get_tree().get_first_node_in_group("character_editor") as CharacterEditor
	test.check(editor!=null,"Customise opens the actual character editor")
	if not editor: return
	await test.wait(0.1)
	editor.choose_category("glasses")
	editor.select_option(3)
	test.check(editor.equip_button.disabled and editor.actor.get_meta("appearance").glasses==3,"locked choice previews on the real model while equip stays disabled")
	editor.draft=catalog.defaults()
	editor.choose_category("hair")
	editor.select_option(7)
	editor.apply()
	test.check(Wardrobe.equipped.hair==7,"editor applies a free face choice")
	Wardrobe.xp=old_xp
	Wardrobe.equipped=old_look
	Wardrobe.save_profile()
	if DisplayServer.get_name()!="headless":
		editor.draft=catalog.defaults()
		editor.draft.hair=2
		editor.draft.hair_colour=3
		editor.draft.brows=4
		editor.draft.facial_hair=7
		editor.choose_category("hair")
		await test.wait(0.2)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/wardrobe/01-face-editor.png"))
		editor.draft.outfits=2
		editor.draft.glasses=3
		editor.draft.earrings=4
		editor.draft.watches=3
		editor.draft.necklaces=1
		editor.choose_category("outfits")
		await test.wait(0.2)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/wardrobe/02-locked-outfit.png"))
		DisplayServer.window_set_size(Vector2i(1280,720))
		await test.wait(0.2)
		await test._shot(ProjectSettings.globalize_path("res://screenshots/wardrobe/03-editor-720p.png"))
		# Native model atlas: one image for every option in each requested category.
		for part: String in catalog.OPTIONS:
			editor.draft=catalog.defaults()
			editor.choose_category(part)
			for index in 8:
				editor.select_option(index)
				await test.wait(0.025)
				await RenderingServer.frame_post_draw
				editor.preview.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/wardrobe/%s-%d.png"%[part,index]))
	editor.finish()
