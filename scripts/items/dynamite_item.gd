extends GameItem
class_name DynamiteItem
signal exploded(point: Vector3)
@export var fuse_seconds = 5.0
@export_file("*.tscn") var original_scene = "res://assets/items/dynamite/worn.tscn"
var fuse = 0.0
var state = "idle"
var elapsed = 0.0
var actor_visual: OriginalCinematicActor
var explosion: OriginalCinematicActor
var sparks: OriginalSpriteEmitter
var sounds: Dictionary
var sound_id = 98
var previous_time = -.001
func _init() -> void: class_id = 2
func _ready() -> void:
	super._ready()
	# Platform moves first, cargo support150 follows, then fuse/explosion200.
	# Blast origin must use this tick's platform position, not the old one.
	process_physics_priority = 200
	visual.hide()
	actor_visual = load(original_scene).instantiate()
	add_child(actor_visual)
	actor_visual.sample_animation("objet",0)
	explosion = load("res://assets/items/dynamite/explosion/worn.tscn").instantiate()
	add_child(explosion)
	explosion.hide()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_01/data/mechanics.json"))
	sounds = data["sounds"]
	sound_id = int(data["fuse_sound"])
	sparks = OriginalSpriteEmitter.new()
	add_child(sparks)
	sparks.position.y = .5
	sparks.configure(JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_01/data/effects.json"))["sheets"]["fuse"],3)
func equip_to(actor: Node3D) -> void:
	super.equip_to(actor)
	actor_visual.sample_animation("link",0)
func use_item(actor: Node3D) -> Dictionary:
	if state != "idle" or not actor is RalphController or not actor.is_on_floor(): return {"success":false}
	# PUT1A -> MSG_DROP(lit=1) -> PUT1B; Near offset is source {0,-2,0}.
	var initial = OriginalPlacement.probe(actor,self,true)
	if initial.is_empty(): return {"success":false}
	var support: Node3D = initial.support
	var ride_point = support.to_local(actor.global_position) if is_instance_valid(support) else Vector3.ZERO
	var ride = func(_time: float,_duration: float):
		# PUT1A/PUT1B locks input/normal movement, but the lift still carries Ralph.
		if is_instance_valid(support) and (support is AnimatableBody3D or support is OriginalSeesaw):
			actor.global_position = support.to_global(ride_point)
	var began = actor.item_actions.begin([
		{"clip":"throw_place","step":ride,"exit":func():
			# Probe again at PUT1A's end: the lift can move during this animation.
			var placement = OriginalPlacement.probe(actor,self,true)
			if placement.is_empty():
				actor.item_actions.stages[actor.item_actions.index+1] = {"clip":"placement_refused"}
				return
			ignite(placement.position-Vector3.UP*.005,placement.support)},
		{"clip":"throw_end","step":ride}])
	return {"success":began,"consumed":false} # Inventory_Remove happens at PUT1A end.
func ignite(point: Vector3, support: Node3D = null) -> void:
	state = "lit"
	active = true
	holder = null
	available = false
	deployed = true
	global_position = point+Vector3.UP*.02
	OriginalPlacement.follow_support(self,{"support":support})
	rotation = Vector3.ZERO
	fuse = fuse_seconds
	elapsed = 0
	actor_visual.idle("stand1")
	actor_visual.show()
	show()
	hint.hide()
	sparks.emitting = true
	if owning_inventory: owning_inventory.state.remove(item_id)
	play_item_sound(sounds[str(sound_id)],true)

func follows_ground_support() -> bool:
	return deployed and state in ["lit","explosion"] and not is_instance_valid(holder)
func item_step(delta: float) -> void:
	if state == "lit":
		fuse = maxf(0,fuse-delta)
		sparks.frame_index = int(fuse/.5)
		if fuse == 0: explode()
	elif state == "explosion":
		elapsed += delta
		explosion.sample_animation("boom",elapsed)
		for cue in explosion.rig["animations"]["boom"]["sound_cues"]:
			if float(cue["time"]) > previous_time and float(cue["time"]) <= elapsed:
				var path = sounds.get(str(int(cue["sound_id"])))
				if path: play_item_sound(path)
		previous_time = elapsed
		if elapsed >= float(explosion.rig["animations"]["boom"]["duration"]):
			hide()
			state = "respawn"
			elapsed = 0
	elif state == "respawn":
		elapsed += delta
		if elapsed >= 3: restore()
func explode() -> void:
	state = "explosion"
	active = false
	elapsed = 0
	previous_time = -.001
	sound.stop()
	sparks.clear()
	actor_visual.hide()
	explosion.show()
	explosion.sample_animation("boom",0)
	# Source broadcasts MSG_LOUD_NOISE/class2 within 3000 units before KILL.
	for target in get_tree().get_nodes_in_group("loud_noise_receivers"):
		if target.get_world_3d() == get_world_3d() and target.has_method("on_loud_noise"):
			target.on_loud_noise(global_position,30.0,2)
	for target in get_tree().get_nodes_in_group("blast_targets")+get_tree().get_nodes_in_group("player"):
		if target.get_world_3d() != get_world_3d(): continue
		var distance: Vector3 = target.global_position-global_position
		if Vector2(distance.x,distance.z).length() > 3 or absf(distance.y) > 2: continue
		if target.has_method("on_blast"): target.on_blast(global_position)
		elif target is RalphController: target.set_state(target.WolfState.BLAST_DEATH)
	exploded.emit(global_position)
func restore() -> void:
	super.restore()
	state = "idle"
	fuse = fuse_seconds
	actor_visual.show()
	actor_visual.sample_animation("objet",0)
	explosion.hide()
	sparks.clear()

func attachment_transform(actor: RalphController) -> Transform3D:
	# Wolf::EquipItem sends MSG_PICKUP joint0x12; Dynamite::AttachTo has no offset.
	var transform = actor.skeleton.global_transform*actor.legacy_skin.last_matrices[18]
	# Cancel the internal export reflection; the item skin applies it once itself.
	transform.basis *= GameSpace.EXPORT_TO_GODOT
	return transform

func _update_held_position():
	if holder is RalphController: global_transform = attachment_transform(holder)
	else: super._update_held_position()

func prepare_held_visual():
	actor_visual.sample_animation("link",0)
