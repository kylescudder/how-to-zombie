extends RefCounted
## Open world: the Director has to keep finding the team wherever it explores.
var test: Node

func run(owner: Node) -> void:
	test = owner
	var level := test.get_tree().get_first_node_in_group("level") as Level
	test.check(level != null and level.open_world, "open world loaded")
	if level == null: return
	var me := level.local_survivor()
	var spots := []
	for index in [0, 2]:
		# Well inland on two different islands, far from the safe camps.
		spots.append(OpenWorld.camp(index) + Vector3(-110, 0.3, 30))
	for spot: Vector3 in spots:
		for s: Survivor in level.get_survivors():
			s.global_position = spot + Vector3(s.slot * 1.5, 0, 0)
			s.velocity = Vector3.ZERO
		level.director.mob_t = 3.0
		var peak := 0
		var t := 0.0
		while t < 25.0:
			await test.get_tree().process_frame
			t += test.get_process_delta_time()
			peak = maxi(peak, level.count_commons())
			if me.incapped: me.host_revive()
			me.hp = 100.0
		print("[WORLD] island %d: director active=%s flow gen=%d peak commons=%d" % [OpenWorld.land_index(spot), level.director.active, level.director.flow.generation, peak])
		test.check(level.director.active, "director wakes up once the team leaves camp")
		test.check(peak >= 8, "infected find the team on island %d (peak %d)" % [OpenWorld.land_index(spot), peak])
		var near := level.all_infected().filter(func(i): return not i.is_dead() and i.global_position.distance_to(me.global_position) < 150.0)
		test.check(near.size() >= 4, "spawns stay near the team after moving islands (%d within 150 m)" % near.size())
