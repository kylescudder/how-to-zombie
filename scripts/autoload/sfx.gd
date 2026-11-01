extends Node
## Procedurally synthesised sound effects, so the project ships with zero audio assets.
## Swap any entry in `_streams` for a real AudioStream later.

const RATE := 22050
var _streams := {}
var _rng := RandomNumberGenerator.new()
var _brown_v := 0.0
var _lp := 0.0


func _ready() -> void:
	_rng.randomize()
	if DisplayServer.get_name() == "headless":
		return  # No audio when headless (tests, dedicated runs); skip the synthesis too.
	# Guns
	_streams["pistol"] = _make(0.22, func(t, _i): return _noise() * exp(-t * 32.0) + sin(t * 1100.0) * exp(-t * 45.0) * 0.5)
	_streams["smg"] = _make(0.14, func(t, _i): return _noise() * exp(-t * 45.0) * 0.9 + sin(t * 1500.0) * exp(-t * 60.0) * 0.3)
	_streams["rifle"] = _make(0.3, func(t, _i): return _noise() * exp(-t * 22.0) + sin(TAU * 90.0 * t) * exp(-t * 18.0) * 0.6)
	_streams["sniper"] = _make(0.8, func(t, _i): return _noise() * exp(-t * 9.0) + sin(TAU * 70.0 * t) * exp(-t * 6.0) * 0.8)
	_streams["shotgun"] = _make(0.6, func(t, _i): return _noise() * exp(-t * 8.0) * 1.1 + sin(TAU * 60.0 * t) * exp(-t * 12.0))
	_streams["pump"] = _make(0.35, func(t, _i): return (_noise() * exp(-t * 70.0) + _noise() * exp(-max(t - 0.18, 0.0) * 70.0) * float(t > 0.18)) * 0.5)
	_streams["reload"] = _make(0.3, func(t, _i): return (_noise() * exp(-t * 60.0) + _noise() * exp(-max(t - 0.18, 0.0) * 60.0) * float(t > 0.18)) * 0.5)
	_streams["empty"] = _make(0.05, func(t, _i): return sin(TAU * 2200.0 * t) * exp(-t * 120.0) * 0.4)
	_streams["swing"] = _make(0.22, func(t, _i): return _noise() * sin(PI * t / 0.22) * 0.3)
	_streams["shove"] = _make(0.2, func(t, _i): return _noise() * exp(-t * 25.0) * 0.6 + sin(TAU * (180.0 - t * 300.0) * t) * exp(-t * 20.0) * 0.5)
	_streams["hit"] = _make(0.16, func(t, _i): return sin(TAU * (170.0 - t * 300.0) * t) * exp(-t * 28.0) + _noise() * exp(-t * 50.0) * 0.5)
	_streams["headshot"] = _make(0.2, func(t, _i): return _noise() * exp(-t * 30.0) * 0.8 + sin(TAU * 600.0 * t) * exp(-t * 40.0) * 0.4)
	_streams["hitmarker"] = _make(0.05, func(t, _i): return sin(TAU * 2600.0 * t) * exp(-t * 90.0) * 0.25)
	# Throwables and world
	_streams["explosion"] = _make(1.4, func(t, _i): return _noise() * exp(-t * 3.2) * 1.2 + sin(TAU * 50.0 * t) * exp(-t * 3.5) * 0.9)
	_streams["beep"] = _make(0.08, func(t, _i): return sin(TAU * 1760.0 * t) * 0.35)
	_streams["glass"] = _make(0.5, func(t, _i): return (_noise() * 0.5 + sin(TAU * 3300.0 * t) * 0.3 + sin(TAU * 4700.0 * t) * 0.2) * exp(-t * 9.0))
	_streams["fire"] = _make(1.0, func(t, _i): return _noise() * (0.25 + 0.15 * sin(t * 37.0)) * min(t * 8.0, 1.0) * min((1.0 - t) * 8.0, 1.0))
	_streams["alarm"] = _make(1.0, func(t, _i): return _square(t * (700.0 if fmod(t, 0.5) < 0.25 else 900.0)) * 0.22)
	_streams["door"] = _make(0.5, func(t, _i): return _saw(t * (70.0 + t * 30.0)) * exp(-t * 5.0) * 0.4 + _noise() * exp(-max(t - 0.4, 0.0) * 40.0) * float(t > 0.4) * 0.6)
	_streams["button"] = _make(0.12, func(t, _i): return _square(t * 600.0) * exp(-t * 20.0) * 0.3)
	_streams["gate"] = _make(2.5, func(t, _i): return (_saw(t * 45.0) * 0.4 + _noise() * 0.2) * sin(PI * t / 2.5))
	_streams["acid"] = _make(0.6, func(t, _i): return _noise() * exp(-t * 4.0) * 0.4 * (0.5 + 0.5 * sin(t * 90.0)))
	# Survivors
	_streams["hurt"] = _make(0.25, func(t, _i): return sin(TAU * (300.0 - t * 600.0) * t) * exp(-t * 10.0) * 0.6)
	_streams["incap"] = _make(0.9, func(t, _i): return sin(TAU * (260.0 - t * 160.0) * t) * exp(-t * 3.0) * 0.6)
	_streams["heal"] = _make(0.6, func(t, _i): return _noise() * 0.25 * sin(PI * t / 0.6) * (0.5 + 0.5 * sin(t * 50.0)))
	_streams["pills"] = _make(0.4, func(t, _i): return _noise() * exp(-fmod(t, 0.1) * 60.0) * 0.4)
	_streams["pickup"] = _make(0.18, func(t, _i): return sin(TAU * (500.0 if t < 0.08 else 750.0) * t) * exp(-t * 10.0) * 0.4)
	_streams["heartbeat"] = _make(0.8, func(t, _i): return sin(TAU * 55.0 * t) * (exp(-t * 18.0) + exp(-max(t - 0.25, 0.0) * 18.0) * float(t > 0.25) * 0.7))
	_streams["click"] = _make(0.04, func(t, _i): return sin(TAU * 1800.0 * t) * exp(-t * 150.0) * 0.5)
	# Infected
	_streams["groan"] = _make(0.9, func(t, _i): return _saw(t * (95.0 + sin(t * 9.0) * 15.0)) * sin(PI * t / 0.9) * 0.3)
	_streams["scream"] = _make(0.7, func(t, _i): return (_saw(t * (380.0 + sin(t * 30.0) * 60.0)) * 0.5 + _noise() * 0.3) * sin(PI * t / 0.7) * 0.5)
	_streams["zombie_hit"] = _make(0.2, func(t, _i): return _noise() * exp(-t * 30.0) * 0.7 + sin(TAU * 120.0 * t) * exp(-t * 25.0) * 0.5)
	_streams["die"] = _make(0.5, func(t, _i): return _saw(t * (150.0 - t * 160.0)) * exp(-t * 5.0) * 0.35)
	_streams["boomer"] = _make(1.0, func(t, _i): return _saw(t * (60.0 + sin(t * 4.0) * 10.0)) * sin(PI * t) * 0.4 + _noise() * 0.1 * sin(PI * t))
	_streams["vomit"] = _make(1.2, func(t, _i): return (_noise() * 0.6 + _saw(t * 80.0) * 0.3) * min(t * 6.0, 1.0) * exp(-t * 1.5))
	_streams["hunter"] = _make(0.9, func(t, _i): return _saw(t * (900.0 - t * 500.0)) * sin(PI * t / 0.9) * 0.3 + _noise() * 0.15 * sin(PI * t / 0.9))
	_streams["pounce"] = _make(0.5, func(t, _i): return (_noise() * 0.6 + _saw(t * 500.0) * 0.4) * exp(-t * 4.0))
	_streams["smoker"] = _make(1.0, func(t, _i): return _noise() * (exp(-fmod(t, 0.33) * 14.0)) * 0.4)
	_streams["tongue"] = _make(0.6, func(t, _i): return sin(TAU * (200.0 + t * 900.0) * t) * exp(-t * 3.0) * 0.4)
	_streams["spitter"] = _make(0.8, func(t, _i): return _saw(t * (520.0 + sin(t * 25.0) * 90.0)) * sin(PI * t / 0.8) * 0.25)
	_streams["spit"] = _make(0.4, func(t, _i): return _noise() * exp(-t * 8.0) * 0.5)
	_streams["tank"] = _make(1.8, func(t, _i): return (_saw(t * (48.0 + sin(t * 4.0) * 12.0)) * 0.7 + _noise() * 0.4) * sin(PI * t / 1.8) * 0.9)
	_streams["punch"] = _make(0.3, func(t, _i): return sin(TAU * (90.0 - t * 120.0) * t) * exp(-t * 12.0) + _noise() * exp(-t * 30.0) * 0.7)
	_streams["rock"] = _make(0.6, func(t, _i): return _noise() * exp(-t * 6.0) * 0.8 + sin(TAU * 40.0 * t) * exp(-t * 6.0) * 0.6)
	_streams["witch_cry"] = _make(2.4, func(t, _i): return sin(TAU * (520.0 + sin(t * 3.0) * 60.0 - fmod(t, 0.8) * 120.0) * t) * (0.5 + 0.5 * sin(t * 7.0)) * 0.18)
	_streams["witch_scream"] = _make(1.3, func(t, _i): return (_saw(t * (950.0 + sin(t * 40.0) * 150.0)) * 0.6 + _noise() * 0.3) * exp(-t * 1.2))
	# Music stingers
	_streams["horde_music"] = _make(2.5, func(t, _i): return (_saw(t * 73.4) + _saw(t * 110.0) * 0.7 + _saw(t * 146.8) * 0.5) * 0.15 * min(t * 4.0, 1.0) * exp(-t * 0.8))
	_streams["tank_music"] = _make(3.0, func(t, _i): return (_square(t * 41.2) * 0.5 + _saw(t * 82.4) * 0.3) * 0.25 * (0.6 + 0.4 * float(fmod(t, 0.5) < 0.25)) * min((3.0 - t) * 2.0, 1.0))
	_streams["saferoom_music"] = _make(3.0, func(t, _i): return (sin(TAU * 261.6 * t) + sin(TAU * 329.6 * t) * 0.7 + sin(TAU * 392.0 * t) * 0.6) * 0.12 * sin(PI * t / 3.0))
	_streams["rescue_horn"] = _make(2.0, func(t, _i): return (_saw(t * 110.0) + _saw(t * 138.6) * 0.8) * 0.3 * min(t * 6.0, 1.0) * min((2.0 - t) * 4.0, 1.0))
	# Air-raid style city siren: slow rising and falling wail.
	_streams["siren"] = _make(5.0, func(t, _i): return (sin(TAU * (380.0 + 240.0 * sin(t * 1.25)) * t) * 0.5 + _saw(t * (380.0 + 240.0 * sin(t * 1.25))) * 0.15) * min(t * 2.0, 1.0) * min((5.0 - t) * 2.0, 1.0) * 0.5)
	# Weather and ambience. The beds loop seamlessly; Atmosphere plays them.
	_streams["thunder"] = _make(4.5, func(t, _i): return _noise() * exp(-t * 14.0) * 0.7 + _brown() * 2.6 * min(t * 12.0, 1.0) * exp(-t * 0.9) * (0.65 + 0.35 * sin(t * 6.3) * sin(t * 2.1)), 11025)
	_streams["thunder_far"] = _make(4.0, func(t, _i): return _brown() * 2.2 * sin(PI * minf(t / 0.6, 1.0) * 0.5) * exp(-t * 0.8) * (0.6 + 0.4 * sin(t * 4.7)), 11025)
	_streams["creak"] = _make(1.6, func(t, _i): return _saw(t * (62.0 + sin(t * 3.0) * 9.0 + fmod(t, 0.21) * 40.0)) * sin(PI * t / 1.6) * 0.25, 11025)
	_streams["wind_loop"] = _make_loop(12.0, func(t, _i): return _lowpass(_noise(), 0.015 + 0.04 * _gust(t, 12.0)) * 5.0 * (0.35 + 0.65 * _gust(t, 12.0)), 11025)
	_streams["rain_loop"] = _make_loop(6.0, func(_t, _i): return _hiss() * 0.32 + _brown() * 0.5 + float(_rng.randf() < 0.0009) * _noise() * 0.5)
	# A low tritone with slow beating: the dread under everything.
	_streams["drone_loop"] = _make_loop(12.0, func(t, _i): return (sin(TAU * 41.25 * t) + sin(TAU * 41.5 * t) * 0.8 + sin(TAU * 58.25 * t) * 0.45 + sin(TAU * 82.5 * t) * 0.2 * (0.5 + 0.5 * sin(TAU * t / 6.0))) * 0.22 * (0.75 + 0.25 * sin(TAU * t / 12.0)), 11025)
	_streams["radio"] = _make(1.2, func(t, _i): return (_noise() * 0.3 + _square(t * 440.0) * 0.1 * float(fmod(t, 0.3) < 0.15)) * sin(PI * t / 1.2))


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _saw(phase: float) -> float:
	return fposmod(phase, 1.0) * 2.0 - 1.0


func _square(phase: float) -> float:
	return 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0


## Brown (integrated) noise: rumble for thunder and rain.
func _brown() -> float:
	_brown_v = clampf(_brown_v * 0.996 + _noise() * 0.045, -1.0, 1.0)
	return _brown_v


## Bright noise (white minus its low end): rain on everything.
func _hiss() -> float:
	var n := _noise()
	return n - _lowpass(n, 0.35)


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


func stream(sound: String) -> AudioStream:
	return _streams.get(sound)


## Play a sound. Pass a world position for 3D audio, or leave it as INF for 2D.
func play(sound: String, pos: Vector3 = Vector3.INF, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound) or DisplayServer.get_name() == "headless":
		return
	if pos == Vector3.INF:
		var p2 := AudioStreamPlayer.new()
		p2.bus = sound_bus(sound)
		p2.stream = _streams[sound]
		p2.volume_db = volume_db
		p2.pitch_scale = pitch * _rng.randf_range(0.92, 1.08)
		add_child(p2)
		p2.play()
		p2.finished.connect(p2.queue_free)
	else:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = sound_bus(sound)
		p3.stream = _streams[sound]
		p3.volume_db = volume_db
		p3.unit_size = 6.0
		p3.max_distance = 90.0
		p3.pitch_scale = pitch * _rng.randf_range(0.9, 1.1)
		add_child(p3)
		p3.global_position = pos
		p3.play()
		p3.finished.connect(p3.queue_free)


func sound_bus(sound: String) -> String:
	if sound.ends_with("_music") or sound == "drone_loop": return "Music"
	if sound in ["hurt", "die", "groan", "witch_cry", "witch_scream", "hunter", "smoker", "boomer", "tank", "spitter", "scream"]: return "Voice"
	return "Effects"
