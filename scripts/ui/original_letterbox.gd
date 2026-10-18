extends Control
class_name OriginalLetterbox

# interface.cpp::Letterbox_Update: 1500 real ms, two 48-line black bars.
var text_card: Control
var timer_ms = 0.0
const OPEN_MS = 1500.0
const VIRTUAL_HEIGHT = 240.0
const BAR_LINES = 48.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	timer_ms = move_toward(timer_ms,OPEN_MS if text_card and text_card.visible else 0.0,delta*1000)
	if text_card:
		text_card.offset_top = -size.y*BAR_LINES/VIRTUAL_HEIGHT+10
		text_card.offset_bottom = -10
	queue_redraw()

func _draw() -> void:
	if timer_ms <= 0: return
	var lines = BAR_LINES if timer_ms >= OPEN_MS else floor(timer_ms*131.0/4096.0)
	var height = size.y*lines/VIRTUAL_HEIGHT
	var tint = Color(0,0,0,timer_ms/OPEN_MS)
	draw_rect(Rect2(0,0,size.x,height),tint)
	draw_rect(Rect2(0,size.y-height,size.x,height),tint)
