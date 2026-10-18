extends Node3D
class_name OriginalTelescope
var definition: Dictionary
var actor: RalphController
var viewing = false
var camera: Camera3D
var visual: OriginalCinematicActor
var previous_camera: Camera3D
var heading = 0.0
var pitch = 0.0
var reverse = false
var ui: CanvasLayer
var optical_anchor = Vector3.ZERO
var was_actor_visible = true

class TelescopeMask extends Control:
	var outer: Texture2D
	var inner: Texture2D
	func _ready() -> void:
		outer = load("res://assets/ui/telescope/outer.png")
		inner = load("res://assets/ui/telescope/inner.png")
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if outer == null: return
		var scale = minf(size.x/512,size.y/240)
		var offset = (size-Vector2(512,240)*scale)/2
		var tile = outer.get_size()*1.5
		var origin = (Vector2(512,240)-tile*Vector2(4,2))/2
		draw_rect(Rect2(0,0,size.x,offset.y+origin.y*scale),Color.BLACK)
		draw_rect(Rect2(0,offset.y+(origin.y+tile.y*2)*scale,size.x,size.y),Color.BLACK)
		draw_rect(Rect2(0,0,offset.x+origin.x*scale,size.y),Color.BLACK)
		draw_rect(Rect2(offset.x+(origin.x+tile.x*4)*scale,0,size.x,size.y),Color.BLACK)
		for row in range(2):
			for col in range(4):
				var xflip = col >= 2
				var yflip = row == 1
				var position = offset+(origin+Vector2(col,row)*tile)*scale
				draw_set_transform(position+Vector2(tile.x*scale if xflip else 0,tile.y*scale if yflip else 0),0,Vector2(-scale if xflip else scale,-scale if yflip else scale))
				draw_texture_rect(outer if col in [0,3] else inner,Rect2(Vector2.ZERO,tile),false)
		draw_set_transform(Vector2.ZERO)
func _ready() -> void:
	visual = load(definition["directory"]+"/worn.tscn").instantiate()
	add_child(visual)
	var meshes = visual.find_children("*","MeshInstance3D",true,false)
	if not meshes.is_empty():
		var bounds: AABB = meshes[0].mesh.get_aabb()
		optical_anchor = Vector3(bounds.get_center().x,bounds.position.y+bounds.size.y*.85,bounds.get_center().z)
	camera = Camera3D.new()
	add_child(camera)
	add_to_group("world_interactables")
	var hint = Label3D.new()
	hint.text = "E · Telescopio"
	hint.position.y = 1.5
	hint.pixel_size = .005
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(hint)
	hint.hide()
	ui = CanvasLayer.new()
	ui.layer = 50
	add_child(ui)
	var mask = TelescopeMask.new()
	ui.add_child(mask)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.hide()
func can_interact(player: Node3D) -> bool:
	if viewing or not player.can_use_item() or not player.is_on_floor(): return false
	if definition.get("reverse_box") != null and TutorialProgress.contains(definition["reverse_box"],player.global_position):
		reverse = true
		return true
	reverse = false
	if definition.get("normal_box") != null: return TutorialProgress.contains(definition["normal_box"],player.global_position)
	return player.global_position.distance_to(global_position) < 2
func interact(player: Node3D) -> bool:
	if not can_interact(player): return false
	actor = player
	previous_camera = get_viewport().get_camera_3d()
	actor.interrupt_actions()
	actor.cinematic_controls_locked = true
	was_actor_visible = actor.visible
	actor.hide()
	heading = rotation.y+(0 if reverse else PI)
	pitch = 0
	camera.fov = rad_to_deg(2*atan(384.0/(2*float(definition["props"]["0x24" if reverse else "0x1c"]))))
	viewing = true
	visual.hide()
	ui.show()
	_update_camera()
	camera.current = true
	return true
func _process(delta: float) -> void:
	if not viewing: return
	var input = Input.get_vector("move_left","move_right","move_forward","move_backward")
	var rate = 600.0*TAU/4096
	var yaw_limit = float(definition["props"]["0x10"])*11*TAU/4096
	var pitch_limit = float(definition["props"]["0x14"])*11*TAU/4096
	var base_yaw = rotation.y+(0 if reverse else PI)
	heading = clampf(heading-input.x*rate*delta,base_yaw-yaw_limit,base_yaw+yaw_limit)
	pitch = clampf(pitch-input.y*rate*delta,-pitch_limit,pitch_limit)
	_update_camera()
func _update_camera() -> void:
	camera.global_rotation = Vector3(pitch,heading,0)
	# Adapt the original distant scripted view to a view through the actual
	# instrument. Steering changes its direction, never its optical origin.
	camera.global_position = global_transform*optical_anchor
func _input(event: InputEvent) -> void:
	if viewing and event.is_action_pressed("action") and not event.is_echo():
		close()
		# Closing releases the lock. Consume this same E so InventoryComponent
		# cannot immediately interact with the telescope again in this frame.
		get_viewport().set_input_as_handled()
func close() -> void:
	viewing = false
	ui.hide()
	visual.show()
	actor.cinematic_controls_locked = false
	actor.visible = was_actor_visible
	if is_instance_valid(previous_camera): previous_camera.current = true
