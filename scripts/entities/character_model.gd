class_name CharacterModel
extends Node3D
## Chunky big-headed character built from boxes. Used for players, zombies and bosses.

var head: Node3D
var torso: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hat_slot: Node3D
var hand_r: Node3D  # Where held items attach.
var zombie := false
var _phase := 0.0
var _swing := 0.0
var _propeller: Node3D


func setup(skin: Color, shirt: Color, pants: Color, is_zombie: bool, belly := 1.0, hat := "none") -> void:
	zombie = is_zombie
	for c in get_children():
		c.queue_free()
	var hips := Node3D.new()
	hips.position = Vector3(0, 0.8, 0)
	add_child(hips)

	leg_l = _limb(hips, Vector3(-0.15, 0, 0), Vector3(0.22, 0.8, 0.24), pants, Color(0.2, 0.15, 0.12))
	leg_r = _limb(hips, Vector3(0.15, 0, 0), Vector3(0.22, 0.8, 0.24), pants, Color(0.2, 0.15, 0.12))

	torso = Node3D.new()
	hips.add_child(torso)
	var tw := 0.62 * belly
	Build.box(torso, Vector3(tw, 0.7, 0.38 * belly), shirt, Vector3(0, 0.35, 0))
	if belly > 1.2:
		Build.sphere(torso, 0.36 * belly, shirt, Vector3(0, 0.3, 0.12 * belly), Vector3(1, 0.9, 0.9))
	if zombie:
		# Torn shirt patch + exposed ribs
		Build.box(torso, Vector3(0.2, 0.18, 0.02), skin.darkened(0.25), Vector3(0.12, 0.2, 0.19 * belly + 0.01))
		Build.box(torso, Vector3(0.16, 0.03, 0.02), Color(0.9, 0.88, 0.8), Vector3(0.12, 0.24, 0.2 * belly + 0.01))
		Build.box(torso, Vector3(0.16, 0.03, 0.02), Color(0.9, 0.88, 0.8), Vector3(0.12, 0.17, 0.2 * belly + 0.01))

	var sh := tw * 0.5 + 0.1
	arm_l = _limb(torso, Vector3(-sh, 0.65, 0), Vector3(0.18, 0.66, 0.2), shirt, skin)
	arm_r = _limb(torso, Vector3(sh, 0.65, 0), Vector3(0.18, 0.66, 0.2), shirt, skin)
	hand_r = Node3D.new()
	hand_r.position = Vector3(0, -0.62, 0.05)
	arm_r.add_child(hand_r)

	head = Node3D.new()
	head.position = Vector3(0, 0.72, 0)
	torso.add_child(head)
	Build.box(head, Vector3(0.52, 0.5, 0.5), skin, Vector3(0, 0.25, 0))
	if zombie:
		# Googly mismatched eyes, stitched mouth, a little brain poking out.
		Build.sphere(head, 0.1, Color.WHITE, Vector3(-0.12, 0.3, 0.25))
		Build.sphere(head, 0.07, Color.WHITE, Vector3(0.13, 0.28, 0.25))
		Build.sphere(head, 0.04, Color(0.85, 0.1, 0.1), Vector3(-0.1, 0.28, 0.33))
		Build.sphere(head, 0.03, Color(0.1, 0.1, 0.1), Vector3(0.14, 0.27, 0.31))
		Build.box(head, Vector3(0.3, 0.06, 0.02), Color(0.25, 0.1, 0.1), Vector3(0, 0.1, 0.26))
		for i in 4:
			Build.box(head, Vector3(0.015, 0.1, 0.02), Color(0.9, 0.9, 0.85), Vector3(-0.1 + i * 0.07, 0.1, 0.27))
		Build.sphere(head, 0.14, Color(0.95, 0.55, 0.6), Vector3(0.1, 0.5, -0.05), Vector3(1.2, 0.6, 1.0))
	else:
		Build.box(head, Vector3(0.08, 0.1, 0.02), Color(0.08, 0.08, 0.1), Vector3(-0.11, 0.3, 0.26))
		Build.box(head, Vector3(0.08, 0.1, 0.02), Color(0.08, 0.08, 0.1), Vector3(0.11, 0.3, 0.26))
		Build.box(head, Vector3(0.2, 0.04, 0.02), Color(0.5, 0.15, 0.15), Vector3(0, 0.13, 0.26))
		Build.box(head, Vector3(0.1, 0.08, 0.06), skin.darkened(0.1), Vector3(0, 0.22, 0.27))
	hat_slot = Node3D.new()
	hat_slot.position = Vector3(0, 0.5, 0)
	head.add_child(hat_slot)
	set_hat(hat)


func _limb(parent: Node3D, pivot: Vector3, size: Vector3, color: Color, end_color: Color) -> Node3D:
	var p := Node3D.new()
	p.position = pivot
	parent.add_child(p)
	Build.box(p, size, color, Vector3(0, -size.y * 0.5, 0))
	Build.box(p, Vector3(size.x * 1.05, size.y * 0.22, size.z * 1.05), end_color, Vector3(0, -size.y * 0.9, 0))
	return p


func set_hat(hat: String) -> void:
	if hat_slot == null:
		return
	for c in hat_slot.get_children():
		c.queue_free()
	_propeller = null
	var h := hat_slot
	match hat:
		"bucket":
			Build.cyl(h, 0.24, 0.3, 0.22, Color(0.85, 0.8, 0.6), Vector3(0, 0.1, 0))
			Build.cyl(h, 0.42, 0.42, 0.03, Color(0.8, 0.75, 0.55), Vector3(0, 0.0, 0))
		"cone":
			Build.cyl(h, 0.02, 0.24, 0.6, Color(1.0, 0.45, 0.1), Vector3(0, 0.3, 0))
			Build.cyl(h, 0.13, 0.17, 0.08, Color.WHITE, Vector3(0, 0.3, 0))
			Build.box(h, Vector3(0.55, 0.04, 0.55), Color(1.0, 0.45, 0.1), Vector3(0, 0.0, 0))
		"viking":
			Build.sphere(h, 0.3, Color(0.6, 0.6, 0.65), Vector3(0, 0.0, 0), Vector3(1, 0.7, 1))
			Build.cyl(h, 0.0, 0.07, 0.35, Color(0.95, 0.92, 0.8), Vector3(-0.3, 0.15, 0), Vector3(0, 0, 50))
			Build.cyl(h, 0.0, 0.07, 0.35, Color(0.95, 0.92, 0.8), Vector3(0.3, 0.15, 0), Vector3(0, 0, -50))
		"crown":
			Build.cyl(h, 0.24, 0.24, 0.14, Color(1.0, 0.8, 0.15), Vector3(0, 0.07, 0), Vector3.ZERO, 8)
			for i in 6:
				var a := TAU * i / 6.0
				Build.cyl(h, 0.0, 0.05, 0.14, Color(1.0, 0.8, 0.15), Vector3(cos(a) * 0.22, 0.2, sin(a) * 0.22))
			Build.sphere(h, 0.04, Color(0.9, 0.1, 0.2), Vector3(0, 0.08, 0.25))
		"propeller":
			Build.sphere(h, 0.27, Color(0.2, 0.5, 0.95), Vector3(0, 0.0, 0), Vector3(1, 0.5, 1))
			Build.cyl(h, 0.02, 0.02, 0.16, Color(0.2, 0.2, 0.2), Vector3(0, 0.16, 0))
			_propeller = Node3D.new()
			_propeller.position = Vector3(0, 0.24, 0)
			h.add_child(_propeller)
			Build.box(_propeller, Vector3(0.5, 0.02, 0.08), Color(1.0, 0.85, 0.2))
			Build.box(_propeller, Vector3(0.08, 0.02, 0.5), Color(0.95, 0.25, 0.25))
		"chef":
			Build.cyl(h, 0.24, 0.24, 0.3, Color.WHITE, Vector3(0, 0.15, 0))
			Build.sphere(h, 0.3, Color.WHITE, Vector3(0, 0.36, 0), Vector3(1, 0.6, 1))
		"party":
			Build.cyl(h, 0.0, 0.18, 0.45, Color(0.9, 0.3, 0.8), Vector3(0, 0.22, 0))
			Build.sphere(h, 0.06, Color(1.0, 0.9, 0.2), Vector3(0, 0.46, 0))
		"pot":
			Build.cyl(h, 0.3, 0.27, 0.25, Color(0.55, 0.57, 0.6), Vector3(0, 0.1, 0))
			Build.box(h, Vector3(0.5, 0.05, 0.08), Color(0.2, 0.2, 0.2), Vector3(0.45, 0.15, 0))
		"santa":
			Build.cyl(h, 0.28, 0.28, 0.08, Color.WHITE, Vector3(0, 0.02, 0))
			Build.cyl(h, 0.02, 0.26, 0.45, Color(0.85, 0.1, 0.12), Vector3(0.05, 0.25, -0.05), Vector3(-25, 0, -10))
			Build.sphere(h, 0.08, Color.WHITE, Vector3(0.12, 0.43, -0.2))
			Build.box(h, Vector3(0.5, 0.3, 0.12), Color.WHITE, Vector3(0, -0.45, 0.26))  # beard
		"captain":
			Build.cyl(h, 0.32, 0.27, 0.15, Color(0.1, 0.15, 0.35), Vector3(0, 0.07, 0))
			Build.box(h, Vector3(0.4, 0.03, 0.2), Color(0.05, 0.05, 0.08), Vector3(0, 0.0, 0.25))
			Build.sphere(h, 0.05, Color(1.0, 0.85, 0.2), Vector3(0, 0.09, 0.3))
		"goggles":
			Build.box(h, Vector3(0.5, 0.14, 0.1), Color(0.15, 0.15, 0.2), Vector3(0, -0.2, 0.25))
			Build.box(h, Vector3(0.18, 0.1, 0.04), Color(0.5, 0.85, 1.0, 0.7), Vector3(-0.11, -0.2, 0.31))
			Build.box(h, Vector3(0.18, 0.1, 0.04), Color(0.5, 0.85, 1.0, 0.7), Vector3(0.11, -0.2, 0.31))
			Build.cyl(h, 0.03, 0.03, 0.5, Color(1.0, 0.8, 0.1), Vector3(0.3, -0.1, 0.1))


## speed: horizontal m/s. attack: 0..1 swing. downed: lying on the ground.
func animate(delta: float, speed: float, attack: float = 0.0, downed := false) -> void:
	if leg_l == null:
		return
	if _propeller:
		_propeller.rotate_y(delta * (6.0 + speed * 6.0))
	_phase += delta * (2.0 + speed * 2.2)
	var amp: float = clamp(speed / 4.0, 0.0, 1.0) * 0.8
	var s := sin(_phase)
	leg_l.rotation.x = s * amp
	leg_r.rotation.x = -s * amp
	_swing = lerp(_swing, attack, clampf(delta * 20.0, 0.0, 1.0))
	if zombie:
		# Arms out front, wobbling. Attack is a big double slam.
		var reach := -1.45 + sin(_phase * 0.7) * 0.12
		arm_l.rotation.x = reach - _swing * 0.9 + sin(_swing * PI) * -1.2
		arm_r.rotation.x = reach + cos(_phase * 0.6) * 0.1 - _swing * 0.9 + sin(_swing * PI) * -1.2
		head.rotation.z = sin(_phase * 0.5) * 0.15
		torso.rotation.x = 0.15 + _swing * 0.3
	else:
		arm_l.rotation.x = -s * amp * 0.8
		arm_r.rotation.x = s * amp * 0.8 - _swing * 1.6
		torso.rotation.x = 0.0
	rotation.x = lerp(rotation.x, -PI * 0.5 if downed else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	position.y = lerp(position.y, 0.25 if downed else 0.0, clampf(delta * 8.0, 0.0, 1.0))
