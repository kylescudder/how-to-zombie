extends RefCounted
func run(test: Node, host: bool) -> void:
	AudioServer.set_bus_mute(0,true)
	test.check(await test.wait_for(func(): return Net.players.size()==2,60),"two peers register appearance profiles")
	var level := test.get_tree().get_first_node_in_group("level") as Level
	if not level: return
	if host: level.director.set_process(false)
	test.check(await test.wait_for(func(): return level.get_survivors().filter(func(s): return not s.bot).size()==2,30),"both custom survivors spawn")
	for survivor: Survivor in level.get_survivors():
		if survivor.bot: continue
		var look: Dictionary=Net.players[survivor.peer_id].appearance
		test.check(survivor.appearance==look and survivor.body_model.get_meta("appearance")==look,"peer %d renders its registered appearance"%survivor.peer_id)
		if survivor.peer_id==1: test.check(look.hair==2 and look.jackets==1,"host's selected hair and jacket replicate")
		else: test.check(look.hair==6 and look.outfits==2,"client's selected hair and outfit replicate")
	if host:
		await test.wait(3)
		for id in Net.players:
			if id!=1: Game.add_stat(Net.slot_of(id),"revives")
		await test.wait(3)
	else:
		test.check(await test.wait_for(func(): return Wardrobe.xp==4040,15),"host-confirmed revive grants persistent XP to the correct client")
		var config := ConfigFile.new()
		config.load(Wardrobe.storage_path)
		test.check(config.get_value("wardrobe","xp",0)==4040,"remote XP reward persists on the client's profile")
		await test.wait(1)
