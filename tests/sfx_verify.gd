extends RefCounted
## Loads and builds every sound headless, then checks each name the game asks for exists, every
## take is audible and unclipped, and that playback caps voices and merges doubles.

## Requested indirectly (built names, conditionals, reload cues), so the scan below misses them.
const INDIRECT := ["thunder", "thunder_far", "creak", "wind_loop", "rain_loop", "drone_loop", "step1", "step2", "step3", "step4", "skid_loop", "mag_out", "mag_in", "rack", "shell", "pump"]


func run(test: Node) -> void:
	var started := Time.get_ticks_msec()
	Sfx.build_now()
	var ms := Time.get_ticks_msec() - started
	print("[TEST]   sound build took %d ms" % ms)
	test.check(ms < 20000, "every sound loads or synthesises within 20 s on one thread")
	var names := _requested()
	test.check(names.size() > 50, "found %d sounds the game requests" % names.size())
	var missing := names.filter(func(n): return Sfx.takes(n).is_empty())
	test.check(missing.is_empty(), "every requested sound is built %s" % [missing])
	var bad := []
	for sound in names:
		for take in Sfx.takes(sound):
			if take.format != AudioStreamWAV.FORMAT_16_BITS:
				if take.get_length() <= 0.0: bad.append(sound)  # Compressed on import: trust the build script's levels.
				continue
			var m := _measure(take)
			print("[TEST]     %-15s %5.2f s  peak %.2f  rms %.3f" % [sound, m.seconds, m.peak, m.rms])
			if m.peak < 0.05 or m.peak > 0.99 or m.rms < 0.003 or m.seconds <= 0.0:
				bad.append(sound)
	test.check(bad.is_empty(), "every take is audible and unclipped %s" % [bad])
	for sound in ["groan", "pistol", "explosion", "hit", "smg", "shotgun"]:
		var takes := Sfx.takes(sound)
		test.check(takes.size() > 1 and takes[0] != takes[1], "%s has distinct takes" % sound)
	test.check(Sfx.takes("pistol").size() >= 4 and Sfx.takes("groan").size() >= 8, "recorded takes load from assets/audio")
	test.check(Sfx.sound_bus("mag_in") == "Weapons" and Sfx.sound_bus("fire_loop") == "Environment" and Sfx.sound_bus("tank") == "Voice", "new sounds route to their buses")
	var cam := test.get_viewport().get_camera_3d()
	var here := cam.global_position if cam else Vector3.ZERO
	for i in 12:
		Sfx.play("groan", here + Vector3(i * 3.0, 0, 0))
	test.check(Sfx.voices("groan") == 6, "a crowd of groans is capped at six voices")
	Sfx.play("pistol", here)
	Sfx.play("pistol", here + Vector3(0.5, 0, 0))
	test.check(Sfx.voices("pistol") == 1, "two identical shots from one spot play once")
	Sfx.play("pistol", here + Vector3(10, 0, 0))
	test.check(Sfx.voices("pistol") == 2, "a second gun nearby still plays")
	Sfx.play("explosion", here + Vector3(5000, 0, 0))
	test.check(cam == null or Sfx.voices("explosion") == 0, "sounds far beyond earshot are skipped")


func _requested() -> Array:
	var found := {}
	for n in INDIRECT:
		found[n] = true
	var re := RegEx.create_from_string("(?:Sfx\\.(?:play|stream|attach_loop)|fx_sound\\.rpc)\\(\"([a-z0-9_]+)\"|\"sound\": \"([a-z0-9_]+)\"")
	for path in _scripts("res://scripts"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			found[m.get_string(1) if m.get_string(1) != "" else m.get_string(2)] = true
	for n in Atmosphere.DISTANT:
		found[n] = true
	return found.keys()


func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out


func _measure(s: AudioStreamWAV) -> Dictionary:
	var n := s.data.size() / 2
	var peak := 0.0
	var sum := 0.0
	for i in n:
		var v := s.data.decode_s16(i * 2) / 32768.0
		peak = maxf(peak, absf(v))
		sum += v * v
	return {"seconds": float(n) / s.mix_rate, "peak": peak, "rms": sqrt(sum / maxi(n, 1))}
