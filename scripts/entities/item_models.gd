class_name ItemModels
## Builds weapon and item meshes. Origin = grip; guns point down -Z.

static func make(item: String, upgrades := {}) -> Node3D:
	if DB.GUN_PROFILES.has(item):
		return GunModels.make(item, upgrades)
	var n := Node3D.new()
	var metal := Color(0.45, 0.47, 0.5)
	var dark := Color(0.13, 0.13, 0.15)
	var wood := Color(0.45, 0.3, 0.18)
	match item:
		"bat":
			Build.cyl(n, 0.065, 0.025, 0.95, Color(0.7, 0.55, 0.35), Vector3(0, 0, -0.42), Vector3(-90, 0, 0), 8)
		"axe":
			Build.cyl(n, 0.025, 0.025, 0.9, Color(0.75, 0.15, 0.1), Vector3(0, 0, -0.4), Vector3(-90, 0, 0), 6)
			Build.box(n, Vector3(0.03, 0.22, 0.18), metal, Vector3(0, 0.1, -0.8))
		"machete":
			Build.box(n, Vector3(0.04, 0.05, 0.14), dark, Vector3(0, 0, 0))
			Build.box(n, Vector3(0.012, 0.07, 0.55), metal, Vector3(0, 0.01, -0.33))
		"pipe_bomb":
			Build.cyl(n, 0.045, 0.045, 0.24, Color(0.5, 0.5, 0.52), Vector3(0, 0, -0.05), Vector3(-90, 0, 0), 8)
			Build.box(n, Vector3(0.05, 0.05, 0.04), Color(0.9, 0.15, 0.1), Vector3(0, 0.05, -0.05), Vector3.ZERO, 2.0)
		"molotov":
			Build.cyl(n, 0.05, 0.06, 0.18, Color(0.35, 0.55, 0.3, 0.9), Vector3(0, 0, -0.05))
			Build.cyl(n, 0.02, 0.025, 0.1, Color(0.35, 0.55, 0.3, 0.9), Vector3(0, 0.14, -0.05))
			Build.box(n, Vector3(0.04, 0.08, 0.04), Color(0.9, 0.85, 0.75), Vector3(0, 0.22, -0.05))
		"bile_jar":
			Build.cyl(n, 0.06, 0.06, 0.16, Color(0.55, 0.7, 0.25, 0.9), Vector3(0, 0, -0.05))
			Build.cyl(n, 0.05, 0.05, 0.03, metal, Vector3(0, 0.09, -0.05))
		"medkit":
			Build.box(n, Vector3(0.32, 0.22, 0.12), Color(0.85, 0.15, 0.12), Vector3(0, 0, -0.05))
			Build.box(n, Vector3(0.14, 0.04, 0.13), Color.WHITE, Vector3(0, 0, -0.05))
			Build.box(n, Vector3(0.04, 0.14, 0.13), Color.WHITE, Vector3(0, 0, -0.05))
		"pills":
			Build.cyl(n, 0.035, 0.035, 0.1, Color(0.95, 0.7, 0.2), Vector3(0, 0, -0.05))
			Build.cyl(n, 0.037, 0.037, 0.03, Color.WHITE, Vector3(0, 0.06, -0.05))
		"hands":
			Build.box(n, Vector3(0.1, 0.1, 0.14), Color(0.85, 0.7, 0.55), Vector3(0, 0, -0.05))
	return n


static func muzzle(item: String) -> Vector3:
	match item:
		"pistol", "dual_pistols": return Vector3(0, 0.04, -0.21)
		"smg": return Vector3(0, 0.067, -0.58)
		"pump_shotgun": return Vector3(0, 0.067, -0.82)
		"auto_shotgun": return Vector3(0, 0.067, -0.86)
		"rifle": return Vector3(0, 0.067, -0.79)
		"hunting_rifle": return Vector3(0, 0.067, -0.9)
	return Vector3(0, 0, -0.3)
