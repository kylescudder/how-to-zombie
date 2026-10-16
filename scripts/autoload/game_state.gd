extends Node
## Shared team progression: wallet, unlocks, quests, island. The host owns it and pushes
## the whole thing to clients whenever it changes (it's tiny).

signal state_changed
signal toast_received(text: String)
signal travel_requested(island: int)

const SAVE_PATH := "user://save.json"
const LOCAL_PATH := "user://local.cfg"

var money := 0
var owned: Array = DB.STARTING_ITEMS.duplicate()
var hats: Array = ["none"]
var island := 0
var unlocked_island := 0
var quest_stage := [0, 0, 0]
var quest_count := [0, 0, 0]
var has_bait := false
var boss_alive := false
var won := false
var stats := {"catches": 0, "kills": 0, "earned": 0, "best_mult": 1.0}

var local_hat := "none"  # This machine's player's chosen hat (cosmetic, not saved in team save).

var _dirty := false
var _autosave_timer := 0.0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LOCAL_PATH) == OK:
		local_hat = cfg.get_value("cosmetic", "hat", "none")


func _process(delta: float) -> void:
	if _dirty and Net.in_session() and Net.is_host():
		_dirty = false
		_sync.rpc(to_dict())
	if Net.in_session() and Net.is_host():
		_autosave_timer += delta
		if _autosave_timer > 30.0:
			_autosave_timer = 0.0
			save_game()


func mark_dirty() -> void:
	_dirty = true
	state_changed.emit()


# --- Save / load (host) -------------------------------------------------------

func reset() -> void:
	money = 0
	owned = DB.STARTING_ITEMS.duplicate()
	hats = ["none"]
	island = 0
	unlocked_island = 0
	quest_stage = [0, 0, 0]
	quest_count = [0, 0, 0]
	has_bait = false
	boss_alive = false
	won = false
	stats = {"catches": 0, "kills": 0, "earned": 0, "best_mult": 1.0}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	from_dict(d)
	boss_alive = false
	return true


func save_game() -> void:
	if not Net.is_host():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict(), "\t"))


func save_local() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("cosmetic", "hat", local_hat)
	cfg.save(LOCAL_PATH)


func to_dict() -> Dictionary:
	return {
		"money": money, "owned": owned, "hats": hats, "island": island, "unlocked_island": unlocked_island,
		"quest_stage": quest_stage, "quest_count": quest_count, "has_bait": has_bait, "boss_alive": boss_alive,
		"won": won, "stats": stats,
	}


func from_dict(d: Dictionary) -> void:
	money = int(d.get("money", 0))
	owned = Array(d.get("owned", DB.STARTING_ITEMS))
	for s in DB.STARTING_ITEMS:
		if s not in owned:
			owned.append(s)
	hats = Array(d.get("hats", ["none"]))
	island = int(d.get("island", 0))
	unlocked_island = int(d.get("unlocked_island", 0))
	quest_stage = Array(d.get("quest_stage", [0, 0, 0])).map(func(v): return int(v))
	quest_count = Array(d.get("quest_count", [0, 0, 0])).map(func(v): return int(v))
	has_bait = bool(d.get("has_bait", false))
	boss_alive = bool(d.get("boss_alive", false))
	won = bool(d.get("won", false))
	stats = d.get("stats", stats)


@rpc("authority", "call_remote", "reliable")
func _sync(d: Dictionary) -> void:
	from_dict(d)
	state_changed.emit()


func on_peer_joined(id: int) -> void:
	_sync.rpc_id(id, to_dict())


# --- Queries ------------------------------------------------------------------

func best_rod() -> String:
	var best := "rod_1"
	for r in DB.ROD_ORDER:
		if r in owned:
			best = r
	return best


func weapons_owned() -> Array:
	return DB.WEAPON_ORDER.filter(func(w): return w in owned)


func current_quests() -> Array:
	return DB.ISLANDS[island].quests


func quests_done(i: int = -1) -> bool:
	if i < 0:
		i = island
	return quest_stage[i] >= DB.ISLANDS[i].quests.size()


func current_quest() -> Dictionary:
	if quests_done():
		return {}
	return current_quests()[quest_stage[island]]


func bait_available() -> bool:
	## Boss bait unlocks once you reach the "bait" step (or any time after beating the island).
	if quests_done():
		return true
	var q := current_quest()
	return q.get("id", "") in ["bait", "boss"]


func quest_text(q: Dictionary, count: int) -> String:
	var t: String = q.text
	if "%d" in t:
		t = t % q.goal
	if q.goal > 1:
		t += "  (%d/%d)" % [min(count, q.goal), q.goal]
	return t


# --- Host-side mutations ------------------------------------------------------

func add_money(amount: int) -> void:
	money = max(money + amount, 0)
	if amount > 0:
		stats.earned += amount
	mark_dirty()


## Called by the host whenever something quest-relevant happens.
func event(kind: String, amount: int = 1, data: Dictionary = {}) -> void:
	if not Net.is_host():
		return
	match kind:
		"catch":
			stats.catches += 1
		"kill":
			stats.kills += 1
			stats.best_mult = max(float(stats.best_mult), float(data.get("mult", 1.0)))
	var q := current_quest()
	if q.is_empty():
		mark_dirty()
		return
	var hit := false
	match q.id:
		"catch":
			hit = kind == "catch"
		"catch_tier3":
			hit = kind == "catch" and int(data.get("tier", 1)) >= 3
		"sell":
			hit = kind == "sell"
		"combo":
			hit = kind == "kill" and float(data.get("mult", 1.0)) >= 2.0
			amount = 1
		"headshot":
			hit = kind == "kill" and data.get("headshot", false)
			amount = 1
		"airborne":
			hit = kind == "kill" and data.get("airborne", false)
			amount = 1
		"slot":
			hit = kind == "slot"
		"bait":
			hit = kind == "bait"
		"boss":
			hit = kind == "boss"
	if hit:
		quest_count[island] += amount
		if quest_count[island] >= int(q.goal):
			_advance_quest()
	mark_dirty()


func _advance_quest() -> void:
	var q := current_quest()
	quest_stage[island] += 1
	quest_count[island] = 0
	Sfx.play("jackpot")
	toast.rpc("QUEST COMPLETE: %s" % quest_text(q, q.goal).split("  (")[0])
	if q.id == "boss":
		if island + 1 < DB.ISLANDS.size():
			unlocked_island = max(unlocked_island, island + 1)
			toast.rpc("The boat is fixed! Sail to %s from the dock." % DB.ISLANDS[island + 1].name)
		else:
			won = true
			toast.rpc("YOU BEAT HOW TO ZOMBIE! Keep fishing for the high score.")
	# The bait step auto-completes if they already bought bait earlier.
	var nq := current_quest()
	if not nq.is_empty() and nq.id == "bait" and has_bait:
		_advance_quest()
	save_game()


@rpc("any_peer", "call_local", "reliable")
func request_buy(item: String) -> void:
	if not Net.is_host():
		return
	var buyer := multiplayer.get_remote_sender_id()
	var price := item_price(item)
	if price < 0 or (item in owned and item != "bait") or money < price:
		_buy_result.rpc_id(buyer, item, false)
		return
	if item == "bait":
		if has_bait or not bait_available() or boss_alive:
			_buy_result.rpc_id(buyer, item, false)
			return
		has_bait = true
		money -= price
		event("bait")
		toast.rpc("%s bought Boss Bait. Pour it in the chum bucket!" % Net.player_name(buyer))
	else:
		owned.append(item)
		money -= price
		toast.rpc("%s bought %s" % [Net.player_name(buyer), item_name(item)])
	mark_dirty()
	save_game()
	_buy_result.rpc_id(buyer, item, true)


@rpc("authority", "call_local", "reliable")
func _buy_result(_item: String, ok: bool) -> void:
	Sfx.play("buy" if ok else "deny")


func item_price(item: String) -> int:
	if item == "bait":
		return int(DB.ISLANDS[island].bait_price)
	if DB.WEAPONS.has(item):
		return int(DB.WEAPONS[item].price)
	if DB.RODS.has(item):
		return int(DB.RODS[item].price)
	return -1


func item_name(item: String) -> String:
	if item == "bait":
		return "Boss Bait"
	if DB.WEAPONS.has(item):
		return DB.WEAPONS[item].name
	if DB.RODS.has(item):
		return DB.RODS[item].name
	return item


@rpc("any_peer", "call_local", "reliable")
func request_travel(to_island: int) -> void:
	if not Net.is_host() or to_island < 0 or to_island > unlocked_island or to_island == island or boss_alive:
		return
	island = to_island
	has_bait = false
	mark_dirty()
	save_game()
	travel_requested.emit(to_island)


@rpc("authority", "call_local", "reliable")
func toast(text: String) -> void:
	toast_received.emit(text)


func set_local_hat(hat: String) -> void:
	local_hat = hat
	save_local()
	_request_hat.rpc_id(1, hat)


@rpc("any_peer", "call_local", "reliable")
func _request_hat(hat: String) -> void:
	if Net.is_host() and hat in hats:
		Net.set_player_hat(multiplayer.get_remote_sender_id(), hat)
