extends Control
class_name OriginalLettucePrompt

var actor: RalphController
var result: Dictionary = {}
var displayed_result: Dictionary = {}
var frames: Array[Texture2D] = []
var elapsed = 0.0
var timer = 0.0
var sheep_icon: Texture2D
var lettuce_icon: Texture2D
var sam_icon: Texture2D

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/lettuce_prompt/source.json"))
	for i in range(int(source.frames)): frames.append(load("res://assets/ui/lettuce_prompt/frame_%d.png" % i))
	sheep_icon = load("res://assets/ui/lettuce_prompt/sheep.png")
	lettuce_icon = load("res://assets/ui/lettuce_prompt/lettuce.png")
	sam_icon = load("res://assets/items/flute/target_sam.png")

func _process(delta):
	elapsed += delta
	result = {}
	var item = actor.inventory.equipped_node
	if item is LettuceItem and item.holder == actor and actor.can_use_inventory() and not actor.inventory.wheel_open:
		result = OriginalLettuceGuidance.query(item, actor.global_position)
	elif item is FanItem and item.holder == actor and not actor.inventory.wheel_open and not actor.cinematic_controls_locked:
		result = item.detection_report()
	elif item is FluteItem and item.holder==actor and not actor.inventory.wheel_open and not actor.cinematic_controls_locked:
		result = item.detection_report()
	if not result.is_empty():
		displayed_result = result
		timer = minf(timer + delta, .5)
	else:
		timer = maxf(timer - delta, 0)
	visible = timer > 0
	queue_redraw()

func prompt_tint() -> Color:
	# Hud_DrawItemPrompt packed RGB (low byte R), converted to D3D BGR.
	return Color(80.0/255,16.0/255,16.0/255) if int(displayed_result.get("value",0)) >= 0xe665 else Color(40.0/255,40.0/255,80.0/255)

func _draw():
	if frames.is_empty() or timer <= 0: return
	var factor = minf(size.x/512,size.y/240)
	# AnimSprite::InitFromRes uses bitmap dimensions minus one.
	var extent = frames[0].get_size() - Vector2.ONE
	var origin = Vector2(18,size.y/factor - 14 - extent.y)
	var remaining = 1-timer/.5
	var phase = pow(floor(timer*64),2)
	var dx = -remaining*cos(phase*44/7*TAU/4096)*24
	var dy = -remaining*cos(phase*4*TAU/4096)*12
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	var rectangle = Rect2(origin-Vector2(dx,dy),extent+Vector2(dx,dy)*2)
	if rectangle.size.x > 0 and rectangle.size.y > 0:
		draw_texture_rect(frames[(int(elapsed*15)&255)%frames.size()],rectangle,false,prompt_tint())
	var icon = sheep_icon if displayed_result.get("sheep",false) else lettuce_icon
	if int(displayed_result.get("class_id",-1))==1: icon = sam_icon
	var icon_extent = icon.get_size() - Vector2.ONE
	# Class icon stays centered while the crayon squashes on entry/exit.
	draw_texture_rect(icon,Rect2(origin+extent/2-icon_extent/2,icon_extent),false)
	draw_set_transform(Vector2.ZERO)
