extends Node
## Procedurally synthesised sound effects, so the project ships with zero audio assets.
## Swap any entry in `_streams` for a real AudioStream later.

const RATE := 22050
var _streams := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_streams["shot"] = _make(0.25, func(t, _i): return _noise() * exp(-t * 28.0) + sin(t * 900.0) * exp(-t * 40.0) * 0.5)
	_streams["shotgun"] = _make(0.5, func(t, _i): return _noise() * exp(-t * 9.0) * 1.1 + sin(t * 400.0) * exp(-t * 20.0))
	_streams["harpoon"] = _make(0.4, func(t, _i): return sin(TAU * (900.0 - t * 1800.0) * t) * exp(-t * 7.0) * 0.6 + _noise() * exp(-t * 30.0) * 0.4)
	_streams["slap"] = _make(0.15, func(t, _i): return _noise() * exp(-t * 60.0) * 1.2 + sin(TAU * 1400.0 * t) * exp(-t * 80.0) * 0.4)
	_streams["hit"] = _make(0.18, func(t, _i): return sin(TAU * (160.0 - t * 300.0) * t) * exp(-t * 25.0) + _noise() * exp(-t * 50.0) * 0.4)
	_streams["squelch"] = _make(0.3, func(t, _i): return sin(TAU * (220.0 + sin(t * 70.0) * 120.0) * t) * exp(-t * 12.0) * 0.7 + _noise() * exp(-t * 20.0) * 0.2)
	_streams["splash"] = _make(0.7, func(t, _i): return _noise() * exp(-t * 5.0) * (0.6 + 0.4 * sin(t * 40.0)) * 0.7)
	_streams["cast"] = _make(0.35, func(t, _i): return _noise() * sin(PI * t / 0.35) * 0.4)
	_streams["plop"] = _make(0.2, func(t, _i): return sin(TAU * (500.0 - t * 1500.0) * t) * exp(-t * 18.0))
	_streams["bite"] = _make(0.3, func(t, _i): return sin(TAU * 880.0 * t) * exp(-t * 10.0) * 0.5 + sin(TAU * 1320.0 * t) * exp(-t * 14.0) * 0.4)
	_streams["reel"] = _make(0.05, func(t, _i): return _noise() * exp(-t * 120.0) * 0.6)
	_streams["snap"] = _make(0.3, func(t, _i): return sin(TAU * 2400.0 * t) * exp(-t * 30.0) * 0.6 + _noise() * exp(-t * 40.0) * 0.6)
	_streams["cash"] = _make(0.5, func(t, _i): return (sin(TAU * 1568.0 * t) * float(t < 0.12) + sin(TAU * 2093.0 * t) * float(t >= 0.12)) * exp(-t * 6.0) * 0.5)
	_streams["explosion"] = _make(1.3, func(t, _i): return _noise() * exp(-t * 3.5) * 1.2 + sin(TAU * 55.0 * t) * exp(-t * 4.0) * 0.8)
	_streams["groan"] = _make(0.9, func(t, _i): return _saw(t * (95.0 + sin(t * 9.0) * 15.0)) * sin(PI * t / 0.9) * 0.35)
	_streams["roar"] = _make(1.6, func(t, _i): return (_saw(t * (60.0 + sin(t * 5.0) * 20.0)) * 0.6 + _noise() * 0.4) * sin(PI * t / 1.6) * 0.8)
	_streams["die"] = _make(0.6, func(t, _i): return _saw(t * (140.0 - t * 160.0)) * exp(-t * 4.0) * 0.4)
	_streams["hurt"] = _make(0.25, func(t, _i): return sin(TAU * (300.0 - t * 600.0) * t) * exp(-t * 10.0) * 0.6)
	_streams["click"] = _make(0.04, func(t, _i): return sin(TAU * 1800.0 * t) * exp(-t * 150.0) * 0.5)
	_streams["buy"] = _make(0.35, func(t, _i): return sin(TAU * (660.0 if t < 0.1 else 990.0) * t) * exp(-t * 6.0) * 0.4)
	_streams["deny"] = _make(0.3, func(t, _i): return _square(t * 140.0) * exp(-t * 8.0) * 0.25)
	_streams["spin"] = _make(1.2, func(t, _i): return _square(t * (400.0 + 300.0 * float(int(t * 16.0) % 2))) * 0.12 * (1.0 - t / 1.2))
	_streams["jackpot"] = _make(1.0, func(t, _i): return sin(TAU * [523.0, 659.0, 784.0, 1047.0][min(int(t * 6.0), 3)] * t) * 0.45 * exp(-max(t - 0.6, 0.0) * 6.0))
	_streams["squawk"] = _make(0.45, func(t, _i): return _saw(t * (1100.0 + sin(t * 60.0) * 400.0)) * exp(-t * 4.0) * 0.3)
	_streams["fuse"] = _make(0.5, func(t, _i): return _noise() * 0.18)
	_streams["reload"] = _make(0.25, func(t, _i): return (_noise() * exp(-t * 60.0) + _noise() * exp(-max(t - 0.15, 0.0) * 60.0) * float(t > 0.15)) * 0.5)
	_streams["swing"] = _make(0.2, func(t, _i): return _noise() * sin(PI * t / 0.2) * 0.25)


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _saw(phase: float) -> float:
	return fposmod(phase, 1.0) * 2.0 - 1.0


func _square(phase: float) -> float:
	return 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0


func _make(duration: float, gen: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v := clampf(float(gen.call(t, i)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


## Play a sound. Pass a world position for 3D audio, or leave it as INF for 2D.
func play(sound: String, pos: Vector3 = Vector3.INF, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound) or DisplayServer.get_name() == "headless":
		return
	if pos == Vector3.INF:
		var p2 := AudioStreamPlayer.new()
		p2.stream = _streams[sound]
		p2.volume_db = volume_db
		p2.pitch_scale = pitch * _rng.randf_range(0.92, 1.08)
		add_child(p2)
		p2.play()
		p2.finished.connect(p2.queue_free)
	else:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = _streams[sound]
		p3.volume_db = volume_db
		p3.unit_size = 6.0
		p3.max_distance = 90.0
		p3.pitch_scale = pitch * _rng.randf_range(0.9, 1.1)
		add_child(p3)
		p3.global_position = pos
		p3.play()
		p3.finished.connect(p3.queue_free)
