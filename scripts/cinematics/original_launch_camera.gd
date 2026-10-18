extends Node3D
# CamShot::Start/Update: native CamSetup, allow skip after1000ms, release Wolf.
var definition: Dictionary
var player: RalphController
var no_freeze = false
var camera: Camera3D
var previous: Camera3D
var was_locked = false
var elapsed = 0.0
var following_player_launch = false
var closed = false
func _ready():
	add_to_group("original_launch_camera")
	previous = get_viewport().get_camera_3d()
	was_locked = player.launch_controls_locked
	if not no_freeze: player.launch_controls_locked = true
	following_player_launch = player.seesaw_launching
	camera = Camera3D.new(); add_child(camera)
	camera.global_position = GameSpace.original_point(Vector3(definition.eye[0],definition.eye[1],definition.eye[2]))
	camera.global_rotation = Vector3(-definition.rotation[0],definition.rotation[1],-definition.rotation[2])*TAU/4096
	camera.fov = rad_to_deg(2*atan(384.0/float(definition.focal)))
	camera.current = true
	player.respawned.connect(close)
func _process(delta):
	elapsed += delta
	if player.seesaw_launching: following_player_launch = true
	# Native MSG_FREEZE masks input; it does not stop gravity. Once Ralph
	# really lands, return the free camera without requiring an extra key.
	if following_player_launch and not player.seesaw_launching and elapsed>=1 and player.is_on_floor() and player.current_state in [player.WolfState.IDLE,player.WolfState.LAND,player.WolfState.WALK,player.WolfState.SNEAK]: close()
	if player.current_state in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH]: close()
func _unhandled_input(event: InputEvent):
	if elapsed>=1 and (event.is_action_pressed("action") or event.is_action_pressed("cancel") or event.is_action_pressed("jump")) and not event.is_echo():
		close(); get_viewport().set_input_as_handled()
func close():
	if closed: return
	closed = true
	if camera.current:
		if is_instance_valid(previous): previous.current = true
		else: player.camera.current = true
	if not no_freeze: player.launch_controls_locked = was_locked
	queue_free()
