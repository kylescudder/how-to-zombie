class_name HUD
extends CanvasLayer
## In-game overlay plus the shop, travel, pause and scoreboard panels.

var root: Control
var money_label: Label
var island_label: Label
var quest_box: VBoxContainer
var toast_box: VBoxContainer
var boss_panel: PanelContainer
var boss_name: Label
var boss_bar: ProgressBar
var prompt_label: Label
var crosshair: Control
var hotbar: HBoxContainer
var hp_bar: ProgressBar
var fish_panel: PanelContainer
var fish_title: Label
var tension_bar: ProgressBar
var stamina_bar: ProgressBar
var fish_hint: Label
var cast_bar: ProgressBar
var bite_label: Label
var downed_overlay: ColorRect
var downed_label: Label
var scoreboard: PanelContainer
var score_list: VBoxContainer
var modal: PanelContainer
var modal_kind := ""
var _hotbar_key := ""


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)

	# Top-left: money + island
	var tl := VBoxContainer.new()
	tl.position = Vector2(24, 18)
	root.add_child(tl)
	money_label = UIKit.label("$0", 46, UIKit.ACCENT)
	tl.add_child(money_label)
	island_label = UIKit.label("", 20, Color(0.85, 0.9, 1.0))
	tl.add_child(island_label)

	# Top-right: quests
	var qp := PanelContainer.new()
	qp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	qp.position = Vector2(-444, 18)
	qp.custom_minimum_size = Vector2(420, 0)
	root.add_child(qp)
	quest_box = VBoxContainer.new()
	qp.add_child(quest_box)

	# Top-center: boss bar + toasts
	var tc := VBoxContainer.new()
	tc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tc.position = Vector2(-330, 18)
	tc.custom_minimum_size = Vector2(660, 0)
	tc.alignment = BoxContainer.ALIGNMENT_BEGIN
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc)
	boss_panel = PanelContainer.new()
	var bv := VBoxContainer.new()
	boss_panel.add_child(bv)
	boss_name = UIKit.label("", 26, Color(1.0, 0.45, 0.35))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(boss_name)
	boss_bar = UIKit.bar(Color(0.9, 0.2, 0.2), 620, 22)
	bv.add_child(boss_bar)
	tc.add_child(boss_panel)
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(toast_box)

	# Center: crosshair, prompt, bite alert
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)
	prompt_label = UIKit.label("", 24)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-400, 40)
	prompt_label.custom_minimum_size = Vector2(800, 0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_label)
	bite_label = UIKit.label("!!! CLICK !!!", 64, UIKit.GOLD)
	bite_label.set_anchors_preset(Control.PRESET_CENTER)
	bite_label.position = Vector2(-300, -140)
	bite_label.custom_minimum_size = Vector2(600, 0)
	bite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(bite_label)

	# Fishing panel
	fish_panel = PanelContainer.new()
	fish_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fish_panel.position = Vector2(-220, -260)
	fish_panel.custom_minimum_size = Vector2(440, 0)
	root.add_child(fish_panel)
	var fv := VBoxContainer.new()
	fish_panel.add_child(fv)
	fish_title = UIKit.label("", 24, UIKit.GOLD)
	fish_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(fish_title)
	fv.add_child(UIKit.label("LINE TENSION", 16, Color(0.8, 0.8, 0.85)))
	tension_bar = UIKit.bar(Color(0.4, 0.85, 0.4), 410, 22)
	fv.add_child(tension_bar)
	fv.add_child(UIKit.label("ZOMBIE STAMINA", 16, Color(0.8, 0.8, 0.85)))
	stamina_bar = UIKit.bar(Color(0.95, 0.65, 0.2), 410, 14)
	fv.add_child(stamina_bar)
	fish_hint = UIKit.label("", 20)
	fish_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(fish_hint)
	cast_bar = UIKit.bar(UIKit.GOLD, 300, 18)
	cast_bar.set_anchors_preset(Control.PRESET_CENTER)
	cast_bar.position = Vector2(-150, 70)
	root.add_child(cast_bar)

	# Bottom: hp + hotbar
	hp_bar = UIKit.bar(Color(0.9, 0.25, 0.3), 280, 26)
	hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_bar.position = Vector2(24, -50)
	root.add_child(hp_bar)
	hotbar = HBoxContainer.new()
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.position = Vector2(-450, -90)
	hotbar.custom_minimum_size = Vector2(900, 70)
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 6)
	root.add_child(hotbar)

	# Downed overlay
	downed_overlay = ColorRect.new()
	downed_overlay.color = Color(0.6, 0.05, 0.05, 0.35)
	downed_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	downed_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(downed_overlay)
	downed_label = UIKit.label("YOU'RE DOWN!\nA friend can slap you awake...\nor Mr. Squawks the seagull will come for you.", 34)
	downed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	downed_label.set_anchors_preset(Control.PRESET_CENTER)
	downed_label.position = Vector2(-450, -60)
	downed_label.custom_minimum_size = Vector2(900, 0)
	downed_overlay.add_child(downed_label)

	# Scoreboard
	scoreboard = PanelContainer.new()
	scoreboard.set_anchors_preset(Control.PRESET_CENTER)
	scoreboard.position = Vector2(-260, -180)
	scoreboard.custom_minimum_size = Vector2(520, 0)
	root.add_child(scoreboard)
	score_list = VBoxContainer.new()
	scoreboard.add_child(score_list)

	Game.toast_received.connect(_on_toast)
	Game.state_changed.connect(_refresh_quests)
	set_active(false)


func set_active(on: bool) -> void:
	visible = on
	if not on:
		close_modal()


# --- Per-frame ------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not visible:
		return
	var lvl := get_tree().get_first_node_in_group("level") as Level
	var p: Player = lvl.local_player() if lvl else null
	money_label.text = DB.format_money(Game.money)
	island_label.text = "%s   |   %d survivor%s" % [DB.ISLANDS[Game.island].name, Net.players.size(), "" if Net.players.size() == 1 else "s"]
	_update_boss()
	if p == null:
		return
	if Input.is_action_just_pressed("pause"):
		if modal:
			close_modal()
		else:
			open_pause()
	scoreboard.visible = Input.is_action_pressed("scoreboard") and modal == null
	if scoreboard.visible:
		_refresh_scoreboard()
	p.ui_open = modal != null
	hp_bar.value = p.hp / Player.MAX_HP
	prompt_label.text = p.prompt if modal == null else ""
	downed_overlay.visible = p.downed
	crosshair.queue_redraw()
	_update_hotbar(p)
	_update_fishing(p)


func _update_boss() -> void:
	var bosses := get_tree().get_nodes_in_group("boss")
	boss_panel.visible = not bosses.is_empty()
	if bosses.size() > 0:
		var b: Zombie = bosses[0]
		boss_name.text = b.data.name
		boss_bar.value = b.hp_fraction()


func _update_fishing(p: Player) -> void:
	var reeling := p.rod_state == Player.Rod.REELING
	fish_panel.visible = reeling
	cast_bar.visible = p.rod_state == Player.Rod.CHARGING
	cast_bar.value = p.cast_power
	bite_label.visible = p.rod_state == Player.Rod.BITE
	if reeling:
		var z: Dictionary = DB.ZOMBIES.get(p.hooked, {})
		fish_title.text = "HOOKED: %s  (%dm)" % [("???" if z.get("rare", false) else "Something"), int(p.reel_dist)]
		tension_bar.value = p.tension
		var tc := Color(0.4, 0.85, 0.4).lerp(Color(1.0, 0.2, 0.2), clampf((p.tension - 0.4) / 0.5, 0.0, 1.0))
		tension_bar.add_theme_stylebox_override("fill", UIKit.box(tc, 8))
		stamina_bar.value = p.stamina
		if p.tension > 0.8:
			fish_hint.text = "LET GO! The line's about to snap!"
			fish_hint.add_theme_color_override("font_color", UIKit.WARN)
		elif p.stamina < 0.3:
			fish_hint.text = "It's TIRED!  [Right-click] to YANK it into the air!"
			fish_hint.add_theme_color_override("font_color", UIKit.GOLD)
		elif p.thrashing:
			fish_hint.text = "It's THRASHING! Ease off..."
			fish_hint.add_theme_color_override("font_color", UIKit.WARN)
		else:
			fish_hint.text = "Hold [Click] to reel, release to rest"
			fish_hint.add_theme_color_override("font_color", Color.WHITE)


func _update_hotbar(p: Player) -> void:
	var key := "%s|%d|%s|%.1f" % [",".join(p.items), p.item_idx, str(p.ammo.get(p.current_item(), 0)), p.reload_t]
	if key == _hotbar_key:
		return
	_hotbar_key = key
	for c in hotbar.get_children():
		c.queue_free()
	for i in p.items.size():
		var id: String = p.items[i]
		var w: Dictionary = DB.WEAPONS[id]
		var panel := PanelContainer.new()
		var sel := i == p.item_idx
		panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.95, 0.55, 0.2, 0.95) if sel else Color(0.08, 0.1, 0.12, 0.7), 10, 3 if sel else 0, Color.WHITE))
		var v := VBoxContainer.new()
		panel.add_child(v)
		v.add_child(UIKit.label(str((i + 1) % 10), 14, Color(1, 1, 1, 0.7)))
		var nm: String = w.name if id != "rod" else DB.RODS[Game.best_rod()].name
		v.add_child(UIKit.label(nm, 17 if sel else 15))
		if w.kind == "gun" and sel:
			var txt := "RELOADING" if p.reload_t > 0.0 else "%d / %d" % [int(p.ammo.get(id, 0)), int(w.mag)]
			v.add_child(UIKit.label(txt, 14, UIKit.GOLD))
		hotbar.add_child(panel)


func _draw_crosshair() -> void:
	var c := Color(1, 1, 1, 0.9)
	crosshair.draw_circle(Vector2.ZERO, 3.0, c)
	crosshair.draw_arc(Vector2.ZERO, 11.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 2.0)


func _refresh_quests() -> void:
	for c in quest_box.get_children():
		c.queue_free()
	quest_box.add_child(UIKit.label("QUESTS", 20, UIKit.GOLD))
	var qs: Array = Game.current_quests()
	var stage: int = Game.quest_stage[Game.island]
	for i in qs.size():
		var q: Dictionary = qs[i]
		var done := i < stage
		var cur := i == stage
		var txt: String = ("✔ " if done else ("▶ " if cur else "• ")) + Game.quest_text(q, Game.quest_count[Game.island] if cur else (q.goal if done else 0))
		var l := UIKit.label(txt, 18, Color(0.6, 0.65, 0.6) if done else (Color.WHITE if cur else Color(0.6, 0.6, 0.65)))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(390, 0)
		quest_box.add_child(l)
	if Game.quests_done():
		var nxt := "All done! Sail on from the boat." if Game.island < DB.ISLANDS.size() - 1 else "You beat the game! Keep fishing for glory."
		quest_box.add_child(UIKit.label(nxt, 18, UIKit.ACCENT))
	if Game.has_bait and not Game.boss_alive:
		quest_box.add_child(UIKit.label("You have Boss Bait! Pour it in the chum bucket.", 16, UIKit.WARN))


func _refresh_scoreboard() -> void:
	if score_list.get_child_count() == Net.players.size() + 2:
		return
	for c in score_list.get_children():
		c.queue_free()
	score_list.add_child(UIKit.label("SURVIVORS", 26, UIKit.GOLD))
	for id in Net.players:
		var info: Dictionary = Net.players[id]
		var col: Color = DB.PLAYER_COLORS[int(info.color) % DB.PLAYER_COLORS.size()]
		score_list.add_child(UIKit.label("%s%s" % [info.name, "  (host)" if id == 1 else ""], 22, col))
	score_list.add_child(UIKit.label("Catches %d  |  Kills %d  |  Earned %s  |  Best combo x%.1f" % [Game.stats.catches, Game.stats.kills, DB.format_money(int(Game.stats.earned)), float(Game.stats.best_mult)], 16, Color(0.8, 0.8, 0.85)))


func _on_toast(text: String) -> void:
	var l := UIKit.label(text, 22)
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


# --- Modals ---------------------------------------------------------------------

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
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.custom_minimum_size = Vector2(760, 0)
	modal.position = Vector2(-380, -330)
	modal.add_theme_stylebox_override("panel", UIKit.box(Color(0.1, 0.12, 0.14, 0.96), 18, 4, Color(0.95, 0.55, 0.2)))
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


func open_shop() -> void:
	var v := _open_modal("shop", "DOC'S BAIT & BRAINS")
	v.add_child(UIKit.label("\"Bring me zombies, I give you money. Don't ask what I do with them.\"", 16, Color(0.75, 0.8, 0.75)))
	var money := UIKit.label("Team wallet: " + DB.format_money(Game.money), 24, UIKit.ACCENT)
	v.add_child(money)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var rebuild := func():
		if modal_kind == "shop":
			open_shop()

	list.add_child(UIKit.label("BOSS BAIT", 20, UIKit.WARN))
	var bait_desc := "Pour it in the chum bucket at the end of the pier to summon %s." % DB.ZOMBIES[DB.ISLANDS[Game.island].boss].name
	var bait_state := ""
	if Game.boss_alive:
		bait_state = "Boss is out!"
	elif Game.has_bait:
		bait_state = "In the bucket"
	elif not Game.bait_available():
		bait_state = "Finish quests first"
	list.add_child(_shop_row("bait", "Boss Bait", bait_desc, bait_state, rebuild))

	list.add_child(UIKit.label("RODS (bigger rods hook tougher zombies)", 20, UIKit.GOLD))
	for r in DB.ROD_ORDER:
		var rd: Dictionary = DB.RODS[r]
		if rd.price == 0:
			continue
		list.add_child(_shop_row(r, rd.name, "Cast x%.1f  Reel x%.1f  Line x%.1f  Hooks tier %d zombies" % [rd.cast, rd.reel, rd.line, rd.tier], "Owned" if r in Game.owned else "", rebuild))
	list.add_child(UIKit.label("WEAPONS", 20, UIKit.GOLD))
	for w in DB.WEAPON_ORDER:
		var wd: Dictionary = DB.WEAPONS[w]
		if wd.price == 0:
			continue
		var desc := ""
		match wd.kind:
			"melee": desc = "Melee. %d dmg, big knockback x%.0f" % [wd.damage, wd.knock]
			"gun": desc = "%d dmg%s, %d round mag" % [wd.damage, (" x%d pellets" % wd.pellets) if wd.pellets > 1 else "", wd.mag]
			"throw": desc = "Thrown. %d dmg, %dm blast. KABOOM bonus!" % [wd.damage, wd.radius]
		list.add_child(_shop_row(w, wd.name, desc, "Owned" if w in Game.owned else "", rebuild))
	v.add_child(UIKit.label("Purchases are shared by the whole team.", 14, Color(0.7, 0.7, 0.75)))


func _shop_row(id: String, nm: String, desc: String, state: String, rebuild: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UIKit.label(nm, 22))
	var d := UIKit.label(desc, 15, Color(0.75, 0.78, 0.8))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(480, 0)
	info.add_child(d)
	var price := Game.item_price(id)
	var b := UIKit.button(state if state != "" else DB.format_money(price), func():
		Game.request_buy.rpc_id(1, id)
		get_tree().create_timer(0.25).timeout.connect(rebuild), 20)
	b.custom_minimum_size = Vector2(170, 0)
	b.disabled = state != "" or Game.money < price
	row.add_child(b)
	return row


func open_travel() -> void:
	var v := _open_modal("travel", "THE S.S. NOPE")
	if Game.boss_alive:
		v.add_child(UIKit.label("Not while there's a boss on the island!", 22, UIKit.WARN))
		return
	v.add_child(UIKit.label("Beat each island's boss to unlock the next one.", 18, Color(0.8, 0.85, 0.9)))
	for i in DB.ISLANDS.size():
		var isl: Dictionary = DB.ISLANDS[i]
		var row := HBoxContainer.new()
		var l := UIKit.label("%d. %s" % [i + 1, isl.name], 24, Color.WHITE if i <= Game.unlocked_island else Color(0.5, 0.5, 0.55))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var txt := "You are here" if i == Game.island else ("Sail!" if i <= Game.unlocked_island else "Locked")
		var idx := i
		var b := UIKit.button(txt, func():
			Game.request_travel.rpc_id(1, idx)
			close_modal(), 20)
		b.disabled = i == Game.island or i > Game.unlocked_island or not Net.is_host()
		b.custom_minimum_size = Vector2(170, 0)
		row.add_child(b)
		v.add_child(row)
	if not Net.is_host():
		v.add_child(UIKit.label("Only the host can steer the boat.", 16, Color(0.7, 0.7, 0.75)))


func open_pause() -> void:
	var v := _open_modal("pause", "PAUSED (the zombies aren't)")
	var mode_txt: String = {"solo": "Solo game", "steam": "Steam friends lobby", "enet": "LAN game"}.get(Net.mode, "")
	v.add_child(UIKit.label(mode_txt, 18, Color(0.8, 0.85, 0.9)))
	v.add_child(UIKit.button("Resume", close_modal, 24))
	if Net.mode == "steam":
		v.add_child(UIKit.button("Invite Steam friends", SteamService.invite_friends, 24))
	elif Net.mode == "enet" and Net.is_host():
		var ips := Array(IP.get_local_addresses()).filter(func(a): return a.begins_with("192.") or a.begins_with("10.") or a.begins_with("172."))
		v.add_child(UIKit.label("Friends on your network can join: %s  (port %d)" % [", ".join(ips), Net.DEFAULT_PORT], 16, UIKit.ACCENT))
	v.add_child(_slider("Mouse sensitivity", 0.0005, 0.008, Settings.mouse_sensitivity, func(x): Settings.mouse_sensitivity = x))
	v.add_child(_slider("Volume", 0.0, 1.0, Settings.master_volume, func(x):
		Settings.master_volume = x
		Settings.apply()))
	v.add_child(_slider("Field of view", 60.0, 110.0, Settings.fov, func(x):
		Settings.fov = x
		var vp_cam := get_viewport().get_camera_3d()
		if vp_cam:
			vp_cam.fov = x))
	v.add_child(UIKit.label("Controls: WASD move, Shift sprint, Space jump, Click use, Right-click yank, E interact,\nQ drop, R reload, 1-0 / wheel switch, Tab scores", 15, Color(0.75, 0.78, 0.8)))
	v.add_child(UIKit.button("Leave to menu", func():
		Settings.save_settings()
		if Net.is_host():
			Game.save_game()
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
