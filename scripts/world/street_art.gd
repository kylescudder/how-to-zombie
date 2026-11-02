class_name StreetArt
extends RefCounted
## A reusable, authored street-corner kit. Simplified painted forms, curved silhouettes.
const CREAM := Color(0.89,0.79,0.57)
const RUST := Color(0.70,0.23,0.13)
const TEAL := Color(0.22,0.45,0.40)

## A parked car, picked from where it stands so every peer sees the same one. Returns its roof height.
static func car(parent: Node3D, color: Color) -> float:
	var models := VehicleCatalog.STREET_MODELS
	var id: String = models[absi(hash(Vector3i(parent.position)))%models.size()]
	VehicleKit.build(parent,id,color)
	return VehicleCatalog.find(id).roof

static func corner(parent: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "BiteSizeDeli"
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	Build.solid_box(n,Vector3(6.2,4.8,0.55),TEAL,Vector3(0,2.4,-0.25))
	for x: float in [-3,3]:
		ArtShapes.link(n,Vector3(x,0,0.05),Vector3(x*0.98,4.7,0.05),0.13,CREAM)
	Build.box(n,Vector3(6.3,0.18,0.8),CREAM,Vector3(0,4.6,0.04),Vector3(0,0,-1.2))
	# Broad sign and individually framed shop windows.
	Build.box(n,Vector3(5.3,0.78,0.18),CREAM,Vector3(0,3.65,0.12),Vector3(0,0,-2))
	var sign := Build.label(n,"BITE SIZE DELI",Vector3(0,3.63,0.23),72,RUST)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.pixel_size = 0.008
	sign.outline_size = 0
	sign.rotation.z = deg_to_rad(-2)
	for x: float in [-1.8,1.8]:
		Build.box(n,Vector3(1.65,1.65,0.12),CREAM,Vector3(x,1.9,0.11))
		Build.box(n,Vector3(1.40,1.40,0.13),Color(0.12,0.27,0.28),Vector3(x,1.9,0.14))
		ArtShapes.link(n,Vector3(x-0.65,1.89,0.23),Vector3(x+0.65,1.89,0.23),0.035,CREAM)
		ArtShapes.link(n,Vector3(x,1.2,0.23),Vector3(x,2.6,0.23),0.035,CREAM)
		# Skewed boards make the comic shapes deliberate.
		Build.box(n,Vector3(1.65,0.19,0.10),Color(0.50,0.31,0.15),Vector3(x,1.65,0.3),Vector3(0,0,12 if x<0 else -15))
		Build.box(n,Vector3(1.65,0.17,0.11),Color(0.66,0.43,0.21),Vector3(x,2.05,0.31),Vector3(0,0,-8 if x<0 else 7))
	Build.box(n,Vector3(1.15,2.45,0.15),CREAM,Vector3(0,1.23,0.12))
	Build.box(n,Vector3(0.93,2.2,0.15),RUST,Vector3(0,1.13,0.20))
	Build.box(n,Vector3(0.64,0.96,0.04),Color(0.14,0.28,0.29),Vector3(0,1.65,0.30))
	ArtShapes.link(n,Vector3(0.31,0.95,0.32),Vector3(0.31,1.17,0.32),0.025,CREAM)
	# Sloped striped awning and rounded scallops.
	for i in 12:
		var x := -2.75+i*0.5
		var color := RUST if i%2==0 else CREAM
		Build.box(n,Vector3(0.50,0.08,1.03),color,Vector3(x,3.0,0.60),Vector3(18,0,0))
		ArtShapes.oval(n,Vector3(0.50,0.28,0.12),color,Vector3(x,2.77,1.08))
	# Chalkboard, planter and curved tree add street-scale silhouettes.
	var board := Node3D.new()
	board.position = Vector3(-2.5,0,1.28)
	board.rotation_degrees = Vector3(0,12,-4)
	n.add_child(board)
	Build.box(board,Vector3(0.82,1.22,0.09),Color(0.49,0.28,0.12),Vector3(0,0.73,0))
	Build.box(board,Vector3(0.67,1.06,0.10),Color(0.12,0.22,0.20),Vector3(0,0.74,0.02))
	var text := Build.label(board,"SOUP\nOF THE\nDEAD",Vector3(0,0.78,0.09),32,CREAM)
	text.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	text.pixel_size = 0.0045
	text.outline_size = 0
	ArtShapes.loft(n,[Vector4(0,0.30,0.30,0),Vector4(0.08,0.36,0.36,0),Vector4(0.55,0.46,0.46,0),Vector4(0.60,0.47,0.47,0)],RUST,Vector3(2.6,0,1.1),12)
	tree(n,Vector3(2.6,0.4,1.1),0.75)
	return n

static func tree(parent: Node3D, pos: Vector3, size := 1.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE*size
	parent.add_child(n)
	ArtShapes.link(n,Vector3.ZERO,Vector3(0.15,1.8,0),0.13,Color(0.43,0.27,0.13))
	ArtShapes.link(n,Vector3(0.12,1.2,0),Vector3(-0.45,2.0,0.08),0.08,Color(0.43,0.27,0.13))
	ArtShapes.oval(n,Vector3(1.7,1.5,1.4),Color(0.33,0.52,0.15),Vector3(0.1,2.5,0),Vector3(0,12,-12),12)
	ArtShapes.oval(n,Vector3(1.2,1.1,1.1),Color(0.48,0.62,0.20),Vector3(-0.5,2.75,0.1),Vector3(0,18,0),12)
	ArtShapes.oval(n,Vector3(1.1,1.0,1.2),Color(0.25,0.43,0.15),Vector3(0.65,2.25,-0.1),Vector3.ZERO,12)
