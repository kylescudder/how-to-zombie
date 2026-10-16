class_name ItemModels
## Builds held-item meshes. Origin = grip; items point down -Z.

static func make(item: String, rod_id := "rod_1") -> Node3D:
	var n := Node3D.new()
	var metal := Color(0.45, 0.47, 0.5)
	var dark := Color(0.15, 0.15, 0.17)
	match item:
		"rod":
			var c: Color = DB.RODS[rod_id].color
			var tip := Node3D.new()
			tip.name = "Tip"
			n.add_child(tip)
			Build.cyl(n, 0.012, 0.03, 1.6, c, Vector3(0, 0.35, -0.65), Vector3(-65, 0, 0), 6)
			Build.cyl(n, 0.035, 0.035, 0.3, dark, Vector3(0, -0.05, 0.05), Vector3(-65, 0, 0), 6)
			Build.cyl(n, 0.07, 0.07, 0.05, metal, Vector3(0.06, 0.02, -0.05), Vector3(0, 0, 90), 10)
			tip.position = Vector3(0, 0.69, -1.37)
		"fists":
			Build.box(n, Vector3(0.12, 0.12, 0.14), Color(0.95, 0.78, 0.62), Vector3(0, 0, -0.05))
		"knife":
			Build.box(n, Vector3(0.04, 0.05, 0.14), Color(0.35, 0.22, 0.12), Vector3(0, 0, 0))
			Build.box(n, Vector3(0.015, 0.06, 0.3), Color(0.6, 0.45, 0.35), Vector3(0, 0.01, -0.22))
		"knuckles":
			Build.box(n, Vector3(0.14, 0.12, 0.14), Color(0.95, 0.78, 0.62), Vector3(0, 0, 0))
			Build.box(n, Vector3(0.16, 0.05, 0.05), Color(0.85, 0.7, 0.25), Vector3(0, 0.03, -0.08))
		"bat":
			Build.cyl(n, 0.07, 0.03, 0.9, Color(0.7, 0.5, 0.3), Vector3(0, 0, -0.4), Vector3(-90, 0, 0), 8)
			for i in 5:
				Build.box(n, Vector3(0.2, 0.012, 0.012), metal, Vector3(0, 0, -0.55 - i * 0.07), Vector3(0, i * 37.0, 0))
		"pistol":
			Build.box(n, Vector3(0.06, 0.13, 0.08), dark, Vector3(0, -0.04, 0.02), Vector3(15, 0, 0))
			Build.box(n, Vector3(0.07, 0.07, 0.26), Color(0.3, 0.75, 0.4), Vector3(0, 0.04, -0.08))
		"shotgun":
			Build.box(n, Vector3(0.07, 0.12, 0.3), Color(0.45, 0.3, 0.18), Vector3(0, -0.03, 0.12))
			Build.cyl(n, 0.035, 0.035, 0.7, dark, Vector3(-0.03, 0.03, -0.35), Vector3(-90, 0, 0), 8)
			Build.cyl(n, 0.035, 0.035, 0.7, dark, Vector3(0.03, 0.03, -0.35), Vector3(-90, 0, 0), 8)
		"smg":
			Build.box(n, Vector3(0.08, 0.12, 0.38), dark, Vector3(0, 0.02, -0.1))
			Build.box(n, Vector3(0.05, 0.22, 0.07), Color(0.95, 0.6, 0.15), Vector3(0, -0.13, -0.1))
			Build.box(n, Vector3(0.06, 0.1, 0.07), dark, Vector3(0, -0.07, 0.06))
		"harpoon":
			Build.box(n, Vector3(0.1, 0.14, 0.5), Color(0.95, 0.85, 0.2), Vector3(0, 0.0, -0.1))
			Build.cyl(n, 0.015, 0.015, 0.8, metal, Vector3(0, 0.07, -0.5), Vector3(-90, 0, 0), 6)
			Build.cyl(n, 0.0, 0.05, 0.12, metal, Vector3(0, 0.07, -0.95), Vector3(-90, 0, 0), 6)
		"dynamite":
			Build.cyl(n, 0.05, 0.05, 0.3, Color(0.85, 0.15, 0.15), Vector3(0, 0.05, -0.05), Vector3(-20, 0, 0), 8)
			Build.box(n, Vector3(0.01, 0.1, 0.01), Color(0.9, 0.9, 0.8), Vector3(0, 0.22, -0.1))
	return n


static func muzzle(item: String) -> Vector3:
	match item:
		"pistol": return Vector3(0, 0.04, -0.24)
		"shotgun": return Vector3(0, 0.03, -0.72)
		"smg": return Vector3(0, 0.02, -0.32)
		"harpoon": return Vector3(0, 0.07, -1.0)
	return Vector3(0, 0, -0.3)
