extends Node
# Shared victory flow for the tutorial and imported levels.
signal finished(save_error: int)
var player: RalphController
var sheep: OriginalSheep
var running = false
var done = false
var save_error = OK

func begin(level_id: String,goal_sheep: OriginalSheep):
	if running or done: return
	running = true
	player = get_parent().get_node("Player")
	sheep = goal_sheep
	OriginalProgress.complete_level(level_id)
	player.interrupt_actions()
	player.set_state(player.WolfState.IDLE)
	sheep.velocity = Vector3.ZERO
	sheep.sheep_audio.stop()
	sheep.set_physics_process(false)
	if sheep.carried_by==player and sheep.put_down_at_goal(_finish): return
	_finish()

func _finish():
	player.cinematic_controls_locked = true
	player.inventory.state.commit_at_checkpoint()
	save_error = SaveFiles.save_level_completion(get_parent())
	done = true; running = false
	finished.emit(save_error)
	if save_error!=OK: push_warning("Level autosave failed: %d" % save_error)
	call_deferred("return_to_studio")

func return_to_studio():
	SaveFiles.remember_level_exit(get_parent())
	var transitions = get_node_or_null("/root/LanguageMenu")
	if transitions: transitions.change_scene(SaveFiles.STUDIO_SCENE)
	else: get_tree().change_scene_to_file(SaveFiles.STUDIO_SCENE)
