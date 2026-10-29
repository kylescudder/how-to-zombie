class_name GunModels
extends RefCounted
## Detailed, original semi-real firearm geometry. Metres, grip origin, muzzle along -Z.
## Chamfered receivers, machined steel, polymer furniture and separate moving actions.

const STEEL := Color(0.24, 0.27, 0.30)
const EDGE := Color(0.36, 0.4, 0.44)
const BLACK := Color(0.035, 0.045, 0.052)
const POLYMER := Color(0.085, 0.10, 0.105)
const WOOD := Color(0.29, 0.125, 0.055)
static var _materials := {}
static var _templates := {}

const BRASS := Color(0.66, 0.43, 0.14)


static func make(id: String, upgrades := {}) -> Node3D:
	var key := id + str(upgrades.hash())
	if not _templates.has(key):
		var gun := _assemble(id, upgrades)
		for child in gun.get_children():
			if child.name in ["Magazine", "ForeEnd", "ReloadShell", "ActionBolt"]:
				_bake(child)
		_bake(gun)
		_owners(gun, gun)
		var scene := PackedScene.new()
		scene.pack(gun)
		gun.free()
		_templates[key] = scene
	return (_templates[key] as PackedScene).instantiate() as Node3D


static func _assemble(id: String, upgrades: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Gun"
	if id == "dual_pistols":
		for x: float in [-0.14, 0.14]:
			var pistol := make("pistol", upgrades)
			pistol.position.x = x
			n.add_child(pistol)
		return n
	if id == "pistol":
		_pistol(n)
	elif id == "pump_shotgun":
		_pump(n)
	else:
		_long_gun(n, id)
	if int(upgrades.get("optic", 0)) > 0 or id == "hunting_rifle":
		_optic(n, id == "hunting_rifle", sight_height(id, upgrades))
	if int(upgrades.get("magazine", 0)) > 0:
		if id == "pump_shotgun":
			_tube(n,Vector3(0,0.015,-0.73),0.23,0.018,STEEL)
		else:
			_part(n.get_node("Magazine") if n.has_node("Magazine") else n,Vector3(0.071,0.035,0.10),EDGE,Vector3(0,-0.22 if id in ["smg","rifle"] else -0.13,-0.15))
	if int(upgrades.get("power", 0)) > 0:
		_part(n, Vector3(0.005, 0.018, 0.045), BRASS, Vector3(0.049, 0.025, -0.12))
	return n


static func _pistol(n: Node3D) -> void:
	_part(n, Vector3(0.038, 0.115, 0.07), POLYMER, Vector3(0, -0.048, 0.015), Vector3(12, 0, 0))
	for x: float in [-0.021, 0.021]:
		_part(n, Vector3(0.006, 0.085, 0.052), BLACK, Vector3(x, -0.05, 0.016), Vector3(12, 0, 0))
		for y in 9:
			_part(n, Vector3(0.007, 0.002, 0.048), EDGE.darkened(0.5), Vector3(x, -0.085 + y * 0.008, 0.014))
	_part(n, Vector3(0.045, 0.023, 0.185), STEEL, Vector3(0, 0.0, -0.055))
	var slide := Node3D.new()
	slide.name = "ActionBolt"
	n.add_child(slide)
	_part(slide, Vector3(0.042, 0.039, 0.205), EDGE, Vector3(0, 0.032, -0.06))
	_part(slide, Vector3(0.025, 0.005, 0.045), BLACK, Vector3(0.009, 0.053, -0.045))
	for x: float in [-0.022, 0.022]:
		for z in 8:
			_part(slide, Vector3(0.002, 0.025, 0.002), BLACK, Vector3(x, 0.033, 0.01 + z * 0.004))
	_barrel(n, Vector3(0, 0.031, -0.135), 0.08, 0.011)
	_sights(n, 0.0, -0.14, 0.058)
	var magazine := _rig(n, "Magazine")
	_part(magazine, Vector3(0.035, 0.11, 0.055), STEEL, Vector3(0, -0.045, 0.012))
	_part(magazine, Vector3(0.044, 0.01, 0.065), BLACK, Vector3(0, -0.105, 0.012))
	_guard(n, -0.058, -0.043, 0.04)
	for z: float in [-0.025, 0.025]:
		_pin(n, Vector3(0.024, 0.002, z), 0.004)
	_part(n, Vector3(0.009, 0.008, 0.032), EDGE, Vector3(0.027, 0.01, -0.015))
	_part(n, Vector3(0.028, 0.009, 0.018), STEEL, Vector3(0, 0.04, 0.052), Vector3(-25, 0, 0))
	_mark(n, "M9  /  9×19", Vector3(0.022, 0.032, -0.07))


static func _long_gun(n: Node3D, id: String) -> void:
	var shotgun := id in ["pump_shotgun", "auto_shotgun"]
	var scout := id == "hunting_rifle"
	var smg := id == "smg"
	var wood := id == "pump_shotgun" or scout
	var furniture := WOOD if wood else POLYMER
	var receiver_len := 0.23 if smg else 0.30
	_part(n, Vector3(0.059, 0.082, receiver_len), STEEL, Vector3(0, 0.028, -0.11))
	_part(n, Vector3(0.047, 0.036, receiver_len - 0.01), EDGE.darkened(0.3), Vector3(0, 0.083, -0.11))
	# Ejection port, bolt carrier and charging handle.
	_part(n, Vector3(0.003, 0.029, 0.095), BLACK, Vector3(0.031, 0.048, -0.12))
	var bolt := Node3D.new()
	bolt.name = "ActionBolt"
	n.add_child(bolt)
	_part(bolt, Vector3(0.005, 0.019, 0.065), EDGE, Vector3(0.034, 0.047, -0.12))
	_tube(bolt, Vector3(0.05, 0.047, -0.078), 0.035, 0.005, EDGE, Vector3(0, 0, 90))
	for z: float in [-0.23, -0.06, 0.015]:
		_pin(n, Vector3(0.031, 0.018, z), 0.005)
	_part(n, Vector3(0.008, 0.006, 0.032), EDGE, Vector3(-0.034, 0.028, 0.01), Vector3(0, 12, 0))
	# Angled grip, stippled backstrap and trigger guard.
	_part(n, Vector3(0.045, 0.12, 0.068), furniture, Vector3(0, -0.073, 0.008), Vector3(18, 0, 0))
	for y in 7:
		_part(n, Vector3(0.047, 0.003, 0.059), BLACK, Vector3(0, -0.12 + y * 0.013, 0.014), Vector3(18, 0, 0))
	_guard(n, -0.071, -0.055, 0.055)
	# Stock with cheek rest, rubber buttpad, sling mount and hardware.
	if smg:
		for x: float in [-0.026, 0.026]:
			_tube(n, Vector3(x, 0.025, 0.16), 0.26, 0.008, EDGE)
		_part(n, Vector3(0.065, 0.12, 0.035), POLYMER, Vector3(0, -0.015, 0.29))
	else:
		_part(n, Vector3(0.055, 0.075, 0.24), furniture, Vector3(0, -0.005, 0.18), Vector3(-7, 0, 0))
		_part(n, Vector3(0.062, 0.037, 0.18), furniture.lightened(0.06), Vector3(0, 0.038, 0.18))
		_part(n, Vector3(0.066, 0.127, 0.035), BLACK, Vector3(0, -0.027, 0.31), Vector3(-7, 0, 0))
		for y in 7:
			_part(n, Vector3(0.066, 0.003, 0.006), EDGE.darkened(0.4), Vector3(0, -0.07 + y * 0.014, 0.33))
	# Fore-end and barrel. Smooth bores with a recessed muzzle, not solid cylinders.
	var muzzle_z := ItemModels.muzzle(id).z
	var front := -0.23
	var barrel_len := absf(muzzle_z - front)
	_barrel(n, Vector3(0, 0.067, (front + muzzle_z) * 0.5), barrel_len, 0.023 if shotgun else 0.014)
	var fore := _rig(n, "ForeEnd")
	_part(fore, Vector3(0.066, 0.072, 0.24 if not smg else 0.18), furniture, Vector3(0, 0.022, -0.36))
	for z in 12:
		var zp := -0.26 - z * 0.017
		if wood or shotgun:
			_part(fore, Vector3(0.069, 0.004, 0.005), furniture.lightened(0.08), Vector3(0, 0.01, zp))
		else:
			for x: float in [-0.034, 0.034]:
				_part(fore, Vector3(0.003, 0.018, 0.009), BLACK, Vector3(x, 0.028, zp))
	if shotgun:
		var shell := _rig(n, "ReloadShell")
		_tube(shell, Vector3.ZERO, 0.06, 0.012, Color(0.65, 0.08, 0.05))
		_tube(shell, Vector3(0, 0, 0.027), 0.01, 0.012, BRASS)
		shell.visible = false
		_tube(n, Vector3(0, 0.018, -0.52), 0.40, 0.018, STEEL)
		# Shell carrier with brass heads on the receiver's left side.
		for i in 4:
			var zp := -0.055 - i * 0.043
			_tube(n, Vector3(-0.043, 0.03, zp), 0.055, 0.012, Color(0.48, 0.09, 0.065), Vector3.ZERO)
			_tube(n, Vector3(-0.043, 0.06, zp), 0.009, 0.012, BRASS, Vector3.ZERO)
	else:
		var magazine := _rig(n, "Magazine")
		var mag := _part(magazine, Vector3(0.043, 0.19 if not scout else 0.1, 0.09), EDGE.darkened(0.25), Vector3(0, -0.11, -0.16), Vector3(-12, 0, 0))
		for z: float in [-0.022, 0.0, 0.022]:
			for x: float in [-0.023, 0.023]:
				_part(mag, Vector3(0.003, 0.14 if not scout else 0.07, 0.004), BLACK, Vector3(x, 0, z))
	_rail(n, -0.10, 0.105, 0.25)
	_sights(n, -0.01, -0.44 if smg else -0.60, 0.132)
	if wood:
		for i in 5:
			_part(n, Vector3(0.001, 0.002, 0.18), WOOD.lightened(0.07 * (i % 2)), Vector3(0.029, -0.027 + i * 0.012, 0.18), Vector3(-5, 0, 0))
	_mark(n, DB.GUN_PROFILES[id].model, Vector3(0.032, 0.017, -0.13))


static func _optic(n: Node3D, scope: bool, y: float) -> void:
	var z := -0.12
	for zp: float in [-0.06, -0.18]:
		_part(n, Vector3(0.045, 0.045, 0.025), BLACK, Vector3(0, y - 0.04, zp))
	_sleeve(n, Vector3(0, y, z), 0.25 if scope else 0.10, 0.032, STEEL)
	for zp: float in [-0.23, -0.02] if scope else [-0.16, -0.08]:
		_sleeve(n, Vector3(0, y, zp), 0.024, 0.039 if scope else 0.035, BLACK)
		_tube(n, Vector3(0, y, zp - 0.013), 0.001, 0.027, Color(0.08, 0.32, 0.34, 0.08))
	_tube(n, Vector3(0.04, y, z), 0.025, 0.016, BLACK, Vector3(0, 0, 90))
	_tube(n, Vector3(0, y + 0.04, z), 0.022, 0.016, BLACK, Vector3.ZERO)


static func _sights(n: Node3D, rear: float, front: float, y: float) -> void:
	for x: float in [-0.014, 0.014]:
		_part(n, Vector3(0.009, 0.023, 0.012), BLACK, Vector3(x, y, rear))
		_part(n, Vector3(0.003, 0.003, 0.002), Color(0.8, 0.86, 0.65), Vector3(x, y + 0.006, rear + 0.007))
	if y > 0.1:
		_part(n, Vector3(0.022, 0.055, 0.022), STEEL, Vector3(0, y - 0.039, front))
	_part(n, Vector3(0.008, 0.024, 0.014), BLACK, Vector3(0, y, front))
	_part(n, Vector3(0.003, 0.004, 0.003), Color(0.8, 0.9, 0.65), Vector3(0, y + 0.008, front + 0.008))


static func _guard(n: Node3D, y: float, z: float, length: float) -> void:
	_part(n, Vector3(0.033, 0.008, length + 0.025), STEEL, Vector3(0, y - 0.02, z))
	_part(n, Vector3(0.033, 0.042, 0.008), STEEL, Vector3(0, y, z - length * 0.5))
	_part(n, Vector3(0.008, 0.028, 0.009), EDGE, Vector3(0, y + 0.01, z), Vector3(-25, 0, 0))


static func _rail(n: Node3D, z: float, y: float, length: float) -> void:
	_part(n, Vector3(0.033, 0.009, length), STEEL, Vector3(0, y, z))
	for i in int(length / 0.017):
		_part(n, Vector3(0.046, 0.009, 0.009), EDGE, Vector3(0, y + 0.008, z - length * 0.5 + i * 0.017))


static func _pin(n: Node3D, pos: Vector3, radius: float) -> void:
	_tube(n, pos, 0.004, radius, EDGE, Vector3(0, 0, 90))
	_part(n, Vector3(0.005, 0.001, radius * 1.2), BLACK, pos + Vector3(0.003, 0, 0), Vector3(20, 0, 0))


static func _barrel(n: Node3D, pos: Vector3, length: float, radius: float) -> void:
	_tube(n, pos, length, radius, STEEL)
	# Black recess and thin steel crown visible from the muzzle.
	_tube(n, pos + Vector3(0, 0, -length * 0.5 - 0.001), 0.002, radius * 0.75, BLACK)
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.72
	torus.outer_radius = radius
	torus.rings = 24
	torus.ring_segments = 12
	var mi := Build.mesh(n, torus, EDGE, pos + Vector3(0, 0, -length * 0.5 - 0.002), Vector3(90, 0, 0))
	_finish(mi, EDGE)


static func _tube(n: Node3D, pos: Vector3, length: float, radius: float, color: Color, rot := Vector3(90, 0, 0)) -> MeshInstance3D:
	var mi := Build.cyl(n, radius, radius, length, color, pos, rot, 32)
	_finish(mi, color)
	return mi


static func _mark(n: Node3D, text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 28
	l.pixel_size = 0.00018
	l.outline_size = 0
	l.modulate = Color(0.55, 0.59, 0.57)
	l.position = pos
	l.rotation_degrees = Vector3(0, 90, 0)
	n.add_child(l)


static func _finish(mi: MeshInstance3D, color: Color) -> void:
	if _materials.has(color):
		mi.material_override = _materials[color]
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.72 if color in [STEEL, EDGE, BRASS] else 0.05
	mat.roughness = 0.31 if mat.metallic > 0.5 else 0.68
	mi.material_override = mat
	_materials[color] = mat


# Bevelled cuboid: eight-sided cross-section, inset end caps, explicit chamfer faces.
static func _part(n: Node3D, size: Vector3, color: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := minf(minf(size.x, size.y), size.z) * 0.15
	var rings: Array = []
	for end in 4:
		var inset := b if end in [0, 3] else 0.0
		var x := size.x * 0.5 - inset
		var y := size.y * 0.5 - inset
		var c := b * 0.7
		var z: float = [-size.z * 0.5, -size.z * 0.5 + b, size.z * 0.5 - b, size.z * 0.5][end]
		rings.append([Vector3(-x + c, -y, z), Vector3(x - c, -y, z), Vector3(x, -y + c, z), Vector3(x, y - c, z), Vector3(x - c, y, z), Vector3(-x + c, y, z), Vector3(-x, y - c, z), Vector3(-x, -y + c, z)])
	for j in 3:
		for i in 8:
			var k := (i + 1) % 8
			_tri(st, rings[j][i], rings[j + 1][k], rings[j + 1][i])
			_tri(st, rings[j][i], rings[j][k], rings[j + 1][k])
	for i in 8:
		var k := (i + 1) % 8
		_tri(st, Vector3(0, 0, -size.z * 0.5), rings[0][k], rings[0][i])
		_tri(st, Vector3(0, 0, size.z * 0.5), rings[3][i], rings[3][k])
	# All sources must be indexed before merging with Godot primitive meshes.
	st.index()
	var mi := Build.mesh(n, st.commit(), color, pos, rot)
	_finish(mi, color)
	return mi


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal((b - a).cross(c - a).normalized())
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


static func _sleeve(n: Node3D, pos: Vector3, length: float, radius: float, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		var a := TAU * i / 32.0
		var b := TAU * (i + 1) / 32.0
		for r: float in [radius, radius * 0.84]:
			var p := Vector3(cos(a) * r, sin(a) * r, -length * 0.5)
			var q := Vector3(cos(b) * r, sin(b) * r, -length * 0.5)
			var dz := Vector3(0, 0, length)
			if r == radius:
				_tri(st, p, q, q + dz)
				_tri(st, p, q + dz, p + dz)
			else:
				_tri(st, p, q + dz, q)
				_tri(st, p, p + dz, q + dz)
		for z: float in [-length * 0.5, length * 0.5]:
			var p := Vector3(cos(a) * radius, sin(a) * radius, z)
			var q := Vector3(cos(b) * radius, sin(b) * radius, z)
			var pi := Vector3(p.x * 0.84, p.y * 0.84, z)
			var qi := Vector3(q.x * 0.84, q.y * 0.84, z)
			_tri(st, p, pi, qi) if z > 0 else _tri(st, p, qi, pi)
			_tri(st, p, qi, q) if z > 0 else _tri(st, p, q, qi)
	# All sources must be indexed before merging with Godot primitive meshes.
	st.index()
	var mi := Build.mesh(n, st.commit(), color, pos)
	_finish(mi, color)


# Combine fixed geometry by material. Detail should cost triangles, not hundreds of draw calls.
static func _bake(gun: Node3D) -> void:
	var groups := {}
	_gather(gun, Transform3D.IDENTITY, groups)
	for child in gun.get_children():
		if child is MeshInstance3D:
			child.free()
	for entry: Dictionary in groups.values():
		var mesh := MeshInstance3D.new()
		mesh.mesh = (entry.tool as SurfaceTool).commit()
		mesh.material_override = entry.material
		gun.add_child(mesh)


static func _gather(parent: Node3D, transform: Transform3D, groups: Dictionary) -> void:
	for child in parent.get_children():
		if not child is Node3D or child.name == "ActionBolt":
			continue
		var local: Transform3D = transform * child.transform
		if child is MeshInstance3D:
			var mat: Material = child.material_override
			var key := mat.get_instance_id()
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"tool": tool, "material": mat}
			(groups[key].tool as SurfaceTool).append_from(child.mesh, 0, local)
			_gather(child, local, groups)
		# Child guns in akimbo are already baked and retain their moving parts.


static func _owners(parent: Node, root: Node) -> void:
	for child in parent.get_children():
		child.owner = root
		_owners(child, root)


static func sight_height(id: String, upgrades: Dictionary) -> float:
	if id == "hunting_rifle":
		return 0.175
	if int(upgrades.get("optic", 0)) > 0:
		return 0.095 if id in ["pistol", "dual_pistols"] else 0.163
	return 0.058 if id in ["pistol", "dual_pistols"] else 0.132


static func _rig(parent: Node3D, name: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name
	parent.add_child(pivot)
	return pivot


static func _pump(n: Node3D) -> void:
	# A tube-fed pump gun: narrow steel receiver and a continuous walnut stock.
	_part(n,Vector3(0.064,0.085,0.28),STEEL,Vector3(0,0.027,-0.105))
	_part(n,Vector3(0.068,0.012,0.27),EDGE.darkened(0.25),Vector3(0,0.073,-0.105))
	_part(n,Vector3(0.003,0.032,0.094),BLACK,Vector3(0.034,0.035,-0.12))
	var bolt := _rig(n,"ActionBolt")
	_part(bolt,Vector3(0.005,0.024,0.075),EDGE,Vector3(0.036,0.035,-0.12))
	var stock := _rig(n,"WalnutStock")
	stock.rotation.x = PI*0.5
	ArtShapes.loft(stock,[Vector4(0.015,0.024,0.037,0.012),Vector4(0.07,0.029,0.043,0.03),Vector4(0.15,0.039,0.068,0.04),Vector4(0.30,0.052,0.108,0.045),Vector4(0.35,0.052,0.105,0.045)],WOOD)
	_part(n,Vector3(0.112,0.221,0.025),BLACK,Vector3(0,-0.045,0.36),Vector3(-5,0,0))
	for side: float in [-1,1]:
		for i in 6:
			_part(n,Vector3(0.0015,0.0025,0.12),WOOD.lightened(0.04+(i%2)*0.035),Vector3(side*0.049,-0.095+i*0.017,0.265),Vector3(-8,0,0))
	_barrel(n,Vector3(0,0.063,-0.54),0.60,0.022)
	_tube(n,Vector3(0,0.013,-0.45),0.43,0.018,STEEL)
	var fore := _rig(n,"ForeEnd")
	var wood := _rig(fore,"WalnutPump")
	wood.rotation.x = PI*0.5
	ArtShapes.loft(wood,[Vector4(-0.51,0.026,0.028,0),Vector4(-0.495,0.043,0.045,0),Vector4(-0.29,0.043,0.045,0),Vector4(-0.275,0.027,0.03,0)],WOOD)
	for i in 10:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.039
		ring.outer_radius = 0.045
		ring.rings = 24
		ring.ring_segments = 8
		var mesh := Build.mesh(fore,ring,WOOD.darkened(0.22),Vector3(0,0,-0.49+i*0.019),Vector3(90,0,0))
		_finish(mesh,WOOD.darkened(0.22))
	_guard(n,-0.045,-0.015,0.065)
	_part(n,Vector3(0.008,0.008,0.032),EDGE,Vector3(0,0.081,0.025))
	_tube(n,Vector3(0,0.088,-0.80),0.012,0.007,BRASS,Vector3.ZERO)
	for z: float in [-0.22,-0.025]:
		_pin(n,Vector3(0.035,0.008,z),0.005)
	for i in 4:
		_tube(n,Vector3(-0.049,0.025,-0.04-i*0.045),0.058,0.011,Color(0.58,0.08,0.055),Vector3.ZERO)
		_tube(n,Vector3(-0.049,0.057,-0.04-i*0.045),0.009,0.011,BRASS,Vector3.ZERO)
	var shell := _rig(n,"ReloadShell")
	_tube(shell,Vector3.ZERO,0.06,0.012,Color(0.65,0.08,0.05))
	_tube(shell,Vector3(0,0,0.027),0.01,0.012,BRASS)
	shell.visible = false
	_mark(n,"M590 / 12 GA",Vector3(0.034,0.052,-0.10))
