extends CanvasLayer
# DoorLevel::MSG_QUERY_ACTION / Text_PrintfStyled at the bottom of the screen.
var player: RalphController
var target: LabLevelDoor
var text = ""
var clock = 0.0
var canvas: DoorCanvas

class DoorCanvas extends Control:
	var status
	var atlas: Texture2D
	func _draw():
		if status.text.is_empty(): return
		var factor = minf(size.x/512,size.y/240)
		var width = status.text.length()*9*factor
		var start = Vector2((size.x-width)/2,size.y-48*factor)
		for i in range(status.text.length()):
			var code = OriginalGameFont.animated_glyph(status.text.unicode_at(i),status.clock)
			var glyph = clampi(code,32,255)-32
			var region = Rect2((glyph%16)*16,int(glyph/16)*16,15,15)
			var rectangle = Rect2(start+Vector2(i*9*factor,0),Vector2(9,13)*factor)
			draw_texture_rect_region(atlas,Rect2(rectangle.position+Vector2.ONE*factor,rectangle.size),region,Color(0,0,0,.85))
			var tint = OriginalGameFont.COLOR
			draw_texture_rect_region(atlas,rectangle,region,Color(tint.r*2,tint.g*2,tint.b*2,1))

func _ready():
	layer = 25
	player = get_parent().get_node("Player")
	canvas = DoorCanvas.new(); canvas.status = self
	canvas.atlas = load("res://assets/ui/pause/font.png")
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(canvas); canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta):
	clock += delta
	target = null
	var nearest = INF
	for door in get_tree().get_nodes_in_group("world_interactables"):
		if not door is LabLevelDoor or door.get_parent()!=get_parent() or not door.can_show_status(player): continue
		var distance = player.global_position.distance_squared_to(door.global_position)
		if distance<nearest: target = door; nearest = distance
	text = target.status_text() if target else ""
	if not target:
		for object in get_tree().get_nodes_in_group("world_interactables"):
			if object.get_parent()!=get_parent() or not object.has_meta("original_class"): continue
			var kind = str(object.get_meta("original_class"))
			if kind in ["BonusManager","MCardManager"] and object.can_interact(player):
				text = "E: "+GameLocalization.text("scene",191 if kind=="BonusManager" else 99,1 if kind=="BonusManager" else 5)
				break
	canvas.queue_redraw()

func reload_localization():
	text = target.status_text() if is_instance_valid(target) else ""
	canvas.queue_redraw()
