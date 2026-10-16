class_name Islands
## Builds the three island layouts out of primitives and returns the marker positions the
## level needs (spawn, shop, grinder, etc). Every island gets the same core set of props.

const SAND := Color(0.93, 0.83, 0.58)
const GRASS := Color(0.45, 0.72, 0.35)
const WOOD := Color(0.6, 0.42, 0.26)
const WOOD_DARK := Color(0.42, 0.28, 0.17)


static func build(root: Node3D, idx: int) -> Dictionary:
	var m := {}
	match idx:
		0:
			m = _pier_island(root)
		1:
			m = _suburb_island(root)
		_:
			m = _mall_island(root)
	# Sea floor so nothing falls forever.
	Build.solid_box(root, Vector3(800, 1, 800), Color(0.3, 0.32, 0.25), Vector3(0, -9.5, 0))
	return m


# --- Island 1: Bait & Tackle Pier --------------------------------------------

static func _pier_island(root: Node3D) -> Dictionary:
	Build.island_mound(root, 17.0, 1.0, Vector3.ZERO, SAND)
	_grass_patch(root, Vector3(-4, 1.0, -4), 9.0)
	_pier(root, Vector3(0, 0, 15), 22.0)
	var m := _core_props(root, Vector3(-7, 1.0, -5), Vector3(6, 1.0, -3), Vector3(10, 1.0, -8), Vector3(-2.5, 1.3, 31), Vector3(1.4, 1.3, 33))
	m.spawn = Vector3(0, 2.0, 2)
	m.boss_spawn = Vector3(0, -3, 52)
	m.boss_target = Vector3(0, 2, 6)
	m.drop_spot = Vector3(-2, 2.5, -1)
	for p in [Vector3(-12, 1, 6), Vector3(12, 1, 7), Vector3(-13, 1, -6), Vector3(4, 1, -12), Vector3(14, 1, -2)]:
		_palm(root, p)
	for p in [Vector3(9, 1, 9), Vector3(-10, 1, 11), Vector3(-15, 0.5, 0)]:
		_rock(root, p, 1.2)
	_crates(root, Vector3(3, 1.0, 5))
	_crates(root, Vector3(1.6, 1.3, 26))
	_lifebuoy_sign(root, Vector3(-1.9, 1.3, 18), "NO SWIMMING\n(zombies)")
	return m


# --- Island 2: Cul-de-Sac Reef ------------------------------------------------

static func _suburb_island(root: Node3D) -> Dictionary:
	Build.island_mound(root, 15.0, 1.0, Vector3.ZERO, GRASS.darkened(0.05))
	_grass_patch(root, Vector3(0, 1.0, 0), 13.5)
	# Road with dashes
	Build.box(root, Vector3(4, 0.05, 28), Color(0.25, 0.25, 0.28), Vector3(4, 1.03, 0))
	for z in range(-12, 13, 4):
		Build.box(root, Vector3(0.25, 0.06, 1.6), Color(0.95, 0.9, 0.4), Vector3(4, 1.05, z))
	_pier(root, Vector3(0, 0, 13), 22.0)
	var m := _core_props(root, Vector3(-7, 1.0, -5), Vector3(8, 1.0, -6), Vector3(10.5, 1.0, 1), Vector3(-2.5, 1.3, 29), Vector3(1.4, 1.3, 31))
	m.spawn = Vector3(0, 2.0, 2)
	m.boss_spawn = Vector3(0, -3, 50)
	m.boss_target = Vector3(0, 2, 4)
	m.drop_spot = Vector3(0, 2.5, -2)
	# Flooded houses poking out of the water, with plank bridges.
	_flooded_house(root, Vector3(26, 0, -6), Color(0.85, 0.55, 0.5))
	_flooded_house(root, Vector3(-26, 0, 6), Color(0.55, 0.7, 0.85))
	_flooded_house(root, Vector3(-4, 0, -30), Color(0.95, 0.85, 0.55))
	_plank_bridge(root, Vector3(14, 1.6, -4), Vector3(21.5, 2.6, -5.5))
	_plank_bridge(root, Vector3(-14, 1.6, 4), Vector3(-21.5, 2.6, 5.5))
	_plank_bridge(root, Vector3(-2, 1.6, -14), Vector3(-3.6, 2.6, -25.5))
	# Picket fences, mailbox, a car roof, and a trampoline (it launches things).
	for x in range(-12, -2, 2):
		Build.solid_box(root, Vector3(0.15, 0.9, 0.15), Color.WHITE, Vector3(x, 1.45, 8))
	Build.box(root, Vector3(10, 0.1, 0.1), Color.WHITE, Vector3(-7, 1.7, 8))
	Build.solid_box(root, Vector3(0.2, 1.2, 0.2), WOOD, Vector3(1.5, 1.6, 7))
	Build.solid_box(root, Vector3(0.5, 0.4, 0.8), Color(0.2, 0.3, 0.8), Vector3(1.5, 2.3, 7))
	Build.solid_box(root, Vector3(4.2, 1.2, 2.2), Color(0.85, 0.15, 0.15), Vector3(-17, 0.2, -12), Vector3(0, 30, 8))
	_trampoline(root, Vector3(-6, 1.0, 3))
	for p in [Vector3(-11, 1, -10), Vector3(11, 1, 10), Vector3(-12, 1, 3)]:
		_tree(root, p)
	return m


# --- Island 3: Mega-Mall Atoll ------------------------------------------------

static func _mall_island(root: Node3D) -> Dictionary:
	# The mall roof is the island. Ramps let you climb out of the sea.
	Build.solid_box(root, Vector3(40, 11, 30), Color(0.7, 0.68, 0.65), Vector3(0, -3.5, 0))
	Build.box(root, Vector3(40.4, 0.4, 30.4), Color(0.55, 0.55, 0.58), Vector3(0, 2.1, 0))
	Build.box(root, Vector3(39, 0.02, 29), Color(0.86, 0.76, 0.62), Vector3(0, 2.0, 0))
	for x in range(-18, 19, 4):
		Build.box(root, Vector3(0.12, 0.03, 29), Color(0.7, 0.6, 0.5), Vector3(x, 2.01, 0))
	for z in range(-14, 15, 4):
		Build.box(root, Vector3(39, 0.03, 0.12), Color(0.7, 0.6, 0.5), Vector3(0, 2.01, z))
	# Painted parking-style arrows + a giant "HELP" message for rescue choppers
	var help := Build.label(root, "H E L P", Vector3(-6, 2.05, -2), 900, Color(0.95, 0.95, 0.9, 0.9))
	help.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	help.rotation_degrees = Vector3(-90, 0, 0)
	help.outline_size = 0
	# Big neon sign
	var sign_root := Node3D.new()
	sign_root.position = Vector3(0, 2, -14.5)
	root.add_child(sign_root)
	Build.box(sign_root, Vector3(18, 3.5, 0.4), Color(0.15, 0.1, 0.2), Vector3(0, 2.2, 0))
	var l := Build.label(sign_root, "MEGA MALL", Vector3(0, 2.3, 0.3), 260, Color(1.0, 0.35, 0.75))
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	for x in [-7, 7]:
		Build.solid_box(sign_root, Vector3(0.4, 2, 0.4), Color(0.3, 0.3, 0.3), Vector3(x, 0.0, 0))
	# AC units + skylights
	for p in [Vector3(-14, 2.6, 8), Vector3(-10, 2.6, 8), Vector3(14, 2.6, -8)]:
		Build.solid_box(root, Vector3(2.4, 1.2, 2.4), Color(0.75, 0.78, 0.8), p)
		Build.cyl(root, 0.9, 0.9, 0.1, Color(0.3, 0.3, 0.32), p + Vector3(0, 0.62, 0))
	for p in [Vector3(0, 2.15, 4), Vector3(6, 2.15, 4)]:
		Build.box(root, Vector3(4, 0.3, 3), Color(0.6, 0.85, 1.0, 0.6), p)
	# Ramps out of the water
	Build.solid_box(root, Vector3(5, 0.4, 16), Color(0.9, 0.85, 0.3), Vector3(-23.5, -0.3, 6), Vector3(-17, 0, 0))
	Build.solid_box(root, Vector3(5, 0.4, 16), Color(0.9, 0.85, 0.3), Vector3(23.5, -0.3, -6), Vector3(17, 180, 0))
	_pier(root, Vector3(0, 0.7, 15), 18.0)
	var m := _core_props(root, Vector3(-12, 2.0, -6), Vector3(10, 2.0, -9), Vector3(14, 2.0, 2), Vector3(-2.5, 2.0, 30), Vector3(1.4, 2.0, 30))
	m.spawn = Vector3(0, 3.0, 0)
	m.boss_spawn = Vector3(0, -3, 50)
	m.boss_target = Vector3(0, 3, 6)
	m.drop_spot = Vector3(0, 3.5, -4)
	# Shopping carts
	for p in [Vector3(4, 2.4, -4), Vector3(-5, 2.4, 9)]:
		Build.solid_box(root, Vector3(0.9, 0.7, 1.3), Color(0.7, 0.72, 0.75), p, Vector3(0, 25, 0))
	# A few flooded mall-front lamp posts sticking out of the sea
	for p in [Vector3(-30, 0, -20), Vector3(30, 0, 20), Vector3(-34, 0, 18), Vector3(28, 0, -22)]:
		Build.solid_cyl(root, 0.2, 9, Color(0.2, 0.2, 0.22), p + Vector3(0, -2.5, 0))
		Build.sphere(root, 0.4, Color(1.0, 0.9, 0.6), p + Vector3(0, 2.2, 0)).material_override = Build.mat(Color(1.0, 0.9, 0.6), 0.5, 2.0)
	return m


# --- Shared props -------------------------------------------------------------

## Builds Doc's shack (shop + mirror), the Brain Bank, the Lucky Brain, the boat and the chum bucket.
static func _core_props(root: Node3D, shack: Vector3, grinder: Vector3, slot: Vector3, boat_dock: Vector3, chum: Vector3) -> Dictionary:
	var m := {}
	# Doc's shack
	var s := Node3D.new()
	s.position = shack
	root.add_child(s)
	Build.solid_box(s, Vector3(6, 3.2, 0.3), WOOD, Vector3(0, 1.6, -2.5))
	Build.solid_box(s, Vector3(0.3, 3.2, 5), WOOD, Vector3(-3, 1.6, 0))
	Build.solid_box(s, Vector3(0.3, 3.2, 5), WOOD, Vector3(3, 1.6, 0))
	Build.solid_box(s, Vector3(6.8, 0.3, 6), WOOD_DARK, Vector3(0, 3.35, 0.2), Vector3(-8, 0, 0))
	Build.solid_box(s, Vector3(5.6, 1.1, 0.8), Color(0.75, 0.3, 0.25), Vector3(0, 0.55, 1.8))  # counter
	Build.box(s, Vector3(5.8, 0.08, 1.0), Color(0.9, 0.85, 0.75), Vector3(0, 1.14, 1.8))
	var doc := CharacterModel.new()
	s.add_child(doc)
	doc.position = Vector3(0, 0, 0.4)
	doc.setup(Color(0.95, 0.78, 0.62), Color(0.95, 0.95, 0.97), Color(0.3, 0.3, 0.35), false, 1.3, "goggles")
	doc.set_meta("idle_npc", true)
	Build.label(s, "DOC'S BAIT & BRAINS", Vector3(0, 4.6, 3.2), 72, Color(1.0, 0.9, 0.4))
	Build.interact_zone(s, "shop", Vector3(5.6, 2, 1.4), Vector3(0, 1.2, 2.3), "Shop with Doc")
	# Shelves with jars
	for i in 4:
		Build.box(s, Vector3(0.3, 0.4, 0.3), Color(0.5, 0.8, 0.4, 0.8), Vector3(-2 + i * 1.3, 2.2, -2.2))
	Build.box(s, Vector3(5.5, 0.08, 0.5), WOOD_DARK, Vector3(0, 1.98, -2.2))
	# Mirror / wardrobe on the outside wall
	Build.box(s, Vector3(0.1, 1.8, 1.0), WOOD_DARK, Vector3(3.2, 1.4, 1.0))
	Build.box(s, Vector3(0.05, 1.6, 0.8), Color(0.75, 0.9, 1.0), Vector3(3.27, 1.4, 1.0)).material_override = Build.mat(Color(0.75, 0.9, 1.0), 0.05)
	Build.interact_zone(s, "wardrobe", Vector3(1.0, 2.0, 1.4), Vector3(3.6, 1.2, 1.0), "Change hat")
	m.shop = shack + Vector3(0, 1.2, 2.3)

	# Brain Bank (sell grinder)
	var g := Node3D.new()
	g.position = grinder
	root.add_child(g)
	Build.solid_box(g, Vector3(2.6, 1.6, 2.6), Color(0.85, 0.2, 0.2), Vector3(0, 0.8, 0))
	Build.cyl(g, 1.5, 0.8, 1.0, Color(0.6, 0.6, 0.65), Vector3(0, 2.1, 0), Vector3.ZERO, 12)
	Build.cyl(g, 0.9, 0.9, 0.05, Color(0.1, 0.1, 0.1), Vector3(0, 2.6, 0), Vector3.ZERO, 12)
	Build.box(g, Vector3(0.8, 0.5, 0.05), Color(0.3, 1.0, 0.4), Vector3(0, 1.1, 1.31), Vector3.ZERO, 1.5)
	Build.label(g, "BRAIN BANK\nwe buy zombies $$$", Vector3(0, 3.5, 0), 56, Color(0.5, 1.0, 0.5))
	Build.interact_zone(g, "grinder", Vector3(3.0, 3.0, 3.0), Vector3(0, 1.5, 0), "Sell corpse")
	m.grinder = grinder + Vector3(0, 2.4, 0)

	# Lucky Brain (slot machine)
	var sl := Node3D.new()
	sl.position = slot
	root.add_child(sl)
	Build.solid_box(sl, Vector3(1.6, 2.4, 1.2), Color(0.55, 0.2, 0.75), Vector3(0, 1.2, 0))
	Build.box(sl, Vector3(1.2, 0.6, 0.05), Color(0.1, 0.1, 0.12), Vector3(0, 1.7, 0.61))
	for i in 3:
		Build.box(sl, Vector3(0.3, 0.45, 0.04), Color(1.0, 0.95, 0.85), Vector3(-0.38 + i * 0.38, 1.7, 0.64))
	Build.cyl(sl, 0.04, 0.04, 0.8, Color(0.7, 0.7, 0.7), Vector3(0.95, 1.6, 0))
	Build.sphere(sl, 0.12, Color(0.9, 0.1, 0.1), Vector3(0.95, 2.05, 0))
	Build.sphere(sl, 0.5, Color(0.95, 0.55, 0.65), Vector3(0, 2.75, 0), Vector3(1.2, 0.8, 1))
	Build.label(sl, "LUCKY BRAIN\ngamble a corpse!", Vector3(0, 3.6, 0), 52, Color(1.0, 0.7, 1.0))
	Build.interact_zone(sl, "slot", Vector3(2.0, 2.6, 2.0), Vector3(0, 1.3, 0.4), "Gamble corpse")
	m.slot = slot + Vector3(0, 1.7, 0.8)

	# Boat (travel)
	var b := Node3D.new()
	b.position = Vector3(boat_dock.x - 3.4, 0.0, boat_dock.z)
	root.add_child(b)
	Build.box(b, Vector3(2.6, 1.0, 6), Color(0.95, 0.95, 0.92), Vector3(0, 0.1, 0))
	Build.box(b, Vector3(2.7, 0.25, 6.1), Color(0.2, 0.4, 0.8), Vector3(0, -0.2, 0))
	Build.cyl(b, 0.0, 1.3, 1.2, Color(0.95, 0.95, 0.92), Vector3(0, 0.1, 3.6), Vector3(90, 0, 0), 4)
	Build.box(b, Vector3(1.6, 1.3, 1.6), Color(0.9, 0.85, 0.7), Vector3(0, 1.2, -1.2))
	Build.box(b, Vector3(1.8, 0.1, 1.8), Color(0.8, 0.25, 0.2), Vector3(0, 1.9, -1.2))
	Build.cyl(b, 0.05, 0.05, 3, Color(0.4, 0.3, 0.2), Vector3(0, 2.6, 1.0))
	Build.label(b, "S.S. NOPE", Vector3(0, 3.0, 0), 60, Color(0.6, 0.85, 1.0))
	b.set_meta("bob", true)
	Build.interact_zone(root, "boat", Vector3(2.0, 2.4, 5.0), boat_dock + Vector3(-0.5, 1.0, 0), "Sail the boat")
	m.boat = boat_dock + Vector3(0, 1.0, 0)

	# Chum bucket (summons the boss)
	var c := Node3D.new()
	c.position = chum
	root.add_child(c)
	Build.cyl(c, 0.38, 0.3, 0.6, Color(0.6, 0.62, 0.65), Vector3(0, 0.3, 0))
	Build.cyl(c, 0.34, 0.34, 0.04, Color(0.55, 0.15, 0.12), Vector3(0, 0.55, 0))
	Build.label(c, "CHUM", Vector3(0, 1.2, 0), 48, Color(1.0, 0.5, 0.4))
	Build.interact_zone(c, "chum", Vector3(1.2, 1.4, 1.2), Vector3(0, 0.5, 0), "Pour Boss Bait")
	m.chum = chum + Vector3(0, 0.8, 0)
	return m


static func _pier(root: Node3D, start: Vector3, length: float) -> void:
	var top := 1.3 if start.y < 0.5 else start.y + 1.3
	var p := Node3D.new()
	p.position = Vector3(start.x, 0, start.z)
	root.add_child(p)
	var deck := Build.solid_box(p, Vector3(4, 0.25, length), WOOD, Vector3(0, top - 0.12, length * 0.5))
	deck.name = "PierDeck"
	for i in int(length / 1.0):
		Build.box(p, Vector3(4.05, 0.04, 0.06), WOOD_DARK, Vector3(0, top + 0.01, i * 1.0 + 0.5))
	for z in range(0, int(length) + 1, 4):
		for x in [-1.9, 1.9]:
			Build.cyl(p, 0.16, 0.16, top + 8.0, WOOD_DARK, Vector3(x, (top - 8.0) * 0.5, z))
	for x in [-2.0, 2.0]:
		Build.box(p, Vector3(0.1, 0.1, length), WOOD_DARK, Vector3(x, top + 0.75, length * 0.5))
		for z in range(0, int(length) + 1, 2):
			Build.box(p, Vector3(0.1, 0.75, 0.1), WOOD_DARK, Vector3(x, top + 0.38, z))


static func _grass_patch(root: Node3D, pos: Vector3, radius: float) -> void:
	Build.cyl(root, radius, radius, 0.08, GRASS, pos + Vector3(0, 0.02, 0), Vector3.ZERO, 20)


static func _palm(root: Node3D, pos: Vector3) -> void:
	var t := Node3D.new()
	t.position = pos
	t.rotation_degrees.y = randf() * 360.0
	root.add_child(t)
	var lean := randf_range(-12, 12)
	for i in 6:
		Build.cyl(t, 0.2, 0.25, 0.9, Color(0.55, 0.4, 0.25).lightened(0.05 * (i % 2)), Vector3(i * 0.08 * sign(lean), 0.45 + i * 0.85, 0), Vector3(0, 0, -lean * 0.3))
	var top := Vector3(6 * 0.08 * sign(lean), 5.3, 0)
	for i in 6:
		var leaf := Node3D.new()
		leaf.position = top
		leaf.rotation_degrees = Vector3(0, i * 60.0, 0)
		t.add_child(leaf)
		Build.box(leaf, Vector3(0.6, 0.06, 2.6), Color(0.25, 0.6, 0.25), Vector3(0, -0.3, 1.2), Vector3(-20, 0, 0))
	Build.sphere(t, 0.2, Color(0.4, 0.28, 0.15), top + Vector3(0.2, -0.3, 0.1))
	Build.sphere(t, 0.2, Color(0.4, 0.28, 0.15), top + Vector3(-0.15, -0.35, 0.2))
	var body := StaticBody3D.new()
	t.add_child(body)
	var cs := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.3
	cap.height = 5.0
	cs.shape = cap
	cs.position = Vector3(0, 2.5, 0)
	body.add_child(cs)


static func _tree(root: Node3D, pos: Vector3) -> void:
	Build.solid_cyl(root, 0.3, 3.0, Color(0.45, 0.32, 0.2), pos + Vector3(0, 1.5, 0), 8)
	Build.sphere(root, 1.8, Color(0.3, 0.6, 0.3), pos + Vector3(0, 3.8, 0), Vector3.ONE, 8)
	Build.sphere(root, 1.3, Color(0.35, 0.68, 0.32), pos + Vector3(0.8, 4.6, 0.3), Vector3.ONE, 8)


static func _rock(root: Node3D, pos: Vector3, s: float) -> void:
	var r := Build.solid_box(root, Vector3(1.6, 1.0, 1.3) * s, Color(0.55, 0.55, 0.58), pos, Vector3(randf() * 20, randf() * 90, randf() * 20))
	r.scale = Vector3.ONE


static func _crates(root: Node3D, pos: Vector3) -> void:
	Build.solid_box(root, Vector3(0.9, 0.9, 0.9), Color(0.75, 0.55, 0.3), pos + Vector3(0, 0.45, 0))
	Build.solid_box(root, Vector3(0.9, 0.9, 0.9), Color(0.7, 0.5, 0.28), pos + Vector3(1.0, 0.45, 0.2), Vector3(0, 20, 0))
	Build.solid_box(root, Vector3(0.9, 0.9, 0.9), Color(0.78, 0.58, 0.32), pos + Vector3(0.5, 1.35, 0.1), Vector3(0, -15, 0))


static func _lifebuoy_sign(root: Node3D, pos: Vector3, text: String) -> void:
	Build.box(root, Vector3(0.12, 1.6, 0.12), WOOD_DARK, pos + Vector3(0, 0.8, 0))
	Build.box(root, Vector3(1.4, 0.8, 0.08), Color(0.95, 0.95, 0.9), pos + Vector3(0, 1.6, 0))
	var l := Build.label(root, text, pos + Vector3(0, 1.6, 0.06), 28, Color(0.8, 0.1, 0.1))
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.outline_size = 0


static func _flooded_house(root: Node3D, pos: Vector3, color: Color) -> void:
	Build.solid_box(root, Vector3(8, 9, 8), color, pos + Vector3(0, -2.5, 0))
	Build.solid_box(root, Vector3(8.6, 0.3, 8.6), Color(0.35, 0.3, 0.32), pos + Vector3(0, 2.1, 0))
	Build.box(root, Vector3(1.4, 1.2, 0.1), Color(0.6, 0.85, 1.0), pos + Vector3(-2, 0.8, 4.01))
	Build.box(root, Vector3(1.4, 1.2, 0.1), Color(0.6, 0.85, 1.0), pos + Vector3(2, 0.8, 4.01))
	Build.solid_box(root, Vector3(0.8, 1.6, 0.8), Color(0.6, 0.3, 0.25), pos + Vector3(2.5, 3.0, -2))  # chimney
	Build.solid_box(root, Vector3(1.2, 0.2, 1.2), Color(0.3, 0.3, 0.3), pos + Vector3(-2, 2.35, 2))  # satellite dish base
	Build.cyl(root, 0.6, 0.1, 0.3, Color(0.9, 0.9, 0.9), pos + Vector3(-2, 2.8, 2), Vector3(40, 0, 0))


static func _plank_bridge(root: Node3D, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var length := d.length()
	var body := Build.solid_box(root, Vector3(1.6, 0.2, length), WOOD, mid)
	body.look_at_from_position(mid, b, Vector3.UP)


static func _trampoline(root: Node3D, pos: Vector3) -> void:
	Build.cyl(root, 1.6, 1.6, 0.15, Color(0.15, 0.15, 0.2), pos + Vector3(0, 0.6, 0), Vector3.ZERO, 16)
	Build.cyl(root, 1.75, 1.75, 0.08, Color(0.2, 0.5, 0.95), pos + Vector3(0, 0.66, 0), Vector3.ZERO, 16)
	for i in 4:
		var a := TAU * i / 4.0
		Build.cyl(root, 0.06, 0.06, 0.6, Color(0.6, 0.6, 0.6), pos + Vector3(cos(a) * 1.5, 0.3, sin(a) * 1.5))
	var area := Area3D.new()
	area.position = pos + Vector3(0, 0.9, 0)
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	area.set_meta("trampoline", true)
	area.add_to_group("trampoline")
	root.add_child(area)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 0.6
	cs.shape = cyl
	area.add_child(cs)
	Build.label(root, "BOING", pos + Vector3(0, 1.6, 0), 40, Color(0.5, 0.8, 1.0))
