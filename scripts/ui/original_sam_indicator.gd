extends CanvasLayer
class_name OriginalSamIndicator
var guard: OriginalSam
var portrait: OriginalCinematicActor
var viewport: SubViewport
var panel: Control
var frame: TextureRect
var image: TextureRect
# g_samZoneColors -> Color_RgbToBgr -> D3D diffuse (low byte is red).
const SOURCE_COLORS = [0x1f702a,0x0f50a0,0x0010f0]
const COLORS = [Color("2a701f"),Color("a0500f"),Color("f01000")]

static func source_color(index: int) -> Color:
	var packed: int = SOURCE_COLORS[clampi(index,0,2)]
	return Color((packed&255)/255.0,((packed>>8)&255)/255.0,((packed>>16)&255)/255.0)


func _ready() -> void:
	layer = 20
	panel = Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(140,120)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	portrait = load(guard.rules["head_directory"]+"/worn.tscn").instantiate()
	viewport.add_child(portrait)
	portrait.sample_animation("default",0)
	var camera = Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0,.245,1.4)
	camera.look_at(Vector3(0,.245,0))
	camera.fov = 25
	camera.current = true
	image = TextureRect.new()
	image.texture = viewport.get_texture()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(image)
	frame = TextureRect.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture = load("res://assets/levels/lvl_01/sam_head/border.png")
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(frame)
	panel.move_child(frame,0) # Crayon backing sorts behind the independent 3-D head.

func _process(_delta: float) -> void:
	panel.visible = guard.alert_level >= 0 and not guard.player.cinematic_controls_locked
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if panel.visible else SubViewport.UPDATE_DISABLED
	if not panel.visible: return
	var size = get_viewport().get_visible_rect().size
	var scale = size.y/240.0
	var center = Vector2(size.x-size.x/8,size.y/4)
	image.position = center-Vector2(35,40)*scale
	image.size = Vector2(70,40)*scale
	frame.position = image.position
	frame.size = image.size
	frame.modulate = source_color(guard.alert_level)
	portrait.rotation.y = guard.relative_angle
