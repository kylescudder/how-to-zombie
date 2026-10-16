class_name Projectile
extends RigidBody3D
## Thrown things: player dynamite, Grill Dad's flaming patties, Mall Santa's present bombs.

const TYPES := {
	"dynamite": {"fuse": 2.2, "radius": 6.0, "damage": 120.0, "knock": 26.0, "impact": false},
	"patty": {"fuse": 6.0, "radius": 2.8, "damage": 18.0, "knock": 12.0, "impact": true},
	"present": {"fuse": 1.6, "radius": 4.0, "damage": 30.0, "knock": 16.0, "impact": false},
}

var type := "dynamite"
var attacker := 0
var net_pos := Vector3.ZERO
var net_rot := Quaternion.IDENTITY
var _vel := Vector3.ZERO
var _t := 0.0
var _done := false
var _spark: MeshInstance3D


func setup(d: Dictionary) -> void:
	type = d.type
	attacker = int(d.get("attacker", 0))
	position = d.pos
	net_pos = d.pos
	_vel = d.vel


func _init() -> void:
	var sync := MultiplayerSynchronizer.new()
	var cfg := SceneReplicationConfig.new()
	for prop in ["net_pos", "net_rot"]:
		var path := NodePath(".:" + prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
	sync.replication_config = cfg
	sync.replication_interval = 1.0 / 30.0
	add_child(sync)


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 4
	mass = 1.0
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.2
	cs.shape = s
	add_child(cs)
	match type:
		"dynamite":
			Build.cyl(self, 0.07, 0.07, 0.45, Color(0.85, 0.15, 0.15), Vector3.ZERO, Vector3(0, 0, 90))
			Build.cyl(self, 0.07, 0.07, 0.45, Color(0.85, 0.15, 0.15), Vector3(0, 0.12, 0), Vector3(0, 0, 90))
			Build.box(self, Vector3(0.12, 0.3, 0.16), Color(0.9, 0.85, 0.7), Vector3(0, 0.06, 0))
		"patty":
			Build.cyl(self, 0.28, 0.28, 0.12, Color(0.4, 0.22, 0.12))
			Build.cyl(self, 0.3, 0.3, 0.03, Color(1.0, 0.85, 0.2), Vector3(0, 0.07, 0))
		"present":
			Build.box(self, Vector3(0.45, 0.45, 0.45), Color(0.2, 0.7, 0.3))
			Build.box(self, Vector3(0.47, 0.47, 0.1), Color(0.95, 0.2, 0.2))
			Build.box(self, Vector3(0.1, 0.47, 0.47), Color(0.95, 0.2, 0.2))
	_spark = Build.sphere(self, 0.07, Color(1.0, 0.8, 0.3), Vector3(0, 0.3, 0))
	_spark.material_override = Build.mat(Color(1.0, 0.7, 0.2), 0.5, 5.0)
	if Net.is_host():
		linear_velocity = _vel
		angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	else:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	global_position = net_pos
	Sfx.play("fuse", global_position, -6.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_spark.visible = int(_t * 10.0) % 2 == 0
	if not Net.is_host():
		global_position = global_position.lerp(net_pos, clampf(delta * 18.0, 0.0, 1.0))
		quaternion = quaternion.slerp(net_rot.normalized(), clampf(delta * 18.0, 0.0, 1.0))
		return
	net_pos = global_position
	net_rot = quaternion
	if global_position.y < DB.WATER_LEVEL - 0.3:
		apply_central_force(Vector3.UP * 16.0 - linear_velocity * 2.0)
	var info: Dictionary = TYPES[type]
	if _done:
		return
	if _t >= info.fuse or (info.impact and _t > 0.15 and get_contact_count() > 0):
		_done = true
		var lvl := _level()
		if lvl:
			lvl.explode(global_position, info.radius, info.damage, info.knock, attacker)
		queue_free()


func _level() -> Level:
	var n := get_parent()
	while n and not (n is Level):
		n = n.get_parent()
	return n as Level
