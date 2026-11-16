extends Node
## Sound effects: CC0 recordings from assets/audio/ (cut by tools/build_audio.py), plus a few
## sounds synthesised at startup (weather beds, footsteps, vehicles, the pipe bomb's beep).
## A worker thread loads and renders them, publishing each group as it finishes.

const RATE := 22050
## Everything not listed here (footsteps, pickups, interface, infected attacks) stays on Effects.
const WEAPON_SOUNDS := ["pistol", "smg", "rifle", "shotgun", "sniper", "mag_out", "mag_in", "rack", "shell", "pump", "empty", "swing", "shove", "hit", "headshot", "hitmarker"]
const VEHICLE_SOUNDS := ["crash", "skid_loop"]
const ENVIRONMENT_SOUNDS := ["rain_loop", "wind_loop", "thunder", "thunder_far", "creak", "siren", "alarm", "radio", "rescue_horn", "door", "gate", "glass", "fire", "fire_loop", "explosion"]
## How each kind of sound carries: [unit size (m), max distance (m), pitch spread, voices at once].
const CARRY := {
	"gun": [14.0, 260.0, 0.03, 10],
	"blast": [22.0, 360.0, 0.05, 4],
	"far": [16.0, 320.0, 0.02, 3],
	"boss": [14.0, 220.0, 0.04, 3],
	"special": [9.0, 140.0, 0.06, 3],
	"common": [5.0, 90.0, 0.1, 6],
	"close": [3.0, 35.0, 0.06, 6],
	"ui": [1.0, 40.0, 0.0, 4],
	"default": [6.0, 90.0, 0.07, 6],
}
const KIND := {
	"pistol": "gun", "smg": "gun", "rifle": "gun", "shotgun": "gun", "sniper": "gun",
	"explosion": "blast",
	"rescue_horn": "far", "siren": "far", "alarm": "far", "gate": "far",
	"tank": "boss", "punch": "boss", "rock": "boss", "witch_scream": "boss",
	"boomer": "special", "vomit": "special", "hunter": "special", "pounce": "special", "smoker": "special",
	"tongue": "special", "spitter": "special", "spit": "special", "witch_cry": "special",
	"groan": "common", "scream": "common", "die": "common", "zombie_hit": "common",
	"step1": "close", "step2": "close", "step3": "close", "step4": "close", "land": "close",
	"mag_out": "close", "mag_in": "close", "rack": "close", "shell": "close", "pump": "close",
	"empty": "close", "pickup": "close", "pills": "close", "heal": "close", "swing": "close",
	"click": "ui", "hitmarker": "ui", "beep": "ui", "button": "ui", "heartbeat": "ui",
}
## Recorded takes, named <sound>_<n>.wav. Any sound found here replaces a synthesised one.
const SAMPLES := "res://assets/audio/"
var _streams := {}  # The worker's working set.
var _live := {}  # What the game reads: a snapshot the worker publishes as groups finish.
var _mutex := Mutex.new()
var _thread: Thread
var _rng := RandomNumberGenerator.new()  # Synthesis only (worker thread).
var _dice := RandomNumberGenerator.new()  # Playback only (main thread).
var _brown_v := 0.0
var _lp := 0.0
var _playing := {}  # sound -> players currently voicing it, oldest first
var _spare_2d := []
var _spare_3d := []
var _last_start := {}  # sound -> [msec, position]
var _last_take := {}


func _ready() -> void:
	_rng.randomize()
	_dice.randomize()
	if DisplayServer.get_name() == "headless":
		return  # No audio when headless (tests, dedicated runs); skip the synthesis too.
	_limit_master()
	_thread = Thread.new()
	_thread.start(_build, Thread.PRIORITY_LOW)


func _exit_tree() -> void:
	_join()
	# Let go of every stream, or the audio server is still holding them when the engine quits.
	for player in get_children():
		player.call("stop")
		player.set("stream", null)
	_streams.clear()
	_live.clear()


## Renders every sound now, on this thread. Headless tests use it.
func build_now() -> void:
	_join()
	if _live.is_empty():
		_build()


func _join() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


## A limiter on Master keeps a tank fight inside a horde from clipping.
func _limit_master() -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.3
	AudioServer.add_bus_effect(0, limiter)


func _build() -> void:
	_load_samples()
	_publish()
	# Weather and ambience. The beds loop seamlessly; Atmosphere plays them.
	_streams["thunder"] = _make(4.5, func(t, _i): return _noise() * exp(-t * 14.0) * 0.7 + _brown() * 2.6 * min(t * 12.0, 1.0) * exp(-t * 0.9) * (0.65 + 0.35 * sin(t * 6.3) * sin(t * 2.1)), 11025)
	_streams["thunder_far"] = _make(4.0, func(t, _i): return _brown() * 2.2 * sin(PI * minf(t / 0.6, 1.0) * 0.5) * exp(-t * 0.8) * (0.6 + 0.4 * sin(t * 4.7)), 11025)
	_streams["creak"] = _make(1.6, func(t, _i): return _saw(t * (62.0 + sin(t * 3.0) * 9.0 + fmod(t, 0.21) * 40.0)) * sin(PI * t / 1.6) * 0.25, 11025)
	_streams["wind_loop"] = _make_loop(12.0, func(t, _i): return _lowpass(_noise(), 0.015 + 0.04 * _gust(t, 12.0)) * 5.0 * (0.35 + 0.65 * _gust(t, 12.0)), 11025)
	_streams["rain_loop"] = _make_loop(6.0, func(_t, _i): return _hiss() * 0.32 + _brown() * 0.5 + float(_rng.randf() < 0.0009) * _noise() * 0.5)
	# A low tritone with slow beating: the dread under everything.
	_streams["drone_loop"] = _make_loop(12.0, func(t, _i): return (sin(TAU * 41.25 * t) + sin(TAU * 41.5 * t) * 0.8 + sin(TAU * 58.25 * t) * 0.45 + sin(TAU * 82.5 * t) * 0.2 * (0.5 + 0.5 * sin(TAU * t / 6.0))) * 0.22 * (0.75 + 0.25 * sin(TAU * t / 12.0)), 11025)
	# Footfalls on grit: a soft heel scuff then a lighter toe, band-limited noise with only a hint of thump.
	# Four variants so a run doesn't machine-gun the same sample.
	for v in 4:
		var toe := 0.045 + v * 0.012
		var bright := 0.35 + v * 0.08
		_streams["step%d" % (v + 1)] = _make(0.14, func(t, _i):
			var grit := _noise() - _lowpass(_noise(), bright)
			var hit := exp(-t * 70.0) + exp(-maxf(t - toe, 0.0) * 90.0) * float(t > toe) * 0.55
			return (grit * 0.55 + sin(TAU * 70.0 * t) * exp(-t * 60.0) * 0.25) * hit * 2.6)
	_streams["land"] = _make(0.25, func(t, _i): return ((_noise() - _lowpass(_noise(), 0.3)) * 0.5 * (exp(-t * 35.0) + exp(-maxf(t - 0.05, 0.0) * 40.0) * float(t > 0.05) * 0.6) + sin(TAU * 60.0 * t) * exp(-t * 30.0) * 0.4) * 2.2)
	# Tyre squeal: a narrow band of noise that wavers, rather than a pure tone.
	_streams["skid_loop"] = _make_loop(2.0, func(t, _i): return _band(_noise(), 900.0 + sin(TAU * 1.5 * t) * 120.0 + sin(TAU * 4.0 * t) * 40.0) * (0.75 + 0.25 * sin(TAU * 9.0 * t) * sin(TAU * 2.0 * t)) * 0.9)
	_streams["crash"] = _make(0.7, func(t, _i): return _noise() * exp(-t * 9.0) * 0.9 + sin(TAU * (75.0 - t * 40.0) * t) * exp(-t * 7.0) * 0.8 + (sin(TAU * 2900.0 * t) + sin(TAU * 4100.0 * t)) * exp(-t * 14.0) * 0.12)
	_build_extras()
	_publish()


func _publish() -> void:
	_mutex.lock()
	_live = _streams.duplicate()
	_mutex.unlock()


func _lookup(sound: String) -> Variant:
	_mutex.lock()
	var s: Variant = _live.get(sound)
	_mutex.unlock()
	return s


# --- Recordings ---------------------------------------------------------------------------

func _load_samples() -> void:
	var found := {}
	for file in ResourceLoader.list_directory(SAMPLES):
		if not file.ends_with(".wav"):
			continue
		var stem := file.get_basename()
		var split := stem.rfind("_")
		found.get_or_add(stem.left(split), []).append([int(stem.substr(split + 1)), SAMPLES + file])
	for sound in found:
		var takes: Array = found[sound]
		takes.sort()
		var streams := []
		for take in takes:
			var s := ResourceLoader.load(take[1]) as AudioStreamWAV
			if s == null:
				continue
			if sound.ends_with("_loop"):
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_end = int(s.get_length() * s.mix_rate)
			streams.append(s)
		if not streams.is_empty():
			_streams[sound] = streams if streams.size() > 1 else streams[0]


## The few sounds that are better made than recorded.
func _build_extras() -> void:
	var b := _buf(0.11)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 2050.0 * t) + sin(TAU * 6150.0 * t) * 0.2) * minf(t / 0.003, 1.0) * minf((0.11 - t) / 0.012, 1.0)
	_streams["beep"] = _finish(b, 0.35)
	# Spitter acid: a hiss with bubbles popping through it.
	var hiss := Svf.new()
	var bubble := [0.0, 400.0, 0.0]  # amplitude, pitch, phase
	_streams["acid_loop"] = _make_loop(3.0, func(t, _i):
		if _rng.randf() < 14.0 / RATE:
			bubble[0] = _rng.randf_range(0.3, 0.8)
			bubble[1] = _rng.randf_range(300.0, 900.0)
		bubble[1] *= 1.0002
		bubble[2] += bubble[1] / RATE
		bubble[0] *= 0.9985
		return hiss.high(_noise(), 3000.0) * (0.18 + 0.08 * sin(TAU * t / 1.5)) + sin(TAU * bubble[2]) * bubble[0] * 0.4)


# --- Synthesis toolkit --------------------------------------------------------------------

## Zero-delay-feedback state-variable filter (stable at any cutoff). band() has unity peak gain.
class Svf:
	var lp := 0.0
	var bp := 0.0
	var hp := 0.0
	var _ic1 := 0.0
	var _ic2 := 0.0
	var _hz := -1.0
	var _q := -1.0
	var _k := 1.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _a3 := 0.0

	func tick(x: float, hz: float, q: float) -> void:
		if hz != _hz or q != _q:
			_hz = hz
			_q = q
			var g := tan(PI * clampf(hz, 10.0, RATE * 0.49) / RATE)
			_k = 1.0 / q
			_a1 = 1.0 / (1.0 + g * (g + _k))
			_a2 = g * _a1
			_a3 = g * _a2
		var v3 := x - _ic2
		var v1 := _a1 * _ic1 + _a2 * v3
		var v2 := _ic2 + _a2 * _ic1 + _a3 * v3
		_ic1 = 2.0 * v1 - _ic1
		_ic2 = 2.0 * v2 - _ic2
		lp = v2
		bp = v1
		hp = x - _k * v1 - v2

	func low(x: float, hz: float, q := 0.707) -> float:
		tick(x, hz, q)
		return lp

	func band(x: float, hz: float, q := 1.0) -> float:
		tick(x, hz, q)
		return bp * _k

	func high(x: float, hz: float, q := 0.707) -> float:
		tick(x, hz, q)
		return hp


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Masters a buffer: DC removed, optionally saturated, peak-normalised, ends de-clicked.
func _finish(b: PackedFloat32Array, peak := 0.9, rate := RATE, drive := 1.0) -> AudioStreamWAV:
	var x1 := 0.0
	var y1 := 0.0
	var top := 0.0
	for i in b.size():
		var y := b[i] - x1 + 0.995 * y1
		x1 = b[i]
		y1 = y
		b[i] = y
		top = maxf(top, absf(y))
	if top <= 0.0:
		top = 1.0
	var shape := tanh(drive) if drive > 1.0 else 1.0
	var tail := mini(int(0.012 * rate), b.size())
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		var v := b[i] / top
		if drive > 1.0:
			v = tanh(v * drive) / shape
		v *= peak * minf(float(b.size() - i) / tail, 1.0) * minf(float(i + 1) / 8.0, 1.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	return _wav(data, rate)


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _saw(phase: float) -> float:
	return fposmod(phase, 1.0) * 2.0 - 1.0


## Brown (integrated) noise: rumble for thunder and rain.
func _brown() -> float:
	_brown_v = clampf(_brown_v * 0.996 + _noise() * 0.045, -1.0, 1.0)
	return _brown_v


## Bright noise (white minus its low end): rain on everything.
func _hiss() -> float:
	var n := _noise()
	return n - _lowpass(n, 0.35)


## A resonant band-pass (state-variable filter) centred on `hz`.
var _svf_lo := 0.0
var _svf_bp := 0.0
func _band(x: float, hz: float) -> float:
	var f := 2.0 * sin(PI * hz / RATE)
	_svf_lo += f * _svf_bp
	_svf_bp += f * (x - _svf_lo - 0.15 * _svf_bp)
	return _svf_bp * 0.15


## One-pole low-pass; `k` near zero is darker.
func _lowpass(x: float, k: float) -> float:
	_lp += (x - _lp) * k
	return _lp


## Slow gusting envelope in 0..1 that repeats exactly every `period` seconds.
func _gust(t: float, period: float) -> float:
	return clampf(0.5 + 0.3 * sin(TAU * t / period) + 0.2 * sin(TAU * 3.0 * t / period + 1.3), 0.0, 1.0)


func _make(duration: float, gen: Callable, rate := RATE) -> AudioStreamWAV:
	var n := int(duration * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := clampf(float(gen.call(t, i)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	return _wav(data, rate)


## A seamless loop: renders a little past the end and crossfades that tail into the start.
func _make_loop(duration: float, gen: Callable, rate := RATE) -> AudioStreamWAV:
	var n := int(duration * rate)
	var fade := int(0.5 * rate)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	for i in n + fade:
		raw[i] = float(gen.call(float(i) / rate, i))
	for i in fade:
		var k := float(i) / fade
		raw[i] = raw[i] * k + raw[n + i] * (1.0 - k)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(raw[i], -1.0, 1.0) * 32000.0))
	var s := _wav(data, rate)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = n
	return s


func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s


# --- Playback -----------------------------------------------------------------------------

## The sound's first take. If the worker hasn't reached it yet, waits until it has.
func stream(sound: String) -> AudioStream:
	var s: Variant = _lookup(sound)
	while s == null and _thread and _thread.is_alive():
		OS.delay_msec(2)
		s = _lookup(sound)
	if s == null:
		s = _lookup(sound)  # The worker may have published its last group as it finished.
	return s[0] if s is Array else s


## Every take of a built sound, for tests.
func takes(sound: String) -> Array:
	var s: Variant = _lookup(sound)
	if s == null:
		return []
	return s if s is Array else [s]


## How many players are voicing `sound` right now.
func voices(sound: String) -> int:
	return _playing.get(sound, []).size()


## Play a sound. Pass a world position for 3D audio, or leave it as INF for 2D.
## Each sound has a voice cap (the oldest is cut), random takes and a pitch spread by kind;
## 3D sounds out of earshot are skipped, and two identical starts in one spot play once.
func play(sound: String, pos: Vector3 = Vector3.INF, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: Variant = _lookup(sound)
	if s == null:
		return
	var carry: Array = CARRY[KIND.get(sound, "default")]
	var positional := pos != Vector3.INF
	var now := Time.get_ticks_msec()
	var last: Array = _last_start.get(sound, [-1000, Vector3.INF])
	var last_pos: Vector3 = last[1]
	if now - int(last[0]) < 25 and (positional == (last_pos != Vector3.INF)) and (not positional or pos.distance_to(last_pos) < 2.0):
		return
	if positional:
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_to(pos) > float(carry[1]):
			return
	_last_start[sound] = [now, pos]
	var playing: Array = _playing.get_or_add(sound, [])
	if playing.size() >= int(carry[3]):
		_release(playing[0])
	var player := _spare(positional)
	player.set_meta("sound", sound)
	player.set("bus", sound_bus(sound))
	player.set("stream", _pick_take(sound, s))
	player.set("volume_db", volume_db)
	player.set("pitch_scale", pitch * (1.0 + _dice.randf_range(-1.0, 1.0) * float(carry[2])))
	if positional:
		var p3 := player as AudioStreamPlayer3D
		p3.unit_size = carry[0]
		p3.max_distance = carry[1]
		p3.global_position = pos
	playing.append(player)
	player.call("play")


## A looping sound riding on `host` that stops when the host is freed (fires, acid pools).
func attach_loop(sound: String, host: Node3D, volume_db := 0.0) -> AudioStreamPlayer3D:
	if _thread == null and _lookup(sound) == null:
		return null  # Headless: nothing was built.
	var s := stream(sound)
	if s == null:
		return null
	var carry: Array = CARRY[KIND.get(sound, "default")]
	var player := AudioStreamPlayer3D.new()
	player.stream = s
	player.bus = sound_bus(sound)
	player.volume_db = volume_db
	player.unit_size = carry[0]
	player.max_distance = carry[1]
	host.add_child(player)
	player.play(_dice.randf() * s.get_length())
	return player


func _pick_take(sound: String, s: Variant) -> AudioStream:
	if s is AudioStream:
		return s
	var all: Array = s
	var i := _dice.randi() % all.size()
	if all.size() > 1 and i == int(_last_take.get(sound, -1)):
		i = (i + 1) % all.size()
	_last_take[sound] = i
	return all[i]


func _spare(positional: bool) -> Node:
	var pool: Array = _spare_3d if positional else _spare_2d
	if not pool.is_empty():
		return pool.pop_back()
	var player: Node
	if positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.attenuation_filter_cutoff_hz = 4000.0  # Distance takes the top off, as air does.
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		player = p3
	else:
		player = AudioStreamPlayer.new()
	add_child(player)
	player.connect("finished", _release.bind(player))
	return player


func _release(player: Node) -> void:
	var playing: Array = _playing.get(player.get_meta("sound", ""), [])
	if not player in playing:
		return
	playing.erase(player)
	player.call("stop")
	(_spare_3d if player is AudioStreamPlayer3D else _spare_2d).append(player)


func sound_bus(sound: String) -> String:
	if sound.ends_with("_music") or sound == "drone_loop": return "Music"
	if sound in ["hurt", "die", "groan", "witch_cry", "witch_scream", "hunter", "smoker", "boomer", "tank", "spitter", "scream"]: return "Voice"
	if sound in WEAPON_SOUNDS: return "Weapons"
	if sound in VEHICLE_SOUNDS: return "Vehicles"
	if sound in ENVIRONMENT_SOUNDS: return "Environment"
	return "Effects"
