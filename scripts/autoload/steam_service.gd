extends Node
## Thin wrapper around GodotSteam. Everything goes through `Engine.get_singleton("Steam")`
## so the project still runs (LAN mode only) when the GodotSteam addon isn't installed.

signal lobby_ready(lobby_id: int)
signal lobby_join_failed(reason: String)
signal lobby_entered(lobby_id: int, owner_id: int)
signal join_requested(lobby_id: int)

## 480 = Valve's "Spacewar" test app. Replace with your own App ID once you have one,
## and update steam_appid.txt to match.
const APP_ID := 480
const LOBBY_TYPE_FRIENDS_ONLY := 1
const MAX_PLAYERS := 4

var steam: Object = null
var available := false
var steam_id := 0
var persona_name := ""
var lobby_id := 0
var init_error := ""


func _ready() -> void:
	if "--no-steam" in OS.get_cmdline_user_args() or not Engine.has_singleton("Steam"):
		init_error = "GodotSteam addon not installed (run tools/install_godotsteam.sh)" if not Engine.has_singleton("Steam") else "Disabled by --no-steam"
		return
	steam = Engine.get_singleton("Steam")
	var result: Dictionary = steam.steamInitEx(APP_ID, true)
	if int(result.get("status", 1)) != 0:
		init_error = "Steam init failed: %s (is the Steam client running?)" % result.get("verbal", "unknown")
		steam = null
		return
	available = true
	steam_id = steam.getSteamID()
	persona_name = steam.getPersonaName()
	steam.lobby_created.connect(_on_lobby_created)
	steam.lobby_joined.connect(_on_lobby_joined)
	steam.join_requested.connect(_on_join_requested)
	print("[Steam] Logged in as %s (%d)" % [persona_name, steam_id])
	# Launched from a friend's invite: "+connect_lobby <id>"
	var args := OS.get_cmdline_args()
	var idx := args.find("+connect_lobby")
	if idx >= 0 and idx + 1 < args.size():
		var id := int(args[idx + 1])
		if id > 0:
			call_deferred("_emit_join_requested", id)


func _emit_join_requested(id: int) -> void:
	join_requested.emit(id)


func create_lobby() -> void:
	if not available:
		lobby_join_failed.emit(init_error)
		return
	steam.createLobby(LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)


func join_lobby(id: int) -> void:
	if not available:
		lobby_join_failed.emit(init_error)
		return
	steam.joinLobby(id)


func leave_lobby() -> void:
	if available and lobby_id != 0:
		steam.leaveLobby(lobby_id)
	lobby_id = 0
	set_presence("")


func invite_friends() -> void:
	if available and lobby_id != 0:
		steam.activateGameOverlayInviteDialog(lobby_id)


func friend_name(id: int) -> String:
	return steam.getFriendPersonaName(id) if available else ""


func set_presence(status: String) -> void:
	if not available:
		return
	steam.setRichPresence("status", status)
	steam.setRichPresence("connect", ("+connect_lobby %d" % lobby_id) if lobby_id != 0 else "")


func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:
		lobby_join_failed.emit("Could not create Steam lobby (code %d)" % result)
		return
	lobby_id = id
	steam.setLobbyJoinable(id, true)
	steam.setLobbyData(id, "name", "%s's survivor squad" % persona_name)
	steam.setLobbyData(id, "game", "how_to_zombie")
	set_presence("Fighting the infected")
	lobby_ready.emit(id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		lobby_join_failed.emit("Could not join lobby (response %d)" % response)
		return
	lobby_id = id
	var owner_id: int = steam.getLobbyOwner(id)
	set_presence("Fighting the infected")
	lobby_entered.emit(id, owner_id)


func _on_join_requested(id: int, _friend_id: int) -> void:
	join_requested.emit(id)
