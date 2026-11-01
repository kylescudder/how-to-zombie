class_name Build
## Tiny helpers for making chunky low-poly geometry out of primitives.

static var _mats := {}
## Identical primitives share one mesh; the city would otherwise upload ~50,000 separate ones.
static var _shapes := {}
static var _surfaces := {}
## How many metres one repeat of each texture in assets/textures covers.
const SURFACES := {"brick": 3.2, "plaster": 5.0, "concrete": 7.0, "asphalt": 7.0, "paving": 6.0, "metal": 4.0, "wood": 2.2, "fabric": 1.0, "grass": 6.0, "sand": 8.0, "tile": 2.4, "painted": 1.4}
## The surface for world geometry built from here on, or "none". Set it around static scenery only:
## it maps in world space, which would swim across anything that moves.
static var paint := ""


static func mat(color: Color, rough: float = 0.85, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [color.to_html(), rough, emission, paint]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	elif color.a >= 1.0 and paint != "none":
		_texture(m, paint if paint != "" else "painted", paint != "")
	_mats[key] = m
	return m


## Triplanar, so no mesh needs UVs: the detail is multiplied over the colour a surface already has.
static func _texture(m: StandardMaterial3D, surface: String, world: bool) -> void:
	if not _surfaces.has(surface):
		_surfaces[surface] = [load("res://assets/textures/%s.png" % surface), load("res://assets/textures/%s_n.png" % surface)]
	m.albedo_texture = _surfaces[surface][0]
	m.normal_enabled = true
	m.normal_texture = _surfaces[surface][1]
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_triplanar_sharpness = 12.0
	m.uv1_scale = Vector3.ONE / float(SURFACES[surface])


static func mesh(parent: Node3D, m: Mesh, color: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, 0.85, emission)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, color: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var b: BoxMesh = _shapes.get(size)
	if not b:
		b = BoxMesh.new()
		b.size = size
		_shapes[size] = b
	return mesh(parent, b, color, pos, rot_deg, emission)


static func cyl(parent: Node3D, top: float, bottom: float, height: float, color: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, segments := 10) -> MeshInstance3D:
	var key := Vector4(top, bottom, height, segments)
	var c: CylinderMesh = _shapes.get(key)
	if not c:
		c = CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = height
		c.radial_segments = segments
		c.rings = 1
		_shapes[key] = c
	return mesh(parent, c, color, pos, rot_deg)


static func sphere(parent: Node3D, radius: float, color: Color, pos := Vector3.ZERO, scale := Vector3.ONE, segments := 10) -> MeshInstance3D:
	var key := Vector2(radius, segments)
	var s: SphereMesh = _shapes.get(key)
	if not s:
		s = SphereMesh.new()
		s.radius = radius
		s.height = radius * 2.0
		s.radial_segments = segments
		s.rings = max(segments / 2, 4)
		_shapes[key] = s
	var mi := mesh(parent, s, color, pos)
	mi.scale = scale
	return mi


## Static, collidable box (world layer).
static func solid_box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	box(body, size, color)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	return body


static func solid_cyl(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3, segments := 16) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	cyl(body, radius, radius, height, color, Vector3.ZERO, Vector3.ZERO, segments)
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = radius
	cs.height = height
	shape.shape = cs
	body.add_child(shape)
	return body


static func label(parent: Node3D, text: String, pos: Vector3, size := 64, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.no_depth_test = false
	parent.add_child(l)
	return l


## Interaction zone the player's look-ray can hit (layer 4).
static func interact_zone(parent: Node3D, kind: String, size: Vector3, pos: Vector3, prompt: String) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 8
	a.collision_mask = 0
	a.monitoring = false
	a.position = pos
	a.set_meta("interact", kind)
	a.set_meta("prompt", prompt)
	parent.add_child(a)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	a.add_child(shape)
	return a
