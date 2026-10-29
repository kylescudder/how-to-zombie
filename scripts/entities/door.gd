class_name Door
extends Node3D
## Safe room door: a heavy red door on a hinge. Infected can't get through it when it's shut.
## Built identically on every peer by the Level; the host decides when it opens or closes.

var index := 0
var kind := "start"  # start / end
var open := false
var cells := Rect2i()
var _slab: StaticBody3D
var _hinge: Node3D
var _angle := 0.0


func setup(i: int, marker: Dictionary) -> void:
	index = i
	kind = marker.kind
	cells = marker.rect
	position = marker.pos
	name = "Door%d" % i


func _ready() -> void:
	# Frame
	Build.box(self, Vector3(0.2, 2.6, 0.5), Color(0.25, 0.25, 0.27), Vector3(-1.1, 1.3, 0))
	Build.box(self, Vector3(0.2, 2.6, 0.5), Color(0.25, 0.25, 0.27), Vector3(1.1, 1.3, 0))
	Build.box(self, Vector3(2.4, 0.3, 0.5), Color(0.25, 0.25, 0.27), Vector3(0, 2.75, 0))
	_hinge = Node3D.new()
	_hinge.position = Vector3(-1.0, 0, 0)
	add_child(_hinge)
	_slab = StaticBody3D.new()
	_slab.collision_layer = 1
	_slab.position = Vector3(1.0, 0, 0)
	_hinge.add_child(_slab)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0, 2.5, 0.12)
	cs.shape = bs
	cs.position.y = 1.25
	_slab.add_child(cs)
	Build.box(_slab, Vector3(2.0, 2.5, 0.12), Color(0.65, 0.1, 0.08), Vector3(0, 1.25, 0))
	Build.box(_slab, Vector3(1.4, 0.8, 0.14), Color(0.55, 0.08, 0.06), Vector3(0, 1.7, 0))
	Build.box(_slab, Vector3(0.12, 0.3, 0.2), Color(0.75, 0.72, 0.6), Vector3(0.75, 1.1, 0))
	var zone := Build.interact_zone(_slab, "door", Vector3(2.0, 2.4, 0.6), Vector3(0, 1.2, 0), "Door")
	zone.name = "Zone"
	open = kind == "end"
	_angle = 1.0 if open else 0.0
	_apply()


func set_open(v: bool) -> void:
	if v == open:
		return
	open = v
	Sfx.play("door", global_position + Vector3.UP)


func _process(delta: float) -> void:
	var goal := 1.0 if open else 0.0
	if not is_equal_approx(_angle, goal):
		_angle = move_toward(_angle, goal, delta * 2.5)
		_apply()


func _apply() -> void:
	# Opens away from the safe room's inside for start doors, into the room for end doors.
	var dir := -1.0 if kind == "start" else 1.0
	_hinge.rotation.y = smoothstep(0.0, 1.0, _angle) * PI * 0.5 * dir
