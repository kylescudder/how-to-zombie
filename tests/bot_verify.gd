extends RefCounted
## --solo --test=bots: bots leave stragglers to the player, never hurt anyone, and keep their distance.
var _me: Survivor
var _level: Level
var _test: Node


func _bots() -> Array:
	return _level.get_survivors().filter(func(s): return s.bot)


func _ring(distance: float) -> void:
	for bot: Survivor in _bots():
		var angle: float = bot.slot*TAU/3.0
		bot.global_position = _me.global_position+Vector3(cos(angle)*distance,0.1,sin(angle)*distance)


func _clear() -> void:
	for inf: Infected in _level.all_infected(): inf.queue_free()
	await _test.get_tree().process_frame


## Earlier scenes run on Expert; a downed teammate would send the bot off to revive them.
func _heal_all() -> void:
	for mate: Survivor in _level.get_survivors():
		if mate.incapped: mate.host_revive()
		mate.hp = DB.MAX_HP
		mate.temp_hp = 0.0
	await _test.get_tree().physics_frame


func _frozen_common(pos: Vector3) -> Infected:
	var inf := _level.spawn_infected("common",pos,false)
	await _test.get_tree().process_frame
	inf.set_physics_process(false)
	inf.set_process(false)
	return inf


func run(test: Node) -> void:
	_test = test
	AudioServer.set_bus_mute(0,true)
	Game.difficulty = 3
	await test.wait_for(func(): return test.me()!=null,20.0)
	_level = test.level()
	_me = test.me()
	_level.director.set_process(false)
	await _clear()
	await _spacing()
	await _stragglers()
	await _packs()
	await _line_of_fire()
	_friendly_fire()


func _spacing() -> void:
	# Bots dropped on top of the player must back off and then stay off.
	_ring(1.0)
	await _test.wait(3.0)
	var closest := INF
	var furthest := 0.0
	for tick in 40:
		await _test.wait(0.1)
		for bot: Survivor in _bots():
			var gap: float = bot.global_position.distance_to(_me.global_position)
			closest = minf(closest,gap)
			furthest = maxf(furthest,gap)
	_test.check(closest>=2.8,"bots give the player room (closest %.1f m)"%closest)
	_test.check(furthest<=12.0,"bots still stay with the player (furthest %.1f m)"%furthest)
	# The player walking into a parked bot gets space back.
	var bot: Survivor = _bots()[0]
	bot.global_position = _me.global_position+Vector3(1.0,0.1,0)
	await _test.wait(2.5)
	_test.check(bot.global_position.distance_to(_me.global_position)>=2.8,"a bot steps away when the player walks into it")


func _stragglers() -> void:
	_ring(5.0)
	await _test.wait(0.5)
	var lone := await _frozen_common(_me.global_position+Vector3(0,0.1,11))
	var hp := lone.hp
	await _test.wait(3.0)
	_test.check(is_instance_valid(lone) and not lone.is_dead() and lone.hp==hp,"a lone distant common is left for the player")
	await _clear()
	var close := await _frozen_common(_bots()[0].global_position+Vector3(0,0.1,2.5))
	_test.check(await _test.wait_for(func(): return not is_instance_valid(close) or close.is_dead() or close.hp<close.max_hp,6.0),"bots still deal with a common at arm's length")
	await _clear()


func _packs() -> void:
	_ring(5.0)
	await _test.wait(0.5)
	var pack: Array[Infected] = []
	for index in 8:
		pack.append(await _frozen_common(_me.global_position+Vector3(-4.0+index*1.2,0.1,10)))
	await _test.wait(1.5)
	var alive := pack.filter(func(inf): return is_instance_valid(inf) and not inf.is_dead()).size()
	_test.check(alive>=4,"a pack lasts long enough for the player to join in (%d of 8 left after 1.5 s)"%alive)
	var cleared: bool = await _test.wait_for(func(): return pack.filter(func(inf): return is_instance_valid(inf) and not inf.is_dead()).size()<8,8.0)
	_test.check(cleared,"bots do engage a pack")
	await _clear()


func _line_of_fire() -> void:
	# Player stands directly between a bot and a target it wants to shoot.
	await _heal_all()
	var bot: Survivor = _bots()[0]
	for other: Survivor in _bots():
		if other!=bot:
			other.set_physics_process(false)
			other.global_position = _me.global_position+Vector3(0,0.1,-20-other.slot)
	bot.global_position = _me.global_position+Vector3(0,0.1,-3)
	var target := await _frozen_common(_me.global_position+Vector3(0,0.1,2.5))
	var before: int = Game.stats[bot.slot].ff
	var hp := _me.hp
	var firing_line := bot.global_position
	var shots: int = bot.net_fire
	for frame in 150:
		bot.global_position = firing_line
		await _test.get_tree().physics_frame
	print("[TEST] bot fired %d shots while blocked"%(bot.net_fire-shots))
	_test.check(Game.stats[bot.slot].ff==before and _me.hp>=hp,"a bot never shoots a teammate standing in its way (%d ff)"%(Game.stats[bot.slot].ff-before))
	await _test.wait(2.0)
	var sidestepped: float = absf(bot.global_position.x-_me.global_position.x)
	_test.check(sidestepped>0.8 or not is_instance_valid(target) or target.is_dead() or target.hp<target.max_hp,"a blocked bot moves for a clear shot (%.1f m aside)"%sidestepped)
	for other: Survivor in _bots(): other.set_physics_process(true)
	await _clear()


func _friendly_fire() -> void:
	var bot: Survivor = _bots()[0]
	var hp := _me.hp
	_level.request_ff(_me.name,40.0,bot.slot)
	_test.check(_me.hp==hp,"bot bullets cannot hurt survivors, even on Expert")
