class_name YellowSticker
## The Yellow Sticker idol: a supermarket reduced label made slightly 3D. A white card with two
## raised yellow bands, a barcode and "was £1.40p / NOW £0.27p". Same art on both faces.

const YELLOW := Color(1.0, 0.85, 0.08)
const INK := Color(0.06, 0.06, 0.06)


## depth: card thickness for a 1.6 m card (the idol is chunky; the gun decal is thin).
static func make(width := 1.6, depth := 0.22) -> Node3D:
	var root := Node3D.new()
	root.name = "YellowSticker"
	var k := width / 1.6  # everything below is laid out for a 1.6 m card
	var card := Node3D.new()
	card.rotation.z = deg_to_rad(8.0)  # the label sits at a jaunty angle, like the real thing
	card.scale = Vector3.ONE * k
	root.add_child(card)
	var slab := MeshInstance3D.new()
	slab.mesh = rounded_slab(Vector2(1.6, 1.3), 0.16, depth)
	slab.material_override = _mat(Color(0.97, 0.97, 0.95))
	slab.position.y = -0.06
	card.add_child(slab)
	for side: float in [1.0, -1.0]:
		var face := Node3D.new()
		face.position.z = depth * 0.5 * side
		face.rotation.y = 0.0 if side > 0.0 else PI
		card.add_child(face)
		_face(face)
	return root


## A rounded rectangle extruded along Z (centred), with bevel-free flat faces.
static func rounded_slab(size: Vector2, radius: float, depth: float, steps := 6) -> ArrayMesh:
	var outline := PackedVector2Array()
	var hx := size.x * 0.5 - radius
	var hy := size.y * 0.5 - radius
	var corners := [Vector2(hx, hy), Vector2(-hx, hy), Vector2(-hx, -hy), Vector2(hx, -hy)]
	for c in 4:
		for i in steps + 1:
			var a := PI * 0.5 * c + PI * 0.5 * float(i) / steps
			outline.append(corners[c] + Vector2(cos(a), sin(a)) * radius)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := depth * 0.5
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		# Front and back caps as fans from the centre, then the rim.
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(0, 0, z))
		st.add_vertex(Vector3(a.x, a.y, z))
		st.add_vertex(Vector3(b.x, b.y, z))
		st.set_normal(Vector3.FORWARD)
		st.add_vertex(Vector3(0, 0, -z))
		st.add_vertex(Vector3(b.x, b.y, -z))
		st.add_vertex(Vector3(a.x, a.y, -z))
		var rim := Vector3((a + b).x, (a + b).y, 0).normalized()
		st.set_normal(rim)
		st.add_vertex(Vector3(a.x, a.y, z))
		st.add_vertex(Vector3(a.x, a.y, -z))
		st.add_vertex(Vector3(b.x, b.y, z))
		st.add_vertex(Vector3(b.x, b.y, z))
		st.add_vertex(Vector3(a.x, a.y, -z))
		st.add_vertex(Vector3(b.x, b.y, -z))
	return st.commit()


static func _face(face: Node3D) -> void:
	# Top band "REDUCED" and bottom band "NOW £0.27p", raised off the card with rounded ends.
	_band(face, Vector2(0.0, 0.4), Vector2(1.5, 0.26))
	_band(face, Vector2(0.06, -0.5), Vector2(1.42, 0.26))
	_text(face, "REDUCED", Vector3(0.0, 0.45, 0.065), 150, INK)
	# Barcode across the middle, its top overlapping the "REDUCED" band like the real label.
	var rng := RandomNumberGenerator.new()
	rng.seed = 97140255
	var x := -0.62
	while x < 0.6:
		var w: float = [0.006, 0.01, 0.016, 0.022][rng.randi() % 4]
		Build.box(face, Vector3(w, 0.36, 0.012), INK, Vector3(x + w * 0.5, 0.13, 0.066))
		x += w + float([0.006, 0.01, 0.014][rng.randi() % 3])
	_text(face, "9714 0255 0017 9052 3000 3005", Vector3(0.08, -0.12, 0.005), 52, INK)
	_text(face, "was £1.40p", Vector3(-0.36, -0.27, 0.005), 80, INK)
	Build.box(face, Vector3(0.32, 0.018, 0.01), INK, Vector3(-0.25, -0.265, 0.01))
	_text(face, "NOW £0.27p", Vector3(0.05, -0.51, 0.065), 140, INK)


## Two-sided so the generated slab's winding never matters.
static func _mat(c: Color) -> StandardMaterial3D:
	var m := Build.mat(c, 0.5).duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _band(face: Node3D, center: Vector2, size: Vector2) -> void:
	var depth := 0.06
	var band := MeshInstance3D.new()
	band.mesh = rounded_slab(size, size.y * 0.5 - 0.001, depth)
	band.material_override = _mat(YELLOW)
	band.position = Vector3(center.x, center.y, depth * 0.5)
	face.add_child(band)


static func _text(face: Node3D, text: String, pos: Vector3, size: int, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0012
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.double_sided = false
	l.shaded = true
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Black", "Helvetica Neue", "Arial", "sans-serif"])
	font.font_weight = 800
	l.font = font
	face.add_child(l)
