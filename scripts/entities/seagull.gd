class_name Seagull
extends Node3D
## A seagull. Pecks about on the ground, bolts when a survivor or an infected comes close, wheels
## overhead for a while and lands back where it started. Sky gulls just circle. Purely local
## scenery: nothing is networked, and gulls far from the camera stop animating.

const SCARE := 9.0
const AWAKE := 170.0
enum { GROUND, CIRCLE, LAND }

var home := Vector3.ZERO
var sky := false
var _state := GROUND
var _rng := RandomNumberGenerator.new()
var _check := 0.0
var _awake := false
var _t := 0.0
var _phase := 0.0
var _orbit := Vector3.ZERO
var _radius := 14.0
var _speed := 7.0
var _airborne := 0.0
var _peck := 0.0
var _goal := Vector3.ZERO
var _wings: Array[Node3D] = []
var _head: Node3D


static func spawn(parent: Node3D, pos: Vector3, seed: int, circling := false) -> Seagull:
	var g := Seagull.new()
	g.home = pos
	g.sky = circling
	g._rng.seed = seed
	g.position = pos
	parent.add_child(g)
	return g


func _ready() -> void:
	_build()
	rotation.y = _rng.randf() * TAU
	_phase = _rng.randf() * TAU
	_check = _rng.randf() * 0.3
	_goal = home
	if sky:
		_take_off(home, home.y)


func _build() -> void:
	var white := Color(0.97, 0.97, 0.95)
	var grey := Color(0.62, 0.66, 0.72)
	var orange := Color(0.98, 0.6, 0.15)
	scale = Vector3.ONE * 1.3
	Build.sphere(self, 0.17, white, Vector3(0, 0.3, 0), Vector3(1.0, 0.85, 1.9), 8)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.44, 0.27)
	add_child(_head)
	Build.sphere(_head, 0.1, white, Vector3.ZERO, Vector3.ONE, 8)
	Build.box(_head, Vector3(0.045, 0.045, 0.15), orange, Vector3(0, -0.02, 0.13))
	for x: float in [-0.055, 0.055]:
		Build.box(_head, Vector3(0.025, 0.025, 0.025), Color(0.05, 0.05, 0.05), Vector3(x, 0.03, 0.06))
		Build.box(self, Vector3(0.025, 0.2, 0.025), orange, Vector3(x, 0.1, 0.0))
	Build.box(self, Vector3(0.14, 0.04, 0.18), grey, Vector3(0, 0.32, -0.36))
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.13, 0.36, 0.02)
		add_child(pivot)
		Build.box(pivot, Vector3(0.5, 0.03, 0.24), grey, Vector3(side * 0.25, 0, 0))
		Build.box(pivot, Vector3(0.14, 0.032, 0.2), Color(0.12, 0.12, 0.14), Vector3(side * 0.55, 0, -0.02))
		pivot.set_meta("side", side)
		_wings.append(pivot)
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = AWAKE
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.3
		var cam := get_viewport().get_camera_3d()
		_awake = cam != null and cam.global_position.distance_squared_to(global_position) < AWAKE * AWAKE
		if _awake and _state == GROUND:
			var threat := _threat()
			if threat != Vector3.INF:
				_take_off(home + (home - threat).normalized() * 6.0, home.y + _rng.randf_range(8.0, 16.0))
	if not _awake:
		return
	_t += delta
	match _state:
		GROUND: _ground(delta)
		CIRCLE: _circle(delta)
		LAND: _land(delta)


func _threat() -> Vector3:
	for group in ["survivors", "infected"]:
		for n in get_tree().get_nodes_in_group(group):
			var p: Vector3 = (n as Node3D).global_position
			if absf(p.x - position.x) < SCARE and absf(p.z - position.z) < SCARE and p.distance_to(position) < SCARE:
				return p
	return Vector3.INF


func _ground(delta: float) -> void:
	_fold(delta)
	# Peck, look about, and now and then waddle a step or two.
	_peck -= delta
	if _peck <= 0.0:
		_peck = _rng.randf_range(0.8, 3.0)
		if _rng.randf() < 0.4:
			_goal = home + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
	var bob := maxf(sin(_t * 9.0 + _phase), 0.0) if fmod(_t + _phase, 4.0) < 1.2 else 0.0
	_head.rotation.x = bob * 0.9
	_head.position.y = 0.44 - bob * 0.12
	var to := _goal - position
	to.y = 0
	if to.length() > 0.1:
		var step := minf(to.length(), delta * 0.6)
		position += to.normalized() * step
		position.y = home.y + absf(sin(_t * 12.0)) * 0.03
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), delta * 6.0)


func _take_off(around: Vector3, altitude: float) -> void:
	_state = CIRCLE
	_orbit = Vector3(around.x, altitude, around.z)
	_radius = _rng.randf_range(10.0, 28.0)
	_speed = _rng.randf_range(6.0, 9.0)
	_airborne = 1e9 if sky else _rng.randf_range(7.0, 14.0)
	_phase = atan2(position.z - _orbit.z, position.x - _orbit.x)


func _circle(delta: float) -> void:
	_airborne -= delta
	_phase += delta * _speed / _radius
	var target := _orbit + Vector3(cos(_phase), sin(_phase * 0.7) * 0.15, sin(_phase)) * _radius
	target.y = _orbit.y + sin(_phase * 0.7) * 2.0
	var to := target - position
	position += to * minf(delta * 1.6, 1.0)
	_face(Vector3(-sin(_phase), 0, cos(_phase)), delta, 0.35)
	_flap(delta, 0.4 if to.y > 0.5 or _airborne > 1e8 and fmod(_t, 6.0) < 1.5 else 0.0)
	if _airborne <= 0.0 and _threat() == Vector3.INF:
		_state = LAND


func _land(delta: float) -> void:
	var to := home - position
	if to.length() < 0.3:
		position = home
		rotation.x = 0.0
		rotation.z = 0.0
		_state = GROUND
		return
	position += to.normalized() * minf(to.length(), delta * maxf(3.0, to.length() * 0.6))
	_face(Vector3(to.x, 0, to.z), delta, 0.0)
	_flap(delta, 0.3 if to.length() < 4.0 else 0.0)
	if _threat() != Vector3.INF:
		_take_off(home, home.y + 12.0)


func _face(dir: Vector3, delta: float, bank: float) -> void:
	if dir.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 4.0)
	rotation.z = lerpf(rotation.z, -bank, delta * 3.0)


## Wings spread; flapping when strength > 0, otherwise gliding with a lazy wobble.
func _flap(delta: float, strength: float) -> void:
	var beat := sin(_t * 13.0) * 0.7 if strength > 0.0 else sin(_t * 2.0) * 0.08
	for w in _wings:
		var side: float = w.get_meta("side")
		w.rotation.y = lerpf(w.rotation.y, 0.0, delta * 8.0)
		w.rotation.z = side * beat


func _fold(delta: float) -> void:
	for w in _wings:
		var side: float = w.get_meta("side")
		w.rotation.z = lerpf(w.rotation.z, 0.0, delta * 8.0)
		w.rotation.y = lerpf(w.rotation.y, side * 1.35, delta * 8.0)
	rotation.z = lerpf(rotation.z, 0.0, delta * 5.0)
