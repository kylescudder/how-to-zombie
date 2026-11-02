extends RefCounted
## The catalog holds together: every model meshes, faces the way it drives and fits where the game puts it.
##   tools/godot --headless -- --solo --test=vehicles
func run(test: Node) -> void:
	test.check(VehicleCatalog.TYPES.size()==12,"twelve vehicle types")
	var names := {}
	var shapes := {}
	for kind: Dictionary in VehicleCatalog.TYPES:
		test.check(kind.models.size()==10,"%s has ten models"%kind.label)
	for id in VehicleCatalog.ids():
		var data := VehicleCatalog.find(id)
		var kit := VehicleKit.new(data)
		kit._assemble()
		test.check(not kit.f.broken and kit.lower.size()>=8,"%s body meshes"%id)
		names[data.name]=true
		shapes["%s|%s|%s|%s"%[data.len,data.roof,data.lamp,",".join(PackedStringArray(data.fit))]]=true
		var holder := Node3D.new()
		test.add_child(holder)
		var mesh := VehicleKit.build(holder,id)
		test.check(mesh.get_aabb().size.y>=data.roof,"%s stands to full height"%id)
		holder.queue_free()
	test.check(names.size()==120,"every model has its own name")
	test.check(shapes.size()==120,"no two models share a silhouette recipe")
	for id: String in VehicleCatalog.STREET_MODELS:
		var data := VehicleCatalog.find(id)
		test.check(data.len<=4.5 and data.wid<=1.95 and data.roof<=1.55,"%s fits a parking space"%id)
	test.check(VehicleCatalog.CAMP_MODELS.size()==OpenWorld.ISLANDS.size(),"one car per island camp")
	for id: String in VehicleCatalog.PICKS+VehicleCatalog.CAMP_MODELS+[VehicleCatalog.POLICE_MODEL]:
		test.check(not VehicleCatalog.find(id).is_empty(),"%s is a real model"%id)
	# TeamVehicle drives towards -Z, so the nose has to lead that way.
	var kit := VehicleKit.new(VehicleCatalog.find("estate_03"))
	test.check(kit.z(0)<kit.z(kit.L),"nose sits at -Z")
