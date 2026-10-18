extends "res://scripts/items/game_item.gd"
class_name FanItem

func _init() -> void:
	class_id = 7

var start_played = false
var actor_visual: OriginalCinematicActor
var spin_time = 0.0

func _ready():
	super._ready()
	add_to_group("fan_sources")
	visual.hide()
	actor_visual = load("res://assets/items/fan/worn.tscn").instantiate()
	add_child(actor_visual)
	actor_visual.sample_animation("objet",0)

func equip_to(actor: Node3D):
	super.equip_to(actor)
	actor_visual.idle_clip = ""
	actor_visual.sample_animation("link",0)

func _update_held_position():
	if holder is RalphController:
		global_transform = holder.skeleton.global_transform*holder.legacy_skin.last_matrices[18]
		global_basis *= GameSpace.EXPORT_TO_GODOT
	else: super._update_held_position()

func use_item(actor: Node3D) -> Dictionary:
	if not is_instance_valid(holder):
		return {"success": false}
	active = not active
	if active:
		start_played = false
		spin_time = 0
		actor_visual.idle_clip = ""
		actor_visual.sample_animation("standv1b",0)
		activated.emit(actor)
	else:
		deactivate()
	return {"success": true, "consumed": false}

func item_step(delta: float) -> void:
	if not active or not is_instance_valid(holder):
		if actor_visual and not is_instance_valid(holder): actor_visual.sample_animation("objet",0)
		return
	spin_time += delta
	var start_duration = float(actor_visual.rig.animations.standv1b.duration)
	if spin_time < start_duration: actor_visual.sample_animation("standv1b",spin_time)
	else:
		var clip = "walkv1" if holder.animation_player.current_animation == "fan_blow_turn" else "standv1"
		actor_visual.sample_animation(clip,spin_time-start_duration,true)
	if not start_played:
		play_item_sound("res://assets/items/audio/fan_start.wav")
		start_played = true
	elif not sound.playing:
		play_item_sound("res://assets/items/audio/fan_loop.wav", true)
	for target in get_tree().get_nodes_in_group("fan_targets"):
		if target == self or not target is Node3D or not target.has_method("on_fan_blow"):
			continue
		# Attached props retain the carrier's gameplay origin for grid queries.
		var overlaps_carrier = target.has_method("receives_fan_from") and target.receives_fan_from(holder,holder.item_facing())
		if overlaps_carrier or ItemRules.in_fan_cone(holder.global_position, holder.item_facing(), target.global_position):
			target.on_fan_blow(holder.item_facing(), delta)

func deactivate():
	super.deactivate()
	spin_time = 0
	start_played = false
	if actor_visual:
		actor_visual.idle_clip = ""
		actor_visual.sample_animation("link" if is_instance_valid(holder) else "objet",0)

func prepare_held_visual(): actor_visual.sample_animation("link",0)

func detection_report() -> Dictionary:
	if not active or not is_instance_valid(holder): return {}
	var best: Dictionary = {}
	for target in get_tree().get_nodes_in_group("fan_targets"):
		if not target is PerfumeItem or not ItemRules.in_fan_cone(holder.global_position,holder.item_facing(),target.global_position): continue
		var report = target.detection_report()
		if not report.is_empty() and (best.is_empty() or int(report.value) < int(best.value)): best = report
	return best
