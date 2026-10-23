extends Node

# FallingGate::MSG_SWITCH_ON uses CamSetup; modelIndex >=10 keeps the view
# until SWITCH_OFF. The free-camera port shows it only for Ralph's button,
# so a distant sheep pressing a switch cannot steal his view or freeze him.
var button: OriginalPressureButton
var player: RalphController
var definition: Dictionary
var camera: Camera3D
var previous: Camera3D
var saved_pivot_rotation = Vector3.ZERO
var active = false
var interrupted = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	camera = Camera3D.new()
	camera.name = "GateCamera"
	add_child(camera)
	camera.global_position = GameSpace.original_point(Vector3(definition.eye[0],definition.eye[1],definition.eye[2]))
	camera.global_rotation = Vector3(-definition.rotation[0],definition.rotation[1],-definition.rotation[2])*TAU/4096
	camera.fov = rad_to_deg(2*atan(384.0/float(definition.focal)))
	if is_instance_valid(player): player.respawned.connect(close)

func update_view() -> void:
	if not is_instance_valid(player): return
	var occupied = button.pressed and button.occupants.has(player)
	var unavailable = player.cinematic_controls_locked or player.launch_controls_locked or player.restart_fade_remaining>0 or player.current_state in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH]
	if not occupied:
		close()
		interrupted = false
		return
	if unavailable:
		close()
		return
	if active:
		if get_viewport().get_camera_3d()!=camera:
			# Never reclaim a camera taken by a conversation, death or another shot.
			interrupted = true
			close()
		return
	if interrupted or get_viewport().get_camera_3d()!=player.camera: return
	previous = player.camera
	saved_pivot_rotation = player.camera_pivot.rotation
	active = true
	camera.make_current()

func close() -> void:
	if not active: return
	active = false
	if is_instance_valid(player): player.camera_pivot.rotation = saved_pivot_rotation
	if camera.is_current():
		if is_instance_valid(previous): previous.make_current()
		elif is_instance_valid(player): player.camera.make_current()

func _exit_tree() -> void:
	close()
