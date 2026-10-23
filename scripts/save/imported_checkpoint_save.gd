extends Node
class_name ImportedCheckpointSave
var snapshot: Dictionary = {}
var level: ImportedLevel
var restoring = false
var level_id = "lvl_01"
func _ready():
	level = get_parent()
	level_id = str(level.manifest.level)
	level.get_node("Checkpoints").checkpoint_reached.connect(func(_index): if not restoring: call_deferred("capture_checkpoint"))
	call_deferred("initialize")
func initialize():
	var pending = SaveFiles.pending
	if pending.get("restart",false): SaveFiles.pending = {}
	elif pending.get("level") == level_id and SaveFiles.valid(pending):
		SaveFiles.pending = {}
		restore_checkpoint(pending)
	if snapshot.is_empty(): capture_checkpoint()
func capture_checkpoint():
	var player = level.player
	var items: Array = []
	for item in player.inventory.state.items.values():
		if item.get("kept",false): items.append(item.duplicate(true))
	var world = {"items":[],"sheep":[],"mailboxes":[],"rocks":[],"pushables":[],"weighted_platforms":[],"gates":[],"rafts":[],"mobile_platforms":[]}
	for child in level.get_children():
		if child.is_in_group("mobile_platforms"): world.mobile_platforms.append({"resource":int(child.get_meta("original_resource")),"distance":child.distance})
		if child is OriginalRaft: world.rafts.append({"resource":int(child.get_meta("original_resource")),"position":SaveFiles.vector(child.global_position)})
		if child.is_in_group("falling_gates"): world.gates.append({"resource":int(child.get_meta("original_resource")),"opened":child.opened,"latched":child.latched})
		if child is GameItem:
			world.items.append({"id":child.item_id,"position":SaveFiles.vector(child.global_position),"home":SaveFiles.vector(child.home_position),"available":child.available,"deployed":child.deployed,"active":child.active,"respawning":(child is LettuceItem and child.respawn_time > 0) or (child is DynamiteItem and child.state != "idle")})
			if child is OriginalElasticItem: world.items[-1]["elastic"] = child.controller.capture_state()
		if child.is_in_group("pushable_rocks"): world.pushables.append({"resource":int(child.get_meta("original_resource")),"position":SaveFiles.vector(child.global_position),"box_delivered":child.box_delivered})
		if child.is_in_group("weighted_platforms"): world.weighted_platforms.append({"resource":int(child.get_meta("original_resource")),"height":child.position.y})
		if child is OriginalSheep:
			var position = child.respawn_position if child.respawn_position != null else child.home
			world.sheep.append({"resource":child.get_meta("original_resource"),"position":SaveFiles.vector(position)})
		if child is OriginalBreakableRocks: world.rocks.append({"resource":child.definition.res,"broken":child.broken})
		if child is OriginalMailbox:
			var containers: Array = []
			for box in child.boxes:
				if is_instance_valid(box): containers.append({"resource":int(box.get_meta("original_resource",-1)),"position":SaveFiles.vector(box.global_position),"state":box.state,"held":box.held_for_rock})
			world.mailboxes.append({"resource":child.definition.res,"opened":child.opened,"committed":child.committed,"containers":containers})
	var daffy = level.get_node_or_null("DaffyLessons")
	world["controllers"] = {}
	for child in level.get_children():
		if child.is_in_group("checkpoint_controllers"): world.controllers[str(child.name)] = child.capture_world_state()
	var porky = level.get_node_or_null("PorkyLessons")
	snapshot = {"version":SaveFiles.VERSION,"level":level_id,"checkpoint":{"index":level.get_node("Checkpoints").current_index,"position":SaveFiles.vector(player.checkpoint_position),"facing":player.checkpoint_facing,"camera":SaveFiles.vector(player.checkpoint_camera_rotation)},"inventory":items,"world":world,"lessons":{"daffy_finished":daffy.intro_finished if daffy else false,"porky_without":porky.without_sheep_played if porky else false,"porky_with":porky.with_sheep_played if porky else false}}
	if daffy and daffy.has_method("capture_progress"): snapshot.lessons["daffy_state"] = daffy.capture_progress()
	var cinematics = level.get_node_or_null("LevelCinematics")
	if cinematics: snapshot.lessons["cinematics"] = cinematics.capture_progress()
func restore_checkpoint(record: Dictionary) -> bool:
	if not SaveFiles.valid(record) or record.level != level_id: return false
	restoring = true
	OriginalProgress.restore(record.get("progress",{}))
	SaveFiles.remember_checkpoint(record)
	var daffy = level.get_node_or_null("DaffyLessons")
	if daffy:
		for movie in daffy.movies.values():
			if movie.playing: movie.finish_sequence(true)
			movie.played = true
		daffy.active_movie = null
		# Skip entry CIN when loading a checkpoint; lesson progress remains recorded.
		daffy.intro_finished = true
	var player = level.player
	var cinematics = level.get_node_or_null("LevelCinematics")
	if cinematics:
		for movie in cinematics.movies.values():
			if movie.playing: movie.finish_sequence(true)
		cinematics.restore_progress(record.lessons.get("cinematics",{}))
	player.interrupt_actions()
	player.inventory.equipped_id = ""
	player.inventory.state.reset()
	player.checkpoint_position = SaveFiles.to_vector(record.checkpoint.position)
	player.checkpoint_facing = record.checkpoint.facing
	player.checkpoint_camera_rotation = SaveFiles.to_vector(record.checkpoint.camera)
	level.get_node("Checkpoints").current_index = record.checkpoint.index
	player.cinematic_controls_locked = false
	player.respawn_at_checkpoint()
	for child in level.get_children():
		if child.is_in_group("mobile_platforms"):
			for platform in record.world.get("mobile_platforms",[]):
				if int(platform.resource)==int(child.get_meta("original_resource")): child.set_distance(float(platform.distance))
		if child is OriginalRaft:
			for raft in record.world.get("rafts",[]):
				if int(raft.resource)==int(child.get_meta("original_resource")):
					child.global_position = SaveFiles.to_vector(raft.position); child.reset_motion()
		if child.is_in_group("falling_gates"):
			for gate in record.world.get("gates",[]):
				if int(gate.resource)==int(child.get_meta("original_resource")): child.restore_state(bool(gate.opened),bool(gate.latched))
		if child.is_in_group("weighted_platforms"):
			for platform in record.world.get("weighted_platforms",[]):
				if int(platform.resource)==int(child.get_meta("original_resource")): child.set_height(float(platform.height))
		if child.is_in_group("pushable_rocks"):
			for rock in record.world.get("pushables",[]):
				if int(rock.resource) == int(child.get_meta("original_resource")):
					child.global_position = SaveFiles.to_vector(rock.position)
					child.box_delivered = bool(rock.get("box_delivered",false))
		if child is GameItem:
			for item in record.world.items:
				if item.id == child.item_id:
					child.home_position = SaveFiles.to_vector(item.home)
					child.restore()
					child.global_position = SaveFiles.to_vector(item.position)
					child.available = item.available
					child.visible = item.available
					child.deployed = item.get("deployed",false)
					child.active = item.get("active",false) and child.deployed
					if item.get("respawning",false):
						child.global_position = child.home_position
						child.available = true
						child.show()
		if child is OriginalSheep:
			for sheep in record.world.sheep:
				if int(sheep.resource) == int(child.get_meta("original_resource")):
					child.respawn_position = SaveFiles.to_vector(sheep.position)
					child.reset_to_home()
		if child is OriginalBreakableRocks:
			for rock in record.world.get("rocks",[]):
				if int(rock.resource) == int(child.definition.res): child.restore_saved_state(rock.broken)
		if child is OriginalMailbox:
			for mailbox in record.world.mailboxes:
				if int(mailbox.resource) == int(child.definition.res):
					child.opened = mailbox.opened
					child.committed = mailbox.committed
					child.restore_containers(mailbox.get("containers",[]))
					if child.opened:
						child.animation_time = float(child.visual.rig.animations.letter1.duration)
						child.previous_time = child.animation_time
						child.visual.sample_animation("letter1",child.animation_time)
	var pickups = {}
	for child in level.get_children():
		if child is GameItem: pickups[child.item_id] = child
	for item in record.inventory:
		var pickup = pickups.get(item.id)
		if is_instance_valid(pickup): pickup.store()
		player.inventory.add_item(item,pickup,false)
	player.inventory.state.clear_selection()
	for child in level.get_children():
		if child is OriginalElasticItem:
			for item in record.world.items:
				if item.id==child.item_id: child.controller.restore_saved_state(item.get("elastic",{}))
	var porky = level.get_node_or_null("PorkyLessons")
	if porky:
		porky.active_movie = null
		porky.without_sheep_played = record.lessons.get("porky_without",false)
		porky.with_sheep_played = record.lessons.get("porky_with",false)
		if porky.with_sheep_played:
			for i in range(porky.salads.size()):
				if player.inventory.state.items.has(porky.salads[i].item_id): porky.revealed[i] = true
				else: porky.show_salad(i)
	for child in level.get_children():
		if child is OriginalTimeKeeper: child.state = child.State.COLLECTED if OriginalProgress.has_clock(child.level_id) else child.State.AVAILABLE
	var checkpoints = level.get_node("Checkpoints")
	var index = int(record.checkpoint.index)
	if index >= 0 and checkpoints.entries[index]["disable_earlier"]:
		for i in range(index): checkpoints.entries[i]["triggers"] = []
	player.cinematic_controls_locked = false
	if daffy and daffy.has_method("restore_progress"):
		daffy.restore_progress(record.lessons.get("daffy_state",{}))
	snapshot = record.duplicate(true)
	# Restore the encounter first; individual mine states then override deployment defaults.
	var controllers = record.world.get("controllers",{})
	for identity in controllers:
		var child = level.get_node_or_null(NodePath(identity))
		if child and not child is OriginalDefusableMine: child.restore_world_state(controllers[identity])
	for identity in controllers:
		var child = level.get_node_or_null(NodePath(identity))
		if child is OriginalDefusableMine: child.restore_world_state(controllers[identity])
	restoring = false
	return true
