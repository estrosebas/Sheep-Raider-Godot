extends Node
class_name LevelCheckpointSave

var snapshot: Dictionary = {}
var restoring = false
var level: Node3D

func _ready() -> void:
	level = get_parent()
	level.get_node("TutorialProgress").checkpoint_reached.connect(_checkpoint_reached)
	call_deferred("_apply_pending")

func _checkpoint_reached(_index: int) -> void:
	# Capture after mailbox checkpoint listeners commit; never writes a file here.
	if not restoring: capture_checkpoint()

func capture_checkpoint() -> void:
	var progress = level.get_node("TutorialProgress")
	if progress.checkpoint_index < 0: return
	var training = level.get_node("CameraTraining")
	var puzzle = level.get_node("TutorialPuzzle")
	var items: Array = []
	for entry in level.get_node("Player").inventory.state.items.values():
		if entry.get("kept",false): items.append(entry.duplicate(true))
	var falling: Array = []
	for key in progress.rocks:
		falling.append({"resource":int(key),"active":progress.rocks[key]["active"]})
	var mailboxes: Array = []
	var world_items: Array = []
	for child in level.get_children():
		if child is OriginalMailbox: mailboxes.append({"resource":int(child.definition["res"]),"opened":child.opened,"committed":child.committed})
		if child is GameItem: world_items.append({"id":child.item_id,"position":SaveFiles.vector(child.global_position),"home":SaveFiles.vector(child.home_position),"available":child.available})
	var rocks: Array = []
	for rock in puzzle.rocks:
		rocks.append({"resource":int(rock.definition["res"]),"position":SaveFiles.vector(rock.global_position)})
	var platforms: Dictionary = {}
	for key in training.director.persistent_platforms: platforms[key] = bool(training.director.persistent_platforms[key])
	snapshot = {"version":SaveFiles.VERSION,"level":"lvl_00",
		"checkpoint":{"index":progress.checkpoint_index,"reached":progress.reached.keys()},
		"inventory":items,
		"training":{"index":training.step_index,"phase":int(training.phase),"position":SaveFiles.vector(training.actor.global_position),"yaw":training.actor.rotation.y,"race_finished":training.race_finished},
		"world":{"falling":falling,"mailboxes":mailboxes,"items":world_items,"rocks":rocks,"platforms":platforms,"gate_open":puzzle.gate_open}}

func _apply_pending() -> void:
	var pending = SaveFiles.pending
	SaveFiles.pending = {}
	if SaveFiles.valid(pending) and pending.level == "lvl_00": restore_checkpoint(pending)

func restore_checkpoint(record: Dictionary) -> bool:
	if not SaveFiles.valid(record) or record.level != "lvl_00": return false
	restoring = true
	OriginalProgress.restore(record.get("progress",{}))
	SaveFiles.remember_checkpoint(record)
	var progress = level.get_node("TutorialProgress")
	var player = level.get_node("Player")
	var training = level.get_node("CameraTraining")
	var director = level.get_node("TutorialIntro")
	var puzzle = level.get_node("TutorialPuzzle")
	player.interrupt_actions()
	director.played = true
	director.playing = false
	director.set_process(false)
	training.voice.stop()
	training.card.hide()
	training.crosshair.hide()
	training.race_active = false
	training.race_armed = false
	training.race_finished = record["training"].get("race_finished",false)
	training.step_index = clampi(int(record["training"]["index"]),0,training.data["slots"].size())
	# Resume the checkpoint's tutorial stage rather than replaying a half spoken line.
	training.phase = training.Phase.WAIT_STAGE if training.step_index < training.data["slots"].size() else training.Phase.COMPLETE
	training.actor.global_position = SaveFiles.to_vector(record["training"]["position"])
	training.actor.rotation.y = float(record["training"]["yaw"])
	training.actor.show()
	training.actor.idle("stand1")
	level.get_node("DaffyDuck").hide()
	for key in record["world"]["platforms"]:
		if director.actors.has(key):
			director.persistent_platforms[key] = bool(record["world"]["platforms"][key])
			director.actors[key].movie_visibility(bool(record["world"]["platforms"][key]))
	progress.reached.clear()
	for index in record["checkpoint"]["reached"]: progress.reached[int(index)] = true
	progress.activate_checkpoint(int(record["checkpoint"]["index"]))
	for saved in record["world"]["falling"]:
		var rock = progress.rocks.get(int(saved["resource"]))
		if rock == null: continue
		rock["active"] = bool(saved["active"])
		rock["ticks"] = 5 if rock["active"] else 0
		rock["elapsed"] = 0
		rock["body"].position = rock["home"]
		rock["body"].visible = rock["active"]
		for shape in rock["body"].get_children():
			if shape is CollisionShape3D: shape.set_deferred("disabled",not rock["active"])
	for child in level.get_children():
		if not child is OriginalMailbox: continue
		for saved in record["world"]["mailboxes"]:
			if int(saved["resource"]) == int(child.definition["res"]):
				child.opened = bool(saved["opened"])
				child.committed = bool(saved["committed"])
				child.animation_time = 10 if child.opened else 0
	for rock in puzzle.rocks:
		for saved in record["world"]["rocks"]:
			if int(saved["resource"]) == int(rock.definition["res"]):
				rock.global_position = SaveFiles.to_vector(saved["position"])
				rock.velocity = Vector3.ZERO
				rock.arc.clear()
	puzzle.gate_open = bool(record["world"]["gate_open"])
	puzzle.pressed = puzzle.gate_open
	puzzle.gate_clip = "open" if puzzle.gate_open else "closed"
	puzzle.gate_shape.set_deferred("disabled",puzzle.gate_open)
	puzzle.gate.visible = not puzzle.gate_open
	player.inventory.state.reset()
	for saved in record["world"]["items"]:
		for child in level.get_children():
			if child is GameItem and child.item_id == saved["id"]:
				child.home_position = SaveFiles.to_vector(saved["home"])
				child.global_position = SaveFiles.to_vector(saved["position"])
				child.available = bool(saved["available"])
				child.visible = child.available
	for entry in record["inventory"]:
		var item = player.inventory.pickup_nodes.get(str(entry["id"]))
		if item == null:
			for child in level.get_children():
				if child is GameItem and child.item_id == str(entry["id"]): item = child
		if item:
			item.owning_inventory = player.inventory
			item.available = false
			player.inventory.add_item(entry,item,false)
			item.store()
	player.inventory.state.clear_selection()
	player.inventory.equipped_id = ""
	player.inventory.equipped_node = null
	player.tutorial_movement_locked = false
	player.cinematic_controls_locked = false
	player.respawn_at_checkpoint()
	player.restart_fade_remaining = 1
	player.restart_fade.set_amount(1)
	if int(record["checkpoint"]["index"]) == 0 and training.step_index == 0:
		# BOX 642 may fire at the start line before CIN1 has positioned Lucas.
		director.sample(float(director.data["duration"]))
		for key in director.actors:
			if key != "2:56": director.actors[key].movie_visibility(false)
		training.actor.show()
		training.actor.idle("stand1")
		training._show_dialogue(0)
	else:
		var phase = int(record["training"].get("phase",training.Phase.WAIT_STAGE))
		if phase in [training.Phase.DIALOGUE,training.Phase.LOOK,training.Phase.DEMO]: training._show_dialogue(training.step_index)
		elif phase == training.Phase.MOVING: training._begin_move()
		else: training._enter_stage(training.step_index)
	snapshot = record.duplicate(true)
	restoring = false
	return true
