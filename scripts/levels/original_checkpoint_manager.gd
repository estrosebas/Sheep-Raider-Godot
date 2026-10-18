extends Node
class_name OriginalCheckpointManager

# CheckpointManager::Update/PostLoadInit. These are runtime respawn points;
# saving to disk remains an explicit action in the pause menu.
var player: RalphController
var flock: OriginalFlock
var entries: Array
var quiet_time = 0.0
var current_index = -1
signal checkpoint_reached(index: int)

func _ready() -> void:
	player = get_parent().get_node("Player")
	flock = get_parent().get_node("Flock")
	entries = JSON.parse_string(FileAccess.get_file_as_string(get_parent().asset_directory+"/data/checkpoints.json"))["entries"]
	player.checkpoint_position = player.global_position
	player.checkpoint_facing = player.skeleton.rotation.y
	player.checkpoint_camera_rotation = player.camera_pivot.rotation
	player.respawned.connect(func(): quiet_time = 0)

func entry_at(point: Vector3, destination: String) -> int:
	for i in range(entries.size()):
		if not entries[i][destination].is_empty() and OriginalSam.contains(point,entries[i]["triggers"]): return i
	return -1

func destination_point(box: Dictionary) -> Vector3:
	var center = Vector3.ZERO
	for axis in range(3): center[axis] = floor((float(box["min"][axis])+float(box["max"][axis]))*.5)
	return player.respawn_ground_position(GameSpace.original_point(center))

func _physics_process(delta: float) -> void:
	if flock.guard.state in [OriginalSam.State.CHASE,OriginalSam.State.CATCH]:
		quiet_time = 0
		return
	quiet_time += delta
	if quiet_time < 2 or player.cinematic_controls_locked or player.current_state in [player.WolfState.SAM_DEATH,player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH] or player.restart_fade_remaining > 0: return
	var wolf_entry = entry_at(player.global_position,"wolf")
	var sheep = flock.outside_sheep
	var sheep_entry = entry_at(sheep.goal_position(),"sheep") if is_instance_valid(sheep) else -1
	if wolf_entry >= 0 and (wolf_entry == sheep_entry or not entries[wolf_entry]["joint"]):
		var entry: Dictionary = entries[wolf_entry]
		player.checkpoint_position = destination_point(entry["wolf"][0])
		player.inventory.state.commit_at_checkpoint()
		for object in get_parent().get_children():
			if object is OriginalMailbox: object.commit()
		player.checkpoint_facing = -float(entry["yaw"])*TAU/4096
		player.checkpoint_camera_rotation = Vector3(0,player.checkpoint_facing+PI,0)
		if entry["disable_earlier"]:
			for i in range(wolf_entry): entries[i]["triggers"] = []
	if sheep_entry >= 0 and (wolf_entry == sheep_entry or not entries[sheep_entry]["joint"]):
		sheep.respawn_position = destination_point(entries[sheep_entry]["sheep"][0])

	if wolf_entry >= 0 and (wolf_entry == sheep_entry or not entries[wolf_entry]["joint"]) and current_index != wolf_entry:
		current_index = wolf_entry
		checkpoint_reached.emit(wolf_entry)
