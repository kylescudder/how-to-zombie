class_name Atmosphere
extends Node3D
## The weather, light and sound of a level: a stormy sky with drifting clouds, layered fog
## (distance, ground mist and volumetric), a low sun, rain or drifting dust that follows the
## camera, lightning with thunder, flickering street lamps, reverb and a distant soundscape.
## Purely cosmetic and local: every peer rolls its own lightning and ambience.

const MOODS := {
	# Main Street and the open world: the last of the light under a breaking storm.
	"storm_dusk": {
		"top": Color(0.07, 0.08, 0.11), "horizon": Color(0.55, 0.33, 0.21),
		"cloud": Color(0.13, 0.13, 0.16), "cloud_lit": Color(0.85, 0.45, 0.25), "cover": 0.72,
		"fog": Color(0.27, 0.25, 0.27), "fog_density": 0.011, "mist": 0.09, "volumetric": 0.022,
		"sun": Color(1.0, 0.5, 0.26), "sun_energy": 1.25, "sun_rot": Vector3(-15, 58, 0),
		"ambient": Color(0.42, 0.47, 0.62), "ambient_energy": 0.75, "exposure": 1.05,
		"rain": 1.0, "dust": 0.0, "lightning": Vector2(12, 34), "reverb": 0.55,
	},
	# The Warehouse: a dead, close night. Dust hangs in the torch beams; heat lightning far off.
	"dead_night": {
		"top": Color(0.015, 0.02, 0.035), "horizon": Color(0.08, 0.1, 0.12),
		"cloud": Color(0.035, 0.04, 0.05), "cloud_lit": Color(0.15, 0.2, 0.25), "cover": 0.6,
		"fog": Color(0.06, 0.075, 0.08), "fog_density": 0.02, "mist": 0.16, "volumetric": 0.03,
		"sun": Color(0.55, 0.68, 0.95), "sun_energy": 0.32, "sun_rot": Vector3(-38, 20, 0),
		"ambient": Color(0.34, 0.42, 0.52), "ambient_energy": 0.5, "exposure": 1.15,
		"rain": 0.0, "dust": 1.0, "lightning": Vector2(30, 70), "reverb": 0.8,
	},
	# The Docks: a drowned night, horizontal rain and lightning on the water.
	"drowned_night": {
		"top": Color(0.02, 0.025, 0.045), "horizon": Color(0.12, 0.14, 0.2),
		"cloud": Color(0.05, 0.055, 0.075), "cloud_lit": Color(0.25, 0.3, 0.42), "cover": 0.85,
		"fog": Color(0.08, 0.09, 0.12), "fog_density": 0.016, "mist": 0.12, "volumetric": 0.028,
		"sun": Color(0.6, 0.7, 1.0), "sun_energy": 0.4, "sun_rot": Vector3(-30, -40, 0),
		"ambient": Color(0.36, 0.42, 0.58), "ambient_energy": 0.52, "exposure": 1.15,
		"rain": 1.6, "dust": 0.0, "lightning": Vector2(7, 20), "reverb": 0.65,
	},
}
## Open-world sightlines run for kilometres; thin the distance fog so islands still read.
const OPEN_WORLD_FOG := 0.3
const DISTANT := ["groan", "groan", "scream", "creak", "witch_cry"]

var mood: Dictionary
var env: Environment
var sun: DirectionalLight3D
var _open_world := false
var _sky_mat: ShaderMaterial
var _bolt: DirectionalLight3D
var _rain: GPUParticles3D
var _rain_mat: StandardMaterial3D
var _dust: GPUParticles3D
var _collider: GPUParticlesCollisionHeightField3D
var _wind: AudioStreamPlayer
var _rain_audio: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _reverbs: Array = []
var _rng := RandomNumberGenerator.new()
var _quality := -1
var _flash := 0.0
var _pulses: Array[float] = []
var _next_strike := 0.0
var _next_distant := 0.0
var _clock := 0.0
var _last_cam := Vector3.INF
var _headless := false


func setup(mood_name: String, open_world: bool) -> void:
	mood = MOODS[mood_name]
	_open_world = open_world


func _ready() -> void:
	_rng.randomize()
	_headless = DisplayServer.get_name() == "headless"
	_build_environment()
	_next_strike = _rng.randf_range(4.0, 10.0)
	_next_distant = _rng.randf_range(3.0, 8.0)
	if _headless:
		return
	_build_weather()
	_build_audio()
	_apply_quality()


func _exit_tree() -> void:
	for pair: Array in _reverbs:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus < 0: continue
		for i in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) == pair[1]:
				AudioServer.remove_bus_effect(bus, i)
				break


# --- Light and air ------------------------------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = _sky_shader()
	for key in ["top", "horizon", "cloud", "cloud_lit"]:
		_sky_mat.set_shader_parameter(key + "_color", mood[key])
	# Below the horizon the sky is only seen through fog (aerial perspective), so match the fog.
	_sky_mat.set_shader_parameter("ground_color", mood.fog)
	_sky_mat.set_shader_parameter("cover", mood.cover)
	_sky_mat.set_shader_parameter("sun_color", mood.sun)
	sky.sky_material = _sky_mat
	# The clouds move, so the radiance map refreshes a little every frame instead of all at once.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = mood.ambient
	env.ambient_light_energy = mood.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = mood.exposure
	env.tonemap_white = 6.0
	# Distance fog, a sun-tinted haze and mist that pools at street level.
	env.fog_enabled = true
	env.fog_light_color = mood.fog
	env.fog_density = mood.fog_density * (OPEN_WORLD_FOG if _open_world else 1.0)
	env.fog_sun_scatter = 0.35
	env.fog_aerial_perspective = 0.15
	env.fog_sky_affect = 0.45
	env.fog_height = 1.5
	env.fog_height_density = mood.mist
	env.volumetric_fog_density = mood.volumetric
	env.volumetric_fog_albedo = mood.fog.lightened(0.55)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_ambient_inject = 1.0
	env.volumetric_fog_sky_affect = 0.0
	# Lit windows, lamps and muzzle flashes bleed into the murk.
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for level in 7:
		env.set_glow_level(level, 1.0 if level in [2, 3, 4, 5] else 0.0)
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.0
	env.ssil_intensity = 0.8
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.88
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = mood.sun_rot
	sun.light_color = mood.sun
	sun.light_energy = mood.sun_energy
	sun.light_volumetric_fog_energy = 1.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	_sky_mat.set_shader_parameter("sun_dir", sun.basis.z)
	# The lightning: a cold second sun that only exists for a few frames at a time.
	_bolt = DirectionalLight3D.new()
	_bolt.name = "Lightning"
	_bolt.light_color = Color(0.72, 0.8, 1.0)
	_bolt.light_energy = 0.0
	_bolt.light_volumetric_fog_energy = 2.5
	_bolt.visible = false
	add_child(_bolt)


func _apply_quality() -> void:
	_quality = clampi(Settings.graphics_quality, 0, 2)
	env.volumetric_fog_enabled = _quality >= 1
	env.ssil_enabled = _quality >= 2
	_bolt.shadow_enabled = _quality >= 2
	if _rain:
		_rain.amount = maxi(int([700, 1500, 2600][_quality] * float(mood.rain)), 1)
		_collider.resolution = [GPUParticlesCollisionHeightField3D.RESOLUTION_256, GPUParticlesCollisionHeightField3D.RESOLUTION_256, GPUParticlesCollisionHeightField3D.RESOLUTION_512][_quality]
	if _dust:
		_dust.amount = [120, 260, 420][_quality]


static func _sky_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type sky;
uniform vec3 top_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 ground_color : source_color;
uniform vec3 cloud_color : source_color;
uniform vec3 cloud_lit_color : source_color;
uniform vec3 sun_color : source_color;
uniform vec3 sun_dir = vec3(0.0, 0.2, 1.0);
uniform vec3 flash_dir = vec3(0.0, 0.5, 1.0);
uniform float cover = 0.7;
uniform float flash = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(-0.02, 0.5, h));
	float toward_sun = max(dot(d, normalize(sun_dir)), 0.0);
	col += sun_color * (pow(toward_sun, 6.0) * 0.45 + pow(toward_sun, 48.0) * 0.8 + pow(toward_sun, 1200.0) * 6.0);
	float cloud_fade = smoothstep(-0.02, 0.14, h);
	if (cloud_fade > 0.0) {
		vec2 uv = d.xz / (h + 0.15) * 0.55 + TIME * vec2(0.012, 0.004);
		float n = fbm(uv * 1.4);
		float detail = fbm(uv * 3.3 - TIME * vec2(0.01, 0.006));
		float c = smoothstep(1.0 - cover, 1.25 - cover, n * 0.75 + detail * 0.35);
		float edge = (1.0 - detail) * pow(toward_sun, 2.5);
		vec3 cc = mix(cloud_color, cloud_lit_color, clamp(edge * 1.4, 0.0, 1.0));
		float near_flash = pow(max(dot(d, normalize(flash_dir)), 0.0), 3.0);
		cc += vec3(0.75, 0.82, 1.0) * flash * (0.35 + detail) * (0.3 + near_flash * 1.6);
		col = mix(col, cc, c * cloud_fade);
	}
	col += vec3(0.45, 0.5, 0.65) * flash * 0.25;
	col = mix(col, ground_color, smoothstep(0.0, -0.1, h));
	COLOR = col;
}
"""
	return shader


# --- Weather ------------------------------------------------------------------------------

func _build_weather() -> void:
	_collider = GPUParticlesCollisionHeightField3D.new()
	_collider.size = Vector3(56, 80, 56)
	_collider.follow_camera_enabled = true
	_collider.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(_collider)
	if float(mood.rain) > 0.0:
		_rain = GPUParticles3D.new()
		_rain.name = "Rain"
		_rain.lifetime = 0.8
		_rain.local_coords = false
		_rain.preprocess = 0.8
		_rain.visibility_aabb = AABB(Vector3(-30, -40, -30), Vector3(60, 60, 60))
		_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(20, 2, 20)
		pm.direction = Vector3(0.18, -1.0, 0.08)
		pm.spread = 3.0
		pm.initial_velocity_min = 24.0
		pm.initial_velocity_max = 32.0
		pm.gravity = Vector3(0, -9.8, 0)
		pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
		_rain.process_material = pm
		var streak := QuadMesh.new()
		streak.size = Vector2(0.014, 0.8)
		_rain_mat = StandardMaterial3D.new()
		_rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_rain_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		_rain_mat.billboard_keep_scale = true
		_rain_mat.albedo_color = Color(0.62, 0.68, 0.8, 0.2)
		streak.material = _rain_mat
		_rain.draw_pass_1 = streak
		add_child(_rain)
	if float(mood.dust) > 0.0:
		_dust = GPUParticles3D.new()
		_dust.name = "Dust"
		_dust.lifetime = 9.0
		_dust.local_coords = false
		_dust.preprocess = 9.0
		_dust.visibility_aabb = AABB(Vector3(-16, -8, -16), Vector3(32, 16, 32))
		_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(12, 4, 12)
		pm.gravity = Vector3(0, -0.04, 0)
		pm.initial_velocity_max = 0.15
		pm.spread = 180.0
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.4
		pm.turbulence_noise_speed_random = 0.3
		pm.scale_min = 0.5
		pm.alpha_curve = _fade_curve()
		_dust.process_material = pm
		var mote := QuadMesh.new()
		mote.size = Vector2(0.03, 0.03)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(1.0, 0.86, 0.66, 0.45)
		mote.material = m
		_dust.draw_pass_1 = mote
		add_child(_dust)


static func _fade_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


# --- Sound --------------------------------------------------------------------------------

func _build_audio() -> void:
	_wind = _loop("wind_loop", -13.0 if mood.rain > 0.0 else -9.0, "Effects")
	if float(mood.rain) > 0.0:
		_rain_audio = _loop("rain_loop", -17.0 + float(mood.rain) * 4.0, "Effects")
	_drone = _loop("drone_loop", -15.0, "Music")
	# Everything echoes a little: streets, warehouses, docks.
	for bus_name in ["Effects", "Voice"]:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus < 0: continue
		var reverb := AudioEffectReverb.new()
		reverb.room_size = mood.reverb
		reverb.damping = 0.55
		reverb.spread = 0.8
		reverb.predelay_msec = 40.0
		reverb.dry = 1.0
		reverb.wet = 0.16
		AudioServer.add_bus_effect(bus, reverb)
		_reverbs.append([bus_name, reverb])


func _loop(sound: String, volume_db: float, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = Sfx.stream(sound)
	player.volume_db = volume_db
	player.bus = bus
	add_child(player)
	if player.stream:
		player.play(_rng.randf_range(0.0, player.stream.get_length()))
	return player


func _distant_sound(cam: Vector3) -> void:
	var sound: String = DISTANT[_rng.randi() % DISTANT.size()]
	if _open_world and _rng.randf() < 0.15:
		sound = "siren"
	var angle := _rng.randf() * TAU
	var pos := cam + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(45.0, 75.0)
	Sfx.play(sound, pos, 4.0 if sound != "siren" else -4.0, _rng.randf_range(0.55, 0.8))


# --- Per frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if not _headless and Settings.graphics_quality != _quality:
		_apply_quality()
	_tick_lightning(delta)
	_flicker()
	var cam := get_viewport().get_camera_3d()
	if cam == null or _headless:
		return
	var p := cam.global_position
	var vel := Vector3.ZERO if _last_cam == Vector3.INF else (p - _last_cam) / maxf(delta, 0.001)
	_last_cam = p
	# Lead the rain into wherever the camera is heading, so driving doesn't outrun it.
	var lead := vel.limit_length(40.0) * Vector3(0.5, 0.0, 0.5)
	if _rain:
		_rain.global_position = p + lead + Vector3(-2.5, 13.0, -1.0)
		_rain_mat.albedo_color.a = 0.2 + _flash * 0.45
	if _dust:
		_dust.global_position = p + lead * 0.5
	_next_distant -= delta
	if _next_distant <= 0.0:
		_next_distant = _rng.randf_range(7.0, 18.0)
		_distant_sound(p)


func _tick_lightning(delta: float) -> void:
	_next_strike -= delta
	if _next_strike <= 0.0:
		_next_strike = _rng.randf_range(mood.lightning.x, mood.lightning.y)
		_strike()
	while not _pulses.is_empty() and _pulses[0] <= _clock:
		_pulses.pop_front()
		_flash = maxf(_flash, _rng.randf_range(0.55, 1.0))
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_bolt.visible = _flash > 0.0
	_bolt.light_energy = _flash * 2.4
	env.ambient_light_energy = mood.ambient_energy + _flash * 0.9
	env.fog_light_energy = 1.0 + _flash * 1.4
	_sky_mat.set_shader_parameter("flash", _flash)


## A strike: two to four stuttering flashes from one direction, then thunder a beat later.
func _strike() -> void:
	var yaw := _rng.randf() * TAU
	var pitch := deg_to_rad(_rng.randf_range(-70.0, -35.0))
	_bolt.rotation = Vector3(pitch, yaw, 0)
	_sky_mat.set_shader_parameter("flash_dir", _bolt.basis.z)
	var t := _clock
	for i in _rng.randi_range(2, 4):
		_pulses.append(t)
		t += _rng.randf_range(0.05, 0.22)
	var distance := _rng.randf()
	var delay := 0.3 + distance * 2.8
	var close := distance < 0.25
	get_tree().create_timer(delay).timeout.connect(func():
		Sfx.play("thunder" if close else "thunder_far", Vector3.INF, -1.0 - distance * 9.0, _rng.randf_range(0.8, 1.05))
	)


func _flicker() -> void:
	for node in get_tree().get_nodes_in_group("flicker_lamp"):
		var light := node as Light3D
		var phase: float = light.get_meta("phase", 0.0)
		var cycle := fposmod(_clock + phase, 7.0)
		var k := 1.0
		if cycle < 1.1:
			k = 0.05 if _rng.randf() < 0.45 else 1.0
		elif cycle < 1.6:
			k = 0.0
		light.light_energy = float(light.get_meta("energy", 1.0)) * k
		var bulb: Variant = light.get_meta("bulb", null)
		if bulb is StandardMaterial3D:
			(bulb as StandardMaterial3D).emission_energy_multiplier = 3.0 * k
