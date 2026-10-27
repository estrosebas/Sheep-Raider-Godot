extends OriginalNpcConversation
# DaffyMilitary: thaw -> native CIN1 -> three lessons; a blast chars him and
# the next conversation plays his original, unskippable punishment once.
var movie: OriginalLevelSequence
var movies: Dictionary = {}
var ice: Node3D
var solid: StaticBody3D
var thaw_pending = false
var talk_elapsed = 0.0
var frozen_transform: Transform3D

func _ready():
	data_path = "res://assets/levels/lvl_06/data/daffy.json"
	actor_prefix = "DaffyMilitary"
	intro_finished = false
	super._ready()
	daffy.idle_clip = ""; daffy.set_process(false); daffy.sample_animation("stand1",0)
	solid = get_parent().get_node("OriginalObjectCollisions/DaffyMilitary_55")
	solid.collision_layer = 0
	frozen_transform = daffy.global_transform
	ice = preload("res://scripts/levels/original_ice_thaw.gd").new()
	ice.name = "IceThaw"; add_child(ice)
	ice.configure(get_parent().get_node("IceCube_56"),get_parent().get_node("OriginalObjectCollisions/IceCube_56"))
	ice.thawed.connect(func(): thaw_pending = true)
	movie = OriginalLevelSequence.new()
	movie.sequence_path = "res://assets/levels/lvl_06/cinematics/sequence_1.json"
	movie.allow_skip = true; movie.apply_empty_visibility_defaults = true
	# The use press which ends blowing must not immediately dismiss the lesson.
	movie.skip_input_delay = 1.0
	add_child(movie); movie.bind_player(player)
	movies[1] = movie
	movie.finished.connect(_lesson_finished)
	player.respawned.connect(_reset_lesson)

func _process(delta: float):
	if active_movie: return
	if thaw_pending and not player.cinematic_controls_locked and player.restart_fade_remaining<=0:
		player.interrupt_actions()
		# MSG_STRIP stores the tool, retaining it in the inventory.
		player.inventory.state.clear_selection()
		player.inventory.equipped_id = ""
		player.inventory._equip_world_item({})
		if movie.start_sequence():
			active_movie = movie; thaw_pending = false; solid.collision_layer = 1
		return
	if not intro_finished: return
	global_position = daffy.global_position
	if speaking:
		talk_elapsed += delta
		var clip = "talk1" if talk_elapsed >= 2 else "stand2"
		if daffy.idle_clip != clip: daffy.idle(clip)
	else:
		if daffy.is_processing() and daffy.idle_clip != "stand2": daffy.idle("stand2")
	if speaking or menu.visible:
		var difference = player.global_position-daffy.global_position
		daffy.rotation.y = rotate_toward(daffy.rotation.y,atan2(difference.x,difference.z),TAU*1.5*delta)

func _lesson_finished(_skipped: bool):
	active_movie = null; intro_finished = true
	daffy.set_process(true); daffy.idle("stand2")
	# The native cinematic can move him away from the former ice block.
	solid.global_position = daffy.global_position
	global_position = daffy.global_position

func interact(actor: RalphController) -> bool:
	var accepted = super.interact(actor)
	if accepted: daffy.set_process(true); daffy.idle("stand2")
	return accepted

func say(answer: Dictionary,skippable: bool = true):
	talk_elapsed = 0
	super.say(answer,skippable and answer != data.burnt)
	daffy.set_process(true); daffy.idle("stand2")

func _voice_finished():
	super._voice_finished()
	daffy.set_process(true); daffy.idle("stand2")

func on_blast(point: Vector3):
	if not intro_finished or active_movie or speaking or menu.visible: return
	super.on_blast(point)
	daffy.idle_clip = ""; daffy.set_process(false)

func reset_burnt():
	super.reset_burnt()
	if intro_finished: daffy.set_process(true); daffy.idle("stand2")

func _reset_lesson():
	# Native Reset refreezes him if interrupted outside the free IDLE state.
	var interrupted = is_instance_valid(active_movie) or speaking or menu.visible
	if is_instance_valid(active_movie): movie.finish_sequence(true)
	voice.stop(); dialogue.close(); speaking = false; menu.hide()
	thaw_pending = false
	if interrupted or not intro_finished:
		intro_finished = false; movie.played = false
		ice.reset_frozen(); solid.collision_layer = 0
		daffy.global_transform = frozen_transform
		solid.global_position = daffy.global_position; global_position = daffy.global_position
		daffy.idle_clip = ""; daffy.set_process(false); daffy.sample_animation("stand1",0)

func capture_progress() -> Dictionary:
	return {"intro_finished":intro_finished,"ice":ice.capture_state(),"burnt":burnt,"punished":burnt_line_said,"position":SaveFiles.vector(daffy.global_position),"rotation":daffy.rotation.y}

func restore_progress(saved: Dictionary):
	if is_instance_valid(active_movie): movie.finish_sequence(true)
	voice.stop(); dialogue.close(); speaking = false; menu.hide()
	player.cinematic_controls_locked = false
	daffy.global_transform = frozen_transform
	intro_finished = saved.get("intro_finished",false)
	thaw_pending = false; movie.played = intro_finished
	ice.restore_state({"melted":intro_finished or saved.get("ice",{}).get("melted",false)})
	if saved.has("position"): daffy.global_position = SaveFiles.to_vector(saved.position)
	daffy.rotation.y = float(saved.get("rotation",daffy.rotation.y))
	solid.global_position = daffy.global_position; solid.collision_layer = 1 if intro_finished else 0
	daffy.set_process(intro_finished); daffy.idle("stand2" if intro_finished else "")
	if not intro_finished: daffy.sample_animation("stand1",0)
	burnt = false; burnt_line_said = saved.get("punished",false)
	OriginalBurntTint.apply(daffy.legacy_skin,false)
	if saved.get("burnt",false): on_blast(Vector3.ZERO)
	thaw_pending = ice.melted and not intro_finished
