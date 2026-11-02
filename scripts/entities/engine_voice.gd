class_name EngineVoice
extends AudioStreamPlayer3D
## A synthesised engine, generated live so revs change the firing rate rather than pitch-shifting a loop.
## Each cylinder firing is a short pressure pulse (slightly uneven per cylinder, like a real block) rung
## through two exhaust resonances, with intake roar that opens up under load.
## Set `revs` (0 idle .. 1 redline) and `load` (0 coasting .. 1 full throttle) every frame.

const RATE := 22050.0

var revs := 0.0
var load := 0.0
var _cylinders := 4
var _idle_rpm := 850.0
var _red_rpm := 6200.0
var _body_hz := Vector2(130, 420)  # exhaust resonances at idle; they open up a little with revs
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _phase := 0.0
var _fired := 0
var _env := 0.0
var _rpm := 850.0
var _gain := 0.0
var _weights: Array[float] = []
# Two state-variable band-pass filters and a one-pole low-pass for the intake.
var _lo1 := 0.0
var _bp1 := 0.0
var _lo2 := 0.0
var _bp2 := 0.0
var _air := 0.0
var _dc := 0.0


func _init(kind := "car") -> void:
	if kind == "boat":
		# A three-cylinder outboard: lower, lumpier, and wetter.
		_cylinders = 3
		_idle_rpm = 700.0
		_red_rpm = 5200.0
		_body_hz = Vector2(95, 300)
	_rng.seed = hash(kind)
	for c in _cylinders: _weights.append(_rng.randf_range(0.75, 1.0))
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	stream = gen
	bus = "Effects"
	unit_size = 8.0
	max_distance = 110.0
	volume_db = -80.0


func _process(_delta: float) -> void:
	if not playing:
		return
	if _playback == null:
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var target_rpm := lerpf(_idle_rpm, _red_rpm, clampf(revs, 0.0, 1.0))
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	var decay := exp(-1.0 / (RATE * 0.0035))
	var open := clampf(revs, 0.0, 1.0)
	var f1 := 2.0 * sin(PI * _body_hz.x * (1.0 + open * 0.6) / RATE)
	var f2 := 2.0 * sin(PI * _body_hz.y * (1.0 + open * 0.4) / RATE)
	var gain_goal := 0.55 + load * 0.45
	for i in frames:
		# Revs and gain glide per sample, so gear changes and throttle lifts don't click.
		_rpm += (target_rpm - _rpm) * 0.0006
		_gain += (gain_goal - _gain) * 0.0008
		# Four-stroke: each cylinder fires every other revolution.
		_phase += _rpm / 60.0 * _cylinders * 0.5 / RATE
		if _phase >= 1.0:
			_phase -= 1.0
			_fired += 1
			_env += _weights[_fired % _cylinders] * _rng.randf_range(0.85, 1.0)
		_env *= decay
		var pulse := _env * (0.7 + _rng.randf_range(-0.3, 0.3))
		_lo1 += f1 * _bp1
		_bp1 += f1 * (pulse - _lo1 - 0.35 * _bp1)
		_lo2 += f2 * _bp2
		_bp2 += f2 * (pulse - _lo2 - 0.6 * _bp2)
		_air += (_rng.randf_range(-1.0, 1.0) - _air) * (0.05 + open * 0.15)
		var s := _bp1 * 0.55 + _bp2 * 0.25 + _lo1 * 0.08 + _air * (0.04 + load * 0.12 * (0.4 + open))
		# Strip DC and keep it inside the speaker.
		_dc += (s - _dc) * 0.002
		# Make-up gain into a soft clip: loud enough to sit over rain, a little grit when pushed.
		s = (s - _dc) * _gain * 3.5
		s = s / (1.0 + absf(s))
		buffer[i] = Vector2(s, s)
	_playback.push_buffer(buffer)
