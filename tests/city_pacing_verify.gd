extends RefCounted

func run(test: Node) -> void:
	AudioServer.set_bus_mute(0,true)
	var level := test.get_tree().get_first_node_in_group("level") as Level
	level.director.set_process(false)
	var pockets: Array = level.markers.street_pockets
	test.check(pockets.size()>60,"city has distributed playable street pockets (%d)"%pockets.size())
	var types := {}
	var blocked := 0
	for pocket: Dictionary in pockets:
		types[pocket.kind]=true
		if level.nav.path(pocket.entry,pocket.loot).is_empty(): blocked+=1
	test.check(types.size()==4,"market, garden, aid station and service yard all represented")
	test.check(blocked==0,"every pocket has an AI route from street entrance to loot (%d blocked)"%blocked)
	# Forty-five simulated minutes, including injuries and boss interruptions.
	var model := EncounterPacing.new()
	var phases: Array = []
	var waves := 0
	var unsafe := 0
	var longest_surge := 0
	var surge := 0
	var recovery := 0
	for second in 2700:
		var injured := second%450>=150 and second%450<185
		var boss := second%600>=300 and second%600<330
		var outcome := model.tick(1,0.3 if injured else 0.85,1 if injured else 0,0,0,boss,second>=2100)
		if outcome=="wave":
			waves+=1
			if injured or boss: unsafe+=1
		phases.append(model.phase)
		if model.phase=="surge": surge+=1
		else: surge=0
		longest_surge=maxi(longest_surge,surge)
		if model.phase=="recover": recovery+=1
	var trace := FileAccess.open("res://screenshots/city-pacing/trace.json",FileAccess.WRITE)
	trace.store_string(JSON.stringify({"seconds":2700,"phases":phases,"waves":waves,"recovery_seconds":recovery}))
	test.check(waves>15 and waves<45,"45-minute pressure simulation creates bounded encounters (%d)"%waves)
	test.check(unsafe==0 and longest_surge<=32,"injuries and bosses prevent new waves; surges end within 32 seconds")
	test.check(recovery>500,"long run includes substantial recovery (%d seconds)"%recovery)
	model.recover(10)
	for step in 100: model.tick(1,1,0,0,20,false)
	test.check(model.phase=="recover","unresolved enemy pressure prevents another wave")
	model=EncounterPacing.new()
	test.check(model.tick(1,1,0,0.3,0,false)=="recover","recent damage triggers immediate relief")
	# Real queue stays bounded even when repeated scripted requests cannot spawn yet.
	var director := level.director
	var me := level.local_survivor()
	for variant in 4:
		var lot: Dictionary = pockets.filter(func(p): return p.kind==variant)[0]
		me.global_position=lot.entry+Vector3.UP*0.2
		me.velocity=Vector3.ZERO
		me.aim(0,0)
		await test.wait(0.1)
		var start := me.global_position
		Input.action_press("move_forward")
		await test.wait(1.6)
		Input.action_release("move_forward")
		test.check(me.global_position.z<start.z-6,"player walks into pocket type %d through its real entrance"%variant)

	var pocket: Dictionary = pockets[0]
	for survivor: Survivor in level.get_survivors(): survivor.global_position=pocket.entry+Vector3(survivor.slot,0.2,0)
	director.flow.start(level.get_survivors().map(func(s): return level.nav.nearest_walkable(s.global_position,3)))
	while director.flow.busy: director.flow.step(100000)
	for attempt in 12: director.spawn_mob(30,false)
	test.check(not director.pending.is_empty(),"horde test actually found hidden spawn positions")
	test.check(director.pending.size()<=DB.MAX_COMMONS,"repeated horde requests cannot build an unbounded queue")
	director.pending.clear()
	for infected in level.all_infected(): infected.queue_free()
	await test.wait(0.1)
	# An injury in the running Director cancels unspawned pressure.
	director.pacing.phase="surge"
	me.hp=20
	me.incapped=true
	director.pending.append({"type":"common","pos":pocket.entry,"horde":true})
	director._world_pacing(0.1,false)
	test.check(director.pacing.phase=="recover" and director.pending.is_empty(),"live Director clears queued pressure when a survivor goes down")
	director.crescendo_t=30
	director.crescendo_wave=0
	director._crescendo(1)
	test.check(director.crescendo_t==29 and director.pending.size()<=4,"injured hold-out squad gets reduced reinforcements while event timer continues")
	director.pending.clear()
	director.crescendo_t=0
	me.incapped=false
	me.hp=100
	if DisplayServer.get_name()!="headless":
		var hud := test.get_tree().get_first_node_in_group("hud") as HUD
		hud.visible=false
		for survivor: Survivor in level.get_survivors(): survivor.global_position=OpenWorld.camp(0)+Vector3(survivor.slot*2,0.2,0)
		var camera := Camera3D.new()
		level.add_child(camera)
		camera.current=true
		for variant in 4:
			var candidates: Array = pockets.filter(func(p): return p.kind==variant)
			var city_center := Vector3(OpenWorld.ISLANDS[0].center.x,0,OpenWorld.ISLANDS[0].center.y)
			candidates.sort_custom(func(a,b): return a.pos.distance_to(city_center)<b.pos.distance_to(city_center))
			var sample: Dictionary = candidates[0]
			camera.global_position=sample.pos+Vector3(0,9,30)
			camera.look_at(sample.pos+Vector3(0,0,-3))
			await test.wait(0.3)
			await test._shot(ProjectSettings.globalize_path("res://screenshots/city-pacing/pocket-%d.png"%variant))
		camera.queue_free()
