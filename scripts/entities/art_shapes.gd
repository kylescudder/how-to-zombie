class_name ArtShapes
extends RefCounted
## Authored cross-section meshes and curved forms for the cartoon art direction.

static var _ovals := {}
static var _links := {}

static func oval(parent: Node3D, size: Vector3, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, segments := 20) -> MeshInstance3D:
	var mesh: SphereMesh = _ovals.get(segments)
	if not mesh:
		mesh = SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = segments
		mesh.rings = 12
		_ovals[segments] = mesh
	var mi := Build.mesh(parent, mesh, color, pos, rot)
	mi.scale = size
	return mi

## Seats a pair of nostrils on the underside of an oval nose, so they follow its shape and tilt.
static func nostrils(nose: MeshInstance3D, size: Vector3, color: Color) -> void:
	for side: float in [-1,1]:
		var dir := Vector3(side*0.5,-0.55,0.67).normalized()
		var nostril := oval(nose,size/nose.scale,color,dir*0.48,Vector3.ZERO,12)
		nostril.name = "Nostril%d" % side


static func link(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var key := Vector2(radius, a.distance_to(b))
	var mesh: CapsuleMesh = _links.get(key)
	if not mesh:
		mesh = CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = a.distance_to(b) + radius * 2
		mesh.radial_segments = 12
		mesh.rings = 5
		_links[key] = mesh
	var mi := Build.mesh(parent, mesh, color, (a + b) * 0.5)
	if a.distance_to(b) > 0.001:
		mi.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return mi

## Each section = (height, half-width, half-depth, forward offset).
static func loft(parent: Node3D, sections: Array[Vector4], color: Color, pos := Vector3.ZERO, segments := 20) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in sections.size() - 1:
		for i in segments:
			var a := _point(sections[j], TAU * i / segments)
			var b := _point(sections[j + 1], TAU * i / segments)
			var c := _point(sections[j + 1], TAU * (i + 1) / segments)
			var d := _point(sections[j], TAU * (i + 1) / segments)
			_face(tool, a, b, c)
			_face(tool, a, c, d)
	# Smooth vertex normals across sections while preserving the authored silhouette.
	tool.set_smooth_group(0)
	tool.generate_normals()
	tool.index()
	return Build.mesh(parent, tool.commit(), color, pos)

static func _point(s: Vector4, angle: float) -> Vector3:
	return Vector3(cos(angle) * s.y, s.x, sin(angle) * s.z + s.w)

static func _face(t: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	t.set_smooth_group(0)
	t.add_vertex(a)
	t.add_vertex(c)
	t.add_vertex(b)
