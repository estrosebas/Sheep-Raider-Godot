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
var subject: Node3D
var saw_subject_flight = false
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
func track_subject(actor: Node3D):
	subject = actor; saw_subject_flight = subject_in_flight(); elapsed = 0

func subject_in_flight() -> bool:
	if not is_instance_valid(subject): return false
	if subject is RalphController: return subject.seesaw_launching
	if subject is OriginalSheep: return not subject.seesaw_arc.is_empty()
	return not subject.arc.is_empty()

func _process(delta):
	if not GameLocalization.camera_assists_enabled(): close(); return
	elapsed += delta
	if player.current_state in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH]: close(); return
	if player.seesaw_launching: following_player_launch = true
	if is_instance_valid(subject) and subject!=player:
		saw_subject_flight = saw_subject_flight or subject_in_flight()
		# Native CamShot waits for a skip after1s. With a free gameplay camera,
		# release it automatically when the actual sheep/rock flight is over too.
		if elapsed>=1 and saw_subject_flight and not subject_in_flight(): close()
		return
	# Native MSG_FREEZE masks input; it does not stop gravity. Once Ralph
	# really lands, return the free camera without requiring an extra key.
	if following_player_launch and not player.seesaw_launching and elapsed>=1 and player.is_on_floor() and player.current_state in [player.WolfState.IDLE,player.WolfState.LAND,player.WolfState.WALK,player.WolfState.SNEAK]: close()
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
