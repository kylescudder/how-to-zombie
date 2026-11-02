class_name FerryDeck
extends RefCounted
## Shared physical dimensions and deck layout for the ferry, spawns and rider simulation.
const HEIGHT := 1.3
const HELM := Vector3(0, HEIGHT, 5.7)
const CAPTAIN_REST := Vector3(-2.2, HEIGHT, 4.0)
const RELEASE := Vector3(1.7, HEIGHT, 4.0)
const WALK_SPEED := 3.2

static func start(index: int) -> Vector3:
	return Vector3(-1.5 if index % 2 == 0 else 1.5, HEIGHT, 0.0 if index < 2 else -3.0)

static func constrain(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, -2.8, 2.8), HEIGHT, clampf(point.z, -6.3, 7.3))

static func build(shell: Node3D) -> void:
	ArtShapes.loft(shell, [Vector4(-0.3, 2.0, 6.8, 0), Vector4(0, 2.8, 8.3, 0), Vector4(1.2, 3.5, 9.0, 0), Vector4(1.35, 3.5, 8.8, 0)], Color(0.19, 0.27, 0.32))
	Build.box(shell, Vector3(6.8, 0.2, 17.2), Color(0.48, 0.35, 0.22), Vector3(0, HEIGHT - 0.1, 0))
	for side in [-1.0, 1.0]:
		for z in [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5]:
			Build.cyl(shell, 0.055, 0.055, 1.0, Color(0.78, 0.81, 0.79), Vector3(side * 3.25, HEIGHT + 0.5, z))
		Build.box(shell, Vector3(0.1, 0.1, 15.5), Color(0.78, 0.81, 0.79), Vector3(side * 3.25, HEIGHT + 1.0, 0))
	for z in [-8.0, 8.0]:
		Build.box(shell, Vector3(6.5, 0.12, 0.12), Color(0.78, 0.81, 0.79), Vector3(0, HEIGHT + 1.0, z))
	# Open helm: no roof for the arrival camera to clip through.
	Build.box(shell, Vector3(1.5, 1.0, 0.7), Color(0.67, 0.7, 0.66), Vector3(0, HEIGHT + 0.5, 4.75))
	Build.box(shell, Vector3(1.2, 0.08, 0.55), Color(0.06, 0.12, 0.14), Vector3(0, HEIGHT + 1.04, 4.75))
	Build.cyl(shell, 0.32, 0.32, 0.08, Color(0.22, 0.16, 0.09), Vector3(0, HEIGHT + 1.0, 5.2), Vector3(65, 0, 0), 12)
	for x in [-2.3, 2.3]:
		Build.box(shell, Vector3(0.7, 0.8, 1.4), Color(0.32, 0.39, 0.34), Vector3(x, HEIGHT + 0.4, -6.0))
	Build.label(shell, "MARLA'S FERRY", Vector3(0, 1.0, 8.95), 38, Color(1, 0.9, 0.7))
