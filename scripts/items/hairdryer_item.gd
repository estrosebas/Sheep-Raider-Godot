extends "res://scripts/items/imported_preview_item.gd"
class_name HairDryerItem

# HairDryer::Blow / MSG_QUERY_HELD_ACTION: native HELD_FAN, joint18.
var blow_time = 0.0
var range_m = 4.0
var half_angle = deg_to_rad(409.0*360/4096)

func _ready():
	super._ready()
	set_meta("prototype_only",false)

func use_item(actor: Node3D) -> Dictionary:
	if not is_instance_valid(holder): return {"success":false}
	active = not active
	if active:
		blow_time = 0
		activated.emit(actor)
	else: deactivate()
	return {"success":true,"consumed":false}

func heats_point(point: Vector3) -> bool:
	if not active or not is_instance_valid(holder): return false
	# Native prop origin and Y-down query [-300,100].
	var difference = point-global_position
	if difference.y < -1 or difference.y > 3: return false
	difference.y = 0
	if difference.length() > range_m: return false
	return difference.is_zero_approx() or holder.item_facing().dot(difference.normalized()) >= cos(half_angle)

func item_step(delta: float):
	if not active or not is_instance_valid(holder): return
	if holder.cinematic_controls_locked or not holder.visible:
		deactivate(); return
	blow_time += delta
	var clip = "walkv1" if holder.animation_player.current_animation == "fan_blow_turn" else "standv1"
	original_visual.sample_animation(clip,blow_time,true)
	play_item_sound("res://assets/levels/%s/audio/283.wav"%source_level,true)
	for target in get_tree().get_nodes_in_group("thaw_targets"):
		if target.get_world_3d()==get_world_3d() and heats_point(target.global_position): target.on_heat(delta)

func sync_held_pose():
	if is_instance_valid(holder): _update_held_position()

func deactivate():
	super.deactivate()
	blow_time = 0
	if original_visual: original_visual.sample_animation("link" if is_instance_valid(holder) else "objet",0)
