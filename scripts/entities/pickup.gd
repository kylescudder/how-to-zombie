class_name Pickup
extends Node3D
## A weapon or item lying around. Press E to take it; the host decides who gets it.

var _visual: Node3D
var _clock := 0.0

var item := "pills"
var extra := {}  # ammo state for dropped guns


func setup(d: Dictionary) -> void:
	item = d.item
	extra = d.get("extra", {})
	position = d.pos
	rotation.y = float(d.get("yaw", 0.0))


func _ready() -> void:
	add_to_group("pickups")
	var m := ItemModels.make(item)
	add_child(m)
	_visual = m
	m.rotation_degrees = Vector3(0, 90, 0) if DB.weapon(item).slot in ["primary", "secondary"] else Vector3.ZERO
	m.position.y = 0.06
	# Faint glow so supplies stand out in the dark.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.9, 0.5, 0.12)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = glow
	var zone := Build.interact_zone(self, "pickup", Vector3(1.0, 0.8, 1.0), Vector3(0, 0.25, 0), "")
	zone.name = "Zone"


func prompt_for(s: Survivor) -> String:
	var w := DB.weapon(item)
	var nm: String = w.name
	if extra.has("price"):
		var left := "" if not extra.has("expire") else "  (%d:%02d left)" % [int(extra.expire) / 60, int(extra.expire) % 60]
		return "Buy %s for %d credits (was £1.40)%s  [you have %d]" % [nm, int(extra.price), left, Game.credits(s.slot)]
	match String(w.slot):
		"primary":
			return ("Swap for " if not s.inv.primary.is_empty() else "Pick up ") + nm
		"secondary":
			if item == "pistol" and s.inv.secondary.get("id", "") == "pistol":
				return "Pick up a second pistol"
			return ("Swap for " if s.inv.secondary.get("id", "") not in ["", "pistol"] else "Pick up ") + nm
		"throwable":
			return ("Swap for " if s.inv.throwable != "" else "Pick up ") + nm
		"medkit":
			return "Pick up First Aid Kit" if not s.inv.medkit else "(already carrying a First Aid Kit)"
		"pills":
			return "Pick up Pain Pills" if not s.inv.pills else "(already carrying Pain Pills)"
	return "Pick up " + nm


## True if the survivor can take it (so we don't waste a medkit on someone who has one).
func can_take(s: Survivor) -> bool:
	match String(DB.weapon(item).slot):
		"medkit":
			return not bool(s.net_inv.get("medkit", false))
		"pills":
			return not bool(s.net_inv.get("pills", false))
	return true


func _process(delta: float) -> void:
	_clock += delta
	# Dropped reduced stock keeps going off on the floor too.
	if extra.has("expire") and Net.is_host():
		extra.expire = float(extra.expire) - delta
		if extra.expire <= 0.0:
			queue_free()
	if _visual:
		_visual.position.y = 0.075 + sin(_clock * 1.6 + position.x) * 0.012
		_visual.rotation.z = sin(_clock * 1.1 + position.z) * 0.015
