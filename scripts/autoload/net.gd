extends Node
## Session management. Host-authoritative: peer 1 (the host) runs the infected, the Director,
## the bots and campaign progress.
## Transport is Steam P2P (SteamMultiplayerPeer) or ENet for LAN / testing without Steam.
## Solo play just uses Godot's OfflineMultiplayerPeer, so all the same code paths run.

signal session_started
signal session_ended(reason: String)
signal players_changed
signal status(text: String)

const DEFAULT_PORT := 24680

var mode := ""  # "", "solo", "steam", "enet"
var players := {}  # peer_id -> {"name": String, "slot": int}  (slot = which survivor they play)
var _connecting := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	SteamService.lobby_ready.connect(_on_lobby_ready)
	SteamService.lobby_entered.connect(_on_lobby_entered)
	SteamService.lobby_join_failed.connect(func(r): _fail(r))
	SteamService.join_requested.connect(_on_steam_join_requested)


func in_session() -> bool:
	return mode != ""


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func my_name() -> String:
	if mode == "steam" and SteamService.persona_name != "":
		return SteamService.persona_name
	return Settings.player_name


func player_name(peer_id: int) -> String:
	return players.get(peer_id, {}).get("name", "Survivor")


func slot_of(peer_id: int) -> int:
	return int(players.get(peer_id, {}).get("slot", -1))


# --- Starting sessions -------------------------------------------------------

func start_solo() -> void:
	_reset_peer()
	mode = "solo"
	_begin_host()


func host_steam() -> void:
	if not SteamService.available:
		_fail(SteamService.init_error)
		return
	status.emit("Creating Steam lobby...")
	_connecting = true
	SteamService.create_lobby()


func join_steam(lobby_id: int) -> void:
	if not SteamService.available:
		_fail(SteamService.init_error)
		return
	if in_session():
		leave("Joining friend...")
	status.emit("Joining Steam lobby...")
	_connecting = true
	SteamService.join_lobby(lobby_id)


func host_enet(port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, SteamService.MAX_PLAYERS)
	if err != OK:
		_fail("Couldn't host on port %d (error %d)" % [port, err])
		return
	multiplayer.multiplayer_peer = peer
	mode = "enet"
	_begin_host()


func join_enet(address: String, port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_fail("Couldn't connect to %s:%d (error %d)" % [address, port, err])
		return
	multiplayer.multiplayer_peer = peer
	mode = "enet"
	_connecting = true
	status.emit("Connecting to %s..." % address)


func leave(reason: String = "") -> void:
	if not in_session() and not _connecting:
		return
	_connecting = false
	if mode == "steam":
		SteamService.leave_lobby()
	_reset_peer()
	mode = ""
	players.clear()
	session_ended.emit(reason)


func _reset_peer() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _begin_host() -> void:
	_connecting = false
	players = {1: {"name": my_name(), "slot": 0}}
	players_changed.emit()
	session_started.emit()


func _fail(reason: String) -> void:
	_connecting = false
	status.emit(reason)
	if in_session():
		leave(reason)


# --- Steam callbacks ---------------------------------------------------------

func _on_lobby_ready(_lobby_id: int) -> void:
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = peer.call("create_host", 0)
	if err != OK:
		_fail("SteamMultiplayerPeer.create_host failed (%d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	mode = "steam"
	_begin_host()


func _on_lobby_entered(_lobby_id: int, owner_id: int) -> void:
	if owner_id == SteamService.steam_id:
		return  # We're the host; already set up in _on_lobby_ready.
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = peer.call("create_client", owner_id, 0)
	if err != OK:
		_fail("SteamMultiplayerPeer.create_client failed (%d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	mode = "steam"
	status.emit("Connecting to %s..." % SteamService.friend_name(owner_id))


func _on_steam_join_requested(lobby_id: int) -> void:
	join_steam(lobby_id)


# --- Peer events --------------------------------------------------------------

func _on_connected_to_server() -> void:
	_connecting = false
	_register.rpc_id(1, my_name())
	session_started.emit()


func _on_connection_failed() -> void:
	_fail("Connection failed.")


func _on_server_disconnected() -> void:
	leave("The host left the game.")


func _on_peer_connected(_id: int) -> void:
	pass  # Wait for _register so we know their name.


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	if players.has(id):
		var n := player_name(id)
		players.erase(id)
		_sync_players.rpc(players)
		Game.toast.rpc("%s left" % n)


@rpc("any_peer", "reliable")
func _register(pname: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	var used := players.values().map(func(p): return p.slot)
	var slot := 0
	while slot in used:
		slot += 1
	if slot >= DB.SURVIVORS.size():
		_kick.rpc_id(id, "The game is full (4 survivors).")
		return
	players[id] = {"name": pname.substr(0, 24), "slot": slot}
	Game.on_peer_joined(id)
	_sync_players.rpc(players)
	Game.toast.rpc("%s joined as %s" % [players[id].name, DB.SURVIVORS[slot].name])


@rpc("authority", "call_local", "reliable")
func _sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()


@rpc("authority", "reliable")
func _kick(reason: String) -> void:
	leave(reason)
