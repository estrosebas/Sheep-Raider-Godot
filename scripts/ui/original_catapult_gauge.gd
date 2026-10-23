extends CanvasLayer
var catapult: Node3D
var canvas: GaugeCanvas

class GaugeCanvas extends Control:
	var owner_gauge: CanvasLayer
	var gauge: Texture2D = preload("res://assets/ui/catapult/gauge.png")
	var frame: Texture2D = preload("res://assets/ui/catapult/frame.png")
	func _draw():
		var factor = minf(size.x/512.0,size.y/240.0)
		var mobile = get_node_or_null("/root/MobileControls")
		# Leave the touch inventory/help row accessible above the native gauge.
		var origin = Vector2(0,48*factor) if mobile and mobile.enabled else Vector2.ZERO
		draw_set_transform(origin,0,Vector2.ONE*factor)
		# Catapult::DrawPowerGauge: ICTJAUG1 at8,16 and native black pointer.
		draw_texture_rect(frame,Rect2(0,8,gauge.get_width()+16,gauge.get_height()+16),false,Color(.5,.5,1))
		draw_texture(gauge,Vector2(8,16))
		var x = floorf(owner_gauge.catapult.power*84.0/1024)+24
		draw_colored_polygon(PackedVector2Array([Vector2(x,39),Vector2(x+4,49),Vector2(x-4,49)]),Color.BLACK)
		draw_set_transform(Vector2.ZERO)

func _ready():
	layer = 30
	canvas = GaugeCanvas.new()
	canvas.owner_gauge = self
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
func _process(_delta):
	visible = is_instance_valid(catapult) and catapult.state==catapult.State.OPERATED
	if visible: canvas.queue_redraw()
