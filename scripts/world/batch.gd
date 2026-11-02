class_name Batch
extends RefCounted
## Static scenery gathered into one MultiMesh per key, so thousands of props cost a few draws.
## The first add of a key fixes its mesh and material; tinted keys take each instance's colour.

static var box := BoxMesh.new()
static var quad := QuadMesh.new()
static var prism := PrismMesh.new()
static var ramp := _make_ramp()
static var ball := _make_ball()
static var post := _make_cylinder(0.5)
static var cone := _make_cylinder(0.0)

var _mm := {}  # key -> {"mesh", "mat", "xforms", ["colors"]}
## Keys whose batches skip shadows (flat decals, emissive glass).
var no_shadow: Array[String] = []


## surface: a Build texture name or "none". tint: one batch for every colour of this key.
func add(key: String, mesh: Mesh, color: Color, t: Transform3D, emission := 0.0, surface := "none", tint := false) -> void:
	if not _mm.has(key):
		Build.paint = surface
		if tint:
			var m: StandardMaterial3D = Build.mat(Color.WHITE, 0.6).duplicate()
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			_mm[key] = {"mesh": mesh, "mat": m, "xforms": [], "colors": []}
		else:
			_mm[key] = {"mesh": mesh, "mat": Build.mat(color, 0.6, emission), "xforms": []}
		Build.paint = ""
	_mm[key].xforms.append(t)
	if _mm[key].has("colors"):
		_mm[key].colors.append(color)


func flush(root: Node3D) -> void:
	for key: String in _mm:
		var e: Dictionary = _mm[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = e.has("colors")
		mm.mesh = e.mesh
		mm.instance_count = e.xforms.size()
		for i in e.xforms.size():
			mm.set_instance_transform(i, e.xforms[i])
			if mm.use_colors:
				mm.set_instance_color(i, e.colors[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_" + key
		mmi.multimesh = mm
		mmi.material_override = e.mat
		for prefix in no_shadow:
			if key.begins_with(prefix):
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	_mm.clear()


## A right-angled prism: one sawtooth roof light.
static func _make_ramp() -> PrismMesh:
	var m := PrismMesh.new()
	m.left_to_right = 0.0
	return m


static func _make_ball() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 10
	m.rings = 5
	return m


static func _make_cylinder(top: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 12
	m.rings = 1
	return m
