extends CanvasLayer
class_name OriginalActionPrompt

var actor: RalphController
var target: Node3D
var text = ""
var timer = 0.0
var icon: Texture2D
var canvas: PromptCanvas

class PromptCanvas extends Control:
	var prompt: OriginalActionPrompt
	var background: Texture2D
	var font: Texture2D
	func _draw() -> void:
		if prompt.timer <= 0 or prompt.text.is_empty(): return
		var scale = minf(size.x/512,size.y/240)
		var remaining = 1-prompt.timer/.5
		var phase = pow(floor(prompt.timer*64),2)
		# Wolf::DrawActionPrompt: 2048 ticks of cosine squash/stretch.
		var dx = -remaining*cos(phase*44/7*TAU/4096)*24
		var dy = -remaining*cos(phase*4*TAU/4096)*12
		var width = prompt.text.length()*9+48+(24 if prompt.icon else 0)
		var rect = Rect2(16-dx,16-dy,width+2*dx,31+2*dy)
		draw_set_transform(rect.position*scale,0,Vector2(rect.size.x/width,rect.size.y/31)*scale)
		# Original g_uiTintColor = 0xa05050 (packed BGR).
		draw_texture_rect(background,Rect2(0,0,width,31),false,Color(80.0/255,80.0/255,160.0/255))
		draw_style_box(_key_box(),Rect2(10,6,18,19))
		glyphs("E",Vector2(14,9),Color.WHITE)
		var x = 35.0
		if prompt.icon:
			draw_texture_rect(prompt.icon,Rect2(x,5,22,22),false)
			x += 25
		glyphs(prompt.text,Vector2(x,9),Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	func _key_box() -> StyleBoxFlat:
		var box = StyleBoxFlat.new()
		box.bg_color = Color(0,0,0,.55)
		box.border_color = Color(.8,.9,1)
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		return box
	func glyphs(value: String,position: Vector2,color: Color):
		for i in range(value.length()):
			var code = clampi(value.unicode_at(i),32,255)-32
			draw_texture_rect_region(font,Rect2(position+Vector2(i*9,0),Vector2(9,13)),Rect2((code%16)*16,int(code/16)*16,15,15),color)

func _ready() -> void:
	actor = get_parent()
	layer = 25
	process_priority = 200
	canvas = PromptCanvas.new()
	canvas.prompt = self
	canvas.background = load("res://assets/ui/action_prompt/background.png")
	canvas.font = load("res://assets/ui/pause/font.png")
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lettuce = OriginalLettucePrompt.new()
	lettuce.actor = actor
	add_child(lettuce)

func label_for(node: Node3D) -> String:
	if node.has_method("action_label"): return node.action_label(actor)
	if node.is_in_group("pushable_rocks"): return GameLocalization.text("lvl_01",0,0x2a)
	if node.is_in_group("bushes"): return GameLocalization.text("lvl_01",0,0x2d)
	if node is OriginalWorldNote: return GameLocalization.ui("Leer nota")
	if node is GameItem: return GameLocalization.text("lvl_01",0,0x36 if node.holder == actor else 0x27)
	if node is OriginalSheep: return GameLocalization.text("lvl_01",0,0x36 if node.carried_by else 0x29)
	if node is OriginalMailbox: return GameLocalization.ui("Solicitar envio")
	if node is OriginalTimeKeeper: return GameLocalization.ui("Usar reloj secreto")
	if node is OriginalTelescope: return GameLocalization.ui("Mirar por telescopio")
	if node is OriginalSignposts or node is OriginalWorldNote: return GameLocalization.ui("Leer cartel") if node is OriginalSignposts else GameLocalization.ui("Leer nota")
	if node is OriginalNpcConversation: return GameLocalization.ui("Hablar con Porky") if node is OriginalLevel01Porky else GameLocalization.ui("Hablar con Lucas")
	if node is LabLevelDoor: return GameLocalization.ui("Entrar al ")+node.level_label
	return GameLocalization.ui("Interactuar")

func _process(delta: float) -> void:
	if not actor.can_use_item() or actor.inventory.wheel_open or actor.inventory_controls_locked:
		target = null
		timer = 0
		canvas.queue_redraw()
		return
	var next = actor.inventory.interaction_target()
	if next == null and actor.inventory.equipped_node is LettuceItem: next = actor.inventory.equipped_node
	if next == target and next and next.has_method("action_label"): text = label_for(next)
	if next != target:
		target = next
		if next:
			text = label_for(next)
			icon = load(next.icon_path) if next is GameItem and not next.icon_path.is_empty() else null
	if next: timer = minf(.5,timer+delta)
	else: timer = maxf(0,timer-delta)
	canvas.queue_redraw()

func reload_localization():
	if is_instance_valid(target): text = label_for(target)
	canvas.queue_redraw()
