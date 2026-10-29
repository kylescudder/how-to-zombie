class_name WorldMap
extends Control
## Live tactical chart, drawn from the same island boundaries as the playable terrain.
var level: Level
var waypoint := Vector3.INF

func _ready() -> void:
	custom_minimum_size = Vector2(680,580)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	queue_redraw()

func chart_rect() -> Rect2:
	var side := minf(size.x,size.y)-24
	return Rect2((size-Vector2.ONE*side)*0.5,Vector2.ONE*side)

func chart(point: Vector3) -> Vector2:
	var rect := chart_rect()
	return rect.position+(Vector2(point.x,point.z)/ (OpenWorld.EXTENT*2)+Vector2.ONE*0.5)*rect.size

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var rect := chart_rect()
		if rect.has_point(event.position):
			var point: Vector2 = ((event.position-rect.position)/rect.size-Vector2.ONE*0.5)*OpenWorld.EXTENT*2
			waypoint=Vector3(point.x,0,point.y)
			level.local_waypoint=waypoint

func _draw() -> void:
	var rect := chart_rect()
	draw_rect(rect,Color(0.055,0.20,0.25))
	for index in 12:
		var t := index/11.0
		draw_line(rect.position+Vector2(rect.size.x*t,0),rect.position+Vector2(rect.size.x*t,rect.size.y),Color(0.25,0.47,0.49,0.25))
		draw_line(rect.position+Vector2(0,rect.size.y*t),rect.position+Vector2(rect.size.x,rect.size.y*t),Color(0.25,0.47,0.49,0.25))
	for index in OpenWorld.ISLANDS.size():
		var island: Dictionary = OpenWorld.ISLANDS[index]
		var polygon := PackedVector2Array()
		for step in 72:
			var angle := step*TAU/72
			var point: Vector2 = island.center+Vector2(cos(angle),sin(angle))*island.radius*OpenWorld.edge(angle,index)
			polygon.append(chart(Vector3(point.x,0,point.y)))
		draw_colored_polygon(polygon,island.color)
		polygon.append(polygon[0])
		draw_polyline(polygon,Color(0.82,0.73,0.46),2)
		var center := chart(Vector3(island.center.x,0,island.center.y))
		var top := chart(Vector3(island.center.x,0,island.center.y-island.radius.y*1.12))
		draw_string_outline(ThemeDB.fallback_font,top+Vector2(-60,-4),island.name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,5,Color(0,0,0,0.85))
		draw_string(ThemeDB.fallback_font,top+Vector2(-60,-4),island.name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		var camp := chart(OpenWorld.camp(index))
		draw_rect(Rect2(camp-Vector2.ONE*4,Vector2.ONE*8),Color(0.5,1,0.75))
	if not is_instance_valid(level): return
	# Barea City's blocks, the survivors you can talk to, and the idol once you know where it is.
	for c: Vector3 in level.markers.get("city_blocks", []):
		var p := chart(c)
		var half := rect.size.x * 24.0 / (OpenWorld.EXTENT * 2.0)
		draw_rect(Rect2(p - Vector2.ONE * half, Vector2.ONE * half * 2.0), Color(0.3, 0.32, 0.34, 0.85))
	for n: StoryNPC in level.npcs:
		var p := chart(n.global_position)
		draw_string(ThemeDB.fallback_font, p + Vector2(-3, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.85, 0.2))
	if level.barea_stage() == "hunt" and level.markers.get("idol", Vector3.INF) != Vector3.INF:
		var p := chart(level.markers.idol)
		draw_circle(p, 7, Color(1.0, 0.85, 0.1))
		draw_string(ThemeDB.fallback_font, p + Vector2(10, 5), "Yellow Sticker idol", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.9, 0.3))
	for vehicle: TeamVehicle in level.vehicles():
		var point := chart(vehicle.global_position)
		draw_circle(point,3.5,Color(0.4,0.85,1) if vehicle.kind=="boat" else Color(1,0.7,0.25))
	for survivor: Survivor in level.get_survivors():
		if survivor.dead: continue
		var point := chart(survivor.global_position)
		draw_circle(point,5,DB.SURVIVORS[survivor.slot].ui)
		draw_arc(point,7,0,TAU,16,Color.BLACK,2)
	if level.local_waypoint!=Vector3.INF:
		var point := chart(level.local_waypoint)
		draw_line(point-Vector2(7,7),point+Vector2(7,7),Color(1,0.4,0.25),3)
		draw_line(point-Vector2(-7,7),point+Vector2(-7,7),Color(1,0.4,0.25),3)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(8,22),"N ↑    DEAD LOW TIDE  /  %.1f km" % (OpenWorld.EXTENT * 2.0 / 1000.0),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(0.8,0.95,0.94))
	draw_string(ThemeDB.fallback_font,rect.end+Vector2(-180,-10),"500 m",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
	draw_line(rect.end+Vector2(-180,-30),rect.end+Vector2(-180+rect.size.x*500/(OpenWorld.EXTENT*2),-30),Color.WHITE,3)
