class_name BotBrain
extends RefCounted
## Drives a bot survivor on the host by filling in the same inputs a player would.
## Priorities: save pinned teammates > revive downed ones > heal > fight > follow the humans.

var survivor: Survivor
var _path := PackedVector3Array()
var _path_i := 0
var _goal := Vector3.INF
var _repath := 0.0
var _think := 0.0
var _threat: Infected
var _aim_err := Vector3.ZERO
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _fire_hold := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func think(delta: float) -> void:
	var s := survivor
	s.in_move = Vector2.ZERO
	s.in_fire = false
	s.in_fire_pressed = false
	s.in_alt = false
	s.in_alt_pressed = false
	s.in_use_pressed = false
	s.in_reload = false
	s.in_slot = ""
	s.in_jump = false
	s.in_crouch = false
	if s.dead or s.pinned_by != "":
		s.in_use = false
		return
	var lvl := s.level()
	if _threat != null and (not is_instance_valid(_threat) or _threat.is_dead()):
		_threat = null
	_think -= delta
	if _think <= 0.0:
		_think = 0.2
		_threat = _pick_threat(lvl)
		_aim_err = Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.1, 0.25), _rng.randf_range(-0.15, 0.15))
	if s.incapped:
		s.in_use = false
		if _threat:
			_engage(_threat, delta, false)
		return

	# 1. Someone's pinned: kill the attacker or shove them free.
	var pinned := _nearest_mate(lvl, func(m): return m.pinned_by != "", 30.0)
	if pinned:
		var attacker := lvl.get_infected(pinned.pinned_by)
		var d := s.global_position.distance_to(pinned.global_position)
		if attacker and _visible(attacker.global_position + Vector3.UP) and s.global_position.distance_to(attacker.global_position) > 2.0:
			_engage(attacker, delta, true)
		if d > 1.8:
			_move_to(pinned.global_position, delta, attacker == null or not _visible(attacker.global_position + Vector3.UP))
		else:
			_look_at(pinned.global_position + Vector3.UP * 0.6, delta)
			s.in_alt_pressed = true
		return

	# 2. Revive anyone who's down (unless something's chewing on us).
	var down := _nearest_mate(lvl, func(m): return m.incapped, 35.0)
	if down and not (_threat and _threat.global_position.distance_to(s.global_position) < 4.0):
		var d := s.global_position.distance_to(down.global_position)
		if d > 1.7:
			s.in_use = false
			_move_to(down.global_position, delta, true)
		else:
			_look_at(down.global_position + Vector3.UP * 0.3, delta)
			if s.action_t <= 0.0:
				s.in_use_pressed = true
			s.in_use = true
		return
	s.in_use = false

	# 3. Patch up when it's quiet.
	var quiet := _threat == null or _threat.global_position.distance_to(s.global_position) > 14.0
	if quiet and s.total_hp() < 40.0 and s.inv.medkit:
		s.in_slot = "medkit"
		if s.cur == "medkit":
			s.in_fire = true
		return
	if s.total_hp() < 45.0 and s.inv.pills and s.action_t <= 0.0:
		s.in_slot = "pills"
		if s.cur == "pills":
			s.in_fire_pressed = true
		return

	# 4. Fight.
	_choose_weapon()
	if _threat:
		_engage(_threat, delta, true)
		var td := _threat.global_position.distance_to(s.global_position)
		if td < 1.6 and s._shove_cd <= 0.0 and not _threat.is_tank():
			s.in_alt_pressed = true
	elif s.cur in ["primary", "secondary"] and _needs_reload():
		s.in_reload = true

	# 5. Move: follow the humans, grab supplies on the way, follow them into the safe room.
	var goal := _follow_goal(lvl)
	if _threat == null or _threat.global_position.distance_to(s.global_position) > 8.0 or _threat.is_tank():
		var item := _wanted_pickup(lvl) if quiet else null
		if item:
			if s.global_position.distance_to(item.global_position) < 2.4:
				lvl.request_pickup(item.name, s.slot)
			else:
				goal = item.global_position
				_move_to(goal, delta, true)
				_unstick(lvl, delta)
				return
		if quiet and s.global_position.distance_to(goal) < 3.0:
			var ammo := _wanted_ammo(lvl)
			if ammo != Vector3.INF:
				goal = ammo
				if s.global_position.distance_to(ammo) < 2.0:
					s._refill_ammo()
	if _threat and _threat.is_tank():
		# Back away from tanks while shooting.
		var away := s.global_position - _threat.global_position
		away.y = 0
		goal = s.global_position + away.normalized() * 6.0
	if s.global_position.distance_to(goal) > 2.5:
		_move_to(goal, delta, _threat == null)
	_unstick(lvl, delta)


func _pick_threat(lvl: Level) -> Infected:
	var s := survivor
	var best: Infected
	var best_score := INF
	for inf: Infected in lvl.all_infected():
		if inf.is_dead() or inf.type == "witch" and not inf.angry():
			continue
		var d := inf.global_position.distance_to(s.global_position)
		if d > 30.0:
			continue
		var score := d
		if inf.type != "common":
			score -= 8.0
		if inf.target_name == s.name:
			score -= 4.0
		if score < best_score and _visible(inf.global_position + Vector3.UP * 1.2):
			best = inf
			best_score = score
	return best


func _visible(p: Vector3) -> bool:
	var s := survivor
	var q := PhysicsRayQueryParameters3D.create(s.eye_position(), p, 1)
	return s.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _engage(inf: Infected, delta: float, allow_move: bool) -> void:
	var s := survivor
	var aim_pt := inf.global_position + Vector3.UP * (1.25 * inf.size) + _aim_err * minf(inf.global_position.distance_to(s.global_position) * 0.05, 1.0)
	var err := _look_at(aim_pt, delta)
	var w := s.current_weapon()
	if w.get("kind", "") == "melee":
		if inf.global_position.distance_to(s.global_position) < float(w.range) and err < 0.4:
			s.in_fire = true
		elif allow_move:
			_move_to(inf.global_position, delta, false)
		return
	if w.get("kind", "") != "gun":
		return
	if err < 0.09:
		_fire_hold += delta
		s.in_fire = true
		s.in_fire_pressed = _fire_hold > 0.0 and fmod(_fire_hold, 0.25) < delta * 1.5
	else:
		_fire_hold = 0.0


## Turns toward p; returns the remaining angle error (radians).
func _look_at(p: Vector3, delta: float) -> float:
	var s := survivor
	var to := p - s.eye_position()
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var dy := wrapf(yaw - s.rotation.y, -PI, PI)
	var turn := 9.0 * delta
	var ny := s.rotation.y + clampf(dy, -turn, turn)
	var np := s._pitch + clampf(pitch - s._pitch, -turn, turn)
	s.aim(ny, np)
	return absf(wrapf(yaw - ny, -PI, PI)) + absf(pitch - np)


func _move_to(goal: Vector3, delta: float, face_move: bool) -> void:
	var s := survivor
	var lvl := s.level()
	_repath -= delta
	if _repath <= 0.0 or _goal.distance_to(goal) > 2.0 or _path_i >= _path.size():
		_repath = 0.5
		_goal = goal
		_path = lvl.nav.path(s.global_position, goal)
		_path_i = 1 if _path.size() > 1 else 0
	var target := goal
	while _path_i < _path.size():
		var wp := _path[_path_i]
		if Vector2(wp.x - s.global_position.x, wp.z - s.global_position.z).length() < 0.7:
			_path_i += 1
		else:
			target = wp
			break
	var dir := target - s.global_position
	dir.y = 0
	if dir.length() < 0.2:
		return
	dir = dir.normalized()
	if face_move:
		_look_at(s.eye_position() + dir * 5.0, delta)
	var local := s.global_transform.basis.inverse() * dir
	s.in_move = Vector2(local.x, local.z).limit_length(1.0)


func _nearest_mate(lvl: Level, pred: Callable, max_d: float) -> Survivor:
	var s := survivor
	var best: Survivor
	var bd := max_d
	for m: Survivor in lvl.get_survivors():
		if m == s or m.dead or not pred.call(m):
			continue
		var d := m.global_position.distance_to(s.global_position)
		if d < bd:
			bd = d
			best = m
	return best


func _leader(lvl: Level) -> Survivor:
	var s := survivor
	var best: Survivor
	var bd := INF
	for m: Survivor in lvl.get_survivors():
		if m == s or m.dead or m.bot:
			continue
		var d := m.global_position.distance_to(s.global_position)
		if d < bd:
			bd = d
			best = m
	if best == null:
		for m: Survivor in lvl.get_survivors():
			if m != s and not m.dead and (best == null or m.global_position.z > best.global_position.z):
				best = m
	return best


func _follow_goal(lvl: Level) -> Vector3:
	var s := survivor
	var leader := _leader(lvl)
	if leader == null:
		return s.global_position
	if lvl.in_end_room(leader.global_position):
		var r: Rect2 = lvl.markers.end_room
		return Vector3(r.get_center().x + (s.slot - 1.5) * 1.2, 0, r.get_center().y + 1.5)
	if lvl.rescue_ready and lvl.markers.rescue_zone.size.x > 0.0:
		var rz: Rect2 = lvl.markers.rescue_zone
		return Vector3(rz.get_center().x + (s.slot - 1.5), 0, rz.get_center().y)
	# Spread out a little behind the leader.
	var behind := -leader.global_transform.basis.z
	behind.y = 0
	var side := leader.global_transform.basis.x * ((s.slot % 2) * 2.0 - 1.0) * 1.5
	var g := leader.global_position - behind.normalized() * 3.0 + side
	if not lvl.nav.walkable_at(g):
		g = leader.global_position
	return g


func _choose_weapon() -> void:
	var s := survivor
	if s.reload_t > 0.0:
		return
	var p: Dictionary = s.inv.primary
	if not p.is_empty() and (int(p.get("mag", 0)) > 0 or int(p.get("reserve", 0)) > 0):
		if s.cur != "primary":
			s.in_slot = "primary"
	elif s.cur != "secondary":
		s.in_slot = "secondary"


func _needs_reload() -> bool:
	var s := survivor
	var w := s.current_weapon()
	if w.get("kind", "") != "gun":
		return false
	var si: Dictionary = s.inv[s.cur]
	return int(si.get("mag", 0)) < int(w.mag) * 0.5 and int(si.get("reserve", -1)) != 0


func _wanted_pickup(lvl: Level) -> Pickup:
	var s := survivor
	var best: Pickup
	var bd := 9.0
	for p: Pickup in lvl.get_pickups():
		var d := p.global_position.distance_to(s.global_position)
		if d >= bd or not _wants(p.item) or p.extra.has("price"):
			continue  # bots don't spend the team's credits
		# Only things we can actually walk to (not through a shut door).
		var route := lvl.nav.path(s.global_position, p.global_position)
		if route.is_empty() or route.size() > 16:
			continue
		best = p
		bd = d
	return best


func _wants(id: String) -> bool:
	var s := survivor
	var w := DB.weapon(id)
	match String(w.get("slot", "")):
		"primary":
			if s.inv.primary.is_empty():
				return true
			var cur_t := int(DB.weapon(s.inv.primary.id).get("tier", 1))
			return int(w.get("tier", 1)) > cur_t
		"medkit":
			return not s.inv.medkit
		"pills":
			return not s.inv.pills
		"secondary":
			return id == "pistol" and s.inv.secondary.get("id", "") == "pistol"
	return false


func _wanted_ammo(lvl: Level) -> Vector3:
	var s := survivor
	var p: Dictionary = s.inv.primary
	if p.is_empty():
		return Vector3.INF
	if int(p.get("reserve", 0)) > int(DB.weapon(p.id).get("reserve", 0)) * 0.5:
		return Vector3.INF
	var best := Vector3.INF
	for a in lvl.ammo_spots:
		if a.distance_to(s.global_position) < 15.0 and (best == Vector3.INF or a.distance_to(s.global_position) < best.distance_to(s.global_position)):
			best = a
	return best


## Bots that fall far behind or get wedged teleport to the leader, out of sight (like L4D).
func _unstick(lvl: Level, delta: float) -> void:
	var s := survivor
	if s.global_position.distance_to(_last_pos) < 0.3 and s.in_move.length() > 0.3:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
		_last_pos = s.global_position
	var leader := _leader(lvl)
	if leader == null:
		return
	if lvl.open_world and OpenWorld.land_index(s.global_position)!=OpenWorld.land_index(leader.global_position): return
	var far := s.global_position.distance_to(leader.global_position) > 45.0
	if _stuck_t > 3.0 or far:
		_stuck_t = 0.0
		# Somewhere near the leader that's genuinely reachable from where they stand.
		for k in 8:
			var off := Vector3(2.0, 0, 0).rotated(Vector3.UP, k * TAU / 8.0)
			var spot := lvl.nav.nearest_walkable(leader.global_position + off, 2)
			if spot.x < 0:
				continue
			var route := lvl.nav.path(leader.global_position, lvl.nav.center(spot))
			if route.is_empty() or route.size() > 5:
				continue
			s.global_position = lvl.nav.center(spot) + Vector3.UP * 0.2
			s.velocity = Vector3.ZERO
			_path = PackedVector3Array()
			return
