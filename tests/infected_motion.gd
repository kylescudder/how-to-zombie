extends RefCounted
## A pack of commons released from one spot should reach the player by different lines, at
## different paces, and close in from more than one side instead of filing in.
var test: Node


func run(owner: Node) -> void:
	test = owner
	var level := test.get_tree().get_first_node_in_group("level") as Level
	test.check(level != null, "level loaded")
	if level == null: return
	test.calm()
	var me := level.local_survivor()
	var home := OpenWorld.camp(0) + Vector3(-200, 0.3, 0)
	me.global_position = home
	me.velocity = Vector3.ZERO
	_park_bots(level, me)
	await test.wait(0.5)
	var start := level.nav.center(level.nav.nearest_walkable(home + Vector3(22, 0, 8), 8)) + Vector3.UP * 0.3
	test.check(start.distance_to(home) > 15.0, "found a release point %.0f m out" % start.distance_to(home))
	var pack: Array[Infected] = []
	for k in 14:
		pack.append(level.spawn_infected("common", start + Vector3(k % 4 - 1.5, 0, k / 4 - 1.5) * 0.9, true))
	var styles := {}
	for i in pack:
		styles[i.gait.style] = true
	test.check(styles.size() >= 3, "the pack mixes gaits (%s)" % ", ".join(styles.keys()))

	var line := (me.global_position - start)
	line.y = 0
	var side := Vector3(line.z, 0, -line.x).normalized()
	var drift := {}      # widest sideways offset from the straight start->player line
	var arrived := {}    # bearing from the player when each first got within reach
	var speeds := {}
	var t := 0.0
	while t < 14.0 and arrived.size() < pack.size():
		await test.get_tree().physics_frame
		t += test.get_physics_process_delta_time()
		me.hp = 100.0
		if me.incapped: me.host_revive()
		_park_bots(level, me)
		for i in pack:
			if not is_instance_valid(i) or i.is_dead() or arrived.has(i.name):
				continue
			var rel := i.global_position - start
			drift[i.name] = maxf(drift.get(i.name, 0.0), absf(rel.dot(side)))
			speeds[i.name] = maxf(speeds.get(i.name, 0.0), Vector2(i.velocity.x, i.velocity.z).length())
			var to := i.global_position - me.global_position
			to.y = 0
			if to.length() < 1.6:
				arrived[i.name] = atan2(to.x, to.z)

	var bearings: Array = arrived.values()
	bearings.sort()
	var widest_gap := 0.0
	for k in bearings.size():
		var next: float = bearings[(k + 1) % bearings.size()] + (TAU if k == bearings.size() - 1 else 0.0)
		widest_gap = maxf(widest_gap, next - bearings[k])
	var spread := TAU - widest_gap if bearings.size() > 1 else 0.0
	var wanderers: int = drift.values().filter(func(d): return d > 1.5).size()
	var top: Array = speeds.values()
	top.sort()
	print("[MOTION] arrived %d/%d in %.1fs, approach arc %.0f deg, %d strayed >1.5 m off the line, top speeds %.1f..%.1f" % [
		arrived.size(), pack.size(), t, rad_to_deg(spread), wanderers, top[0] if top.size() else 0.0, top[-1] if top.size() else 0.0])
	test.check(arrived.size() >= pack.size() * 0.7, "most of the pack reached the player (%d/%d)" % [arrived.size(), pack.size()])
	test.check(spread > deg_to_rad(70.0), "they close in across a wide arc (%.0f deg)" % rad_to_deg(spread))
	test.check(wanderers >= pack.size() / 3, "plenty of them leave the straight line (%d)" % wanderers)
	test.check(top.size() > 1 and top[-1] - top[0] > 1.0, "they don't all run at the same pace")


## Bots would shoot the pack and give it other targets; keep them well out of it.
func _park_bots(level: Level, me: Survivor) -> void:
	for s: Survivor in level.get_survivors():
		if s.bot:
			s.global_position = me.global_position + Vector3(0, 0, 400 + s.slot * 3)
			s.velocity = Vector3.ZERO
