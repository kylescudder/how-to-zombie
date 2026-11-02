class_name Forge
extends RefCounted
## Collects flat-shaded panels into one mesh, so a whole vehicle or body part costs a single node and its edges stay hard.
## GLASS doubles as the wet layer for eyes, teeth and gore; GLOW is unlit.
enum {PAINT, GLASS, CHROME, GLOW}
const LAYERS := 4

var _verts: Array[PackedVector3Array] = []
var _normals: Array[PackedVector3Array] = []
var _colors: Array[PackedColorArray] = []
## Set when a profile could not be meshed, so the catalog test can name the model.
var broken := false

func _init() -> void:
	for layer in LAYERS:
		_verts.append(PackedVector3Array())
		_normals.append(PackedVector3Array())
		_colors.append(PackedColorArray())

func tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, color: Color, layer := PAINT) -> void:
	var n := (b-a).cross(c-a)
	if n.length_squared() < 1e-12: return
	n = n.normalized()
	if n.dot(out) < 0:
		n = -n
		var swap := b
		b = c
		c = swap
	for point: Vector3 in [a,c,b]:
		_verts[layer].append(point)
		_normals[layer].append(n)
		_colors[layer].append(color)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, color: Color, layer := PAINT) -> void:
	tri(a,b,c,out,color,layer)
	tri(a,c,d,out,color,layer)

func block(center: Vector3, size: Vector3, color: Color, layer := PAINT, basis := Basis.IDENTITY) -> void:
	var h := size*0.5
	var c: Array[Vector3] = []
	for k in 8:
		c.append(center+basis*Vector3(h.x if k&1 else -h.x,h.y if k&2 else -h.y,h.z if k&4 else -h.z))
	quad(c[0],c[1],c[3],c[2],-basis.z,color,layer)
	quad(c[4],c[5],c[7],c[6],basis.z,color,layer)
	quad(c[0],c[2],c[6],c[4],-basis.x,color,layer)
	quad(c[1],c[3],c[7],c[5],basis.x,color,layer)
	quad(c[0],c[1],c[5],c[4],-basis.y,color,layer)
	quad(c[2],c[3],c[7],c[6],basis.y,color,layer)

## A square bar between two points.
func beam(a: Vector3, b: Vector3, thick: float, color: Color, layer := PAINT) -> void:
	var y := (b-a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	block((a+b)*0.5,Vector3(thick,a.distance_to(b),thick),color,layer,Basis(x,y,x.cross(y)))

## A faceted cone or cylinder from a to b, capped at b.
func tube(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, layer := PAINT, segments := 12, cap := true) -> void:
	var axis := (b-a).normalized()
	var x := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var y := x.cross(axis)
	for i in segments:
		var t0 := TAU*i/segments
		var t1 := TAU*(i+1)/segments
		var d0 := x*cos(t0)+y*sin(t0)
		var d1 := x*cos(t1)+y*sin(t1)
		quad(a+d0*ra,a+d1*ra,b+d1*rb,b+d0*rb,(d0+d1).normalized(),color,layer)
		if cap: tri(b,b+d0*rb,b+d1*rb,axis,color,layer)

## A faceted ellipsoid. from and to are latitudes (-PI/2 at the bottom), so a dome is from 0.
func ball(center: Vector3, radii: Vector3, color: Color, layer := PAINT, basis := Basis.IDENTITY, segments := 8, rings := 4, from := -PI*0.5, to := PI*0.5) -> void:
	for j in rings:
		var a0 := lerpf(from,to,float(j)/rings)
		var a1 := lerpf(from,to,float(j+1)/rings)
		for i in segments:
			var b0 := TAU*i/segments
			var b1 := TAU*(i+1)/segments
			var p := [_round(a0,b0,radii),_round(a0,b1,radii),_round(a1,b1,radii),_round(a1,b0,radii)]
			var mid: Vector3 = (p[0]+p[1]+p[2]+p[3])*0.25
			quad(center+basis*p[0],center+basis*p[1],center+basis*p[2],center+basis*p[3],basis*mid,color,layer)
	if from > -PI*0.5:
		var rim: Array[Vector3] = []
		for i in segments: rim.append(center+basis*_round(from,TAU*i/segments,radii))
		for i in range(1,segments-1): tri(rim[0],rim[i],rim[i+1],basis*Vector3.DOWN,color,layer)

static func _round(lat: float, lon: float, radii: Vector3) -> Vector3:
	return Vector3(cos(lat)*cos(lon)*radii.x,sin(lat)*radii.y,cos(lat)*sin(lon)*radii.z)

## A faceted loft up through (height, half width, half depth, forward) sections, painted face by face:
## paint(ring, segment, centre) returns the colour. Alpha 0 leaves the face open and alpha under 1 puts it
## on the GLASS layer. inside also lines the open faces' backs, darkened, so a hood shows its lining.
func loft(sections: Array, segments: int, paint: Callable, origin := Vector3.ZERO, basis := Basis.IDENTITY, base := false, inside := false) -> void:
	for j in sections.size()-1:
		var s0: Vector4 = sections[j]
		var s1: Vector4 = sections[j+1]
		for i in segments:
			var t0 := TAU*i/segments
			var t1 := TAU*(i+1)/segments
			var a := _section(s0,t0)
			var b := _section(s0,t1)
			var c := _section(s1,t1)
			var e := _section(s1,t0)
			var mid := (a+b+c+e)*0.25
			var out := mid-Vector3(0,mid.y,(s0.w+s1.w)*0.5)
			if out.length_squared() < 1e-8: out = Vector3(0,signf(s1.x-s0.x),0)
			var color: Color = paint.call(j,i,mid)
			if color.a <= 0: continue
			var layer := PAINT
			if color.a < 1:
				layer = GLASS
				color.a = 1
			quad(origin+basis*a,origin+basis*b,origin+basis*c,origin+basis*e,basis*out,color,layer)
			if inside: quad(origin+basis*a,origin+basis*b,origin+basis*c,origin+basis*e,-(basis*out),color.darkened(0.55),layer)
	if base:
		var s: Vector4 = sections[0]
		var color: Color = paint.call(-1,0,Vector3(0,s.x,s.w))
		for i in segments:
			tri(origin+basis*Vector3(0,s.x,s.w),origin+basis*_section(s,TAU*i/segments),origin+basis*_section(s,TAU*(i+1)/segments),basis*Vector3.DOWN,color)

static func _section(s: Vector4, angle: float) -> Vector3:
	return Vector3(cos(angle)*s.y,s.x,sin(angle)*s.z+s.w)

## Curved band around the x axis at (z,y), facing inwards; lines the wheel arches.
func liner(z: float, y: float, r: float, x0: float, x1: float, angle0: float, angle1: float, color: Color, segments := 8) -> void:
	for i in segments:
		var a := lerpf(angle0,angle1,float(i)/segments)
		var b := lerpf(angle0,angle1,float(i+1)/segments)
		var p := Vector3(0,y+sin(a)*r,z+cos(a)*r)
		var q := Vector3(0,y+sin(b)*r,z+cos(b)*r)
		quad(Vector3(x0,p.y,p.z),Vector3(x1,p.y,p.z),Vector3(x1,q.y,q.z),Vector3(x0,q.y,q.z),Vector3(0,y-(p.y+q.y)*0.5,z-(p.z+q.z)*0.5),color)

## Flat ring on the side of the body at x, lipping a wheel arch.
func lip(z: float, y: float, r0: float, r1: float, x: float, angle0: float, angle1: float, color: Color, depth: float, segments := 8) -> void:
	var out := Vector3(signf(x),0,0)
	for i in segments:
		var a := lerpf(angle0,angle1,float(i)/segments)
		var b := lerpf(angle0,angle1,float(i+1)/segments)
		var pa := Vector3(0,sin(a),cos(a))
		var pb := Vector3(0,sin(b),cos(b))
		var c := Vector3(x,y,z)
		var e := c+out*depth
		quad(e+pa*r0,e+pa*r1,e+pb*r1,e+pb*r0,out,color)
		quad(c+pa*r1,e+pa*r1,e+pb*r1,c+pb*r1,(pa+pb).normalized(),color)

## Extrudes a (z,y) side profile across the car; width(y) gives the half width, so cabins can lean in.
func prism(profile: PackedVector2Array, width: Callable, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(profile)
	if indices.is_empty():
		broken = true
		push_error("Vehicle profile did not triangulate")
		return
	for k in range(0,indices.size(),3):
		var a := profile[indices[k]]
		var b := profile[indices[k+1]]
		var c := profile[indices[k+2]]
		for side: float in [-1,1]:
			tri(_on(a,side,width),_on(b,side,width),_on(c,side,width),Vector3(side,0,0),color)
	var area := 0.0
	for i in profile.size():
		area += profile[i].cross(profile[(i+1)%profile.size()])
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i+1)%profile.size()]
		var edge := (b-a).normalized()
		var out := Vector2(edge.y,-edge.x)*signf(area)
		quad(_on(a,-1,width),_on(a,1,width),_on(b,1,width),_on(b,-1,width),Vector3(0,out.y,out.x),color)

## A flat panel lying on the width(y) surface of one side, lifted just off it.
func pane(profile: PackedVector2Array, side: float, width: Callable, lift: float, color: Color, layer := PAINT) -> void:
	var indices := Geometry2D.triangulate_polygon(profile)
	var w := func(y: float) -> float: return float(width.call(y))+lift
	for k in range(0,indices.size(),3):
		tri(_on(profile[indices[k]],side,w),_on(profile[indices[k+1]],side,w),_on(profile[indices[k+2]],side,w),Vector3(side,0,0),color,layer)

## Frustum between two upright rectangles (half width, bottom, top) at za and zb, for tapered noses and tails.
func frustum(za: float, a: Vector3, zb: float, b: Vector3, color: Color) -> void:
	var out := Vector3(0,0,signf(zb-za))
	var p := func(x: float, y: float, z: float) -> Vector3: return Vector3(x,y,z)
	var a0: Vector3 = p.call(-a.x,a.y,za)
	var a1: Vector3 = p.call(a.x,a.y,za)
	var a2: Vector3 = p.call(a.x,a.z,za)
	var a3: Vector3 = p.call(-a.x,a.z,za)
	var b0: Vector3 = p.call(-b.x,b.y,zb)
	var b1: Vector3 = p.call(b.x,b.y,zb)
	var b2: Vector3 = p.call(b.x,b.z,zb)
	var b3: Vector3 = p.call(-b.x,b.z,zb)
	quad(b0,b1,b2,b3,out,color)
	quad(a1,b1,b2,a2,Vector3(1,0,out.z*0.5),color)
	quad(a0,b0,b3,a3,Vector3(-1,0,out.z*0.5),color)
	quad(a3,a2,b2,b3,Vector3(0,1,out.z*0.3),color)
	quad(a0,a1,b1,b0,Vector3(0,-1,0),color)

func commit(materials: Array[Material]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for layer in LAYERS:
		if _verts[layer].is_empty(): continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts[layer]
		arrays[Mesh.ARRAY_NORMAL] = _normals[layer]
		arrays[Mesh.ARRAY_COLOR] = _colors[layer]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,materials[layer])
	return mesh

static func _on(point: Vector2, side: float, width: Callable) -> Vector3:
	return Vector3(side*float(width.call(point.y)),point.y,point.x)
