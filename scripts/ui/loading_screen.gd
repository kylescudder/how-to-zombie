class_name LoadingScreen
extends CanvasLayer
## Full-screen cover shown while a level builds. Level construction blocks the main thread, so
## report() repaints directly; the deferred redraw of an ordinary Control would never get to run.

const INK := Color(0.09,0.14,0.13)
const PAPER := Color(0.91,0.87,0.76)
const GOLD := Color(0.78,0.65,0.39)
const STAGES := ["Charting the islands","Raising Barea City","Wiring up the outer islands","Stocking the shelves","Rounding up the survivors"]
const TIPS := [
	"Car alarms bring the whole street down on you. Mind the bumpers.",
	"Pipe bombs buy time. Bile jars buy a lot more of it.",
	"A downed friend can't revive themselves. Probably.",
	"Gunsmith benches turn spare credits into better guns.",
	"The Reduced Rifle is a bargain until the sell-by date arrives.",
	"Whoever carries the Yellow Sticker idol carries everyone's problems.",
	"Cars beat walking. Boats beat drowning.",
]
const REPAINT_MS := 50
const MIN_SHOWN_MS := 600
const STEADY_FRAMES := 5
const STALL_SECONDS := 0.1

static var current: LoadingScreen

var active := false
var reports := 0
var shown_ms := 0
var _root: Control
var _fill: ColorRect
var _title: Label
var _tip: Label
var _stages: Array[Label] = []
var _progress := 0.0
var _shown_at := 0
var _painted_at := 0
var _steady := 0


## Called from world generation. Safe when no screen is up, e.g. test scenes.
static func report(progress: float, stage: int) -> void:
	if current and current.active:
		current._report(progress, stage)


func _ready() -> void:
	current = self
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = ColorRect.new()
	(_root as ColorRect).color = INK
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIKit.field_theme()
	add_child(_root)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	column.offset_left = 72
	column.offset_right = -72
	column.offset_top = -250
	column.offset_bottom = -64
	column.add_theme_constant_override("separation",12)
	_root.add_child(column)
	_title = UIKit.label("",44,PAPER)
	column.add_child(_title)
	_tip = UIKit.label("",22,PAPER.darkened(0.2))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_tip)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var stage_box := Control.new()
	stage_box.custom_minimum_size.y = 28
	column.add_child(stage_box)
	for text: String in STAGES + ["Almost there"]:
		var stage := UIKit.label(text.to_upper(),18,GOLD)
		stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.modulate.a = 0.0
		stage_box.add_child(stage)
		_stages.append(stage)
	var track := ColorRect.new()
	track.color = Color(0.20,0.28,0.26)
	track.custom_minimum_size.y = 10
	column.add_child(track)
	_fill = ColorRect.new()
	_fill.color = GOLD
	_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(_fill)
	visible = false
	set_process(false)


func begin() -> void:
	var linear: bool = Net.is_host() and not Game.open_world
	_title.text = "CHAPTER %d: %s" % [Game.chapter + 1, Game.chapter_data().name.to_upper()] if linear else "DEAD LOW TIDE"
	_tip.text = TIPS[randi() % TIPS.size()]
	_progress = 0.0
	_fill.scale.x = 0.0
	_steady = 0
	_shown_at = Time.get_ticks_msec()
	_painted_at = 0
	_show_stage(0)
	_root.modulate.a = 1.0
	active = true
	visible = true
	set_process(true)


## Hides straight away; used when a session ends mid-load.
func cancel() -> void:
	active = false
	visible = false
	set_process(false)


func _report(progress: float, stage: int) -> void:
	reports += 1
	_progress = maxf(_progress,progress)
	_fill.scale.x = _progress
	_show_stage(stage)
	var now := Time.get_ticks_msec()
	if now-_painted_at >= REPAINT_MS:
		_painted_at = now
		RenderingServer.force_draw()


func _show_stage(stage: int) -> void:
	for index in _stages.size():
		_stages[index].modulate.a = 1.0 if index == stage else 0.0


## Stays up through the first frames too: pipelines compile on the first draw of the world.
func _process(delta: float) -> void:
	var level := get_tree().get_first_node_in_group("level") as Level
	var ready := level != null and not level.is_queued_for_deletion() and level.local_survivor() != null
	if not ready:
		_steady = 0
		return
	_progress = 1.0
	_fill.scale.x = 1.0
	_show_stage(_stages.size()-1)
	_steady = _steady+1 if delta < STALL_SECONDS else 0
	if _steady >= STEADY_FRAMES and Time.get_ticks_msec()-_shown_at >= MIN_SHOWN_MS:
		_reveal()


func _reveal() -> void:
	shown_ms = Time.get_ticks_msec()-_shown_at
	active = false
	set_process(false)
	var fade := create_tween()
	fade.tween_property(_root,"modulate:a",0.0,0.25)
	fade.tween_callback(func():
		if not active: visible = false)
