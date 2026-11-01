class_name HUD
extends CanvasLayer
## In-game overlay: team health, your health and weapons, crosshair, prompts, alerts,
## chapter banners, screen effects (bile, incap, black & white), scoreboard and pause menu.

var root: Control
var team_box: VBoxContainer
var me_panel: PanelContainer
var me_name: Label
var me_hp_label: Label
var me_bar: ProgressBar
var me_temp: ProgressBar
var me_status: Label
var weapon_box: VBoxContainer
var objective: Label
var toast_box: VBoxContainer
var tank_panel: PanelContainer
var tank_bar: ProgressBar
var _hit_t := 0.0
var crosshair: Control
var prompt_label: Label
var action_panel: PanelContainer
var action_label: Label
var action_bar: ProgressBar
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label
var fx_rect: ColorRect
var fx_mat: ShaderMaterial
var big_status: Label
var scoreboard: PanelContainer
var score_grid: GridContainer
var modal: PanelContainer
var modal_kind := ""
var _banner_t := 0.0
var _hurt := 0.0
var _hp_seen := -1.0
var _team_key := ""
var _weapon_key := ""
var _score_key := ""
var _heartbeat := 0.0


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)

	# Full-screen effects: damage, bile, incapacitated, black & white.
	fx_rect = ColorRect.new()
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = Shader.new()
	fx_mat.shader.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float hurt = 0.0;
uniform float bile = 0.0;
uniform float down = 0.0;
uniform float grey = 0.0;
uniform float grain = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	if (bile > 0.0) {
		uv += vec2(sin(uv.y * 30.0 + TIME * 3.0), cos(uv.x * 24.0 + TIME * 2.0)) * 0.004 * bile;
	}
	float v = distance(UV, vec2(0.5));
	// A cheap lens: colour fringing towards the edges.
	vec2 fringe = (UV - vec2(0.5)) * v * 0.006 * grain;
	vec3 c = vec3(texture(screen_tex, uv + fringe).r, texture(screen_tex, uv).g, texture(screen_tex, uv - fringe).b);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), grey);
	// Film grain (stronger in the shadows) and a heavy vignette.
	float n = fract(sin(dot(FRAGCOORD.xy + fract(TIME * 7.13) * vec2(97.3, 41.9), vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * (0.075 - l * 0.04) * grain;
	c *= 1.0 - smoothstep(0.3, 0.92, v) * 0.55 * grain;
	c = mix(c, vec3(0.6, 0.0, 0.0), hurt * smoothstep(0.25, 0.75, v) * 0.8);
	c = mix(c, vec3(0.35, 0.6, 0.1) * (0.5 + l), bile * (0.55 + 0.3 * smoothstep(0.2, 0.7, v)));
	c = mix(c, c * vec3(1.0, 0.35, 0.3), down * 0.7);
	c *= 1.0 - down * smoothstep(0.3, 0.8, v) * 0.7;
	COLOR = vec4(c, 1.0);
}
"""
	fx_rect.material = fx_mat
	root.add_child(fx_rect)

	# Left: teammates
	team_box = VBoxContainer.new()
	team_box.position = Vector2(20, 20)
	team_box.add_theme_constant_override("separation", 6)
	root.add_child(team_box)

	# Bottom-left: me
	me_panel = PanelContainer.new()
	me_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	me_panel.position = Vector2(20, -128)
	me_panel.custom_minimum_size = Vector2(360, 0)
	root.add_child(me_panel)
	var mv := VBoxContainer.new()
	me_panel.add_child(mv)
	var mh := HBoxContainer.new()
	mv.add_child(mh)
	me_name = UIKit.label("", 22)
	me_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(me_name)
	me_hp_label = UIKit.label("100", 34, UIKit.ACCENT)
	mh.add_child(me_hp_label)
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(330, 22)
	mv.add_child(bars)
	me_temp = UIKit.bar(Color(0.85, 0.85, 0.85, 0.75), 330, 22)
	bars.add_child(me_temp)
	me_bar = UIKit.bar(UIKit.ACCENT, 330, 22)
	me_bar.add_theme_stylebox_override("background", UIKit.box(Color(0, 0, 0, 0), 8))
	bars.add_child(me_bar)
	me_status = UIKit.label("", 16, Color(0.85, 0.85, 0.85))
	mv.add_child(me_status)

	# Bottom-right: weapons
	weapon_box = VBoxContainer.new()
	weapon_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_box.position = Vector2(-330, -250)
	weapon_box.custom_minimum_size = Vector2(310, 230)
	weapon_box.alignment = BoxContainer.ALIGNMENT_END
	weapon_box.add_theme_constant_override("separation", 4)
	root.add_child(weapon_box)

	# Top-right: objective
	objective = UIKit.label("", 18, Color(0.9, 0.9, 0.9))
	objective.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective.position = Vector2(-520, 20)
	objective.custom_minimum_size = Vector2(500, 0)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(objective)

	# Top-centre: tank bar, toasts
	var tc := VBoxContainer.new()
	tc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tc.position = Vector2(-330, 18)
	tc.custom_minimum_size = Vector2(660, 0)
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc)
	tank_panel = PanelContainer.new()
	var tv := VBoxContainer.new()
	tank_panel.add_child(tv)
	var tl := UIKit.label("TANK", 24, Color(1.0, 0.4, 0.3))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(tl)
	tank_bar = UIKit.bar(Color(0.85, 0.2, 0.15), 620, 18)
	tv.add_child(tank_bar)
	tc.add_child(tank_panel)
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(toast_box)

	# Centre: crosshair, prompt, channel progress, big status
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)
	prompt_label = UIKit.label("", 22)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-400, 50)
	prompt_label.custom_minimum_size = Vector2(800, 0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_label)
	action_panel = PanelContainer.new()
	action_panel.set_anchors_preset(Control.PRESET_CENTER)
	action_panel.position = Vector2(-200, 90)
	action_panel.custom_minimum_size = Vector2(400, 0)
	root.add_child(action_panel)
	var av := VBoxContainer.new()
	action_panel.add_child(av)
	action_label = UIKit.label("", 20)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(action_label)
	action_bar = UIKit.bar(Color(0.5, 0.8, 1.0), 370, 16)
	av.add_child(action_bar)
	big_status = UIKit.label("", 34)
	big_status.set_anchors_preset(Control.PRESET_CENTER)
	big_status.position = Vector2(-500, -170)
	big_status.custom_minimum_size = Vector2(1000, 0)
	big_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(big_status)

	# Banner (chapter titles, safe room, failure, rescue)
	banner = VBoxContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-600, -300)
	banner.custom_minimum_size = Vector2(1200, 0)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	banner_title = UIKit.label("", 64, Color(0.95, 0.9, 0.85))
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_constant_override("outline_size", 14)
	banner.add_child(banner_title)
	banner_sub = UIKit.label("", 26, Color(0.85, 0.3, 0.25))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_sub)

	# Scoreboard
	scoreboard = PanelContainer.new()
	scoreboard.set_anchors_preset(Control.PRESET_CENTER)
	scoreboard.position = Vector2(-430, -120)
	scoreboard.custom_minimum_size = Vector2(860, 0)
	root.add_child(scoreboard)
	var sv := VBoxContainer.new()
	scoreboard.add_child(sv)
	sv.add_child(UIKit.label("SURVIVORS", 28, UIKit.GOLD))
	score_grid = GridContainer.new()
	score_grid.columns = 7
	score_grid.add_theme_constant_override("h_separation", 22)
	sv.add_child(score_grid)

	Game.toast_received.connect(_on_toast)
	Game.banner.connect(_on_banner)
	set_active(false)


func set_active(on: bool) -> void:
	visible = on
	if not on:
		close_modal()


# --- Per frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	var lvl := get_tree().get_first_node_in_group("level") as Level
	var me: Survivor = lvl.local_survivor() if lvl and is_instance_valid(lvl) else null
	if modal:
		modal.position = (get_viewport().get_visible_rect().size - modal.size) * 0.5
	_banner_t -= delta
	banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	if Input.is_action_just_pressed("pause") and not get_tree().has_group("settings_panel"):
		if modal:
			close_modal()
		else:
			open_pause()
	if lvl and lvl.open_world and Input.is_action_just_pressed("world_map") and not get_tree().has_group("settings_panel"):
		if modal_kind == "world_map": close_modal()
		elif modal == null: open_world_map(lvl)
	var show_scores := (Input.is_action_pressed("scoreboard") and modal == null) or Game.phase in ["complete", "victory"]
	scoreboard.visible = show_scores
	if show_scores:
		_refresh_scoreboard(lvl)
	if me == null or lvl == null:
		for n in [me_panel, weapon_box, team_box, action_panel, tank_panel]:
			n.visible = false
		prompt_label.text = ""
		return
	if modal_kind == "gunsmith" and (not lvl.at_gunsmith(me) or Game.phase not in ["playing", "complete"]):
		close_modal()
	me.ui_open = modal != null or get_tree().has_group("settings_panel")
	me_panel.visible = true
	weapon_box.visible = true
	team_box.visible = true
	_update_me(me, delta)
	_update_team(lvl, me)
	_update_weapons(me)
	_update_action(lvl, me)
	_update_objective(lvl)
	_update_talk(lvl, me)
	_update_tank(lvl)
	prompt_label.text = ("MISFIRE!" if me.misfire_t > 0.0 else me.prompt) if modal == null and not me.dead else ""
	crosshair.set_meta("spread", me.spread)
	crosshair.set_meta("aim", me.aim_blend)
	crosshair.visible = lvl.vehicle_for_slot(me.slot)==null and not me.dead and me.pinned_by == "" and modal == null
	_hit_t = maxf(0.0, _hit_t - delta)
	crosshair.queue_redraw()


func _health_color(s: Survivor) -> Color:
	if s.incapped or s.dead:
		return Color(0.85, 0.15, 0.1)
	var t := s.total_hp()
	if t >= 40.0:
		return Color(0.35, 0.8, 0.3)
	if t >= 25.0:
		return Color(0.95, 0.8, 0.2)
	return Color(0.9, 0.25, 0.15)


func _update_me(me: Survivor, delta: float) -> void:
	me_name.text = me.short_name()
	me_name.add_theme_color_override("font_color", DB.SURVIVORS[me.slot].ui)
	var c := _health_color(me)
	if me.incapped:
		me_bar.value = me.hp / DB.INCAP_HP
		me_temp.value = 0.0
		me_hp_label.text = str(ceili(me.hp))
	else:
		me_bar.value = me.hp / DB.MAX_HP
		me_temp.value = (me.hp + me.temp_hp) / DB.MAX_HP
		me_hp_label.text = str(ceili(me.total_hp()))
	me_bar.add_theme_stylebox_override("fill", UIKit.box(c, 8))
	me_hp_label.add_theme_color_override("font_color", c)
	var status := ""
	if me.dead:
		status = "DEAD"
	elif me.incapped:
		status = "INCAPACITATED - bleeding out"
	elif me.black_and_white():
		status = "BLACK & WHITE - one more down and you're dead"
	elif me.total_hp() < 40.0:
		status = "Limping"
	me_status.text = status
	# Screen effects
	if _hp_seen >= 0.0 and me.total_hp() < _hp_seen - 0.5:
		_hurt = 1.0
	_hp_seen = me.total_hp()
	_hurt = maxf(_hurt - delta * 2.0, 0.0)
	fx_mat.set_shader_parameter("hurt", _hurt * Settings.hit_flashes)
	fx_mat.set_shader_parameter("bile", clampf(me.biled / 3.0, 0.0, 1.0))
	fx_mat.set_shader_parameter("down", 1.0 if me.incapped else 0.0)
	fx_mat.set_shader_parameter("grain", Settings.film_grain)
	fx_mat.set_shader_parameter("grey", 0.9 if me.black_and_white() or me.dead else 0.0)
	if me.black_and_white() or me.incapped:
		_heartbeat -= delta
		if _heartbeat <= 0.0:
			_heartbeat = 0.9
			Sfx.play("heartbeat", Vector3.INF, -4.0)
	# Big centre text for the bad moments
	var big := ""
	if me.dead:
		var who: String = me.spectating.short_name() if is_instance_valid(me.spectating) else "your team"
		big = "You're dead.  Watching %s  [click to switch]\nYou'll be back next chapter." % who
	elif me.pinned_by != "":
		big = "%s HAS YOU!\nA teammate needs to shove it off or kill it." % me.pin_type.to_upper()
	elif me.incapped:
		big = "YOU'RE DOWN\nShoot with your pistol and wait for a teammate to revive you."
	big_status.text = big
	big_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3) if not me.dead else Color(0.85, 0.85, 0.85))


func _update_team(lvl: Level, me: Survivor) -> void:
	var mates := lvl.get_survivors().filter(func(s): return s != me)
	mates.sort_custom(func(a, b): return a.slot < b.slot)
	var key := ""
	for s in mates:
		key += "%s|%s|%d|%d|%s|%s|%s|%s;" % [s.name, s.short_name(), int(s.total_hp()), int(s.hp), s.incapped, s.dead, s.pinned_by, str(s.net_inv.hash())]
	if key == _team_key:
		return
	_team_key = key
	for c in team_box.get_children():
		c.queue_free()
	for s in mates:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(250, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var top := HBoxContainer.new()
		v.add_child(top)
		var nm := UIKit.label(s.short_name() + ("  (bot)" if s.bot else ""), 17, DB.SURVIVORS[s.slot].ui)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		var st := "DEAD" if s.dead else ("DOWN" if s.incapped else ("PINNED" if s.pinned_by != "" else str(ceili(s.total_hp()))))
		top.add_child(UIKit.label(st, 17, _health_color(s)))
		var bar := UIKit.bar(_health_color(s), 220, 10)
		bar.value = 0.0 if s.dead else (s.hp / DB.INCAP_HP if s.incapped else s.total_hp() / DB.MAX_HP)
		v.add_child(bar)
		var inv: Dictionary = s.net_inv
		var items: Array = []
		if inv.get("primary", {}).has("id"):
			items.append(DB.weapon(inv.primary.id).name)
		if String(inv.get("throwable", "")) != "":
			items.append(DB.weapon(inv.throwable).name)
		if inv.get("medkit", false):
			items.append("Medkit")
		if inv.get("pills", false):
			items.append("Pills")
		if not items.is_empty():
			v.add_child(UIKit.label("  ".join(items), 13, Color(0.75, 0.75, 0.78)))
		team_box.add_child(card)


func _update_weapons(me: Survivor) -> void:
	var inv_key: Dictionary = me.inv.duplicate(true)
	var expire := -1
	if inv_key.primary.has("expire"):
		expire = int(inv_key.primary.expire)
		inv_key.primary.erase("expire")
	var key := "%s|%s|%.1f|%s|%d" % [str(inv_key.hash()), me.cur, me.reload_t, str(Game.arsenal.hash()), expire]
	if key == _weapon_key:
		return
	_weapon_key = key
	for c in weapon_box.get_children():
		c.queue_free()
	for i in DB.SLOTS.size():
		var sl: String = DB.SLOTS[i]
		var id := me.weapon_id(sl)
		if id == "":
			continue
		var w := Game.gun_stats(me.slot, id)
		var sel := sl == me.cur
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.55, 0.12, 0.1, 0.92) if sel else Color(0.08, 0.09, 0.1, 0.7), 8, 2 if sel else 0, Color(1, 1, 1, 0.8)))
		var rows := VBoxContainer.new()
		panel.add_child(rows)
		var row := HBoxContainer.new()
		rows.add_child(row)
		row.add_child(UIKit.label(str(i + 1), 14, Color(1, 1, 1, 0.6)))
		var nm := UIKit.label(w.get("model", w.name), 19 if sel else 16)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		if w.kind == "gun":
			var si: Dictionary = me.inv[sl]
			var txt := "RELOADING" if sel and me.reload_t > 0.0 else ("%d" % int(si.mag) + ("" if int(si.get("reserve", -1)) < 0 else " / %d" % int(si.reserve)))
			row.add_child(UIKit.label(txt, 18 if sel else 15, UIKit.GOLD))
			if si.has("expire"):
				var left := maxi(int(si.expire), 0)
				rows.add_child(UIKit.label("REDUCED · USE BY %d:%02d" % [left / 60, left % 60], 15, Color(1.0, 0.3, 0.2) if left < 60 else Color(1.0, 0.85, 0.2)))
		weapon_box.add_child(panel)


func _update_action(lvl: Level, me: Survivor) -> void:
	var text := ""
	var t := 0.0
	if me.action_t > 0.0:
		var kind := me.net_action.get_slice(":", 0)
		var target := lvl.get_survivor(me.action_target)
		match kind:
			"revive":
				text = "Reviving %s..." % (target.short_name() if target else "")
			"heal":
				text = "Healing %s..." % (target.short_name() if target else "")
			"heal_self":
				text = "Healing yourself..."
		t = me.net_action_t
	else:
		for s: Survivor in lvl.get_survivors():
			if s != me and s.net_action.ends_with(":" + me.name):
				text = ("%s is reviving you..." if s.net_action.begins_with("revive") else "%s is healing you...") % s.short_name()
				t = s.net_action_t
	action_panel.visible = text != ""
	action_label.text = text
	action_bar.value = t


func _update_objective(lvl: Level) -> void:
	if lvl.open_world:
		var me := lvl.local_survivor()
		if not me: return
		var index := OpenWorld.land_index(me.global_position)
		var region: String = OpenWorld.ISLANDS[index].name if index>=0 else "Open Sea"
		var vehicle := lvl.vehicle_for_slot(me.slot)
		var goal := Story.objective(lvl.barea_stage())
		if lvl.barea_stage() == "alert":
			var carrier := lvl.get_survivor_by_slot(int(Game.story.get("idol_carrier", -1)))
			if carrier == null:
				goal = "The idol's on the ground! Pick it up, then get to the old ferry terminal (west)!"
			elif carrier == me:
				goal = "YOU have the idol (it slows you down). Get everyone onto Marla's ferry (west shore)!"
			else:
				goal = "%s has the idol. Get everyone onto Marla's ferry (west shore)!" % carrier.short_name()
		if lvl.event_left() > 0.0:
			var left := int(ceil(lvl.event_left()))
			goal += "\nHOLD OUT: %d:%02d" % [left / 60, left % 60]
		objective.text = "DEAD LOW TIDE • %s\n%s\n[M] World map" % [region, goal]
		if vehicle: objective.text += "\n%s • %d km/h • %d/4 aboard" % [vehicle.kind.capitalize(),roundi(absf(vehicle.net_speed)*3.6),4-Array(vehicle.seats).count(-1)]
		if lvl.local_waypoint!=Vector3.INF: objective.text += "\nWaypoint: %d m" % roundi(me.global_position.distance_to(lvl.local_waypoint))
		return
	var ch: Dictionary = DB.CHAPTERS[lvl.chapter]
	var txt := "%s  -  Chapter %d: %s\n%s" % [DB.CAMPAIGN_NAME, lvl.chapter + 1, ch.name, DB.difficulty(Game.difficulty).name]
	var goal := "Get to the safe room."
	if lvl.markers.button != Vector3.INF and not lvl.gate_open:
		goal = "Hold out while the gate opens!" if lvl.gate_opening else "Find the gate control to get through the warehouse."
	if lvl.markers.radio != Vector3.INF:
		if not lvl.radio_used:
			goal = "Find the radio on the docks and call for rescue."
		elif lvl.rescue_ready:
			goal = "The boat is here! Get to the end of the pier!" if lvl._boat_t >= 1.0 else "The boat's coming. Hold out!"
		else:
			goal = "Survive until the rescue boat arrives."
	objective.text = txt + "\n" + goal


func _update_tank(lvl: Level) -> void:
	var tank: Infected = null
	for i: Infected in lvl.all_infected():
		if i.is_tank() and not i.is_dead():
			tank = i
	tank_panel.visible = tank != null
	if tank:
		tank_bar.value = tank.hp_fraction()


func confirm_hit() -> void:
	_hit_t = 0.18
	if Settings.hit_marker_sound: Sfx.play("hitmarker")


func _draw_crosshair() -> void:
	if _hit_t > 0 and Settings.hit_markers:
		for direction in [Vector2(1,1), Vector2(-1,1), Vector2(1,-1), Vector2(-1,-1)]:
			crosshair.draw_line(direction * 5, direction * 11, Color.WHITE, 2)
	if float(crosshair.get_meta("aim", 0.0)) > 0.8:
		crosshair.draw_circle(Vector2.ZERO, 2.0 * Settings.crosshair_size, Color(Settings.crosshair_color, Settings.crosshair_opacity))
		return
	var gap := (6.0 + float(crosshair.get_meta("spread", 1.0)) * 6.0) * Settings.crosshair_size
	var c := Color(Settings.crosshair_color, Settings.crosshair_opacity)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		crosshair.draw_line(d * gap, d * (gap + 9.0 * Settings.crosshair_size), c, 2.0)
	crosshair.draw_circle(Vector2.ZERO, 1.5 * Settings.crosshair_size, c)


func _refresh_scoreboard(lvl: Level) -> void:
	var key := str(Game.stats.hash()) + str(Net.players.hash())
	if key == _score_key:
		return
	_score_key = key
	for c in score_grid.get_children():
		c.queue_free()
	for h in ["Survivor", "Kills", "Specials", "Headshots", "Revives", "Friendly fire", "Damage taken"]:
		score_grid.add_child(UIKit.label(h, 16, Color(0.75, 0.75, 0.78)))
	for slot in DB.SURVIVORS.size():
		var label: String = "%s (bot)" % DB.SURVIVORS[slot].name
		for id in Net.players:
			if Net.slot_of(id) == slot:
				label = "%s (%s)" % [Net.player_name(id), DB.SURVIVORS[slot].name]
		var st: Dictionary = Game.stats[slot] if slot < Game.stats.size() else {}
		score_grid.add_child(UIKit.label(label, 18, DB.SURVIVORS[slot].ui))
		for k in ["kills", "specials", "headshots", "revives", "ff", "damage"]:
			score_grid.add_child(UIKit.label(str(st.get(k, 0)), 18))


func _on_toast(text: String, color: Color) -> void:
	var l := UIKit.label(text, 21, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(660, 0)
	toast_box.add_child(l)
	while toast_box.get_child_count() > 5:
		toast_box.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func _on_banner(title: String, sub: String) -> void:
	banner_title.text = title
	banner_sub.text = sub
	_banner_t = 5.0


# --- Modals ---------------------------------------------------------------------------

# --- Story dialogue ---------------------------------------------------------------------

var _talk_panel: PanelContainer
var _talk_name: Label
var _talk_text: Label
var _talk_id := ""
var _talk_lines: Array = []
var _talk_i := 0


## Called when the local player presses E on an NPC: starts or advances the conversation.
func talk(lvl: Level, id: String) -> void:
	var npc := lvl.npc(id)
	if npc == null:
		return
	if _talk_id == id and _talk_panel and _talk_panel.visible:
		_talk_i += 1
		if _talk_i >= _talk_lines.size():
			_end_talk()
			return
	else:
		_talk_id = id
		_talk_lines = npc.lines(lvl.barea_stage())
		_talk_i = 0
		npc.mark_talked()
		lvl.request_story_talk.rpc_id(1, id)
	_show_talk(npc.data.name, _talk_lines[_talk_i], _talk_i == _talk_lines.size() - 1)


func _show_talk(who: String, line: String, last: bool) -> void:
	if _talk_panel == null:
		_talk_panel = PanelContainer.new()
		_talk_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_talk_panel.position = Vector2(-420, -300)
		_talk_panel.custom_minimum_size = Vector2(840, 0)
		_talk_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.06, 0.07, 0.92), 12, 3, Color(1.0, 0.85, 0.2)))
		root.add_child(_talk_panel)
		var v := VBoxContainer.new()
		_talk_panel.add_child(v)
		_talk_name = UIKit.label("", 22, Color(1.0, 0.85, 0.2))
		v.add_child(_talk_name)
		_talk_text = UIKit.label("", 21)
		_talk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_talk_text.custom_minimum_size = Vector2(800, 0)
		v.add_child(_talk_text)
	_talk_panel.visible = true
	_talk_name.text = who
	_talk_text.text = "\"%s\"\n[E] %s" % [line, "Done" if last else "Continue"]


func _end_talk() -> void:
	_talk_id = ""
	if _talk_panel:
		_talk_panel.visible = false


func _update_talk(lvl: Level, me: Survivor) -> void:
	if _talk_id == "" or lvl == null or me == null:
		return
	var npc := lvl.npc(_talk_id)
	if npc == null or npc.global_position.distance_to(me.global_position) > 6.0 or me.dead:
		_end_talk()


func close_modal() -> void:
	if modal:
		modal.queue_free()
		modal = null
	modal_kind = ""
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_modal(kind: String, title: String) -> VBoxContainer:
	close_modal()
	modal_kind = kind
	modal = PanelContainer.new()
	modal.set_anchors_preset(Control.PRESET_TOP_LEFT)
	modal.custom_minimum_size = Vector2(760, 0)
	modal.position = Vector2(-380, -330)
	modal.add_theme_stylebox_override("panel", UIKit.box(Color(0.08, 0.08, 0.09, 0.96), 14, 3, Color(0.6, 0.12, 0.1)))
	root.add_child(modal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	modal.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UIKit.label(title, 34, UIKit.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Close [Esc]", close_modal, 18))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return v


func open_pause() -> void:
	var v := _open_modal("pause", "PAUSED (the infected aren't)")
	var mode_txt: String = {"solo": "Solo game (bots fill the team)", "steam": "Steam friends lobby", "enet": "LAN game"}.get(Net.mode, "")
	v.add_child(UIKit.label(mode_txt, 18, Color(0.8, 0.85, 0.9)))
	v.add_child(UIKit.button("Resume", close_modal, 24))
	if Net.mode == "steam":
		v.add_child(UIKit.button("Invite Steam friends", SteamService.invite_friends, 24))
	elif Net.mode == "enet" and Net.is_host():
		var ips := Array(IP.get_local_addresses()).filter(func(a): return a.begins_with("192.") or a.begins_with("10.") or a.begins_with("172."))
		v.add_child(UIKit.label("Friends on your network can join: %s  (port %d)" % [", ".join(ips), Net.DEFAULT_PORT], 16, UIKit.ACCENT))
	v.add_child(UIKit.button("Settings", func():
		var settings := SettingsPanel.new()
		add_child(settings), 24))
	var controls := UIKit.label("WASD move, Space jump, Ctrl crouch, Shift walk, Left-click fire / use, Right-click aim, V shove (or heal/give a teammate),\nR reload, I inspect, E use / pick up / hold to revive, F flashlight, 1-5 or wheel switch, Tab scores", 15, Color(0.75, 0.78, 0.8))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(controls)
	if Net.is_host():
		v.add_child(UIKit.button("Restart world" if Game.open_world else "Restart chapter", func():
			close_modal()
			Game.goto_chapter(Game.chapter), 20))
	v.add_child(UIKit.button("Leave to menu", func():
		Settings.save_settings()
		Net.leave(""), 22))


func _slider(text: String, lo: float, hi: float, val: float, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	var l := UIKit.label(text, 18)
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(x):
		cb.call(x)
		Settings.save_settings())
	row.add_child(s)
	return row


func open_gunsmith(s: Survivor) -> void:
	if not s.level().at_gunsmith(s):
		return
	var v := _open_modal("gunsmith", "THE GUNSMITH")
	modal.custom_minimum_size.x = 1120
	modal.position = Vector2(-560, -360)
	modal.add_theme_stylebox_override("panel", UIKit.box(Color(0.035, 0.055, 0.065, 0.99), 8, 2, ArsenalPanel.MINT.darkened(0.4)))
	var panel := ArsenalPanel.new()
	panel.setup(s)
	v.add_child(panel)
	s.ui_open = true


func open_world_map(lvl: Level) -> void:
	var box := _open_modal("world_map", "DEAD LOW TIDE — WORLD MAP")
	modal.custom_minimum_size.x = 900
	var map := WorldMap.new()
	map.level = lvl
	box.add_child(map)
	box.add_child(UIKit.label("Green squares: camps / gunsmiths • Orange: cars • Blue: boats\nClick to mark a personal waypoint. [M] or Esc to close.",16,UIKit.ACCENT))
