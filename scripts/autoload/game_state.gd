extends Node
## Campaign state shared by the team: chapter, difficulty, what each survivor carries between
## chapters, and the stats for the end screens. The host owns it and pushes it to clients.

signal state_changed
signal toast_received(text: String, color: Color)
signal chapter_requested(chapter: int)
signal banner(title: String, subtitle: String)

const SAVE_PATH := "user://save.json"

var open_world := true
var chapter := 0
var difficulty := 1
## "playing", "complete" (safe room reached), "failed" (team wiped), "victory" (rescued)
var phase := "playing"
## Per survivor slot: {"hp": float, "inv": Dictionary} captured when a chapter starts.
var carry: Array = [{}, {}, {}, {}]
## Per survivor slot.
var stats: Array = []
var arsenal: Array = []  # Host-owned credits and gun-specific upgrades, per survivor slot.
var finale_stage := -1  # -1 = not started
## Island stories (see Story). Barea City: arrive -> hunt -> alert -> escaped.
var story := {"barea": "arrive", "idol_carrier": -1, "idol_drop": Vector3.INF}

var _dirty := false


func _ready() -> void:
	reset()


func _process(_delta: float) -> void:
	if _dirty and Net.in_session() and Net.is_host():
		_dirty = false
		_sync.rpc(to_dict())


func mark_dirty() -> void:
	_dirty = true
	state_changed.emit()


func reset(start_chapter := 0) -> void:
	chapter = start_chapter
	phase = "playing"
	finale_stage = -1
	carry = [{}, {}, {}, {}]
	story = {"barea": "arrive", "idol_carrier": -1, "idol_drop": Vector3.INF}
	arsenal = []
	for i in 4:
		arsenal.append({"credits": 500, "guns": {}})
	reset_stats()


func reset_stats() -> void:
	stats = []
	for i in 4:
		stats.append({"kills": 0, "specials": 0, "headshots": 0, "ff": 0, "damage": 0, "revives": 0, "incaps": 0})


func diff() -> Dictionary:
	return DB.difficulty(difficulty)


func chapter_data() -> Dictionary:
	return DB.CHAPTERS[clampi(chapter, 0, DB.CHAPTERS.size() - 1)]


# --- Save: just remembers the furthest chapter so you can carry on later ------

func has_save() -> bool:
	return saved_chapter() > 0


func saved_chapter() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return clampi(int(d.get("chapter", 0)), 0, DB.CHAPTERS.size() - 1) if d is Dictionary else 0


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"chapter": chapter, "difficulty": difficulty}))


# --- Sync ----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"open_world": open_world, "chapter": chapter, "difficulty": difficulty, "phase": phase, "stats": stats, "finale_stage": finale_stage, "arsenal": arsenal, "story": story}


@rpc("authority", "call_remote", "reliable")
func _sync(d: Dictionary) -> void:
	open_world = d.get("open_world", false)
	chapter = d.chapter
	difficulty = d.difficulty
	phase = d.phase
	stats = d.stats
	arsenal = d.get("arsenal", arsenal)
	finale_stage = d.finale_stage
	story = d.get("story", story)
	state_changed.emit()


func on_peer_joined(id: int) -> void:
	_sync.rpc_id(id, to_dict())


func add_stat(slot: int, key: String, amount := 1) -> void:
	if not Net.is_host() or slot < 0 or slot >= stats.size():
		return
	stats[slot][key] = int(stats[slot].get(key, 0)) + amount
	if key in ["kills", "specials"]:
		arsenal[slot].credits += amount * (15 if key == "kills" else 75)
	mark_dirty()


@rpc("authority", "call_local", "reliable")
func toast(text: String, color := Color.WHITE) -> void:
	toast_received.emit(text, color)


@rpc("authority", "call_local", "reliable")
func show_banner(title: String, subtitle := "") -> void:
	banner.emit(title, subtitle)


## Host: go to a chapter (also used to restart the current one after a wipe).
func goto_chapter(i: int) -> void:
	if not Net.is_host():
		return
	chapter = i
	phase = "playing"
	finale_stage = -1
	save_progress()
	mark_dirty()
	chapter_requested.emit(i)


func gun_upgrades(slot: int, id: String) -> Dictionary:
	if slot < 0 or slot >= arsenal.size():
		return {}
	return arsenal[slot].guns.get(id, {})


func gun_stats(slot: int, id: String) -> Dictionary:
	return DB.gun_stats(id, gun_upgrades(slot, id))


func credits(slot: int) -> int:
	return int(arsenal[slot].credits) if slot >= 0 and slot < arsenal.size() else 0


# Called only after Level validates the requesting peer, equipped gun and bench distance.
func buy_upgrade(slot: int, id: String, kind: String) -> bool:
	if DB.weapon(id).has("expires"):
		return false  # reduced stock: no upgrades
	if not Net.is_host() or not DB.GUN_PROFILES.has(id) or not DB.UPGRADES.has(kind) or slot < 0 or slot >= arsenal.size():
		return false
	var upgrades := gun_upgrades(slot, id).duplicate()
	var tier := int(upgrades.get(kind, 0))
	var cost := DB.upgrade_cost(kind, tier)
	if tier >= int(DB.UPGRADES[kind].max) or credits(slot) < cost:
		return false
	arsenal[slot].credits -= cost
	upgrades[kind] = tier + 1
	arsenal[slot].guns[id] = upgrades
	mark_dirty()
	return true
