class_name VehicleKit
extends RefCounted
## Hard-edged vehicles assembled from VehicleCatalog entries: side profile, cabin, glass, trim, then fittings.
## Front is -Z, the way TeamVehicle drives. Distances called `t` run from the nose (0) to the tail (length).
const TYRE := Color(0.055,0.06,0.065)
const TRIM := Color(0.075,0.085,0.09)
const SHADOW := Color(0.03,0.035,0.04)
const GLASS := Color(0.09,0.19,0.23)
const GLARE := Color(0.30,0.46,0.50)
const HEADLAMP := Color(1.0,0.93,0.68)
const TAILLAMP := Color(0.78,0.09,0.07)
const AMBER := Color(0.98,0.60,0.12)
const STEEL := Color(0.44,0.47,0.48)
const RUST := Color(0.47,0.22,0.11)
const PLATE := Color(0.90,0.88,0.72)
const WOOD := Color(0.53,0.33,0.16)
const CANVAS := Color(0.41,0.42,0.28)

static var _meshes := {}
static var _materials: Array[Material] = []

var v: Dictionary
var f := Forge.new()
var rng := RandomNumberGenerator.new()
var paint: Color
var L: float
var W: float
var ride: float
var r: float
var belt: float
var roof: float
var cowl: float
var peak: float
var back: float
var foot: float
var nose: float
var tail: float
var hw: float
var lower: PackedVector2Array
var cabin: PackedVector2Array

## Adds the model to parent as a single mesh. Identical vehicles share it. An alpha-0 paint keeps the catalog colour.
static func build(parent: Node3D, id: String, color := Color(0,0,0,0)) -> MeshInstance3D:
	var key := "%s|%s" % [id,color.to_html()]
	if not _meshes.has(key):
		var data := VehicleCatalog.find(id)
		if color.a > 0: data.paint = color
		var kit := VehicleKit.new(data)
		kit._assemble()
		_meshes[key] = kit.f.commit(_layer_materials())
	var mi := MeshInstance3D.new()
	mi.name = "Vehicle"
	mi.mesh = _meshes[key]
	parent.add_child(mi)
	return mi

static func _layer_materials() -> Array[Material]:
	if _materials.is_empty():
		var surface := Build.paint
		Build.paint = ""
		var body: StandardMaterial3D = Build.mat(Color.WHITE,0.46).duplicate()
		Build.paint = surface
		# Keep only a faint dent in the surface: the albedo grain reads as cloth across a van side.
		body.albedo_texture = null
		body.normal_scale = 0.25
		for m: StandardMaterial3D in [body,StandardMaterial3D.new(),StandardMaterial3D.new()]:
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			_materials.append(m)
		(_materials[1] as StandardMaterial3D).roughness = 0.12
		(_materials[1] as StandardMaterial3D).metallic_specular = 0.8
		(_materials[2] as StandardMaterial3D).roughness = 0.24
		(_materials[2] as StandardMaterial3D).metallic = 0.3
	return _materials

func _init(data: Dictionary) -> void:
	v = data
	paint = v.paint
	L = v.len
	W = v.wid
	ride = v.ride
	r = v.r
	belt = v.belt
	roof = v.roof
	cowl = v.cowl
	peak = v.peak
	back = v.back
	foot = v.foot
	nose = v.nose
	tail = v.tail
	hw = W*0.5-0.1
	rng.seed = hash(v.id)

func z(t: float) -> float:
	return t-L*0.5

func half(y: float) -> float:
	if y <= belt: return W*0.5
	return lerpf(W*0.5-0.03,W*0.5*float(v.tuck),(y-belt)/(roof-belt))

func hood_y(t: float) -> float:
	return belt if t >= cowl else lerpf(nose,belt,t/cowl)

func deck_y(t: float) -> float:
	if v.step and t >= foot: return tail
	return belt if t <= foot else lerpf(belt,tail,(t-foot)/(L-foot))

func axles() -> Array:
	return [v.ax_f,v.ax_r]+Array(v.axles)

## Tall tyres on a low body keep a thin strip of metal over the wheel instead of cutting through the bonnet.
func arch_radius(t := -1.0) -> float:
	if t < 0: return r*1.2
	return clampf(minf(hood_y(t),deck_y(t))-r-0.05,r*1.03,r*1.2)

func _assemble() -> void:
	_body()
	_glazing()
	_flanks()
	_bonnet()
	_nose()
	_tail()
	for t: float in axles(): _wheels(t)
	_cargo()
	for fitting: String in v.fit: _fit(fitting)
	_wear()

func _body() -> void:
	var taper := 0.14
	var c := taper
	var pts := PackedVector2Array([Vector2(c,ride),Vector2(L-c,ride)])
	var tail_top := deck_y(L-c)
	pts.append(Vector2(L-c,tail_top))
	if v.step:
		pts.append(Vector2(foot,tail))
		pts.append(Vector2(foot,belt))
	elif foot < L-c:
		pts.append(Vector2(foot,belt))
	if cowl > c:
		pts.append(Vector2(cowl,belt))
	var nose_top := hood_y(c)
	pts.append(Vector2(c,nose_top))
	lower = PackedVector2Array()
	for p in pts: lower.append(Vector2(z(p.x),p.y))
	var list := axles()
	for t: float in list:
		var hole := PackedVector2Array()
		for i in 16:
			hole.append(Vector2(z(t)+cos(TAU*i/16.0)*arch_radius(t),r+sin(TAU*i/16.0)*arch_radius(t)))
		lower = _largest(Geometry2D.clip_polygons(lower,hole))
	var bottom: Color = Color(v.paint2) if v.fit.has("two_tone") else paint
	f.prism(lower,func(_y: float) -> float: return W*0.5,paint)
	f.frustum(z(c),Vector3(W*0.5,ride,nose_top),z(0),Vector3(hw,ride+0.05,nose),paint)
	f.frustum(z(L-c),Vector3(W*0.5,ride,tail_top),z(L),Vector3(hw,ride+0.05,deck_y(L)),paint)
	# Underside, so nothing shows through the wheel arches.
	var inner := W-float(v.tw)*2-0.12
	var fill_top := minf(minf(nose,tail),belt)-0.06
	f.block(Vector3(0,(ride+fill_top)*0.5,z(L*0.5)),Vector3(inner,fill_top-ride,L-0.3),SHADOW)
	for t: float in list:
		var ra := arch_radius(t)
		var a0 := asin(clampf((ride-r)/ra,-1,1))
		for side: float in [-1,1]:
			f.liner(z(t),r,ra-0.004,side*W*0.5,side*inner*0.5,PI-a0,a0,SHADOW)
			var lip_color: Color = Color(v.flare) if v.has("flare") else paint.darkened(0.2)
			f.lip(z(t),r,ra-0.01,ra+(0.1 if v.has("flare") else 0.035),side*W*0.5,PI-a0,a0,lip_color,0.07 if v.has("flare") else 0.012)
	if bottom != paint:
		_side(0,L,ride,ride+(belt-ride)*0.46,bottom,lower,0.004)
	# Cabin.
	var crown := roof+float(v.crown)
	var mid := (peak+back)*0.5
	cabin = PackedVector2Array([Vector2(z(cowl),belt-0.01),Vector2(z(peak),roof),Vector2(z(mid),crown),Vector2(z(back),roof),Vector2(z(foot),belt-0.01)])
	f.prism(cabin,half,Color(v.roof_paint) if v.has("roof_paint") else paint)

static func _largest(pieces: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var size := 0.0
	for piece in pieces:
		var area := 0.0
		for i in piece.size():
			area += piece[i].cross(piece[(i+1)%piece.size()])
		if absf(area) > size:
			size = absf(area)
			best = piece
	return best

func _glazing() -> void:
	var inset: float = v.pillar_width
	var shrunk := Geometry2D.offset_polygon(cabin,-inset,Geometry2D.JOIN_MITER)
	if shrunk.is_empty(): return
	var limit := PackedVector2Array([Vector2(z(-1),belt+0.07),Vector2(z(minf(v.glass_to,L+1)),belt+0.07),Vector2(z(minf(v.glass_to,L+1)),roof+1),Vector2(z(-1),roof+1)])
	var band := Geometry2D.intersect_polygons(shrunk[0],limit)
	var pillar: Color = Color(v.pillar) if v.has("pillar") else TRIM
	for piece: PackedVector2Array in band:
		for side: float in [-1,1]:
			f.pane(piece,side,half,0.012,GLASS,Forge.GLASS)
			for t: float in v.pillars:
				var post := PackedVector2Array([Vector2(z(t)-0.045,belt),Vector2(z(t)+0.045,belt),Vector2(z(t)+0.045,roof+1),Vector2(z(t)-0.045,roof+1)])
				for bit: PackedVector2Array in Geometry2D.intersect_polygons(post,piece):
					f.pane(bit,side,half,0.02,pillar)
			# Black window surround.
			var frame := Geometry2D.offset_polygon(piece,0.03,Geometry2D.JOIN_MITER)
			if not frame.is_empty():
				for bit: PackedVector2Array in Geometry2D.clip_polygons(frame[0],piece):
					f.pane(bit,side,half,0.008,TRIM)
	_screen(cowl+0.03,belt+0.05,peak-0.02,roof-0.05,-1)
	if v.rear_glass: _screen(foot-0.03,belt+0.07,back+0.02,roof-0.06,1)
	# Scuttle and wipers.
	var base := z(cowl)+0.05
	f.block(Vector3(0,belt+0.02,base),Vector3(half(belt+0.02)*1.9,0.05,0.16),TRIM)
	for x: float in [-0.42,0.14]:
		f.beam(Vector3(x,belt+0.075,base+0.02),Vector3(x+0.42,belt+0.11,base+0.11),0.02,SHADOW)

func _screen(t0: float, y0: float, t1: float, y1: float, facing: float) -> void:
	var a := Vector3(0,y0,z(t0))
	var b := Vector3(0,y1,z(t1))
	var n := (b-a).cross(Vector3.RIGHT).normalized()
	if n.z*facing < 0: n = -n
	var lift := n*0.016
	var w0 := half(y0)-0.1
	var w1 := half(y1)-0.1
	f.quad(a+Vector3(-w0,0,0)+lift*0.5-(b-a).normalized()*0.04,a+Vector3(w0,0,0)+lift*0.5-(b-a).normalized()*0.04,b+Vector3(w1,0,0)+lift*0.5+(b-a).normalized()*0.04,b+Vector3(-w1,0,0)+lift*0.5+(b-a).normalized()*0.04,n,TRIM)
	f.quad(a+Vector3(-w0+0.04,0,0)+lift,a+Vector3(w0-0.04,0,0)+lift,b+Vector3(w1-0.04,0,0)+lift,b+Vector3(-w1+0.04,0,0)+lift,n,GLASS,Forge.GLASS)
	var g := lift*1.3
	f.quad(a.lerp(b,0.1)+Vector3(-w0*0.55,0,0)+g,a.lerp(b,0.1)+Vector3(-w0*0.25,0,0)+g,a.lerp(b,0.86)+Vector3(w1*0.1,0,0)+g,a.lerp(b,0.86)+Vector3(-w1*0.2,0,0)+g,n,GLARE,Forge.GLASS)

## A panel on both flanks over t0..t1, clipped to the body so it follows arches and shoulders.
func _side(t0: float, t1: float, y0: float, y1: float, color: Color, clip := lower, lift := 0.006, layer := Forge.PAINT) -> void:
	var rect := PackedVector2Array([Vector2(z(t0),y0),Vector2(z(t1),y0),Vector2(z(t1),y1),Vector2(z(t0),y1)])
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(rect,clip):
		for side: float in [-1,1]:
			f.pane(piece,side,half,lift,color,layer)

func _flanks() -> void:
	var seams: Array = v.doors if not v.doors.is_empty() else [cowl+0.06]+Array(v.pillars)+[minf(back-0.1,axles()[1]-arch_radius()-0.05)]
	var top := belt-0.03
	for t: float in seams:
		_side(t-0.009,t+0.009,ride+0.06,top,paint.darkened(0.55))
		if v.handles: _handle(t+0.09,belt-0.14)
	_side(cowl+0.06,seams[-1],top-0.012,top+0.004,paint.darkened(0.55))
	_side(0,L,ride,ride+0.07,TRIM,lower,0.01)
	if v.rub != "none":
		var y := ride+(belt-ride)*0.5
		var color: Color = STEEL if v.rub == "chrome" else TRIM
		_side(0.2,L-0.2,y-0.03,y+0.03,color,lower,0.016,Forge.CHROME if v.rub == "chrome" else Forge.PAINT)
	# Mirrors on stalks.
	for side: float in [-1,1]:
		var at := Vector3(side*(W*0.5+0.13),belt+0.12,z(minf(peak,cowl+0.42)))
		f.beam(Vector3(side*W*0.47,belt+0.05,at.z+0.04),at,0.03,TRIM)
		f.block(at,Vector3(0.17,0.13 if W < 2.2 else 0.34,0.09),TRIM)

func _handle(t: float, y: float) -> void:
	for side: float in [-1,1]:
		f.block(Vector3(side*(W*0.5+0.012),y,z(t)),Vector3(0.03,0.035,0.15),TRIM)

## Panel on the sloping bonnet, x centred, between t0 and t1.
func _hood_panel(x: float, wide: float, t0: float, t1: float, lift: float, color: Color, layer := Forge.PAINT) -> void:
	var a := Vector3(x-wide*0.5,hood_y(t0)+lift,z(t0))
	var b := Vector3(x+wide*0.5,hood_y(t0)+lift,z(t0))
	var c := Vector3(x+wide*0.5,hood_y(t1)+lift,z(t1))
	var d := Vector3(x-wide*0.5,hood_y(t1)+lift,z(t1))
	f.quad(a,b,c,d,Vector3.UP,color,layer)

func _bonnet() -> void:
	if cowl < 0.8: return
	for x: float in [-1,1]:
		_hood_panel(x*(W*0.5-0.24),0.018,0.16,cowl-0.05,0.004,paint.darkened(0.45))
	_hood_panel(0,W-0.46,0.17,0.19,0.004,paint.darkened(0.45))

## A block on the nose. Centre x, height y.
func _front(x: float, y: float, sx: float, sy: float, color: Color, depth := 0.05, layer := Forge.PAINT) -> void:
	f.block(Vector3(x,y,z(0)-depth*0.5+0.01),Vector3(sx,sy,depth),color,layer)

func _back_block(x: float, y: float, sx: float, sy: float, color: Color, depth := 0.05, layer := Forge.PAINT) -> void:
	f.block(Vector3(x,y,z(L)+depth*0.5-0.01),Vector3(sx,sy,depth),color,layer)

func _nose() -> void:
	var top := nose-0.04
	var bumper_top := ride+0.26
	var lamp: String = v.lamp
	var lx := hw-0.27
	var ly := lerpf(bumper_top,top,0.62)
	var round_lamp := func(x: float, y: float, radius: float) -> void:
		f.tube(Vector3(x,y,z(0)+0.02),Vector3(x,y,z(0)-0.03),radius+0.03,radius+0.03,STEEL,Forge.CHROME,12)
		f.tube(Vector3(x,y,z(0)-0.02),Vector3(x,y,z(0)-0.05),radius,radius*0.92,HEADLAMP,Forge.GLASS,12)
	var grille_w: float = v.grille_w*hw
	var grille_h := minf((top-bumper_top)*0.74,0.62)
	var gy := bumper_top+(top-bumper_top)*0.52
	match String(v.front):
		"slats":
			_front(0,gy,grille_w*2,grille_h,SHADOW,0.03)
			for i in 5:
				_front(0,gy-grille_h*0.4+i*grille_h*0.2,grille_w*2,0.022,STEEL,0.05)
		"mesh":
			_front(0,gy,grille_w*2,grille_h,SHADOW,0.03)
			for i in 9:
				_front(-grille_w+i*grille_w*0.25,gy,0.016,grille_h,TRIM.lightened(0.15),0.04)
			for i in 5:
				_front(0,gy-grille_h*0.4+i*grille_h*0.2,grille_w*2,0.016,TRIM.lightened(0.15),0.04)
		"bars":
			_front(0,gy,grille_w*2,grille_h,SHADOW,0.03)
			for i in 7:
				_front(-grille_w+(i+0.5)*grille_w*2/7,gy,0.05,grille_h,paint.darkened(0.12),0.05)
		"split":
			for side: float in [-1,1]:
				_front(side*grille_w*0.54,gy,grille_w*0.84,grille_h,SHADOW,0.03)
				_front(side*grille_w*0.54,gy,grille_w*0.78,0.02,STEEL,0.05)
			_front(0,gy,grille_w*0.2,grille_h+0.04,paint.darkened(0.2),0.05)
		"chrome":
			_front(0,gy,grille_w*2+0.08,grille_h+0.08,STEEL,0.04,Forge.CHROME)
			_front(0,gy,grille_w*2,grille_h,SHADOW,0.05)
			for i in 11:
				_front(-grille_w+(i+0.5)*grille_w*2/11,gy,0.024,grille_h,STEEL,0.06,Forge.CHROME)
		"slot":
			_front(0,top-0.09,grille_w*2,0.07,SHADOW,0.03)
			_front(0,bumper_top+0.1,grille_w*1.5,0.12,SHADOW,0.03)
		"flat":
			pass
	match lamp:
		"rect":
			for side: float in [-1,1]:
				_front(side*lx,ly,0.42,0.18,TRIM,0.03)
				_front(side*lx,ly,0.37,0.14,HEADLAMP,0.05,Forge.GLASS)
				_front(side*(lx+0.27),ly,0.09,0.14,AMBER,0.04,Forge.GLASS)
		"slim":
			for side: float in [-1,1]:
				_front(side*lx,top-0.05,0.54,0.08,TRIM,0.03)
				_front(side*lx,top-0.05,0.48,0.05,HEADLAMP,0.05,Forge.GLASS)
		"round":
			for side: float in [-1,1]:
				round_lamp.call(side*lx,ly,0.135)
				_front(side*(lx-0.26),ly-0.14,0.09,0.06,AMBER,0.04,Forge.GLASS)
		"quad":
			for side: float in [-1,1]:
				round_lamp.call(side*(lx+0.15),ly,0.095)
				round_lamp.call(side*(lx-0.1),ly,0.095)
		"square":
			for side: float in [-1,1]:
				_front(side*lx,ly,0.3,0.3,TRIM,0.03)
				_front(side*lx,ly,0.25,0.25,HEADLAMP,0.05,Forge.GLASS)
				_front(side*lx,ly-0.21,0.25,0.08,AMBER,0.04,Forge.GLASS)
		"hooded":
			for side: float in [-1,1]:
				round_lamp.call(side*lx,ly,0.11)
				_front(side*lx,ly+0.15,0.32,0.05,paint.darkened(0.2),0.14)
	_plate_front(bumper_top)
	_bumper(true)

func _plate_front(y: float) -> void:
	if W < 2.2: _front(0,y-0.14,0.34,0.09,PLATE,0.09)

func _bumper(front: bool) -> void:
	var style: String = v.bumper
	var place := func(x: float, y: float, sx: float, sy: float, color: Color, depth := 0.16, layer := Forge.PAINT) -> void:
		if front: _front(x,y,sx,sy,color,depth,layer)
		else: _back_block(x,y,sx,sy,color,depth,layer)
	var y := ride+0.11
	match style:
		"black":
			place.call(0,y,hw*2+0.02,0.2,TRIM,0.12)
			place.call(0,y-0.05,hw*2-0.2,0.08,TRIM.lightened(0.04),0.16)
		"body":
			place.call(0,y,hw*2+0.02,0.2,paint.darkened(0.12),0.12)
			place.call(0,y-0.06,hw*2-0.2,0.07,TRIM,0.15)
		"chrome":
			place.call(0,y,W-0.02,0.13,STEEL,0.13,Forge.CHROME)
			for x: float in [-0.5,0.5]: place.call(x,y,0.09,0.25,STEEL,0.19,Forge.CHROME)
		"steel":
			place.call(0,y+0.02,W+0.04,0.25,TRIM.lightened(0.08),0.2)
			for x: float in [-1,1]: place.call(x*(W*0.5-0.18),y+0.17,0.09,0.12,TRIM.lightened(0.08),0.1)
		"none":
			place.call(0,y,W-0.24,0.1,SHADOW,0.08)

func _tail() -> void:
	var top := deck_y(L)-0.05
	var bumper_top := ride+0.25
	var lamp: String = v.tail_lamp
	var ly := lerpf(bumper_top,top,0.66)
	var lx := hw-0.2
	match lamp:
		"rect":
			for side: float in [-1,1]:
				_back_block(side*lx,ly,0.46,0.17,TAILLAMP,0.04,Forge.GLASS)
				_back_block(side*(lx-0.3),ly,0.14,0.17,AMBER,0.03,Forge.GLASS)
		"tall":
			for side: float in [-1,1]:
				_back_block(side*(hw-0.06),lerpf(bumper_top,top,0.55),0.13,minf(top-bumper_top,0.62)*0.86,TAILLAMP,0.04,Forge.GLASS)
		"round":
			for side: float in [-1,1]:
				for x: float in [0.0,-0.27]:
					var at := Vector3(side*(lx+x),ly,z(L))
					f.tube(at-Vector3(0,0,0.01),at+Vector3(0,0,0.04),0.105,0.1,TAILLAMP,Forge.GLASS,10)
		"bar":
			_back_block(0,ly,hw*2-0.1,0.09,TAILLAMP,0.04,Forge.GLASS)
		"small":
			for side: float in [-1,1]:
				_back_block(side*lx,bumper_top+0.1,0.2,0.1,TAILLAMP,0.04,Forge.GLASS)
	if W < 2.2:
		_back_block(0,bumper_top+0.14,0.42,0.1,PLATE,0.03)
	if foot > L-0.6 and belt == tail and not v.fit.has("bed"):
		_back_block(0,(top+bumper_top)*0.5,0.018,top-bumper_top,paint.darkened(0.5),0.03)
	_bumper(false)
	if v.exhaust:
		f.tube(Vector3(0.45,ride+0.03,z(L)-0.2),Vector3(0.45,ride+0.03,z(L)+0.12),0.04,0.04,STEEL,Forge.CHROME,8)

func _wheels(t: float) -> void:
	var tw: float = v.tw
	var pairs: int = 2 if v.dual and t != v.ax_f else 1
	for side: float in [-1,1]:
		for k in pairs:
			var outer := W*0.5+float(v.get("track",0.015))-k*(tw+0.03)
			var inner := outer-tw
			var at := Vector3(0,r,z(t))
			var o := Vector3(side*outer,0,0)
			var i := Vector3(side*inner,0,0)
			f.tube(at+i,at+o-Vector3(side*0.035,0,0),r,r,TYRE,Forge.PAINT,16,false)
			f.tube(at+o-Vector3(side*0.035,0,0),at+o,r,r*0.9,TYRE,Forge.PAINT,16)
			if k == 0: _rim(at+o,side)

func _rim(at: Vector3, side: float) -> void:
	var out := Vector3(side,0,0)
	var style: String = v.rim
	var color: Color = Color(v.rim_paint) if v.has("rim_paint") else STEEL
	var layer := Forge.CHROME if not v.has("rim_paint") else Forge.PAINT
	var size := r*0.62
	f.tube(at,at+out*0.008,size*1.08,size*1.04,TRIM,Forge.PAINT,12)
	match style:
		"steel":
			f.tube(at+out*0.008,at+out*0.018,size,size*0.92,color,layer,12)
			f.tube(at+out*0.018,at+out*0.024,size*0.5,size*0.42,TRIM,Forge.PAINT,8)
			for i in 6:
				var a := TAU*i/6.0
				f.tube(at+out*0.018+Vector3(0,sin(a),cos(a))*size*0.7,at+out*0.024+Vector3(0,sin(a),cos(a))*size*0.7,size*0.1,size*0.1,SHADOW,Forge.PAINT,6)
		"star":
			f.tube(at+out*0.008,at+out*0.012,size,size,SHADOW,Forge.PAINT,12)
			for i in 5:
				var a := TAU*i/5.0
				f.beam(at+out*0.022,at+out*0.022+Vector3(0,sin(a),cos(a))*size,size*0.26,color,layer)
			f.tube(at+out*0.012,at+out*0.04,size*0.24,size*0.2,color,layer,8)
		"deep":
			f.tube(at+out*0.008,at+out*0.014,size,size,color,layer,12)
			f.tube(at+out*0.014,at+out*0.018,size*0.82,size*0.82,SHADOW,Forge.PAINT,12)
			f.tube(at+out*0.018,at+out*0.05,size*0.42,size*0.3,color,layer,8)
		"truck":
			f.tube(at+out*0.008,at+out*0.014,size,size*0.95,color,layer,10)
			f.tube(at+out*0.014,at+out*0.06,size*0.45,size*0.36,color.darkened(0.2),Forge.PAINT,8)
			for i in 8:
				var a := TAU*i/8.0
				f.tube(at+out*0.014+Vector3(0,sin(a),cos(a))*size*0.7,at+out*0.034+Vector3(0,sin(a),cos(a))*size*0.7,0.024,0.02,SHADOW,Forge.PAINT,6)

func _cargo() -> void:
	if v.has("box"):
		var box: Dictionary = v.box
		var a: float = box.a
		var b: float = box.b
		var top: float = box.top
		var bottom := tail-0.02
		var color: Color = box.get("color",Color(0.82,0.80,0.74))
		f.block(Vector3(0,(top+bottom)*0.5,z((a+b)*0.5)),Vector3(W,top-bottom,b-a),color)
		var ribs: int = box.get("ribs",8)
		for i in ribs+1:
			var t := lerpf(a+0.04,b-0.04,float(i)/ribs)
			for side: float in [-1,1]:
				f.block(Vector3(side*(W*0.5+0.01),(top+bottom)*0.5,z(t)),Vector3(0.03,top-bottom-0.06,0.05),color.darkened(0.18))
		f.block(Vector3(0,top+0.015,z((a+b)*0.5)),Vector3(W+0.04,0.04,b-a+0.04),color.darkened(0.25))
		f.block(Vector3(0,bottom+0.03,z((a+b)*0.5)),Vector3(W+0.05,0.07,b-a+0.04),color.darkened(0.35))
		if b > L-0.5:
			f.block(Vector3(0,(top+bottom)*0.5,z(b)+0.01),Vector3(W-0.16,top-bottom-0.16,0.04),color.darkened(0.08))
			if box.get("shutter",false):
				var n := 9
				for i in n:
					f.block(Vector3(0,lerpf(bottom+0.14,top-0.14,float(i)/(n-1)),z(b)+0.035),Vector3(W-0.2,0.03,0.02),color.darkened(0.3))
			else:
				f.block(Vector3(0,(top+bottom)*0.5,z(b)+0.035),Vector3(0.03,top-bottom-0.2,0.02),color.darkened(0.45))
				for x: float in [-0.25,0.25]:
					f.block(Vector3(x,(top+bottom)*0.5,z(b)+0.045),Vector3(0.05,top-bottom-0.24,0.03),STEEL)

## Everything that bolts on. Keeping these as named parts lets a variant change silhouette in one word.
func _fit(fitting: String) -> void:
	var paint2: Color = v.get("paint2",Color(0.9,0.87,0.78))
	var mid := (peak+back)*0.5
	var top := roof+float(v.crown)
	match fitting:
		"bed":
			var y := tail
			var a := foot+0.08
			var b := L-0.1
			f.block(Vector3(0,y+0.002,z((a+b)*0.5)),Vector3(W-0.18,0.02,b-a),SHADOW)
			for side: float in [-1,1]:
				f.block(Vector3(side*(W*0.5-0.045),y+0.035,z((a+b)*0.5)),Vector3(0.09,0.07,b-a+0.08),TRIM)
			f.block(Vector3(0,y+0.035,z(a)),Vector3(W,0.07,0.09),TRIM)
			f.block(Vector3(0,y+0.035,z(b)),Vector3(W,0.07,0.09),TRIM)
			_side(foot+0.1,L-0.06,y-0.05,y-0.035,paint.darkened(0.5))
		"canopy":
			var a := foot+0.04
			var b := L-0.08
			var profile := PackedVector2Array([Vector2(z(a),tail+0.04),Vector2(z(a),roof-0.02),Vector2(z(b)-0.12,roof-0.1),Vector2(z(b),tail+0.04)])
			f.prism(profile,func(y: float) -> float: return lerpf(W*0.5-0.03,W*0.42,(y-tail)/(roof-tail)),Color(v.get("canopy_paint",paint.darkened(0.08))))
			for side: float in [-1,1]:
				f.pane(PackedVector2Array([Vector2(z(a+0.2),tail+0.2),Vector2(z(b-0.3),tail+0.2),Vector2(z(b-0.3),roof-0.2),Vector2(z(a+0.2),roof-0.2)]),side,func(y: float) -> float: return lerpf(W*0.5-0.03,W*0.42,(y-tail)/(roof-tail)),0.012,GLASS,Forge.GLASS)
		"tarp":
			var a := foot+0.08
			var b := L-0.12
			var hoop := tail+0.72
			for i in 5:
				var t := lerpf(a,b,i/4.0)
				f.block(Vector3(0,hoop+0.015,z(t)),Vector3(W-0.06,0.05,0.05),CANVAS.darkened(0.3))
			f.block(Vector3(0,(tail+hoop)*0.5,z((a+b)*0.5)),Vector3(W-0.12,hoop-tail,b-a),CANVAS)
			f.block(Vector3(0,hoop-0.02,z((a+b)*0.5)),Vector3(W-0.08,0.05,b-a+0.03),CANVAS.darkened(0.12))
		"load":
			for k in 6:
				var c := Color(0.58,0.42,0.22).darkened(rng.randf()*0.25)
				f.block(Vector3(rng.randf_range(-0.35,0.35),tail+0.2+(k%2)*0.3,z(rng.randf_range(foot+0.45,L-0.5))),Vector3(0.48,0.3,0.5),c,Forge.PAINT,Basis(Vector3.UP,rng.randf_range(-0.3,0.3)))
		"rack":
			var a := peak+0.2
			var b := back-0.02
			for side: float in [-1,1]:
				f.block(Vector3(side*(half(roof)-0.09),top+0.13,z((a+b)*0.5)),Vector3(0.05,0.05,b-a),TRIM)
				for t: float in [a+0.08,b-0.08]:
					f.block(Vector3(side*(half(roof)-0.09),top+0.05,z(t)),Vector3(0.05,0.13,0.05),TRIM)
			var n := int((b-a)/0.3)
			for i in n+1:
				f.block(Vector3(0,top+0.13,z(lerpf(a,b,float(i)/n))),Vector3(half(roof)*2-0.18,0.03,0.04),TRIM)
		"rails":
			for side: float in [-1,1]:
				f.block(Vector3(side*(half(roof)-0.08),top+0.06,z(mid)),Vector3(0.05,0.04,back-peak-0.2),STEEL,Forge.CHROME)
		"luggage":
			f.block(Vector3(-0.2,top+0.3,z(mid-0.25)),Vector3(0.6,0.28,0.8),CANVAS)
			f.block(Vector3(0.28,top+0.26,z(mid+0.35)),Vector3(0.5,0.22,0.7),Color(0.32,0.2,0.12))
			f.block(Vector3(0.2,top+0.27,z(mid-0.4)),Vector3(0.36,0.24,0.42),Color(0.25,0.33,0.35))
		"bull":
			var y0 := ride+0.08
			var y1 := nose+0.1
			var front := z(0)-0.2
			for x: float in [-0.5,0.5]:
				f.tube(Vector3(x,y0,front),Vector3(x,y1,front),0.04,0.04,TRIM,Forge.PAINT,8)
			f.tube(Vector3(-W*0.5+0.1,ride+0.25,front),Vector3(W*0.5-0.1,ride+0.25,front),0.04,0.04,TRIM,Forge.PAINT,8)
			f.tube(Vector3(-0.5,y1,front),Vector3(0.5,y1,front),0.04,0.04,TRIM,Forge.PAINT,8)
		"plough":
			var y0 := 0.14
			var y1 := nose+0.08
			for side: float in [-1,1]:
				f.quad(Vector3(0,y0,z(0)-0.62),Vector3(side*(W*0.5+0.16),y0,z(0)-0.22),Vector3(side*(W*0.5+0.16),y1,z(0)-0.14),Vector3(0,y1,z(0)-0.5),Vector3(side*0.4,0.2,-1),Color(0.63,0.5,0.14))
				f.quad(Vector3(0,y0,z(0)-0.60),Vector3(side*(W*0.5+0.16),y0,z(0)-0.20),Vector3(side*(W*0.5+0.16),y1,z(0)-0.12),Vector3(0,y1,z(0)-0.48),Vector3(0,0,1),TRIM)
				for i in 3:
					var k := (i+0.5)/3.0
					f.beam(Vector3(side*(W*0.5+0.16)*k,y0+0.03,z(0)-0.63+k*0.41),Vector3(side*(W*0.5+0.16)*k,y1,z(0)-0.51+k*0.37),0.03,Color(0.1,0.1,0.1))
		"ram":
			for i in 5:
				var x := -W*0.5+0.12+i*(W-0.24)/4
				f.tube(Vector3(x,ride+0.2,z(0)-0.05),Vector3(x,ride+0.2,z(0)-0.62),0.05,0.012,STEEL,Forge.PAINT,6)
			f.block(Vector3(0,ride+0.2,z(0)-0.08),Vector3(W+0.05,0.26,0.12),TRIM)
		"lightbar":
			f.block(Vector3(0,top+0.05,z(peak+0.35)),Vector3(W*0.42,0.07,0.12),TRIM)
			for side: float in [-1,1]:
				f.block(Vector3(side*W*0.13,top+0.13,z(peak+0.35)),Vector3(W*0.2,0.1,0.18),Color(v.get("beacon",Color(0.15,0.3,0.95))),Forge.GLASS)
			f.block(Vector3(0,top+0.13,z(peak+0.35)),Vector3(W*0.06,0.08,0.16),TRIM)
		"redbar":
			f.block(Vector3(0,top+0.05,z(peak+0.35)),Vector3(W*0.5,0.07,0.12),TRIM)
			f.block(Vector3(0,top+0.13,z(peak+0.35)),Vector3(W*0.48,0.1,0.18),Color(0.92,0.13,0.08),Forge.GLASS)
		"beacon":
			f.tube(Vector3(0,top,z(peak+0.3)),Vector3(0,top+0.2,z(peak+0.3)),0.1,0.08,AMBER,Forge.GLASS,8)
		"taxi":
			f.block(Vector3(0,top+0.1,z(mid)),Vector3(0.62,0.18,0.14),Color(0.98,0.82,0.2),Forge.PAINT)
			f.block(Vector3(0,top+0.1,z(mid)-0.08),Vector3(0.46,0.09,0.02),SHADOW)
		"spare":
			var at := Vector3(0,lerpf(ride,tail,0.6)+0.05,z(L)+0.06)
			f.tube(at,at+Vector3(0,0,0.24),r*0.92,r*0.92,TYRE,Forge.PAINT,14)
			f.tube(at+Vector3(0,0,0.24),at+Vector3(0,0,0.27),r*0.56,r*0.5,STEEL,Forge.PAINT,10)
		"roof_spare":
			var at := Vector3(0,top+0.2,z(mid+0.3))
			f.tube(at-Vector3(0,0.1,0),at+Vector3(0,0.1,0),r*0.92,r*0.92,TYRE,Forge.PAINT,14)
		"snorkel":
			var x := W*0.5+0.04
			var t := cowl+0.1
			f.tube(Vector3(x,belt-0.1,z(t)),Vector3(x,roof+0.1,z(t+0.05)),0.05,0.05,TRIM,Forge.PAINT,8)
			f.block(Vector3(x,roof+0.16,z(t+0.02)),Vector3(0.13,0.13,0.2),TRIM)
		"ladder":
			var x := W*0.25
			for k: float in [-0.22,0.22]:
				f.block(Vector3(x+k,(ride+0.3+top)*0.5,z(L)+0.06),Vector3(0.03,top-ride-0.3,0.03),STEEL,Forge.CHROME)
			for i in 7:
				f.block(Vector3(x,lerpf(ride+0.4,top-0.1,i/6.0),z(L)+0.06),Vector3(0.44,0.025,0.03),STEEL,Forge.CHROME)
		"jerry":
			for x: float in [-0.56,-0.26]:
				f.block(Vector3(x,tail-0.25,z(L)+0.1),Vector3(0.26,0.42,0.14),Color(0.22,0.33,0.2))
		"mesh":
			var a := cowl+0.05
			var b := peak-0.02
			for i in 8:
				var x := lerpf(-W*0.42,W*0.42,i/7.0)
				f.beam(Vector3(x,belt+0.06,z(a)-0.02),Vector3(x*0.92,roof-0.03,z(b)-0.02),0.02,TRIM)
			for i in 4:
				var k := (i+0.5)/4.0
				var y := lerpf(belt+0.06,roof-0.03,k)
				var at := lerpf(a,b,k)
				f.block(Vector3(0,y,z(at)-0.03),Vector3(W*0.86,0.02,0.02),TRIM)
		"cage":
			for t: float in v.get("cage_at",[cowl+0.5,peak+0.5,mid,back-0.3]):
				for side: float in [-1,1]:
					_side(t-0.012,t+0.012,belt+0.03,roof,STEEL,cabin,0.03)
			for k in 3:
				var y := lerpf(belt+0.18,roof-0.08,k/2.0)
				_side(peak-0.1,back+0.2,y-0.012,y+0.012,STEEL,cabin,0.032)
		"boards":
			for k in 4:
				var y := lerpf(belt+0.14,roof-0.08,k/3.0)
				var tilt := rng.randf_range(-9.0,9.0)
				for side: float in [-1,1]:
					var c := WOOD.darkened(rng.randf()*0.25)
					f.block(Vector3(side*(half(y)+0.03),y,z(rng.randf_range(peak+0.35,back-0.4))),Vector3(0.03,0.13,1.1),c,Forge.PAINT,Basis(Vector3.RIGHT,deg_to_rad(tilt)))
				var c2 := WOOD.darkened(rng.randf()*0.2)
				f.block(Vector3(0,y,z(lerpf(cowl,peak,inverse_lerp(belt,roof,y)))-0.04),Vector3(W*0.82,0.11,0.03),c2,Forge.PAINT,Basis(Vector3.FORWARD,deg_to_rad(tilt*0.7)))
		"windscreen_slit":
			var y0 := belt+0.05
			var y1 := roof-0.28
			var a := Vector3(0,y0,z(cowl+0.03)-0.05)
			var b := Vector3(0,y1,z(lerpf(cowl,peak,inverse_lerp(belt,roof,y1))+0.03)-0.05)
			f.quad(a+Vector3(-W*0.46,0,0),a+Vector3(W*0.46,0,0),b+Vector3(W*0.42,0,0),b+Vector3(-W*0.42,0,0),Vector3(0,0.5,-1),Color(v.get("plate_paint",Color(0.32,0.34,0.33))))
		"plates":
			var color: Color = v.get("plate_paint",Color(0.32,0.34,0.33))
			var n := int(L/0.85)
			for i in n:
				var t0 := lerpf(0.1,L-0.1,float(i)/n)
				var t1 := lerpf(0.1,L-0.1,float(i+1)/n)-0.03
				var shade := color.darkened(rng.randf()*0.22)
				if rng.randf() < 0.2: shade = shade.lerp(RUST,0.55)
				_side(t0,t1,ride+0.07,belt-0.04,shade,lower,0.022)
				for k: float in [0.1,0.42]:
					_side(t0+0.06,t0+0.1,lerpf(ride,belt,k+0.2),lerpf(ride,belt,k+0.2)+0.04,TRIM,lower,0.03)
		"spikes":
			for t: float in [0.5,1.1,1.7,L-1.6,L-1.0,L-0.4]:
				for side: float in [-1,1]:
					f.tube(Vector3(side*W*0.5,belt-0.14,z(t)),Vector3(side*(W*0.5+0.32),belt-0.1,z(t)),0.04,0.006,STEEL,Forge.PAINT,6)
		"sandbags":
			for k in 7:
				var side := -1.0 if k%2 else 1.0
				f.block(Vector3(side*(W*0.5-0.2),tail+0.17+(k%3)*0.16,z(lerpf(foot+0.3,L-0.3,(k%5)/4.0))),Vector3(0.34,0.17,0.62),Color(0.62,0.56,0.40).darkened(rng.randf()*0.15))
		"roll":
			var at := z(foot+0.5)
			for side: float in [-1,1]:
				f.tube(Vector3(side*W*0.42,tail,at),Vector3(side*W*0.38,roof+0.1,at),0.04,0.04,TRIM,Forge.PAINT,8)
			f.tube(Vector3(-W*0.38,roof+0.1,at),Vector3(W*0.38,roof+0.1,at),0.04,0.04,TRIM,Forge.PAINT,8)
			for x: float in [-0.4,-0.14,0.14,0.4]:
				f.block(Vector3(x,roof+0.1,at-0.02),Vector3(0.18,0.13,0.09),HEADLAMP,Forge.GLASS)
		"drums":
			for i in 4:
				var at := Vector3(-0.42+(i%2)*0.84,tail+0.02,z(foot+0.45+(i/2)*0.65))
				f.tube(at,at+Vector3(0,0.62,0),0.27,0.27,Color(0.17,0.34,0.5).darkened(rng.randf()*0.25),Forge.PAINT,12)
		"tank":
			var a := foot+0.25
			var b := L-0.18
			var y := tail+0.72
			var at := Vector3(0,y,z(a))
			var e := Vector3(0,y,z(b))
			f.tube(e,at,0.58,0.58,Color(v.get("tank_paint",STEEL)),Forge.PAINT,14)
			f.tube(at,e,0.58,0.58,Color(v.get("tank_paint",STEEL)),Forge.PAINT,14)
			for t: float in [0.2,0.5,0.8]:
				var x := lerpf(a,b,t)
				f.tube(Vector3(0,y,z(x)-0.03),Vector3(0,y,z(x)+0.03),0.6,0.6,TRIM,Forge.PAINT,14)
			f.tube(Vector3(0,y+0.58,z(a+0.8)),Vector3(0,y+0.7,z(a+0.8)),0.16,0.16,TRIM,Forge.PAINT,8)
		"tent":
			f.block(Vector3(0,top+0.14,z(mid)),Vector3(half(roof)*1.9,0.2,minf(back-peak-0.1,1.8)),Color(0.17,0.22,0.22))
			f.block(Vector3(0,top+0.255,z(mid)),Vector3(half(roof)*1.9-0.1,0.04,minf(back-peak-0.1,1.8)-0.1),Color(v.get("paint2",AMBER)))
		"poptop":
			var a := peak+0.3
			var b := back-0.3
			var profile := PackedVector2Array([Vector2(z(a),top),Vector2(z(a),top+0.14),Vector2(z(b),top+0.62),Vector2(z(b),top)])
			f.prism(profile,func(_y: float) -> float: return half(roof)-0.1,paint2)
		"hightop":
			var a := peak+0.15
			var b := back-0.1
			var profile := PackedVector2Array([Vector2(z(a),top-0.02),Vector2(z(a+0.3),top+0.42),Vector2(z(b),top+0.42),Vector2(z(b),top-0.02)])
			f.prism(profile,func(_y: float) -> float: return half(roof)-0.05,paint2)
		"awning":
			var a := peak+0.6
			var b := back-0.5
			f.block(Vector3(W*0.5-0.02,roof-0.1,z((a+b)*0.5)),Vector3(0.1,0.1,b-a),Color(0.82,0.8,0.74))
		"sunroof":
			f.block(Vector3(0,top+0.008,z(mid-0.1)),Vector3(half(roof)*1.1,0.015,0.8),GLASS,Forge.GLASS)
		"vinyl":
			f.prism(PackedVector2Array([Vector2(z(peak+0.1),roof+0.01),Vector2(z(mid),top+0.012),Vector2(z(back),roof+0.01),Vector2(z(foot-0.06),belt+0.2),Vector2(z(back+0.1),belt+0.2)]),func(y: float) -> float: return half(y)+0.008,TRIM)
		"scoop":
			var t := cowl*0.48
			f.block(Vector3(0,hood_y(t)+0.07,z(t)),Vector3(0.52,0.13,0.72),paint.darkened(0.08))
			f.block(Vector3(0,hood_y(t)+0.08,z(t-0.36)),Vector3(0.44,0.08,0.02),SHADOW)
		"blower":
			var t := cowl*0.55
			f.block(Vector3(0,hood_y(t)+0.09,z(t)),Vector3(0.36,0.18,0.54),STEEL,Forge.CHROME)
			f.block(Vector3(0,hood_y(t)+0.26,z(t)),Vector3(0.28,0.2,0.3),TRIM)
		"hood_vents":
			for side: float in [-1,1]:
				for i in 3:
					_hood_panel(side*0.34,0.34,cowl*0.45+i*0.1,cowl*0.45+i*0.1+0.05,0.006,SHADOW)
		"hood_stripe":
			_hood_panel(0,0.5,0.14,cowl,0.005,paint2)
		"rally":
			for x: float in [-0.48,-0.16,0.16,0.48]:
				var at := Vector3(x,top+0.13,z(peak+0.08))
				f.tube(at+Vector3(0,0,0.04),at-Vector3(0,0,0.04),0.095,0.095,TRIM,Forge.PAINT,10)
				f.tube(at-Vector3(0,0,0.04),at-Vector3(0,0,0.055),0.08,0.08,HEADLAMP,Forge.GLASS,10)
		"spoiler":
			var y := deck_y(L-0.2)
			for x: float in [-0.56,0.56]:
				f.block(Vector3(x,y+0.09,z(L-0.26)),Vector3(0.05,0.2,0.2),TRIM)
			f.block(Vector3(0,y+0.2,z(L-0.24)),Vector3(W-0.1,0.035,0.3),paint.darkened(0.2))
		"lip":
			f.block(Vector3(0,deck_y(L-0.1)+0.03,z(L-0.1)),Vector3(W-0.18,0.05,0.16),TRIM)
		"splitter":
			f.block(Vector3(0,ride+0.02,z(0)-0.05),Vector3(W-0.04,0.03,0.22),TRIM)
		"side_pipes":
			for side: float in [-1,1]:
				f.tube(Vector3(side*(W*0.5+0.05),ride+0.02,z(float(v.ax_f)+0.5)),Vector3(side*(W*0.5+0.05),ride+0.02,z(float(v.ax_r)-0.5)),0.05,0.05,STEEL,Forge.CHROME,8)
		"stripes":
			for x: float in [-0.2,0.2]:
				_hood_panel(x,0.24,0.14,cowl,0.005,paint2)
				f.block(Vector3(x,top+0.006,z(mid)),Vector3(0.24,0.01,back-peak-0.1),paint2)
				f.block(Vector3(x,deck_y(foot+0.3)+0.005,z((foot+L)*0.5)),Vector3(0.24,0.012,L-foot-0.2),paint2)
		"band":
			_side(0,L,belt-0.26,belt-0.1,paint2,lower,0.009)
		"low_band":
			_side(0,L,ride+0.07,ride+(belt-ride)*0.42,paint2,lower,0.008)
		"wood":
			_side(cowl+0.05,back+0.1,ride+0.1,belt-0.08,WOOD,lower,0.01)
			for y: float in [belt-0.09,ride+0.1]:
				_side(cowl+0.05,back+0.1,y-0.02,y+0.02,Color(0.8,0.67,0.42),lower,0.014)
		"checker":
			var n := int(L/0.5)
			var rows := 2
			var y0 := belt-0.48
			for i in n:
				for k in rows:
					if (i+k)%2 == 0:
						_side(i*0.5,(i+1)*0.5,y0+k*0.22,y0+(k+1)*0.22,paint2,lower,0.009)
		"cab_stripe":
			var y0 := belt+(roof-belt)*0.22
			_side(0,L,y0,y0+0.16,paint2,cabin,0.012)
		"chevrons":
			for i in 6:
				var x := -W*0.5+0.17+i*0.34
				var color := Color(0.98,0.75,0.08) if i%2 else Color(0.08,0.09,0.09)
				_back_block(clampf(x,-W*0.5,W*0.5),ride+0.34,0.34,0.3,color,0.06)
		"cross":
			var y := (ride+belt)*0.5+0.1
			for side: float in [-1,1]:
				f.block(Vector3(side*(W*0.5+0.012),y,z(L*0.62)),Vector3(0.02,0.46,0.15),Color(0.8,0.1,0.08))
				f.block(Vector3(side*(W*0.5+0.012),y,z(L*0.62)),Vector3(0.02,0.15,0.46),Color(0.8,0.1,0.08))
		"pump":
			var box_t: float = v.get("pump_t",cowl+2.4)
			_side(box_t,L-0.1,ride+0.12,belt-0.1,STEEL.darkened(0.25),lower,0.012)
			for i in int((L-0.3-box_t)/0.42):
				var t := box_t+0.12+i*0.42
				_side(t,t+0.3,ride+0.2,belt-0.18,paint.darkened(0.15),lower,0.018)
		"hose":
			var at := Vector3(0,roof+0.24,z(L*0.56))
			f.block(at,Vector3(0.22,0.12,L*0.6),STEEL)
			f.block(at+Vector3(0.33,0,0),Vector3(0.09,0.1,L*0.6),STEEL.darkened(0.2))
			for x: float in [-0.75,0.75]:
				f.block(Vector3(x,roof+0.14,z(L*0.56)),Vector3(0.06,0.3,L*0.55),TRIM)
		"ac":
			f.block(Vector3(0,top+0.1,z(L*0.5)),Vector3(W*0.6,0.2,1.6),Color(0.78,0.78,0.74))
			f.block(Vector3(0,top+0.21,z(L*0.5)),Vector3(W*0.5,0.03,1.4),TRIM)
		"destination":
			var y := roof-0.1
			f.block(Vector3(0,y,z(peak)-0.05),Vector3(W*0.6,0.2,0.05),SHADOW)
			f.block(Vector3(0,y,z(peak)-0.08),Vector3(W*0.5,0.09,0.02),AMBER,Forge.GLASS)
		"door_bus":
			_side(0.42,1.4,ride+0.1,roof-0.25,GLASS,lower,0.02,Forge.GLASS)
			_side(0.42,1.4,belt,roof-0.25,GLASS,cabin,0.024,Forge.GLASS)
			_side(0.9,0.93,ride+0.1,belt,TRIM,lower,0.024)
			_side(0.9,0.93,belt,roof-0.25,TRIM,cabin,0.03)
		"stop_arm":
			for side: float in [-1,1]:
				f.block(Vector3(side*(W*0.5+0.02),belt-0.1,z(1.6)),Vector3(0.03,0.3,0.3),Color(0.8,0.1,0.08))
		"exhaust_stack":
			var x := W*0.5-0.08
			var t: float = back+0.08
			f.tube(Vector3(x,tail,z(t)),Vector3(x,roof+0.5,z(t)),0.075,0.075,STEEL,Forge.CHROME,10)
		"visor":
			f.block(Vector3(0,roof+0.03,z(peak)-0.16),Vector3(W*0.8,0.05,0.38),paint.darkened(0.2),Forge.PAINT,Basis(Vector3.RIGHT,-0.2))
		"winch":
			f.block(Vector3(0,ride+0.24,z(0)-0.28),Vector3(0.58,0.2,0.24),TRIM.lightened(0.05))
			f.tube(Vector3(-0.24,ride+0.24,z(0)-0.3),Vector3(0.24,ride+0.24,z(0)-0.3),0.09,0.09,STEEL,Forge.PAINT,8)
		"steps":
			for side: float in [-1,1]:
				f.block(Vector3(side*(W*0.5+0.09),ride-0.04,z((float(v.ax_f)+float(v.ax_r))*0.5)),Vector3(0.22,0.05,float(v.ax_r)-float(v.ax_f)-arch_radius()*2.3),TRIM.lightened(0.05))
		"tow":
			f.block(Vector3(0,ride+0.02,z(L)+0.2),Vector3(0.08,0.08,0.3),TRIM)
			f.tube(Vector3(0,ride+0.08,z(L)+0.32),Vector3(0,ride+0.15,z(L)+0.32),0.05,0.05,STEEL,Forge.PAINT,8)
		"crane":
			var at := Vector3(0.0,tail,z(foot+0.32))
			f.block(at+Vector3(0,0.2,0),Vector3(0.5,0.4,0.5),AMBER.darkened(0.15))
			f.beam(at+Vector3(0,0.38,0),at+Vector3(0,1.4,1.7),0.15,AMBER.darkened(0.15))
			f.beam(at+Vector3(0,1.4,1.7),at+Vector3(0,0.65,1.85),0.025,TRIM)
			f.block(at+Vector3(0,0.6,1.85),Vector3(0.14,0.16,0.14),TRIM)

## Scuffs and rust, seeded by id so every peer sees the same dents.
func _wear() -> void:
	var level: int = v.wear
	if level == 0: return
	for k in level*7:
		var t := rng.randf_range(0.2,L-0.3)
		var y := rng.randf_range(ride+0.1,belt-0.08)
		var sx := rng.randf_range(0.1,0.42)
		var sy := rng.randf_range(0.05,0.2)
		var color := RUST.darkened(rng.randf()*0.3) if k%3 != 2 else paint.darkened(0.32)
		var patch := PackedVector2Array([Vector2(z(t),y),Vector2(z(t+sx),y+rng.randf_range(-0.03,0.03)),Vector2(z(t+sx*1.1),y+sy),Vector2(z(t+sx*0.3),y+sy*1.2),Vector2(z(t-sx*0.1),y+sy*0.6)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(patch,lower):
			f.pane(piece,1.0 if k%2 else -1.0,half,0.007+k*0.0004,color)
	if level >= 2:
		for k in 4:
			var t := rng.randf_range(0.3,minf(cowl,L*0.5))
			f.block(Vector3(rng.randf_range(-0.5,0.5),hood_y(t)+0.005,z(t)),Vector3(rng.randf_range(0.14,0.36),0.008,rng.randf_range(0.1,0.3)),RUST.darkened(rng.randf()*0.3))
