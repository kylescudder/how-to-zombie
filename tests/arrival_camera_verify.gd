extends SceneTree
## Fast regression for the camera passing directly over its look target.
func _initialize() -> void:
	var director = load("res://scripts/world/arrival_cutscene.gd").new()
	var worst := 0.0
	for yaw in [-PI, -PI * 0.5, 0.0, PI * 0.5]:
		var eye := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), Vector3(0, 2.5, 0))
		for city in [Vector3(200, 2, 80), Vector3(-200, 2, -80)]:
			var before: Transform3D = director.arrival_pose(3.8, city, eye)
			for frame in range(1, 49):
				var pose: Transform3D = director.arrival_pose(3.8 + frame / 120.0, city, eye)
				worst = maxf(worst, rad_to_deg(before.basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion())))
				before = pose
	print("[CAMERA] largest rotation step at descent start: %.3f degrees at 120fps" % worst)
	print("[CAMERA] %s: no sudden rotation at overhead junction" % ("PASS" if worst < 1.0 else "FAIL"))
	director.free()
	quit(0 if worst < 1.0 else 1)
