class_name ArsenalPanel
extends VBoxContainer
## Gunsmith: real-time stats and a lit 3D inspection of the gun being upgraded.

const MINT := Color(0.48, 0.92, 0.77)
const MUTED := Color(0.57, 0.65, 0.67)
var survivor: Survivor
var selected := ""
var _key := ""
var _preview: Node3D
var _t := 0.0
var _pending := 0.0


func setup(s: Survivor) -> void:
	survivor = s
	selected = s.weapon_id("primary") if s.has_slot("primary") else s.weapon_id("secondary")


func _process(delta: float) -> void:
	if not is_instance_valid(survivor):
		return
	_t += delta
	_pending = maxf(0, _pending - delta)
	var key := str(Game.arsenal.hash()) + selected + str(survivor.net_inv.get("primary", {}).get("id", "")) + str(survivor.net_inv.get("secondary", {}).get("id", "")) + str(_pending > 0)
	if key != _key:
		_key = key
		_rebuild()
	if _preview:
		_preview.rotation.y = -0.30 + sin(_t * 0.35) * 0.12


func _rebuild() -> void:
	_preview = null
	for c in get_children():
		c.free()
	add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	add_child(top)
	var note := UIKit.label("BUILD YOUR GUN. KEEP YOUR EDGE.", 15, MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(note)
	top.add_child(UIKit.label("%s  /  %d CREDITS" % [survivor.short_name().to_upper(), Game.credits(survivor.slot)], 20, MINT))
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for id: String in DB.GUN_PROFILES:
		if DB.weapon(id).has("expires"):
			continue  # discounted stock: no warranty, no upgrades
		var gun_id := id
		var button := UIKit.button(DB.GUN_PROFILES[id].model, func(): selected = gun_id, 13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.modulate = MINT if selected == id else Color(0.65, 0.7, 0.72)
		tabs.add_child(button)
	var w := Game.gun_stats(survivor.slot, selected)
	if w.is_empty():
		return
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 22)
	add_child(middle)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(left)
	left.add_child(UIKit.label(w.model, 32, Color(0.9, 0.94, 0.93)))
	left.add_child(UIKit.label("%s  /  %s" % [w.caliber, "FULL AUTO" if w.auto else "SEMI AUTO" if selected != "pump_shotgun" else "PUMP ACTION"], 14, MUTED))
	left.add_child(_inspection())
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 385
	right.add_theme_constant_override("separation", 6)
	middle.add_child(right)
	right.add_child(UIKit.label("WEAPON DATA", 16, MINT))
	for row in [
		["Damage / projectile", "%.1f × %d" % [w.dmg, w.pellets]],
		["Rate of fire", "%d RPM" % roundi(60.0 / w.rof)],
		["Magazine", "%d rounds" % w.mag],
		["Reload", "%.2f s" % w.reload],
		["Hip spread", "%.2f°" % w.spread],
		["Recoil / shot", "%.2f°" % rad_to_deg(w.recoil)],
		["Recoil recovery", "%.1f / s" % w.recovery],
		["Full damage range", "%.0f m" % w.range],
		["Aim magnification", "%.1f×" % w.zoom],
	]:
		var r := HBoxContainer.new()
		right.add_child(r)
		var label := UIKit.label(row[0], 17, MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(label)
		r.add_child(UIKit.label(row[1], 18))
	var owned := selected in [survivor.weapon_id("primary"), survivor.weapon_id("secondary")]
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	add_child(grid)
	for kind: String in DB.UPGRADES:
		var spec: Dictionary = DB.UPGRADES[kind]
		var tier := int(Game.gun_upgrades(survivor.slot, selected).get(kind, 0))
		var cost := DB.upgrade_cost(kind, tier)
		var maxed := tier >= int(spec.max)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UIKit.box(Color(0.075, 0.12, 0.13), 5, 1, Color(0.2, 0.32, 0.31)))
		grid.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 7)
		card.add_child(v)
		v.add_child(UIKit.label("%s  %d/%d" % [spec.name, tier, spec.max], 14, MINT))
		var desc := UIKit.label(spec.detail, 14, MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(210, 45)
		v.add_child(desc)
		var next := Game.gun_upgrades(survivor.slot, selected).duplicate()
		next[kind] = tier + 1
		var after := DB.gun_stats(selected, next)
		var benefit := {"power": "Damage %.1f → %.1f" % [w.dmg, after.dmg], "magazine": "Rounds %d → %d" % [w.mag, after.mag], "handling": "Reload %.2f → %.2f s" % [w.reload, after.reload], "optic": "Aim %.1f× → %.1f×" % [w.zoom, after.zoom]}
		v.add_child(UIKit.label("FULLY UPGRADED" if maxed else benefit[kind], 14))
		var caption := "INSTALLED" if maxed else ("EQUIP THIS GUN" if not owned else ("BUY · %d CR" % cost if Game.credits(survivor.slot) >= cost else "NEED %d CR" % cost))
		var upgrade_kind := kind
		var gun_id := selected
		var buy := UIKit.button(caption, func():
			_pending = 0.8
			survivor.level().request_upgrade.rpc_id(1, survivor.slot, gun_id, upgrade_kind), 16)
		buy.name = "Buy_" + kind
		buy.disabled = maxed or not owned or Game.credits(survivor.slot) < cost or _pending > 0
		v.add_child(buy)
	var footer := UIKit.label("RMB aim · V shove · R reload    /    15 credits per infected · 75 per special\nUpgrades belong to this survivor + gun type for this campaign. New magazines must be reloaded.", 14, MUTED)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(footer)


func _inspection() -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(560, 250)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(560, 250)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.075, 0.10, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.75, 0.8)
	e.ambient_light_energy = 1.0
	env.environment = e
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -40, 0)
	light.light_energy = 2.5
	world.add_child(light)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.5, 0.5, 0.2)
	rim.light_color = MINT
	rim.light_energy = 3.0
	world.add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1, 0.6, 0.6)
	fill.light_color = Color(1.0, 0.92, 0.82)
	fill.light_energy = 2.0
	world.add_child(fill)
	_preview = ItemModels.make(selected, Game.gun_upgrades(survivor.slot, selected))
	world.add_child(_preview)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.30 if selected == "pistol" else (0.43 if selected == "dual_pistols" else 0.55)
	world.add_child(cam)
	var center := Vector3(0, 0, -0.20 if selected not in ["pistol", "dual_pistols"] else -0.05)
	cam.position = center + Vector3(1.0, 0.32, 0.45)
	cam.transform = Transform3D(Basis.looking_at(center - cam.position), cam.position)
	return container
