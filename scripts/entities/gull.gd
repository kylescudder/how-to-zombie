class_name Gull
extends Node3D
## Mr. Squawks: swoops in, grabs a downed player by the collar and dumps them back at Doc's.
## Purely visual on every peer; the carried player's owner moves their own body along.

var target: Player
var drop := Vector3.ZERO
var _t := 0.0
var _from := Vector3.ZERO
var _pickup := Vector3.ZERO
var _wing_l: Node3D
var _wing_r: Node3D
const ARRIVE := 1.6
const CARRY := 3.2


func start(p: Player, drop_pos: Vector3) -> void:
	target = p
	drop = drop_pos
	_pickup = p.global_position + Vector3.UP * 1.2
	_from = _pickup + Vector3(25, 22, -10)
	global_position = _from
	Build.sphere(self, 0.6, Color.WHITE, Vector3.ZERO, Vector3(1.0, 0.9, 1.6))
	Build.sphere(self, 0.4, Color.WHITE, Vector3(0, 0.45, -0.8))
	Build.cyl(self, 0.0, 0.14, 0.45, Color(1.0, 0.7, 0.1), Vector3(0, 0.4, -1.3), Vector3(-90, 0, 0), 6)
	Build.sphere(self, 0.07, Color.BLACK, Vector3(-0.2, 0.55, -1.05))
	Build.sphere(self, 0.07, Color.BLACK, Vector3(0.2, 0.55, -1.05))
	_wing_l = Node3D.new()
	_wing_l.position = Vector3(-0.5, 0.2, 0)
	add_child(_wing_l)
	Build.box(_wing_l, Vector3(1.8, 0.08, 0.8), Color(0.85, 0.85, 0.88), Vector3(-0.9, 0, 0))
	_wing_r = Node3D.new()
	_wing_r.position = Vector3(0.5, 0.2, 0)
	add_child(_wing_r)
	Build.box(_wing_r, Vector3(1.8, 0.08, 0.8), Color(0.85, 0.85, 0.88), Vector3(0.9, 0, 0))
	Sfx.play("squawk", global_position, 6.0)


func _process(delta: float) -> void:
	_t += delta
	var flap := sin(_t * 18.0) * 0.6
	_wing_l.rotation.z = flap
	_wing_r.rotation.z = -flap
	var pos: Vector3
	if _t < ARRIVE:
		var k := _t / ARRIVE
		pos = _from.lerp(_pickup, k * k * (3.0 - 2.0 * k))
	elif _t < ARRIVE + CARRY:
		var k := (_t - ARRIVE) / CARRY
		var flat := _pickup.lerp(drop + Vector3.UP * 2.0, k)
		pos = flat + Vector3.UP * sin(k * PI) * 10.0
		if is_instance_valid(target) and target.is_multiplayer_authority():
			target.carried_by_gull(pos + Vector3.DOWN * 2.2)
	elif _t < ARRIVE + CARRY + 2.0:
		if is_instance_valid(target) and target.is_multiplayer_authority() and not target.gull_dropped:
			target.gull_dropped = true
			target.gull_finished()
			Sfx.play("squawk", global_position, 4.0)
		pos = global_position + Vector3(14, 10, 8) * delta
	else:
		queue_free()
		return
	if pos.distance_to(global_position) > 0.01:
		look_at(pos, Vector3.UP)
	global_position = pos
