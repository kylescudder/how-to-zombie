extends Node
## Local, persistent cosmetic progression. Hosts award XP; cosmetics never alter combat stats.
signal changed
var storage_path := "user://wardrobe.cfg"
var xp := 0
var equipped := CosmeticCatalog.defaults()
const REWARDS := {"kills":5,"specials":25,"revives":40}

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(storage_path)!=OK: return
	var value: Variant=config.get_value("wardrobe","xp",0)
	xp=clampi(int(value),0,10000000) if value is int else 0
	var look: Variant=config.get_value("wardrobe","equipped",{})
	equipped=CosmeticCatalog.normalise(look if look is Dictionary else {},xp)
	changed.emit()

func save_profile() -> bool:
	var config := ConfigFile.new()
	config.set_value("wardrobe","xp",xp)
	config.set_value("wardrobe","equipped",equipped)
	return config.save(storage_path)==OK

func equip(look: Dictionary) -> bool:
	var safe := CosmeticCatalog.normalise(look,xp)
	if safe!=CosmeticCatalog.normalise(look,xp,true): return false
	var previous := equipped
	equipped=safe
	if not save_profile():
		equipped=previous
		return false
	changed.emit()
	return true

@rpc("authority","call_local","reliable")
func add_xp(amount: int) -> void:
	if amount<=0 or amount>1000: return
	xp=mini(xp+amount,10000000)
	save_profile()
	changed.emit()

func reward_stat(slot: int, key: String, amount: int) -> void:
	if not Net.is_host() or not REWARDS.has(key) or amount<=0: return
	for id in Net.players:
		if Net.slot_of(id)==slot: add_xp.rpc_id(id,mini(1000,REWARDS[key]*amount))

func reward_escape() -> void:
	if not Net.is_host(): return
	for id in Net.players: add_xp.rpc_id(id,250)
