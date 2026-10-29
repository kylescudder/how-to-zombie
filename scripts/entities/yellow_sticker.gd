class_name YellowSticker
## The Yellow Sticker idol: a supermarket reduced label made slightly 3D. A white card with two
## raised yellow bands, a barcode and "was £1.40p / NOW £0.27p". Same art on both faces.

const YELLOW := Color(1.0, 0.85, 0.08)
const INK := Color(0.06, 0.06, 0.06)


static func make(width := 1.6) -> Node3D:
	var root := Node3D.new()
	root.name = "YellowSticker"
	var k := width / 1.6  # everything below is laid out for a 1.6 m card
	var card := Node3D.new()
	card.rotation.z = deg_to_rad(8.0)  # the label sits at a jaunty angle, like the real thing
	card.scale = Vector3.ONE * k
	root.add_child(card)
	Build.box(card, Vector3(1.6, 1.3, 0.05), Color(0.97, 0.97, 0.95), Vector3(0, -0.06, 0))
	for side: float in [1.0, -1.0]:
		var face := Node3D.new()
		face.position.z = 0.025 * side
		face.rotation.y = 0.0 if side > 0.0 else PI
		card.add_child(face)
		_face(face)
	return root


static func _face(face: Node3D) -> void:
	# Top band "REDUCED" and bottom band "NOW £0.27p", raised off the card with rounded ends.
	_band(face, Vector2(0.0, 0.4), Vector2(1.5, 0.26))
	_band(face, Vector2(0.06, -0.5), Vector2(1.42, 0.26))
	_text(face, "REDUCED", Vector3(0.0, 0.45, 0.05), 150, INK)
	# Barcode across the middle, its top overlapping the "REDUCED" band like the real label.
	var rng := RandomNumberGenerator.new()
	rng.seed = 97140255
	var x := -0.62
	while x < 0.6:
		var w: float = [0.006, 0.01, 0.016, 0.022][rng.randi() % 4]
		Build.box(face, Vector3(w, 0.36, 0.012), INK, Vector3(x + w * 0.5, 0.13, 0.046))
		x += w + float([0.006, 0.01, 0.014][rng.randi() % 3])
	_text(face, "9714 0255 0017 9052 3000 3005", Vector3(0.08, -0.12, 0.03), 52, INK)
	_text(face, "was £1.40p", Vector3(-0.36, -0.27, 0.03), 80, INK)
	Build.box(face, Vector3(0.32, 0.018, 0.01), INK, Vector3(-0.25, -0.265, 0.036))
	_text(face, "NOW £0.27p", Vector3(0.05, -0.51, 0.06), 140, INK)


static func _band(face: Node3D, center: Vector2, size: Vector2) -> void:
	var r := size.y * 0.5
	var depth := 0.04
	Build.box(face, Vector3(size.x - size.y, size.y, depth), YELLOW, Vector3(center.x, center.y, depth * 0.5))
	for end: float in [-1.0, 1.0]:
		Build.cyl(face, r, r, depth, YELLOW, Vector3(center.x + end * (size.x - size.y) * 0.5, center.y, depth * 0.5), Vector3(90, 0, 0), 16)


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
