extends RefCounted
## The catalog holds together: every look meshes, every infected kind has looks, and the head sits where the hit capsule expects.
##   tools/godot --headless -- --solo --test=zombies
func run(test: Node) -> void:
	test.check(ZombieCatalog.TYPES.size()==12,"twelve infected types")
	for kind: Dictionary in ZombieCatalog.TYPES:
		test.check(kind.models.size()==10,"%s has ten models"%kind.label)
	var names := {}
	var recipes := {}
	for id in ZombieCatalog.ids():
		var data := ZombieCatalog.find(id)
		names[data.name]=true
		recipes["%s|%s|%s|%s|%s|%s|%s|%s"%[data.kind,data.top,data.pattern,data.hair,data.hat,data.legwear,data.shirt.to_html(),",".join(PackedStringArray(data.fit))]]=true
		var model := CharacterModel.new()
		test.add_child(model)
		model.setup_infected(data.kind,0,id)
		var parts := 0
		for node: Node3D in [model.torso,model.head,model.arm_l,model.arm_r,model.elbow_l,model.elbow_r,model.leg_l,model.leg_r,model.knee_l,model.knee_r]+model._eyes:
			if (node as MeshInstance3D).mesh.get_surface_count()>0: parts += 1
		test.check(parts==12,"%s builds every part (%d of 12)"%[id,parts])
		if data.kind=="common":
			var top: float = model.head.global_position.y+0.64*model.head.scale.y
			test.check(top>1.9 and top<2.35,"%s keeps its head in the hit capsule (%.2f)"%[id,top])
		model.queue_free()
	test.check(names.size()==120,"every look has its own name")
	test.check(recipes.size()==120,"no two looks share a recipe")
	for kind: String in DB.INFECTED:
		test.check(ZombieCatalog.KINDS.has(kind),"%s has looks"%kind)
		test.check(ZombieCatalog.find(ZombieCatalog.pick(kind,12345)).kind==kind,"%s picks its own looks"%kind)
	var seen := {}
	for s in 400: seen[ZombieCatalog.pick("common",s)]=true
	test.check(seen.size()>=50,"a horde draws on most of the commons (%d of 60)"%seen.size())
	for id: String in ZombieCatalog.PICKS:
		test.check(not ZombieCatalog.find(id).is_empty(),"%s is a real look"%id)
	# Hangs on the rig that the death clips pose.
	var probe := CharacterModel.new()
	test.add_child(probe)
	probe.setup_infected("common",7)
	test.check(probe.knee_l.get_parent()==probe.leg_l and probe.elbow_r.get_parent()==probe.arm_r,"limbs bend at knee and elbow")
	test.check(probe.mouth!=null and probe.hand_r!=null,"mouth and hand anchors exist")
	probe.queue_free()
