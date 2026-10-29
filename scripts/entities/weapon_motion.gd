class_name WeaponMotion
extends RefCounted
## Cosmetic animation only. Ammo, reload completion and hit traces stay in Survivor.
var clock := 0.0
var gait := 0.0
var movement := 0.0
var sway := Vector2.ZERO
var equip := 1.0
var inspect := 0.0
var landing := 0.0
var _grounded := true
var _vertical := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _started := false


func sample(delta: float, id: String, velocity: Vector3, grounded: bool, yaw: float, pitch: float, aim: float, shot_age: float, reload: float, rounds: int) -> Dictionary:
	clock += delta
	equip = maxf(0.0, equip - delta / 0.38)
	inspect = maxf(0.0, inspect - delta)
	landing = move_toward(landing, 0.0, delta * 3.5)
	if grounded and not _grounded:
		landing = clampf(absf(_vertical) / 9.0, 0.15, 1.0)
	_grounded = grounded
	_vertical = velocity.y
	if _started:
		var turn := Vector2(angle_difference(_yaw, yaw), pitch - _pitch) / maxf(delta, 0.001)
		sway = sway.lerp(turn.clamp(Vector2(-3, -3), Vector2(3, 3)), 1.0 - exp(-delta * 9.0))
	_started = true
	_yaw = yaw
	_pitch = pitch
	var speed := Vector2(velocity.x, velocity.z).length()
	movement = lerpf(movement, minf(speed / 5.4, 1.0) if grounded else 0.0, 1.0 - exp(-delta * 10.0))
	gait += delta * (5.5 + speed * 1.8) if speed > 0.1 and grounded else 0.0
	var quiet := lerpf(1.0, 0.08, aim)
	var pos := Vector3(sin(clock * 1.7) * 0.004, sin(clock * 2.0) * 0.006, cos(clock * 1.7) * 0.003) * quiet
	pos += Vector3(sin(gait) * 0.019, -absf(cos(gait)) * 0.025, sin(gait * 2) * 0.012) * movement * quiet
	pos += Vector3(-sway.x * 0.012, -sway.y * 0.009 - landing * 0.055, clampf(velocity.y * -0.004, -0.025, 0.035)) * quiet
	var rot := Vector3(sin(clock * 2.0) * 0.008, sin(clock * 1.3) * 0.007, sin(gait) * movement * 0.035) * quiet
	rot += Vector3(sway.y * 0.013, -sway.x * 0.012, -sway.x * 0.025 - landing * 0.035) * quiet
	pos *= Settings.weapon_sway
	rot *= Settings.weapon_sway
	var kick := exp(-shot_age * (15.0 if "shotgun" in id else 24.0))
	pos.z += kick * (0.08 if "shotgun" in id else 0.038)
	rot.x += kick * (0.19 if "shotgun" in id else 0.09)
	pos.y -= equip * 0.30
	rot += Vector3(-0.5, 0.16, -0.35) * equip
	var support := Vector3(-0.055, -0.035, -0.30)
	if id in ["pistol", "dual_pistols"]:
		support = Vector3(-0.045, -0.05, 0.015)
	if id == "pump_shotgun" and reload < 0:
		support.z += sin(clampf((shot_age - 0.15) / 0.38, 0, 1) * PI) * 0.12
	var magazine := Vector3.ZERO
	var mag_rot := Vector3.ZERO
	var shell := false
	if reload >= 0:
		var lift := smoothstep(0.0, 0.15, reload) * (1.0 - smoothstep(0.86, 1.0, reload))
		var tube := id in ["pump_shotgun", "auto_shotgun"]
		pos += Vector3(-0.06, 0.055, 0.07) * lift
		rot += Vector3(0.12, -0.2, -0.9 if tube else -0.48) * lift
		if tube:
			var cycle := fposmod(clampf((reload - 0.14) / 0.68, 0, 1) * mini(rounds, 8), 1.0)
			var feed := sin(cycle * PI)
			support = support.lerp(Vector3(-0.10 - feed * 0.09, -0.12 + feed * 0.09, -0.08 + feed * 0.06), lift)
			shell = reload > 0.15 and reload < 0.82
		else:
			var out := smoothstep(0.12, 0.32, reload) * (1.0 - smoothstep(0.46, 0.72, reload))
			magazine = Vector3(-0.035, -0.27, 0.07) * out
			mag_rot.z = -0.18 * out
			support = support.lerp(Vector3(-0.035, -0.17, -0.13) + magazine, lift)
			if reload > 0.75:
				support = support.lerp(Vector3(-0.06, 0.10, -0.03), sin((reload - 0.75) / 0.25 * PI))
	if inspect > 0:
		var p := 1.0 - inspect / 3.2
		var envelope := smoothstep(0, 0.16, p) * (1.0 - smoothstep(0.82, 1, p))
		rot += Vector3(-0.20, 0.42 + sin(p * TAU) * 0.25, -0.70) * envelope
		pos += Vector3(-0.10, 0.08, 0.10) * envelope
		support += Vector3(-0.07, -0.10, 0.14) * envelope
	return {"position": pos, "rotation": rot, "support": support, "magazine": magazine, "mag_rotation": mag_rot, "shell": shell}


static func animate_parts(gun: Node3D, id: String, reload: float, shot_age: float, rounds: int, pose: Dictionary = {}) -> void:
	if gun == null:
		return
	if id == "dual_pistols":
		var side := 0
		for child in gun.get_children():
			if child is Node3D:
				animate_parts(child, "pistol", reload, shot_age + side * 0.04, rounds, pose)
				side += 1
		return
	var bolt := gun.get_node_or_null("ActionBolt") as Node3D
	if bolt:
		var rack := sin(clampf((reload - 0.77) / 0.17, 0, 1) * PI) if reload >= 0 else 0.0
		bolt.position.z = maxf(exp(-shot_age * 35) * 0.045, rack * 0.065)
	var mag := gun.get_node_or_null("Magazine") as Node3D
	if mag:
		if pose.is_empty():
			var out := smoothstep(0.12, 0.32, reload) * (1 - smoothstep(0.46, 0.72, reload)) if reload >= 0 else 0.0
			mag.position = Vector3(0, -0.27, 0.07) * out
		else:
			mag.position = pose.magazine
			mag.rotation = pose.mag_rotation
	var fore := gun.get_node_or_null("ForeEnd") as Node3D
	if fore:
		var pump := sin(clampf((shot_age - 0.15) / 0.38, 0, 1) * PI) if id == "pump_shotgun" else 0.0
		fore.position.z = pump * 0.12
	var shell := gun.get_node_or_null("ReloadShell") as Node3D
	if shell:
		shell.visible = reload > 0.15 and reload < 0.82
		if shell.visible:
			var cycle := fposmod((reload - 0.14) / 0.68 * mini(rounds, 8), 1.0)
			shell.position = Vector3(-0.08 - sin(cycle * PI) * 0.10, -0.10 + sin(cycle * PI) * 0.08, -0.08)
			shell.rotation.z = -0.7 + cycle * 0.8
