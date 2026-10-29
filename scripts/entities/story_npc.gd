class_name StoryNPC
extends Node3D
## A survivor holed up somewhere in the world. Built the same on every peer; not networked.
## Press E to talk. The infected ignore them (they've learned to keep very still).

const HAIR := ["cap", "ponytail", "bandana", "beanie"]

var id := ""
var data: Dictionary
var model: CharacterModel
var _t := 0.0


func setup(npc_id: String, pos: Vector3, yaw: float) -> void:
	id = npc_id
	data = Story.npc(id)
	name = "NPC_" + id
	position = pos
	rotation.y = yaw


func _ready() -> void:
	add_to_group("story_npcs")
	model = CharacterModel.new()
	add_child(model)
	var look: Array = data.look
	model.setup_npc(look[0], look[1], look[2], HAIR[absi(hash(id)) % HAIR.size()], look[2].darkened(0.3))
	var tag := Build.label(self, data.name, Vector3(0, 2.45, 0), 34, Color(1.0, 0.9, 0.5))
	tag.fixed_size = false
	Build.label(self, "!", Vector3(0, 2.95, 0), 90, Color(1.0, 0.85, 0.1)).name = "Marker"
	var zone := Build.interact_zone(self, "npc", Vector3(1.4, 2.0, 1.4), Vector3(0, 1.0, 0), "Talk to " + data.name)
	zone.set_meta("npc", id)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)


func _process(delta: float) -> void:
	_t += delta
	model.animate(delta, 0.0, 0.0, "")
	var marker := get_node_or_null("Marker") as Node3D
	if marker:
		marker.position.y = 2.95 + sin(_t * 3.0) * 0.08


func lines(stage: String) -> Array:
	return data.alert if stage == "alert" else data.lines


func mark_talked() -> void:
	var marker := get_node_or_null("Marker")
	if marker:
		marker.queue_free()
