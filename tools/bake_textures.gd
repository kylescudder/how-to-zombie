extends SceneTree
## Bakes the tiling surface textures into assets/textures. Albedos are grey, so a surface keeps the
## colour it was given and only gains detail. Run: godot --headless --script tools/bake_textures.gd
const SIZE := 512
const OUT := "res://assets/textures/"
const CRACK := 0.022

var _clouds: PackedByteArray
var _blotch: PackedByteArray
var _grain: PackedByteArray
var _cells: PackedByteArray
var _speck := PackedByteArray()
var _height := PackedFloat32Array()
var _shade := PackedFloat32Array()
var _x := 0.0
var _y := 0.0
var _i := 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_clouds = _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3.0, 5, 1)
	_blotch = _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 9.0, 4, 2)
	_grain = _noise(FastNoiseLite.TYPE_SIMPLEX, 60.0, 3, 3)
	_cells = _cellular()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_speck.resize(SIZE * SIZE)
	for i in _speck.size():
		_speck[i] = rng.randi() % 256
	_height.resize(SIZE * SIZE)
	_shade.resize(SIZE * SIZE)
	for surface: String in ["brick", "plaster", "concrete", "asphalt", "paving", "metal", "wood", "fabric", "grass", "sand", "tile", "painted"]:
		for y in SIZE:
			for x in SIZE:
				_i = y * SIZE + x
				_x = float(x) / SIZE
				_y = float(y) / SIZE
				call("_" + surface)
		_ground_detail(surface)
		_save(surface)
		print("baked ", surface)
	quit()


func _noise(kind: int, frequency: float, octaves: int, seed_v: int) -> PackedByteArray:
	var noise := FastNoiseLite.new()
	noise.noise_type = kind
	noise.frequency = frequency / SIZE
	noise.fractal_octaves = octaves
	noise.seed = seed_v
	var image := noise.get_seamless_image(SIZE, SIZE)
	image.convert(Image.FORMAT_L8)
	return image.get_data()


func _cellular() -> PackedByteArray:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.frequency = 7.0 / SIZE
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.seed = 4
	var image := noise.get_seamless_image(SIZE, SIZE)
	image.convert(Image.FORMAT_L8)
	return image.get_data()


func _n(field: PackedByteArray) -> float:
	return field[_i] / 255.0


## Thin dark lines where the cell noise meets, only in the patches where the mask allows.
func _crack(chance: float) -> float:
	if _n(_clouds) < 1.0 - chance:
		return 0.0
	return 1.0 - smoothstep(0.0, CRACK, _n(_cells))


func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 1000) / 1000.0


func _put(height: float, shade: float) -> void:
	_height[_i] = height
	_shade[_i] = shade


func _brick() -> void:
	var rows := 20.0
	var cols := 8.0
	var row := int(_y * rows)
	var u := _x * cols + (0.5 if row % 2 == 1 else 0.0)
	var col := int(u) % int(cols)
	var fx := u - floorf(u)
	var fy := _y * rows - row
	var edge := minf(minf(fx, 1.0 - fx) * 2.6, minf(fy, 1.0 - fy))
	var face := smoothstep(0.05, 0.12, edge)
	var tone := 0.72 + _hash(row, col) * 0.26
	if _hash(col, row + 40) > 0.9:
		tone *= 0.72
	var wear := 0.9 + _n(_blotch) * 0.2 + (_n(_speck) - 0.5) * 0.05
	var mortar := 1.0 + _n(_grain) * 0.1
	_put(face * (0.72 + _n(_grain) * 0.26), minf(lerpf(mortar, tone * wear, face) * (0.8 + _n(_clouds) * 0.32), 1.0))


func _plaster() -> void:
	var stain := smoothstep(0.25, 0.85, _n(_clouds))
	var crack := _crack(0.16)
	_put(0.55 + _n(_blotch) * 0.2 + _n(_grain) * 0.14 - crack * 0.5, (0.97 - stain * 0.1 + (_n(_blotch) - 0.5) * 0.07) * (1.0 - crack * 0.6))


func _concrete() -> void:
	var seam := minf(fposmod(_x * 2.0, 1.0), fposmod(_y * 2.0, 1.0))
	var line := 1.0 - smoothstep(0.0, 0.012, seam)
	var pit := smoothstep(0.93, 1.0, _n(_speck)) * smoothstep(0.35, 0.7, _n(_blotch))
	var crack := _crack(0.3)
	_put(0.7 + _n(_grain) * 0.14 - line * 0.5 - pit * 0.3 - crack * 0.4, (0.9 + (_n(_clouds) - 0.5) * 0.26 + (_n(_grain) - 0.5) * 0.12) * (1.0 - line * 0.45) * (1.0 - pit * 0.4) * (1.0 - crack * 0.55))


func _asphalt() -> void:
	var stone := _n(_speck)
	var patch := smoothstep(0.58, 0.62, _n(_clouds))
	var crack := _crack(0.45)
	var tone := 0.72 + (stone - 0.5) * 0.42 + (_n(_blotch) - 0.5) * 0.22
	_put(0.5 + stone * 0.4 - crack * 0.5 - patch * 0.12, clampf(tone * (1.0 - patch * 0.26) * (1.0 - crack * 0.72), 0.0, 1.0))


func _paving() -> void:
	var cells := 4.0
	var cx := int(_x * cells)
	var cy := int(_y * cells)
	var fx := _x * cells - cx
	var fy := _y * cells - cy
	var edge := minf(minf(fx, 1.0 - fx), minf(fy, 1.0 - fy))
	var face := smoothstep(0.012, 0.03, edge)
	var tone := 0.78 + _hash(cx, cy + 9) * 0.2
	var crack := _crack(0.25)
	_put(face * 0.8 + _n(_grain) * 0.14 - crack * 0.4, (lerpf(0.46, tone, face) + (_n(_blotch) - 0.5) * 0.14) * (1.0 - crack * 0.6))


func _metal() -> void:
	var streak := absf(sin(_x * TAU * 3.0 + _n(_clouds) * 4.0)) * 0.5 + 0.5
	var drip := smoothstep(0.52, 0.8, _n(_blotch)) * smoothstep(0.2, 0.9, streak)
	var scratch := smoothstep(0.84, 0.96, _n(_grain))
	_put(0.6 + _n(_blotch) * 0.14 - drip * 0.12, clampf(0.92 - drip * 0.34 + scratch * 0.1, 0.0, 1.0))


func _wood() -> void:
	var planks := 6.0
	var plank := int(_x * planks)
	var fx := _x * planks - plank
	var gap := smoothstep(0.0, 0.03, minf(fx, 1.0 - fx))
	var band := sin((_x + _n(_clouds) * 0.09) * TAU * 44.0 + plank * 2.0) * 0.5 + 0.5
	var tone := 0.74 + _hash(plank, 3) * 0.24
	_put(gap * (0.7 + band * 0.18), clampf((tone + (band - 0.5) * 0.24) * lerpf(0.4, 1.0, gap), 0.0, 1.0))


func _fabric() -> void:
	var weave := sin(_x * TAU * 90.0) * sin(_y * TAU * 90.0) * 0.5 + 0.5
	_put(0.5 + weave * 0.3, clampf(0.88 + (weave - 0.5) * 0.14 + (_n(_blotch) - 0.5) * 0.18, 0.0, 1.0))


func _grass() -> void:
	var blade := _n(_speck) * 0.5 + _n(_grain) * 0.5
	_put(blade, clampf(0.66 + blade * 0.34 + (_n(_clouds) - 0.5) * 0.46, 0.0, 1.0))


func _sand() -> void:
	var ripple := sin((_y + _n(_clouds) * 0.14) * TAU * 14.0) * 0.5 + 0.5
	_put(0.4 + ripple * 0.3 + _n(_speck) * 0.12, clampf(0.84 + (ripple - 0.5) * 0.12 + (_n(_speck) - 0.5) * 0.1 + (_n(_blotch) - 0.5) * 0.14, 0.0, 1.0))


func _tile() -> void:
	var cells := 6.0
	var cx := int(_x * cells)
	var cy := int(_y * cells)
	var fx := _x * cells - cx
	var fy := _y * cells - cy
	var edge := minf(minf(fx, 1.0 - fx), minf(fy, 1.0 - fy))
	var face := smoothstep(0.015, 0.04, edge)
	var tone := 0.86 + _hash(cx, cy) * 0.12
	_put(face * 0.8, lerpf(0.5, tone, face) * (0.92 + _n(_blotch) * 0.1))


## The fallback for anything without a real surface: broad paint variation and light scuffs.
func _painted() -> void:
	_put(0.6 + _n(_blotch) * 0.16 + _n(_grain) * 0.06, clampf(0.9 + (_n(_clouds) - 0.5) * 0.2 + (_n(_grain) - 0.5) * 0.08, 0.0, 1.0))


## Wrapped stamps give the ground readable shapes at walking distance, beyond fine noise.
## A private seed keeps rebakes reproducible and never changes gameplay random streams.
func _ground_detail(surface: String) -> void:
	if surface not in ["grass", "asphalt", "paving", "sand", "concrete"]:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	if surface == "grass":
		for blade in 3400:
			var start := Vector2(rng.randf_range(0, SIZE), rng.randf_range(0, SIZE))
			var angle := rng.randf_range(-PI, PI)
			var length := rng.randf_range(4, 13)
			var direction := Vector2.from_angle(angle)
			var tone := rng.randf_range(0.48, 0.98)
			for step in int(length):
				var t := float(step) / length
				var point := start + direction * step + direction.orthogonal() * t * t * 3.0
				_stamp(point, 0.8 * (1.0 - t) + 0.35, 0.25, tone, 0.85)
	# Sparse, rounded mineral chips; grass and sand carry larger exposed pebbles.
	for stone in (180 if surface in ["grass", "sand"] else 650):
		var point := Vector2(rng.randf_range(0, SIZE), rng.randf_range(0, SIZE))
		var radius := rng.randf_range(1.3, 3.8) if surface in ["grass", "sand"] else rng.randf_range(0.6, 1.8)
		_stamp(point + Vector2(0.8, 1), radius + 0.7, -0.10, 0.4, 0.7)
		_stamp(point, radius, 0.24, rng.randf_range(0.66, 1.0), 0.95)
	if surface in ["asphalt", "paving", "concrete"]:
		for fissure in 7:
			var point := Vector2(rng.randf_range(0, SIZE), rng.randf_range(0, SIZE))
			var angle := rng.randf_range(-PI, PI)
			for step in rng.randi_range(35, 100):
				angle += rng.randf_range(-0.45, 0.45)
				point += Vector2.from_angle(angle) * 1.4
				_stamp(point, 1.6, -0.16, 0.46, 0.5)
				_stamp(point, 0.75, -0.42, 0.20, 0.95)
				if step % 24 == 0:
					var branch := point
					var direction := Vector2.from_angle(angle + 1.1)
					for twig in 15:
						branch += direction + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
						_stamp(branch, 0.6, -0.3, 0.28, 0.85)


func _stamp(point: Vector2, radius: float, relief: float, tone: float, opacity: float) -> void:
	var extent := ceili(radius)
	for y in range(-extent, extent + 1):
		for x in range(-extent, extent + 1):
			var distance := Vector2(x, y).length() / radius
			if distance > 1.0:
				continue
			var weight := (1.0 - smoothstep(0.4, 1.0, distance)) * opacity
			var index := posmod(roundi(point.y) + y, SIZE) * SIZE + posmod(roundi(point.x) + x, SIZE)
			_height[index] += relief * weight
			_shade[index] = lerpf(_shade[index], tone, weight)


func _save(name: String) -> void:
	var albedo := PackedByteArray()
	var normal := PackedByteArray()
	albedo.resize(SIZE * SIZE)
	normal.resize(SIZE * SIZE * 3)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			albedo[i] = clampi(int(_shade[i] * 255.0), 0, 255)
			# Wrapping neighbours keep the normals seamless too.
			var dx := _height[y * SIZE + (x + 1) % SIZE] - _height[y * SIZE + (x + SIZE - 1) % SIZE]
			var dy := _height[(y + 1) % SIZE * SIZE + x] - _height[(y + SIZE - 1) % SIZE * SIZE + x]
			var n := Vector3(-dx * 3.5, dy * 3.5, 1.0).normalized()
			normal[i * 3] = int((n.x * 0.5 + 0.5) * 255.0)
			normal[i * 3 + 1] = int((n.y * 0.5 + 0.5) * 255.0)
			normal[i * 3 + 2] = int((n.z * 0.5 + 0.5) * 255.0)
	Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, albedo).save_png(OUT + name + ".png")
	Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, normal).save_png(OUT + name + "_n.png")
