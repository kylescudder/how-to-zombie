extends Node
## Renders every death clip of every infected into one sprite sheet per type, plus a gallery page.
## Needs a window: tools/godot --fixed-fps 12 -- --solo --test=death_capture [--only=tank]
const FPS := 12
const TILE := Vector2i(240, 180)
const LEAD := 3     # Living frames before the blow.
const TAIL := 6     # Frames held on the corpse.
const TYPES := ["common", "boomer", "hunter", "smoker", "spitter", "tank", "witch"]

const PAGE := """<!doctype html><meta charset="utf-8"><title>Infected deaths</title>
<style>
body{margin:0;padding:12px;background:#1b1d1c;color:#e8e6df;font:14px system-ui}
nav{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:8px}
button{padding:6px 12px;border:1px solid #555;border-radius:6px;background:#2a2d2b;color:inherit;font:inherit;cursor:pointer}
button[aria-pressed=true]{background:#d9c77a;color:#1b1d1c}
#speed{margin-left:auto}
#grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:8px}
figure{margin:0}.tile{position:relative;overflow:hidden;width:240px;height:180px;border-radius:6px;background:#333}
.tile img{position:absolute;max-width:none}figcaption{padding:3px 2px;font-size:12px}
.tag{opacity:.65}.own{color:#d9c77a}
</style>
<nav id="tabs"></nav><p id="count"></p><div id="grid"></div>
<script>
const data=__CLIPS__;
const tile=data.tile,tabs=document.getElementById('tabs'),grid=document.getElementById('grid'),count=document.getElementById('count');
let live=[],slow=1;
const show=type=>{
	grid.textContent='';live=[];
	const set=data.types[type];
	const mine=set.clips.filter(c=>c.own).length;
	count.textContent=`${set.clips.length} deaths: ${mine} only the ${type} has, ${set.clips.length-mine} shared. Each loops with a short hold on the body.`;
	set.clips.forEach((clip,row)=>{
		const f=document.createElement('figure'),box=document.createElement('div'),img=document.createElement('img'),cap=document.createElement('figcaption');
		box.className='tile';img.src=(window.SHEETS||{})[type]||type+'.jpg';
		img.style.top=-row*tile[1]+'px';img.style.width=set.columns*tile[0]+'px';box.append(img);
		cap.innerHTML=`<span class="${clip.own?'own':''}">${clip.id.replace(/_/g,' ')}</span> <span class="tag">${clip.cause}, hit ${clip.hit}</span>`;
		f.append(box,cap);grid.append(f);live.push({img,frames:clip.frames});
	});
	[...tabs.querySelectorAll('button[data-type]')].forEach(b=>b.setAttribute('aria-pressed',b.dataset.type===type));
};
Object.keys(data.types).forEach(type=>{
	const b=document.createElement('button');b.textContent=type;b.dataset.type=type;b.onclick=()=>show(type);tabs.append(b);
});
const speed=document.createElement('button');speed.id='speed';speed.textContent='Speed: normal';
speed.onclick=()=>{slow=slow===1?3:1;speed.textContent=slow===1?'Speed: normal':'Speed: 1/3'};tabs.append(speed);
let tick=0;setInterval(()=>{tick++;if(tick%slow)return;const n=Math.floor(tick/slow);
	for(const c of live){const f=n%(c.frames+6);c.img.style.left=-Math.min(f,c.frames-1)*tile[0]+'px';}
},1000/data.fps);
show(Object.keys(data.types)[0]);
</script>"""

var runner: Node
var lvl: Level
var base := Vector3.ZERO
var camera: Camera3D
var stage: MeshInstance3D


func run(test: Node) -> void:
	AudioServer.set_bus_mute(0, true)
	runner = test
	await runner.wait_for(func(): return runner.me() != null)
	lvl = runner.level()
	runner.calm()
	base = runner.ahead(30)
	var p: Survivor = runner.me()
	runner.place(p, base + Vector3(0, 0, -40))
	p.viewmodel.hide()
	p.ui_open = true
	for mate: Survivor in lvl.get_survivors():
		if mate.bot:
			mate.brain = null
			mate.in_move = Vector2.ZERO
			runner.place(mate, base + Vector3(mate.slot * 2, 0, -40))
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	hud.set_process(false)
	hud.visible = false
	# A plain floor: the sheet is for judging motion, and a level's clutter gets in the way.
	lvl.get_node("Geometry").visible = false
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(400, 400)
	stage = Build.mesh(lvl, floor_plane, Color(0.33, 0.36, 0.35), base + Vector3.UP * 0.002, Vector3.ZERO)
	camera = Camera3D.new()
	camera.fov = 42.0
	lvl.add_child(camera)
	camera.current = true
	var fill := DirectionalLight3D.new()
	fill.light_energy = 1.1
	lvl.add_child(fill)
	fill.look_at_from_position(base + Vector3(3, 6, 5), base)
	var out := ProjectSettings.globalize_path("res://screenshots/deaths")
	DirAccess.make_dir_recursive_absolute(out)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
	var manifest := {}
	for type: String in TYPES:
		if only != "" and only != type:
			continue
		manifest[type] = await _sheet(type, out)
	var file := FileAccess.open(out.path_join("clips-%s.json" % (only if only != "" else "all")), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": FPS, "tile": [TILE.x, TILE.y], "types": manifest}))
	file.close()
	if only == "":
		_gallery(out, manifest)


func _sheet(type: String, out: String) -> Dictionary:
	var clips := DeathClips.for_type(type)
	var rate: float = DeathClips.WEIGHT.get(type, 1.0)
	var longest := 0.0
	for id: String in clips:
		longest = maxf(longest, float(DeathClips.compiled(id, false).dur))
	var columns := LEAD + ceili(longest * rate * FPS) + TAIL
	var sheet := Image.create(columns * TILE.x, clips.size() * TILE.y, false, Image.FORMAT_RGB8)
	var rows: Array = []
	for row in clips.size():
		var id: String = clips[row]
		var clip := DeathClips.compiled(id, false)
		var frames := LEAD + ceili(float(clip.dur) * rate * FPS) + TAIL
		var zombie := lvl.spawn_infected(type, base, false)
		zombie.set_physics_process(false)
		zombie.rotation.y = 0.0
		zombie.net_anim = Infected.A.IDLE
		_clear_stage(zombie.get_parent())
		_frame_camera(type, clip, zombie.global_position)
		for f in frames:
			if f == LEAD:
				zombie.anim = Infected.A.DEAD
				zombie.net_death = DeathClips.encode(id, false)
				zombie.net_anim = Infected.A.DEAD
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var side := mini(img.get_width() * 3 / 4, img.get_height())
			var crop := img.get_region(Rect2i((img.get_width() - side * 4 / 3) / 2, (img.get_height() - side) / 2, side * 4 / 3, side))
			crop.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
			crop.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, TILE), Vector2i(f * TILE.x, row * TILE.y))
		zombie.queue_free()
		await get_tree().process_frame
		rows.append({"id": id, "frames": frames, "own": DeathClips.CLIPS[id].has("only"), "cause": DeathClips.CLIPS[id].get("cause", "signature"), "hit": DeathClips.CLIPS[id].hit})
		print("[DEATHS] %s %d/%d %s" % [type, row + 1, clips.size(), id])
	sheet.save_jpg(out.path_join("%s.jpg" % type), 0.72)
	return {"columns": columns, "clips": rows}


## Vehicles and props live all over the level, so hide everything but the lights and the bodies.
func _clear_stage(keep: Node, from: Node = null) -> void:
	for child in (from if from else lvl).get_children():
		if child is Infected or child == camera or child == stage or child is Light3D:
			continue
		if child == keep or not child is Node3D:
			_clear_stage(keep, child)
		else:
			child.visible = false


## Frames the walk from where the body starts to where the clip throws it.
func _frame_camera(type: String, clip: Dictionary, feet: Vector3) -> void:
	var last: Vector3 = clip["keys"][-1].pose[12]
	var travel := Vector3(last.x, 0, last.z)
	var reach := 1.0 + travel.length() * 0.42
	reach *= {"tank": 1.2, "smoker": 1.3, "boomer": 1.2, "spitter": 1.15}.get(type, 1.05)
	var mid := feet + travel * 0.5 + Vector3.UP * 0.55 * (1.5 if type == "tank" else 1.0)
	camera.look_at_from_position(mid + Vector3(3.1, 2.4, 3.6) * reach, mid)


## A page that plays every sheet: open screenshots/deaths/index.html in a browser.
func _gallery(out: String, manifest: Dictionary) -> void:
	var page := PAGE.replace("__CLIPS__", JSON.stringify({"fps": FPS, "tile": [TILE.x, TILE.y], "types": manifest}))
	var file := FileAccess.open(out.path_join("index.html"), FileAccess.WRITE)
	file.store_string(page)
	file.close()
