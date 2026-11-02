class_name GroundDetail
extends RefCounted
## Real, faceted ground dressing. Shared meshes, spatial batches, no collision or gameplay RNG.
const CHUNK := 64.0
static var _meshes := {}
var _batches := {}

func add(kind: String, pos: Vector3, size := 1.0, yaw := 0.0) -> void:
	var cell := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	var key := "%s:%d:%d" % [kind, cell.x, cell.y]
	if not _batches.has(key):
		_batches[key] = {"kind": kind, "origin": Vector3(cell.x * CHUNK, 0, cell.y * CHUNK), "transforms": []}
	var batch: Dictionary = _batches[key]
	batch.transforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), pos - batch.origin))

func flush(parent: Node3D) -> void:
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = model(batch.kind)
		mm.instance_count = batch.transforms.size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, batch.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.name = "GroundDetail_" + batch.kind
		node.multimesh = mm
		node.position = batch.origin
		node.add_to_group("ground_detail")
		node.visibility_range_end = 85.0
		node.visibility_range_end_margin = 15.0
		parent.add_child(node)
	_batches.clear()

static func model(kind: String) -> ArrayMesh:
	if _meshes.has(kind): return _meshes[kind]
	var f := Forge.new()
	match kind:
		"grass": _grass(f, Vector3.ZERO)
		"stone":
			f.ball(Vector3(0,0.10,0), Vector3(0.28,0.17,0.23), Color(0.48,0.48,0.41), Forge.PAINT, Basis(Vector3.UP,0.4), 7, 3)
			f.ball(Vector3(0.28,0.035,0.18), Vector3(0.12,0.08,0.10), Color(0.61,0.57,0.46), Forge.PAINT, Basis.IDENTITY, 5, 2)
		"broken_paving":
			# Uneven raised lips on either side of a jagged, open seam, with loose chips.
			for i in 4:
				var z := (i - 1.5) * 0.38
				var x := 0.08 if i % 2 == 0 else -0.06
				for side: float in [-1,1]:
					var basis := Basis(Vector3.FORWARD, side * 0.13)
					f.block(Vector3(x + side * 0.18,0.035,z),Vector3(0.25,0.09,0.4),Color(0.51,0.49,0.43),Forge.PAINT,basis)
			f.ball(Vector3(0.43,0.04,0.55),Vector3(0.13,0.09,0.19),Color(0.46,0.44,0.38),Forge.PAINT,Basis.IDENTITY,5,2)
			_grass(f,Vector3(0,0,0.15),0.65)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := f.commit([material,material,material,material])
	_meshes[kind] = mesh
	return mesh

static func _grass(f: Forge, origin: Vector3, size := 1.0) -> void:
	for i in 9:
		var angle := i * 2.4
		var radial := Vector3(cos(angle),0,sin(angle))
		var base := origin + radial * 0.09 * size
		var side := Vector3(-sin(angle),0,cos(angle)) * 0.045 * size
		var height := (0.25 + (i % 4) * 0.09) * size
		var mid := base + Vector3.UP * height * 0.6 + radial * 0.06 * size
		var tip := base + Vector3.UP * height + radial * 0.20 * size
		var color := Color(0.27 + (i % 3) * 0.06,0.40 + (i % 3) * 0.07,0.12)
		f.quad(base-side,base+side,mid+side*0.55,mid-side*0.55,radial,color)
		f.tri(mid-side*0.55,mid+side*0.55,tip,radial,color.lightened(0.12))
