class_name MenuHideout
extends SubViewportContainer
## A small, isolated title-screen diorama. Nothing here participates in the game simulation.
signal discovered(message: String)
var world: SubViewport
var camera: Camera3D
var _characters: Array[CharacterModel] = []
var _picks := {}
var _buoys: Array[Node3D] = []
var _boat: Node3D
var _fire: OmniLight3D
var _time := 0.0
var _station := 0
var _selected := -1
var _reaction := 0.0
const STATIONS := ["Marla: Bring your friends. And something with a safety catch.","Weather: light drizzle, scattered teeth. Lovely boating weather.","Old Reg: If it groans, don't offer it a cup of tea."]

func _ready() -> void:
	stretch=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	world=SubViewport.new()
	world.own_world_3d=true
	world.size=Vector2i(1600,900)
	world.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(world)
	var scene := Node3D.new()
	world.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0.19,0.30,0.34)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(0.7,0.83,0.86)
	env.environment.ambient_light_energy=0.65
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0)
	sun.light_color=Color(1,0.77,0.5)
	sun.light_energy=1.1
	sun.shadow_enabled=true
	scene.add_child(sun)
	var sea := PlaneMesh.new()
	sea.size=Vector2(160,100)
	Build.mesh(scene,sea,Color(0.18,0.39,0.44),Vector3(0,-0.45,0))
	Build.cyl(scene,13,13,0.8,Color(0.52,0.51,0.35),Vector3(2,-0.4,0),Vector3.ZERO,48)
	# The jetty, crooked shelter and a little supply table.
	Build.box(scene,Vector3(6,0.18,17),Color(0.48,0.34,0.23),Vector3(9,-0.05,3))
	for z in range(-5,12): Build.box(scene,Vector3(6.1,0.025,0.04),Color(0.29,0.25,0.20),Vector3(9,0.06,z))
	for z in [-4,4,11]:
		for x in [6.2,11.8]: Build.cyl(scene,0.15,0.19,1.6,Color(0.35,0.29,0.20),Vector3(x,0,z))
	Build.box(scene,Vector3(6,3.6,4),Color(0.29,0.42,0.36),Vector3(2,1.8,-5))
	var roof := PrismMesh.new()
	roof.size=Vector3(7,2,5)
	Build.mesh(scene,roof,Color(0.58,0.31,0.20),Vector3(2,4.5,-5))
	Build.box(scene,Vector3(1.4,2.6,0.08),Color(0.16,0.25,0.24),Vector3(2,1.3,-2.95))
	for x in [0,4]: Build.box(scene,Vector3(1.15,1.1,0.08),Color(0.94,0.73,0.36),Vector3(x,2.2,-2.94),Vector3.ZERO,0.5)
	var sign := Build.label(scene,"LAST SAFE CUPPA",Vector3(2,3.3,-2.8),40,Color(0.95,0.86,0.65))
	sign.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	sign.pixel_size=0.008
	Build.box(scene,Vector3(2.6,0.15,1.2),Color(0.48,0.34,0.23),Vector3(7,1.05,-1))
	for x in [6,8]: Build.box(scene,Vector3(0.12,1,0.9),Color(0.31,0.30,0.22),Vector3(x,0.5,-1))
	var radio := Build.box(scene,Vector3(0.9,0.6,0.35),Color(0.42,0.48,0.29),Vector3(7,1.42,-1))
	Build.box(scene,Vector3(0.45,0.28,0.02),Color(0.16,0.22,0.20),Vector3(6.85,1.42,-0.81))
	Build.cyl(scene,0.025,0.025,1,Color(0.65,0.68,0.59),Vector3(7.35,2.15,-1),Vector3(0,0,-12))
	_pick(scene,"radio",radio.position,Vector3(1.5,1.3,1))
	var gun := GunModels.make("pump_shotgun")
	gun.position=Vector3(7,1.2,-0.5)
	gun.rotation_degrees=Vector3(0,90,80)
	scene.add_child(gun)
	for index in 4:
		var actor := CharacterModel.new()
		scene.add_child(actor)
		if index==0: actor.setup_custom(Wardrobe.equipped)
		else: actor.setup_survivor(index)
		actor.position=Vector3(2.5+index*1.7,0,2+sin(index)*0.8)
		actor.rotation.y=0.25
		_characters.append(actor)
		_pick(scene,"survivor%d"%index,actor.position+Vector3.UP,Vector3(1.2,2.3,1.2))
	var zombie := CharacterModel.new()
	scene.add_child(zombie)
	zombie.setup_infected("common",27)
	zombie.position=Vector3(10,0,8)
	_characters.append(zombie)
	_pick(scene,"zombie",zombie.position+Vector3.UP,Vector3(1.5,2.5,1.5))
	for offset in [Vector3(-2,0,-7),Vector3(11,0,-6),Vector3(-1,0,3)]: StreetArt.tree(scene,offset,1.5)
	_boat=Node3D.new()
	scene.add_child(_boat)
	_boat.position=Vector3(15,-0.15,3)
	_boat.rotation.y=-0.25
	ArtShapes.loft(_boat,[Vector4(-0.3,0.2,0.4,0),Vector4(0.0,0.7,1.9,0),Vector4(0.5,0.9,2.3,0)],Color(0.69,0.37,0.20))
	Build.box(_boat,Vector3(1.2,0.15,3.2),Color(0.76,0.65,0.43),Vector3(0,0.42,0))
	for z in [-0.8,0.8]: Build.box(_boat,Vector3(1.6,0.2,0.4),Color(0.37,0.43,0.33),Vector3(0,0.65,z))
	Build.cyl(scene,0.12,0.10,0.22,Color(0.88,0.83,0.65),Vector3(6.3,1.25,-1))
	for index in 5:
		var buoy := Node3D.new()
		scene.add_child(buoy)
		buoy.position=Vector3(14+index*3,-0.1,-6+index*5)
		Build.cyl(buoy,0.16,0.35,0.8,Color(0.79,0.43,0.24),Vector3.ZERO)
		_buoys.append(buoy)
	Build.cyl(scene,0.7,0.9,0.3,Color(0.27,0.28,0.24),Vector3(4,0.1,0),Vector3.ZERO,12)
	for side in [-1,1]: Build.box(scene,Vector3(1.3,0.22,0.2),Color(0.43,0.28,0.16),Vector3(4,0.3,0),Vector3(0,side*30,0))
	ArtShapes.oval(scene,Vector3(0.5,0.9,0.4),Color(1,0.57,0.17),Vector3(4,0.8,0))
	_fire=OmniLight3D.new()
	_fire.position=Vector3(4,1.3,0)
	_fire.light_color=Color(1,0.58,0.2)
	_fire.omni_range=9
	scene.add_child(_fire)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=22
	camera.position=Vector3(21,14,24)
	scene.add_child(camera)
	camera.look_at(Vector3(2,1.2,0))
	camera.current=true
	Wardrobe.changed.connect(func():
		if is_instance_valid(_characters[0]) and _characters[0].get_meta("appearance",{})!=Wardrobe.equipped: _characters[0].setup_custom(Wardrobe.equipped))

func _pick(scene: Node3D, id: String, pos: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.position=pos
	area.collision_layer=1
	area.collision_mask=0
	scene.add_child(area)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=size
	shape.shape=box
	area.add_child(shape)
	area.set_meta("pick",id)
	_picks[id]=pos

func set_active(active: bool) -> void:
	if world: world.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	set_process(active)

func _process(delta: float) -> void:
	_time+=delta
	_reaction=maxf(0,_reaction-delta)
	_fire.light_energy=2.0+sin(_time*11)*0.25
	_boat.position.y=-0.15+sin(_time*1.2)*0.10
	_boat.rotation.z=sin(_time*0.9)*0.04
	for index in _characters.size():
		var actor := _characters[index]
		actor.animate(delta,0,0,"inspect" if _selected==index and _reaction>0 else "ready")
		if index==4:
			actor.rotation.y=sin(_time*7)*0.7 if _selected==4 and _reaction>0 else sin(_time*0.6)*0.4+0.3
			actor.position.x=10+sin(_time*0.4)*0.6
		elif _selected==index and _reaction>0: actor.rotation.y=sin(_time*7)*0.2
		else: actor.rotation.y=0.25
	for index in _buoys.size():
		_buoys[index].position.y=-0.1+sin(_time*1.5+index)*0.12
		_buoys[index].rotation.z=sin(_time+index)*0.1

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT: return
	var pos: Vector2=event.position*Vector2(world.size)/size
	var from := camera.project_ray_origin(pos)
	var query := PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(pos)*100,1)
	query.collide_with_areas=true
	query.collide_with_bodies=false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var id: String=hit.collider.get_meta("pick","")
	if id=="radio":
		_station=(_station+1)%STATIONS.size()
		discovered.emit(STATIONS[_station])
	elif id=="zombie":
		_selected=4
		_reaction=2
		discovered.emit("That's Colin. He hasn't noticed the apocalypse yet.")
	else:
		_selected=int(id.trim_prefix("survivor"))
		_reaction=2.0
		var lines := ["Gus: Packed the shells. Forgot the sandwiches.","Rosa: I'm driving. Last time Dex parked in the sea.","Dex: That boat was already on fire.","Mei: Three medkits. Four people. Try to behave."]
		discovered.emit(lines[_selected])
	Sfx.play("click")
