class_name OpenWorld
extends RefCounted
## One deterministic 2.2 km archipelago. Flat combat terrain, curved beaches and local POIs.
const EXTENT := 1100.0
const ISLANDS := [
	{"name": "Haven Harbour", "center": Vector2(-350,-250), "radius": Vector2(270,235), "color": Color(0.39,0.56,0.34), "kind": "town"},
	{"name": "Rustwater Works", "center": Vector2(380,-300), "radius": Vector2(250,220), "color": Color(0.46,0.49,0.32), "kind": "industry"},
	{"name": "Pinefall Reserve", "center": Vector2(-420,420), "radius": Vector2(240,250), "color": Color(0.26,0.46,0.32), "kind": "forest"},
	{"name": "Sunfield County", "center": Vector2(360,420), "radius": Vector2(285,245), "color": Color(0.58,0.62,0.33), "kind": "farm"},
	{"name": "Last Light", "center": Vector2(0,-800), "radius": Vector2(150,125), "color": Color(0.41,0.52,0.42), "kind": "lighthouse"},
]
var grid: NavGrid
var markers: Dictionary
var root: Node3D
var _rng := RandomNumberGenerator.new()

static func edge(angle: float, index: int) -> float:
	return 1.0 + sin(angle * 3 + index) * 0.055 + cos(angle * 5 - index) * 0.035

static func land_index(p: Vector3, margin := 0.0) -> int:
	for index in ISLANDS.size():
		var island: Dictionary = ISLANDS[index]
		var d: Vector2 = (Vector2(p.x,p.z) - island.center) / (island.radius - Vector2.ONE * margin)
		if d.length() <= edge(atan2(d.y,d.x), index): return index
	return -1

static func dock(index: int) -> Vector3:
	var island: Dictionary = ISLANDS[index]
	return Vector3(island.center.x + island.radius.x * edge(0,index) - 12, 0, island.center.y)

static func camp(index: int) -> Vector3:
	return dock(index) + Vector3(-32,0,0)

static func build(parent: Node3D) -> OpenWorld:
	var world := OpenWorld.new()
	world.root = parent
	world._rng.seed = 771204
	world.markers = {"art_corner": Vector3.INF, "benches": [], "spawns": [], "doors": [], "items": [], "caches": [], "witch_spots": [], "alarm_cars": [], "path": [], "start_room": Rect2(Vector2(camp(0).x-12,camp(0).z-12),Vector2(24,24)), "end_room": Rect2(), "gate": {}, "button": Vector3.INF, "radio": Vector3.INF, "rescue_zone": Rect2(), "boat_dock": Vector3.INF, "end_z": EXTENT, "lights": 0, "vehicles": [], "regions": ISLANDS}
	world._generate()
	return world

func _generate() -> void:
	grid = NavGrid.new(550,550,Vector2(-EXTENT,-EXTENT),4.0)
	for z in grid.h:
		for x in grid.w:
			var cell := Vector2i(x,z)
			var index := land_index(grid.center(cell), 5)
			if index >= 0: grid.set_cell(cell,NavGrid.Cell.WALK,index+1)
	var water := PlaneMesh.new()
	water.size = Vector2(EXTENT*2.2,EXTENT*2.2)
	var sea := Build.mesh(root,water,Color(0.12,0.49,0.59),Vector3(0,-0.8,0))
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = """shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(world.x*0.12+TIME)*cos(world.z*0.1+TIME*0.6)*0.08;}
void fragment(){float wave=sin(world.x*0.18+TIME*1.2)*cos(world.z*0.16+TIME);ALBEDO=mix(vec3(0.04,0.32,0.42),vec3(0.18,0.61,0.65),wave*0.5+0.5);ROUGHNESS=0.35;METALLIC=0.15;}"""
	sea.material_override = material
	for index in ISLANDS.size():
		_terrain(index)
		_roads(index)
		_settlement(index)
		_harbour(index)
		var base := camp(index)
		var bench := MapGen.new()
		bench.root = root
		bench.markers = markers
		bench._gunsmith(base + Vector3(6,0,-6))
		markers.caches.append({"pos": base + Vector3(0,0,6), "items": ["smg", "pump_shotgun", "rifle", "hunting_rifle", "medkit", "medkit", "pills"], "dir": Vector3.RIGHT})
		markers.items.append(base + Vector3(-6,0,-4))
		markers.path.append(Vector3(ISLANDS[index].center.x,0,ISLANDS[index].center.y))
		markers.vehicles.append({"type": "car", "pos": base + Vector3(-8,0,0), "yaw": PI/2})
		markers.vehicles.append({"type": "boat", "pos": dock(index) + Vector3(31,-0.45,10), "yaw": PI})
	for index in 4: markers.spawns.append(camp(0) + Vector3(index*1.5-3,0.1,3))
	grid.build_astar()

func _terrain(index: int) -> void:
	var island: Dictionary = ISLANDS[index]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 96:
		var points: Array[Vector3] = []
		for angle in [TAU*segment/96.0,TAU*(segment+1)/96.0]:
			var d: Vector2 = Vector2(cos(angle),sin(angle)) * island.radius * edge(angle,index)
			points.append(Vector3(island.center.x+d.x,0,island.center.y+d.y))
		var center := Vector3(island.center.x,0,island.center.y)
		for point in [center,points[0],points[1]]: st.add_vertex(point)
		var outer_a := center + (points[0]-center)*1.07 + Vector3.DOWN*0.9
		var outer_b := center + (points[1]-center)*1.07 + Vector3.DOWN*0.9
		for point in [points[0],outer_b,points[1],points[0],outer_a,outer_b]: st.add_vertex(point)
	st.generate_normals()
	var mesh := st.commit()
	var body := StaticBody3D.new()
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Build.mat(island.color)
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	# Sandy coast follows the same organic silhouette beneath the grassy combat shelf.
	var sand := MeshInstance3D.new()
	sand.mesh = mesh
	sand.material_override = Build.mat(Color(0.75,0.67,0.44))
	sand.position = Vector3(island.center.x, -0.12, island.center.y)
	sand.scale = Vector3(1.045,1,1.045)
	mi.position = Vector3.ZERO
	# Scale about island centre rather than world origin.
	sand.position -= Vector3(island.center.x*1.045,0,island.center.y*1.045)
	root.add_child(sand)

func _roads(index: int) -> void:
	var island: Dictionary = ISLANDS[index]
	var center := Vector3(island.center.x,0.025,island.center.y)
	var color := Color(0.25,0.30,0.29) if island.kind != "forest" else Color(0.51,0.43,0.31)
	for axis in 2:
		var size := Vector3(island.radius.x*1.6,0.035,13) if axis == 0 else Vector3(13,0.035,island.radius.y*1.5)
		Build.box(root,size,color,center)
	for segment in 48:
		var angle := TAU*segment/48.0
		var pos := center + Vector3(cos(angle)*island.radius.x*0.61,0,sin(angle)*island.radius.y*0.61)
		var next := center + Vector3(cos(angle+TAU/48)*island.radius.x*0.61,0,sin(angle+TAU/48)*island.radius.y*0.61)
		var road := Build.box(root,Vector3(11,0.035,pos.distance_to(next)+1),color,(pos+next)*0.5)
		road.rotation.y = atan2(next.x-pos.x,next.z-pos.z)
		if segment%3==0:
			var stripe := Build.box(root,Vector3(0.2,0.02,3.5),Color(0.85,0.77,0.49),pos+Vector3.UP*0.03)
			stripe.rotation.y = road.rotation.y
	if island.kind == "town":
		for lane in [-120,-60,60,120]:
			Build.box(root,Vector3(310,0.035,9),color,center+Vector3(0,0,lane))
			Build.box(root,Vector3(9,0.035,270),color,center+Vector3(lane,0,0))
	# Dock approach follows a broad, clear east/west road.
	Build.box(root,Vector3(island.radius.x,0.04,13),color,center+Vector3(island.radius.x*0.5,0,0))

func _solid(size: Vector3, color: Color, pos: Vector3) -> void:
	Build.solid_box(root,size,color,pos)
	var a := grid.cell_of(pos-size*0.5-Vector3(2,0,2))
	var b := grid.cell_of(pos+size*0.5+Vector3(2,0,2))
	for z in range(a.y,b.y+1):
		for x in range(a.x,b.x+1): grid.set_cell(Vector2i(x,z),NavGrid.Cell.PROP)

func _settlement(index: int) -> void:
	var island: Dictionary = ISLANDS[index]
	var center := Vector3(island.center.x,0,island.center.y)
	if island.kind == "town":
		StreetArt.corner(root, center+Vector3(-36,0,-38),0)
		markers.art_corner = center+Vector3(-36,0,-38)
	var count: int = {"town": 150, "industry": 85, "forest": 125, "farm": 70, "lighthouse": 12}[island.kind]
	for i in count:
		var pos := center + Vector3(_rng.randf_range(-island.radius.x*0.72,island.radius.x*0.72),0,_rng.randf_range(-island.radius.y*0.72,island.radius.y*0.72))
		var d := Vector2((pos.x-center.x)/island.radius.x,(pos.z-center.z)/island.radius.y).length()
		if absf(pos.x-center.x)<19 or absf(pos.z-center.z)<19 or absf(d-0.61)<0.09 or land_index(pos,25)!=index: continue
		if island.kind == "town":
			var on_street := false
			for lane in [-120,-60,60,120]:
				if absf(pos.x-center.x-lane)<15 or absf(pos.z-center.z-lane)<15: on_street=true
			if on_street: continue
		if island.kind == "forest" or i%3==0:
			StreetArt.tree(root,pos,3.5 if island.kind=="forest" else 2.5)
			Build.solid_cyl(root,0.5,4,Color(0.35,0.25,0.16),pos+Vector3.UP*2)
		elif island.kind == "industry":
			var size := Vector3(12,5 if i%2==0 else 9,7)
			_solid(size,MapGen.CONTAINER[i%MapGen.CONTAINER.size()],pos+Vector3.UP*size.y*0.5)
		elif island.kind == "farm":
			for row in 5: Build.box(root,Vector3(16,0.2,1),Color(0.65,0.48,0.23),pos+Vector3(0,0.12,row*2))
			if i%4==0: _solid(Vector3(12,6,10),Color(0.64,0.25,0.18),pos+Vector3.UP*3)
		else:
			var height := _rng.randf_range(5,12)
			_solid(Vector3(13,height,12),MapGen.BRICK[i%MapGen.BRICK.size()],pos+Vector3.UP*height*0.5)
			var roof := PrismMesh.new()
			roof.size = Vector3(14,3.5,13)
			Build.mesh(root,roof,Color(0.53,0.26,0.18),pos+Vector3.UP*(height+1.75))
			Build.box(root,Vector3(1.8,2.8,0.1),Color(0.36,0.23,0.14),pos+Vector3(0,1.4,-6.08))
			for floor_index in int(height/2.7):
				for x in [-3.5,0.0,3.5]: Build.box(root,Vector3(1.5,1.5,0.08),Color(0.31,0.62,0.65),pos+Vector3(x,1.8+floor_index*2.7,-6.05))
	if island.kind == "lighthouse":
		Build.solid_cyl(root,5,30,Color(0.88,0.80,0.60),center+Vector3.UP*15)
		Build.cyl(root,6,6,2,Color(0.69,0.24,0.18),center+Vector3.UP*24)
		Build.cyl(root,4.5,5,4,Color(0.65,0.82,0.79),center+Vector3.UP*32)
		Build.cyl(root,0,6,4,Color(0.68,0.24,0.18),center+Vector3.UP*36)
	if island.kind == "industry":
		var plant := center+Vector3(-70,0,-75)
		_solid(Vector3(36,13,25),Color(0.49,0.40,0.30),plant+Vector3.UP*6.5)
		for offset in [-12,0,12]:
			Build.solid_cyl(root,2,36,Color(0.50,0.30,0.22),plant+Vector3(offset,18,0))
		Build.label(root,"RUSTWATER POWER",plant+Vector3(0,17,-13),42,Color(1,0.8,0.46))
	if island.kind == "farm":
		var silo := center+Vector3(-70,0,-60)
		for offset in [-10,10]:
			Build.solid_cyl(root,6,18,Color(0.65,0.68,0.60),silo+Vector3(offset,9,0))
			Build.cyl(root,0,6.3,4,Color(0.44,0.51,0.50),silo+Vector3(offset,20,0))
	Build.label(root,island.name.to_upper(),center+Vector3(0,17,0),80,Color(1,0.89,0.56))

func _harbour(index: int) -> void:
	var pos := dock(index)
	Build.solid_box(root,Vector3(42,0.35,14),Color(0.55,0.42,0.29),pos+Vector3(12,-0.2,0))
	for x in [0,12,24]:
		for z in [-6,6]: Build.cyl(root,0.25,0.28,3,Color(0.35,0.28,0.21),pos+Vector3(x,-0.4,z))
	Build.label(root,"FERRY / BOATS",pos+Vector3(3,4,0),32,Color(0.95,0.83,0.48))
	Build.label(root,"SAFE CAMP • GUNSMITH • SUPPLIES",camp(index)+Vector3(0,4,-8),26,Color(0.6,0.96,0.77))
