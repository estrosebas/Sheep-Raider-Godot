extends Node3D
# Original MCardManager/BonusManager MSG_QUERY_ACTION: Manhattan XZ <300 units.
var definition: Dictionary
var visual: OriginalCinematicActor
var camera: Camera3D
var previous_camera: Camera3D
func _ready():
	visual = load("res://assets/levels/scene/models/%d/worn.tscn"%int(definition.model_res)).instantiate()
	add_child(visual); visual.idle("stand")
	add_to_group("world_interactables")
	add_to_group("studio_pedestals")
	set_meta("original_resource",int(definition.res))
	set_meta("original_class",definition.class_name)
	camera = Camera3D.new(); add_child(camera)
func activate_camera():
	previous_camera = get_viewport().get_camera_3d()
	var record = definition.camera
	camera.global_position = GameSpace.original_point(Vector3(record.eye[0],record.eye[1],record.eye[2]))
	camera.global_rotation = Vector3(-record.rotation[0],record.rotation[1],-record.rotation[2])*TAU/4096
	camera.fov = rad_to_deg(2*atan(384.0/float(record.focal)))
	camera.current = true
func can_interact(actor: RalphController) -> bool:
	var gap = actor.global_position-global_position
	return actor.can_use_item() and absf(gap.x)+absf(gap.z)<3.0 and absf(gap.y)<2.0
func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	activate_camera()
	if int(definition.class_id)==98:
		var menu = get_parent().get_node("PauseMenu")
		menu.open_menu(); menu.show_page("save")
	else: get_parent().get_node("Bonuses").open_menu(definition)
	return true
func _process(_delta: float):
	if not camera.current: return
	var opened = get_parent().get_node("PauseMenu").opened if int(definition.class_id)==98 else get_parent().get_node("Bonuses").opened
	if not opened:
		release_camera()
func release_camera():
	if not camera.current: return
	if is_instance_valid(previous_camera): previous_camera.current = true
	else: get_parent().player.camera.current = true
