class_name CharacterModel
extends Node3D
## Rounded comic characters with authored silhouettes, facial forms and procedural node rigs.

var kind := "survivor"
var head: Node3D
var torso: Node3D
var hips: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hand_r: Node3D  # Where held items attach.
var mouth: Node3D   # Where tongues and vomit come from.
var _phase := 0.0
var _time := 0.0
var _eyes: Array[Node3D] = []
var _tail: Node3D
var _swing := 0.0
var _hip_h := 0.8
var _lie := 0.0
var _skin := Color.WHITE


func setup_survivor(i: int) -> void:
	var s: Dictionary = DB.SURVIVORS[i]
	_body(s.skin, s.shirt, s.pants, Vector3(0.62, 0.7, 0.38), 1.0, 1.0)
	_face_survivor()
	_survivor_hair(s.hat, s.hat_color)
	_survivor_details(i, s)


func setup_infected(type: String, seed_v: int) -> void:
	kind = type
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pale := Color(0.55, 0.6, 0.5).lerp(Color(0.62, 0.58, 0.55), rng.randf())
	match type:
		"boomer":
			_body(Color(0.62, 0.62, 0.4), Color(0.55, 0.5, 0.35), Color(0.3, 0.28, 0.25), Vector3(1.1, 0.8, 0.8), 1.0, 1.0)
			Build.sphere(torso, 0.62, Color(0.66, 0.65, 0.42), Vector3(0, 0.3, 0.22), Vector3(1.0, 0.95, 0.9))
			for k in 7:
				var a := rng.randf() * TAU
				Build.sphere(torso, rng.randf_range(0.08, 0.16), Color(0.75, 0.55, 0.4), Vector3(cos(a) * 0.5, 0.3 + rng.randf_range(-0.3, 0.3), 0.35 + sin(a) * 0.2))
			_face_infected(Color(0.9, 0.85, 0.3))
		"hunter":
			_body(pale, Color(0.18, 0.2, 0.24), Color(0.15, 0.15, 0.18), Vector3(0.58, 0.7, 0.36), 1.0, 1.0)
			_face_infected(Color(1.0, 0.25, 0.15))
			ArtShapes.oval(head, Vector3(0.70, 0.68, 0.64), Color(0.15, 0.17, 0.2), Vector3(0, 0.29, -0.03))  # hood
			ArtShapes.oval(head, Vector3(0.48, 0.37, 0.08), Color(0.05, 0.05, 0.06), Vector3(0, 0.25, 0.28))
			for hand in [arm_l, arm_r]:
				for k in 3:
					Build.box(hand, Vector3(0.03, 0.18, 0.03), Color(0.85, 0.85, 0.75), Vector3(-0.06 + k * 0.06, -0.85, 0.06))
		"smoker":
			_body(Color(0.5, 0.45, 0.4), Color(0.4, 0.35, 0.3), Color(0.25, 0.22, 0.2), Vector3(0.5, 0.85, 0.32), 1.25, 1.2)
			_face_infected(Color(1.0, 0.3, 0.2))
			for k in 6:
				Build.sphere(head, rng.randf_range(0.06, 0.12), Color(0.55, 0.25, 0.2), Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.1, 0.45), 0.24))
			for k in 4:
				Build.sphere(torso, rng.randf_range(0.06, 0.11), Color(0.55, 0.25, 0.2), Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.1, 0.6), 0.18))
		"spitter":
			_body(Color(0.55, 0.6, 0.35), Color(0.3, 0.35, 0.2), Color(0.2, 0.22, 0.15), Vector3(0.5, 0.7, 0.32), 1.05, 1.0)
			head.position.y += 0.3
			Build.box(torso, Vector3(0.16, 0.36, 0.16), Color(0.55, 0.6, 0.35), Vector3(0, 0.88, 0))
			_face_infected(Color(0.6, 1.0, 0.2))
			Build.box(head, Vector3(0.3, 0.18, 0.04), Color(0.5, 1.0, 0.2), Vector3(0, 0.08, 0.26), Vector3.ZERO).material_override = Build.mat(Color(0.5, 1.0, 0.2), 0.5, 2.5)
		"tank":
			_body(Color(0.6, 0.5, 0.48), Color(0.6, 0.5, 0.48), Color(0.22, 0.2, 0.25), Vector3(1.5, 0.9, 0.9), 1.0, 0.9, 2.0)
			_face_infected(Color(1.0, 0.2, 0.1))
			head.scale = Vector3(0.75, 0.75, 0.75)
			head.position = Vector3(0, 0.8, 0.25)
			for k in 8:
				Build.sphere(torso, rng.randf_range(0.12, 0.25), Color(0.55, 0.42, 0.4), Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.2, 0.8), rng.randf_range(-0.4, 0.4)))
		"witch":
			_body(Color(0.92, 0.9, 0.88), Color(0.75, 0.72, 0.7), Color(0.75, 0.72, 0.7), Vector3(0.44, 0.7, 0.28), 1.0, 1.0)
			_face_infected(Color(1.0, 0.85, 0.6))
			ArtShapes.oval(head, Vector3(0.65, 0.80, 0.28), Color(0.95, 0.95, 0.92), Vector3(0, 0.1, -0.22))  # hair
			ArtShapes.oval(head, Vector3(0.66, 0.3, 0.58), Color(0.95, 0.95, 0.92), Vector3(0, 0.5, 0))
			for hand in [arm_l, arm_r]:
				for k in 3:
					var claw := Build.box(hand, Vector3(0.025, 0.4, 0.025), Color(0.95, 0.9, 0.85), Vector3(-0.05 + k * 0.05, -0.95, 0.05))
					claw.rotation.x = 0.2
		_:  # common
			var shirts := [Color(0.35, 0.3, 0.25), Color(0.25, 0.3, 0.38), Color(0.45, 0.2, 0.18), Color(0.4, 0.4, 0.38), Color(0.2, 0.28, 0.2), Color(0.55, 0.5, 0.4), Color(0.6, 0.6, 0.62)]
			var pants := [Color(0.2, 0.22, 0.3), Color(0.3, 0.25, 0.2), Color(0.15, 0.15, 0.17), Color(0.35, 0.33, 0.3)]
			var belly := rng.randf_range(0.9, 1.15)
			_body(pale, shirts[rng.randi() % shirts.size()], pants[rng.randi() % pants.size()], Vector3(0.6 * belly, 0.7, 0.36 * belly), rng.randf_range(0.95, 1.08), 1.0)
			_face_infected(Color(1.0, 0.3, 0.2))
			ArtShapes.oval(torso,Vector3(0.22,0.18,0.035),pale.darkened(0.14),Vector3(0.12,0.25,0.21))
			for k in 3:
				ArtShapes.link(torso,Vector3(0.02+k*0.065,0.35,0.23),Vector3(0.04+k*0.065,0.27,0.24),0.018,shirts[seed_v%shirts.size()])
			ArtShapes.oval(torso,Vector3(0.12,0.10,0.02),Color(0.47,0.15,0.12),Vector3(-0.16,0.43,0.19))



func _body(skin: Color, shirt: Color, pants: Color, torso_size: Vector3, height := 1.0, legs := 1.0, arms := 1.0) -> void:
	for child in get_children(): child.queue_free()
	_skin = skin
	_eyes.clear()
	_tail = null
	_hip_h = 0.8 * legs * height
	hips = Node3D.new()
	hips.position.y = _hip_h
	add_child(hips)
	var lh := 0.8 * legs * height
	leg_l = _limb(hips, Vector3(-torso_size.x * 0.24, 0, 0), Vector3(0.26, lh, 0.27), pants, skin, true)
	leg_r = _limb(hips, Vector3(torso_size.x * 0.24, 0, 0), Vector3(0.26, lh, 0.27), pants, skin, true)
	torso = Node3D.new()
	hips.add_child(torso)
	var th := torso_size.y * height
	var w := torso_size.x * 0.5
	var d := torso_size.z * 0.5
	ArtShapes.loft(torso, [Vector4(-0.04,w*0.72,d*0.8,0),Vector4(0.02,w*0.96,d,0),Vector4(th*0.23,w*1.05,d*1.14,0.015),Vector4(th*0.6,w,d,0),Vector4(th*0.86,w*1.08,d*0.9,0),Vector4(th,w*0.60,d*0.70,0),Vector4(th+0.015,0.01,0.01,0)], shirt)
	var sh := w + 0.05 * arms
	var arm_size := Vector3(0.20 * arms, 0.66 * height * (1.0 + (arms-1.0)*0.3), 0.22 * arms)
	arm_l = _limb(torso, Vector3(-sh,th*0.86,0), arm_size, shirt if arms<=1 else skin, skin)
	arm_r = _limb(torso, Vector3(sh,th*0.86,0), arm_size, shirt if arms<=1 else skin, skin)
	hand_r = Node3D.new()
	hand_r.position = Vector3(0,-arm_size.y*0.95,0.045)
	arm_r.add_child(hand_r)
	ArtShapes.oval(torso, Vector3(w*1.7,0.07,d*1.9), shirt.darkened(0.25), Vector3(0,0.04,0))
	ArtShapes.oval(torso, Vector3(0.18,0.18,0.17), skin, Vector3(0,th,0))
	head = Node3D.new()
	head.position = Vector3(0,th+0.02,0)
	torso.add_child(head)
	# Cheekbones, tapering jaw and a high round cranium, not a scaled cube.
	ArtShapes.loft(head,[Vector4(-0.02,0.08,0.11,0.025),Vector4(0.03,0.22,0.21,0.035),Vector4(0.16,0.29,0.25,0.015),Vector4(0.32,0.325,0.255,0),Vector4(0.46,0.31,0.24,-0.015),Vector4(0.57,0.23,0.19,-0.025),Vector4(0.63,0.08,0.08,-0.025),Vector4(0.64,0.001,0.001,-0.025)],skin)
	for side: float in [-1,1]:
		ArtShapes.oval(head,Vector3(0.13,0.22,0.12),skin,Vector3(side*0.31,0.27,0))
		ArtShapes.oval(head,Vector3(0.065,0.12,0.035),skin.darkened(0.22),Vector3(side*0.352,0.27,0.04))
	mouth = Node3D.new()
	mouth.position = Vector3(0,0.10,0.30)
	head.add_child(mouth)


func _limb(parent: Node3D, pivot: Vector3, size: Vector3, color: Color, skin: Color, leg := false) -> Node3D:
	var joint := Node3D.new()
	joint.position = pivot
	parent.add_child(joint)
	var r := size.x*0.49
	var h := size.y
	ArtShapes.link(joint,Vector3(0,-r*0.4,0),Vector3(0,-h*0.43,0.01),r,color)
	ArtShapes.link(joint,Vector3(0,-h*0.42,0.01),Vector3(0,-h*0.80,0.035),r*0.83,color if leg else skin)
	ArtShapes.oval(joint,Vector3(size.x*1.05,0.07,size.z*1.03),color.lightened(0.08),Vector3(0,-h*0.5,0.015))
	if leg:
		var leather := Color(0.23,0.12,0.075)
		ArtShapes.oval(joint,Vector3(size.x*1.15,0.24,size.z*1.55),leather,Vector3(0,-h+0.12,0.07))
		ArtShapes.oval(joint,Vector3(size.x*1.20,0.075,size.z*1.6),Color(0.075,0.09,0.09),Vector3(0,-h+0.025,0.08))
		for y: float in [-h+0.12,-h+0.17]:
			ArtShapes.link(joint,Vector3(-r*0.55,y,0.18),Vector3(r*0.55,y,0.18),0.012,Color(0.76,0.64,0.42))
	else:
		ArtShapes.oval(joint,Vector3(size.x*0.95,0.17,size.z*0.8),skin,Vector3(0,-h*0.91,0.04))
		ArtShapes.oval(joint,Vector3(0.08,0.12,0.09),skin,Vector3(r*0.8,-h*0.88,0.08),Vector3(0,0,-25))
		for i in 3:
			ArtShapes.link(joint,Vector3(-r*0.5+i*r*0.5,-h*0.94,0.09),Vector3(-r*0.5+i*r*0.5,-h*1.01,0.08),0.021,skin.darkened(0.04))
	return joint


func _eye(pos: Vector3, size: Vector3, pupil: Color, tilt := 0.0) -> void:
	var eye := Node3D.new()
	eye.position = pos
	eye.rotation.z = tilt
	head.add_child(eye)
	ArtShapes.oval(eye,size,Color(0.97,0.94,0.80))
	ArtShapes.oval(eye,Vector3(size.x*0.40,size.y*0.63,0.025),pupil,Vector3(0,-size.y*0.03,size.z*0.47))
	ArtShapes.oval(eye,Vector3(0.018,0.023,0.009),Color.WHITE,Vector3(-0.012,0.025,size.z*0.56))
	_eyes.append(eye)


func _face_survivor() -> void:
	_eye(Vector3(-0.122,0.335,0.218),Vector3(0.17,0.20,0.13),Color(0.09,0.15,0.16),-0.08)
	_eye(Vector3(0.122,0.335,0.218),Vector3(0.17,0.20,0.13),Color(0.09,0.15,0.16),0.08)
	ArtShapes.oval(head,Vector3(0.17,0.16,0.25),_skin.lightened(0.07),Vector3(0,0.23,0.31),Vector3(-8,0,0))
	for x: float in [-0.045,0.045]:
		ArtShapes.oval(head,Vector3(0.024,0.016,0.013),Color(0.28,0.13,0.10),Vector3(x,0.185,0.41))
	ArtShapes.oval(head,Vector3(0.19,0.054,0.045),Color(0.25,0.10,0.08),Vector3(0,0.085,0.256),Vector3(0,0,-8))
	ArtShapes.oval(head,Vector3(0.10,0.024,0.015),Color(0.92,0.84,0.68),Vector3(0.01,0.10,0.280),Vector3(0,0,-8))
	for side: float in [-1,1]:
		ArtShapes.link(head,Vector3(side*0.055,0.455,0.238),Vector3(side*0.20,0.445,0.19),0.026,Color(0.20,0.13,0.085))
		ArtShapes.oval(head,Vector3(0.12,0.055,0.025),Color(0.74,0.31,0.22),Vector3(side*0.21,0.19,0.224))


func _face_infected(_eye_color: Color) -> void:
	_eye(Vector3(-0.13,0.35,0.23),Vector3(0.22,0.25,0.18),Color(0.24,0.075,0.025),-0.20)
	_eye(Vector3(0.13,0.31,0.24),Vector3(0.19,0.21,0.16),Color(0.24,0.075,0.025),0.15)
	ArtShapes.oval(head,Vector3(0.20,0.17,0.26),Color(0.47,0.56,0.28),Vector3(-0.025,0.20,0.32),Vector3(0,0,-15))
	ArtShapes.oval(head,Vector3(0.32,0.15,0.17),Color(0.36,0.43,0.23),Vector3(0.035,0.035,0.235),Vector3(0,0,-12))
	ArtShapes.oval(head,Vector3(0.28,0.11,0.09),Color(0.20,0.055,0.055),Vector3(0.025,0.095,0.282),Vector3(0,0,-12))
	for i in 4:
		var tooth := ArtShapes.oval(head,Vector3(0.045,0.07 if i%2==0 else 0.05,0.034),Color(0.9,0.83,0.56),Vector3(-0.09+i*0.07,0.10,0.325),Vector3(0,0,-10+i*6))
		tooth.name = "CrookedTooth%d" % i
	ArtShapes.oval(head,Vector3(0.08,0.07,0.09),Color(0.68,0.25,0.24),Vector3(0.06,0.04,0.33),Vector3(0,0,-12))
	ArtShapes.link(head,Vector3(-0.24,0.47,0.17),Vector3(-0.07,0.48,0.23),0.03,Color(0.24,0.29,0.13))
	for i in 5:
		var tuft := ArtShapes.loft(head,[Vector4(0,0.05,0.04,0),Vector4(0.10,0.035,0.025,0),Vector4(0.17,0.001,0.001,0)],Color(0.19,0.22,0.11),Vector3(-0.20+i*0.085,0.51,-0.04))
		tuft.rotation.z = deg_to_rad(-18+i*9)


func _survivor_hair(style: String, color: Color) -> void:
	match style:
		"cap":
			ArtShapes.oval(head,Vector3(0.68,0.28,0.58),color,Vector3(0,0.54,-0.04))
			ArtShapes.oval(head,Vector3(0.59,0.055,0.43),color.darkened(0.15),Vector3(0,0.48,0.28),Vector3(-8,0,0))
			ArtShapes.oval(head,Vector3(0.13,0.11,0.018),Color(0.95,0.82,0.47),Vector3(0,0.57,0.25))
			ArtShapes.oval(head,Vector3(0.46,0.13,0.12),Color(0.29,0.18,0.10),Vector3(0,0.07,0.22))
		"ponytail":
			ArtShapes.oval(head,Vector3(0.65,0.30,0.56),color,Vector3(0,0.51,-0.04))
			_tail = ArtShapes.link(head,Vector3(0,0.40,-0.25),Vector3(0,0.12,-0.42),0.105,color)
			ArtShapes.oval(head,Vector3(0.25,0.19,0.12),color,Vector3(-0.15,0.48,0.21),Vector3(0,0,25))
		"bandana":
			ArtShapes.oval(head,Vector3(0.67,0.17,0.57),color,Vector3(0,0.49,-0.02))
			ArtShapes.link(head,Vector3(0.18,0.45,-0.26),Vector3(0.24,0.23,-0.39),0.05,color)
		"beanie":
			ArtShapes.oval(head,Vector3(0.69,0.35,0.59),color,Vector3(0,0.55,-0.03))
			ArtShapes.oval(head,Vector3(0.71,0.12,0.61),color.darkened(0.18),Vector3(0,0.46,-0.02))
			ArtShapes.oval(head,Vector3(0.15,0.14,0.15),color,Vector3(0,0.75,-0.03))


func _survivor_details(i: int, data: Dictionary) -> void:
	var cloth: Color = data.shirt
	for side: float in [-1,1]:
		ArtShapes.oval(torso,Vector3(0.22,0.16,0.055),cloth.darkened(0.16),Vector3(side*0.17,0.36,0.19),Vector3(0,0,-side*7))
		ArtShapes.link(torso,Vector3(side*0.06,0.61,0.13),Vector3(side*0.17,0.49,0.20),0.045,cloth.lightened(0.18))
		ArtShapes.oval(torso,Vector3(0.027,0.027,0.018),Color(0.72,0.58,0.32),Vector3(side*0.17,0.40,0.222))
	ArtShapes.link(torso,Vector3(0,0.08,0.218),Vector3(0,0.54,0.178),0.012,Color(0.78,0.64,0.36))
	ArtShapes.oval(torso,Vector3(0.40,0.49,0.24),Color(0.47,0.29,0.15),Vector3(0,0.34,-0.25))
	for side: float in [-1,1]:
		ArtShapes.link(torso,Vector3(side*0.18,0.10,-0.21),Vector3(side*0.22,0.62,-0.05),0.035,Color(0.31,0.20,0.12))
	if i == 0:
		ArtShapes.oval(arm_l,Vector3(0.06,0.13,0.15),Color(0.66,0.17,0.11),Vector3(-0.10,-0.20,0.02))
		ArtShapes.oval(leg_r,Vector3(0.19,0.12,0.035),Color(0.71,0.65,0.43),Vector3(0,-0.42,0.135),Vector3(0,0,12))
		for x: float in [-0.08,0,0.08]:
			ArtShapes.oval(head,Vector3(0.024,0.020,0.012),Color(0.23,0.14,0.08),Vector3(x,0.025,0.22))


## speed: horizontal m/s. attack: 0..1 swing.
## pose: "", "crouch", "down" (lying), "sit" (witch), "stagger", "pounce", "vomit", "aim"
func animate(delta: float, speed: float, attack := 0.0, pose := "", reload := -1.0, action := 0.0, shot := 0.0) -> void:
	if leg_l == null or pose == "dead":
		return
	_time += delta
	_phase += delta * (2.0 + speed * 2.2)
	var alive := pose not in ["dead", "down"]
	var breath := sin(_time * (2.0 if kind == "survivor" else 2.8)) if alive else 0.0
	var idle := 1.0 - clampf(speed / 2.0, 0, 1)
	var amp := clampf(speed / 4.0, 0.0, 1.0) * 0.8
	var s := sin(_phase)
	var k := 1.0 - exp(-delta * 12.0)
	leg_l.rotation = Vector3(s * amp, 0, 0)
	leg_r.rotation = Vector3(-s * amp, 0, 0)
	_swing = lerpf(_swing, attack, 1.0 - exp(-delta * 20.0))
	var crouch := pose in ["crouch", "pounce", "sit", "revive"]
	var hip_goal := _hip_h * (0.55 if crouch else 1.0)
	hips.position.y = lerpf(hips.position.y, hip_goal + absf(cos(_phase)) * amp * 0.035 + breath * 0.008, k)
	hips.rotation = Vector3(0, sin(_phase) * amp * 0.045, sin(_time * 0.9) * 0.025 * idle if alive else 0.0)
	torso.scale = Vector3(1.0 + breath * 0.007, 1.0 + breath * 0.008, 1.0 + breath * 0.016)
	torso.rotation.y = sin(_phase) * amp * -0.055
	head.rotation = Vector3(breath * 0.018, sin(_time * 0.65) * 0.12 * idle, sin(_time * 0.85) * 0.025 * idle) if alive else Vector3.ZERO
	arm_l.rotation = Vector3.ZERO
	arm_r.rotation = Vector3.ZERO
	if _tail:
		_tail.rotation = Vector3(sin(_phase + 0.7) * (amp * 0.18 + 0.03), 0, sin(_time * 1.7) * 0.06)
	for eye in _eyes:
		var blink := pow(maxf(0.0, sin(_time * 1.7 + 1.5)), 40.0)
		eye.scale.y = 1.0 - blink * 0.92 if alive else 0.1
	if crouch:
		leg_l.rotation.x = -1.0 + s * amp * 0.3
		leg_r.rotation.x = -1.0 - s * amp * 0.3
	var lean := breath * 0.012
	if kind == "survivor":
		var armed := pose in ["aim", "ready", "reload", "inspect"]
		arm_l.rotation.x = (-1.15 if pose == "aim" else -0.85) if armed else -s * amp * 0.8 + breath * 0.025
		arm_r.rotation.x = ((-1.35 if pose == "aim" else -1.05) if armed else s * amp * 0.8) - _swing * 1.4 - shot * 0.16
		arm_l.rotation.z = 0.85 if armed else -0.035
		arm_r.rotation.z = -0.20 if armed else 0.035
		if pose == "reload":
			arm_r.rotation.x = -1.0
			arm_r.rotation.z = -0.3
			arm_l.rotation.x = -0.9 + sin(reload * TAU * 1.5) * 0.5
			arm_l.rotation.z = -0.2 - sin(reload * PI) * 0.5
			head.rotation.x = 0.17
		elif pose == "inspect":
			arm_r.rotation.z = -0.5
			arm_l.rotation.x = -0.6 + sin(_time * 3) * 0.2
			head.rotation.x = 0.18
		elif pose in ["revive", "heal"]:
			lean = 0.25 if pose == "revive" else 0.1
			arm_l.rotation.x = -1.0 + sin(_time * 7) * 0.12
			arm_r.rotation.x = -1.1 - sin(_time * 7) * 0.12
			arm_l.rotation.z = -0.15
			arm_r.rotation.z = 0.15
			head.rotation.x = 0.3
		elif pose == "ready" and speed < 0.1:
			# A small weight shift and grip adjustment between breaths.
			arm_l.rotation.x += pow(maxf(0, sin(_time * 0.9)), 8) * 0.1
	elif pose == "sit":
		arm_l.rotation = Vector3(-2.2 + sin(_time * 5) * 0.04, 0, 0.5)
		arm_r.rotation = Vector3(-2.2 - sin(_time * 5) * 0.04, 0, -0.5)
		lean = 0.6 + sin(_time * 3.5) * 0.07
		head.rotation.x = 0.5 + sin(_time * 6.0) * 0.06
	else:
		var reach := -1.3 + sin(_phase * 1.3) * 0.35 * amp
		arm_l.rotation.x = reach - _swing * 0.9 - sin(_swing * PI) * 1.2 + breath * idle * 0.06
		arm_r.rotation.x = reach - cos(_phase * 1.1) * 0.3 * amp - _swing * 0.9 - sin(_swing * PI) * 1.2 - breath * idle * 0.06
		head.rotation.z += sin(_phase * 0.5) * 0.10
		lean = 0.25 + amp * 0.2 + _swing * 0.3 + breath * 0.025
		if kind == "tank":
			lean = 0.4 + _swing * 0.4 + breath * 0.04
			arm_l.rotation.z = 0.13 + breath * 0.035
			arm_r.rotation.z = -0.13 - breath * 0.035
		if pose == "vomit":
			lean = 0.5 + sin(_time * 16) * 0.04
			head.rotation.x = -0.4 + sin(_time * 18) * 0.03
	if pose == "stagger":
		lean = -0.5 + sin(_time * 10) * 0.08
		arm_l.rotation.z = 0.5
		arm_r.rotation.z = -0.5
	torso.rotation.x = lerpf(torso.rotation.x, lean, k)
	_lie = lerpf(_lie, 1.0 if pose == "down" else 0.0, 1.0 - exp(-delta * 8.0))
	rotation.x = -PI * 0.5 * _lie
	position.y = 0.25 * _lie
