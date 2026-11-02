extends Node
## Host owns readiness, skip votes and the handoff back to gameplay.
const DURATION := 25.0
const CRUISE_HEIGHT := 200.0
const LINES := ["Marla: Barea City. Keep your heads down. Those streets are crawling.", "Marla: The Yellow Sticker idol is inside the Megamart. That's what we're here for.", "Marla: Get the idol, get back to the boat. I'll keep the engine running."]
var ready_peers := {}
var votes := {}
var announced := false
var started := false
var ending := false
var elapsed := 0.0
var camera: Camera3D
var caption: Label
var skip_status: Label
var overlay: CanvasLayer
var level: Level
var _hud: CanvasLayer
var _hud_visible := false
var _director_processing := false
var crowd_ready := false
var crowd: Array[Infected] = []

func _ready() -> void:
	level = get_parent() as Level
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Once per session: not again after a wipe restart, nor for a friend dropping in later.
	if Game.story.get("intro_done", false):
		queue_free()
		return
	if Net.is_host():
		_director_processing = level.director.is_processing()
		level.director.set_process(false)
		_prepare_city_crowd.call_deferred()

func human_peers() -> Array:
	var peers: Array = []
	for peer in Net.players:
		if Net.slot_of(peer) >= 0:
			peers.append(peer)
	peers.sort()
	return peers

func _process(delta: float) -> void:
	if ending:
		return
	if not started:
		if Game.story.get("intro_done", false):
			queue_free()
			return
		if not announced and level.local_survivor() != null and LoadingScreen.current and not LoadingScreen.current.visible:
			announced = true
			_loaded.rpc_id(1)
		if Net.is_host() and announced:
			var everyone := not human_peers().is_empty()
			for peer in human_peers():
				everyone = everyone and ready_peers.has(peer)
			if everyone and crowd_ready:
				_begin.rpc(0.0)
		return
	elapsed += delta
	_refresh_votes()
	if Net.is_host():
		_check_skip()
		if elapsed >= DURATION and not ending:
			_finish.rpc()
	if ending:
		return
	var survivor := level.local_survivor()
	if survivor == null or survivor.camera == null:
		return
	var city: Vector3 = level.markers.idol
	var index := mini(int(elapsed / 7.0), 2)
	if caption.text != LINES[index]:
		caption.text = LINES[index]
		var voices := DisplayServer.tts_get_voices_for_language("en")
		if not voices.is_empty():
			DisplayServer.tts_speak(caption.text, voices[0], 85, 1.0, 0.95, 0, true)
	if elapsed < 7.0:
		camera.global_position = city + Vector3(90.0 - elapsed * 5.0, 55, 85)
		camera.look_at(city)
	elif elapsed < 14.0:
		var t := (elapsed - 7.0) / 7.0
		camera.global_position = city + Vector3(5.0 - t * 9.0, 2.5, 7)
		camera.look_at(city)
	else:
		camera.global_transform = arrival_pose(elapsed - 14.0, city, survivor.camera.global_transform)
		camera.fov = lerpf(65, survivor.camera.fov, smoothstep(4.0, 11.0, elapsed - 14.0))

## Travel above the skyline first. Only descend once directly over the player's boat seat.
## A vertical approach on the open deck avoids crossing city buildings or the ferry cabin.
func arrival_pose(seconds: float, city: Vector3, eye: Transform3D) -> Transform3D:
	var overhead := eye.origin + Vector3.UP * CRUISE_HEIGHT
	var pose := Transform3D.IDENTITY
	if seconds < 4.0:
		pose.origin = (city + Vector3.UP * CRUISE_HEIGHT).lerp(overhead, smoothstep(0.0, 4.0, seconds))
	else:
		pose.origin = overhead.lerp(eye.origin, smoothstep(4.0, 11.0, seconds))
	# Looking straight down has no unique yaw: look_at() can flip almost 90 degrees
	# as its horizontal target offset crosses zero. Keep the player's heading fixed
	# throughout the aerial move, then tilt smoothly into their eye orientation.
	var aerial := Basis.from_euler(Vector3(-PI * 0.5, eye.basis.get_euler().y, 0))
	pose.basis = aerial.slerp(eye.basis.orthonormalized(), smoothstep(9.0, 11.0, seconds))
	return pose

func _unhandled_key_input(event: InputEvent) -> void:
	if started and not ending and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		_vote_skip.rpc_id(1)
		get_viewport().set_input_as_handled()

@rpc("any_peer", "call_local", "reliable")
func _loaded() -> void:
	if not Net.is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = 1
	if peer not in human_peers():
		return
	ready_peers[peer] = true
	if started and not ending:
		_begin.rpc_id(peer, elapsed)
		_sync_votes.rpc_id(peer, votes)

@rpc("any_peer", "call_local", "reliable")
func _vote_skip() -> void:
	if not Net.is_host() or not started or ending:
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = 1
	if peer not in human_peers() or votes.has(peer):
		return
	votes[peer] = true
	_sync_votes.rpc(votes)
	_check_skip()

func _check_skip() -> void:
	var humans := human_peers()
	if humans.is_empty():
		return
	for peer in humans:
		if not votes.has(peer):
			return
	_finish.rpc()

@rpc("authority", "call_local", "reliable")
func _sync_votes(updated: Dictionary) -> void:
	votes = updated.duplicate()
	_refresh_votes()

func _refresh_votes() -> void:
	if skip_status == null:
		return
	var rows := PackedStringArray(["SPACE — vote to skip"])
	for peer in human_peers():
		rows.append("%s  %s · %s%s" % ["READY" if votes.has(peer) else "WAITING", Net.player_name(peer), DB.SURVIVORS[Net.slot_of(peer)].name, " (you)" if peer == Net.my_id() else ""])
	skip_status.text = "\n".join(rows)

@rpc("authority", "call_local", "reliable")
func _begin(at_time: float) -> void:
	if started or ending:
		return
	started = true
	elapsed = at_time
	get_tree().paused = true
	var main := level.get_parent().get_parent()
	_hud = main.get("hud") as CanvasLayer
	if _hud:
		_hud_visible = _hud.visible
		_hud.visible = false
	camera = Camera3D.new()
	add_child(camera)
	camera.global_position = level.markers.idol + Vector3(90, 55, 85)
	camera.look_at(level.markers.idol)
	camera.make_current()
	overlay = CanvasLayer.new()
	overlay.layer = 45
	add_child(overlay)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -100
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_constant_override("outline_size", 8)
	overlay.add_child(caption)
	skip_status = Label.new()
	skip_status.position = Vector2(36, 36)
	skip_status.add_theme_font_size_override("font_size", 20)
	skip_status.add_theme_constant_override("outline_size", 8)
	overlay.add_child(skip_status)
	_refresh_votes()

@rpc("authority", "call_local", "reliable")
func _finish() -> void:
	if ending:
		return
	ending = true
	if Net.is_host():
		Game.story.intro_done = true
		Game.mark_dirty()
	var survivor := level.local_survivor()
	if survivor and survivor.camera:
		survivor.camera.make_current()
	_restore()
	queue_free()

func _restore() -> void:
	DisplayServer.tts_stop()
	get_tree().paused = false
	if Net.is_host() and is_instance_valid(level.director):
		level.director.set_process(_director_processing)
	for infected in level.all_infected():
		if infected.intro_roamer:
			infected.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(_hud):
		_hud.visible = _hud_visible

func _exit_tree() -> void:
	if started:
		_restore()


## Prepare real, replicated infected while the loading cover is still up. Their normal
## wander AI and animation keep running during the cutscene; combat and survivors stay paused.
func _prepare_city_crowd() -> void:
	await get_tree().physics_frame
	if ending or not is_instance_valid(level):
		return
	var city: Vector3 = level.markers.idol
	var candidates: Array[Vector3] = []
	for block: Vector3 in level.markers.get("city_blocks", []):
		for offset in [-18.0, -6.0, 6.0, 18.0]:
			candidates.append(block + Vector3(BareaCity.PITCH * 0.5, 0, offset))
			candidates.append(block + Vector3(offset, 0, BareaCity.PITCH * 0.5))
	# Fill streets in the foreground of the establishing shot first.
	var foreground := city + Vector3(40, 0, 40)
	candidates.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(foreground) < b.distance_squared_to(foreground))
	for point in candidates:
		if crowd.size() >= 40:
			break
		if not level.nav.walkable_at(point):
			continue
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 5, point - Vector3.UP * 2, 1)
		var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.position.y > 0.8 or hit.normal.y < 0.8:
			continue
		var infected := level.spawn_infected("common", hit.position, false, true)
		crowd.append(infected)
	crowd_ready = true
