extends "res://scripts/items/imported_preview_item.gd"
class_name MineDetectorItem
var phase = "idle"
var elapsed = 0.0
var reading = INF
var gauge: CanvasLayer
var rules: Dictionary
func _ready():
	super._ready(); set_meta("prototype_only",false)
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/"+source_level+"/data/snow.json"))
	gauge = preload("res://scripts/ui/original_detector_gauge.gd").new(); gauge.detector = self; add_child(gauge)
func use_item(actor: Node3D) -> Dictionary:
	if holder!=actor or not actor is RalphController or not actor.is_on_floor(): return {"success":false}
	if active:
		phase = "lowering"; elapsed = 0; active = false; sound.stop()
	else:
		active = true; phase = "raising"; elapsed = 0; reading = INF; activated.emit(actor)
	return {"success":true,"consumed":false}
func deactivate():
	super.deactivate(); phase = "idle"; elapsed = 0; reading = INF
	if original_visual: original_visual.sample_animation("link" if is_instance_valid(holder) else "objet",0)
func step_player(actor: RalphController,delta: float) -> bool:
	if phase=="idle": return false
	if actor.cinematic_controls_locked or actor.current_state in [actor.WolfState.PIT_FALL,actor.WolfState.SAM_DEATH,actor.WolfState.BLAST_DEATH] or not actor.is_on_floor(): deactivate(); return false
	elapsed += delta
	var input = Input.get_vector("move_left","move_right","move_forward","move_backward") if phase=="scanning" else Vector2.ZERO
	var direction = actor.movement_camera_basis()*Vector3(input.x,0,input.y)
	if not direction.is_zero_approx(): actor.skeleton.rotation.y = lerp_angle(actor.skeleton.rotation.y,atan2(direction.x,direction.z),minf(1,actor.rotation_speed*delta))
	var clip = "detector_walk" if not direction.is_zero_approx() else "detector_idle"
	var prop_clip = "detec2" if not direction.is_zero_approx() else "detec1"
	if phase=="raising": clip = "detector_start"; prop_clip = "detec3"
	elif phase=="lowering": clip = "detector_end"; prop_clip = "detec4"
	if actor.animation_player.current_animation!=clip: actor.play_anim(clip)
	original_visual.sample_animation(prop_clip,elapsed,phase=="scanning")
	actor.velocity = direction*2.0; actor.velocity.y = -1
	actor.move_and_slide(); actor.was_on_floor = actor.is_on_floor(); actor.check_void_below()
	if phase=="raising" and elapsed>=float(actor.run_data.animations.detector_start.duration):
		phase = "scanning"; elapsed = 0
	elif phase=="lowering" and elapsed>=float(actor.run_data.animations.detector_end.duration):
		deactivate(); actor.set_state(actor.WolfState.IDLE)
	return true
func item_step(_delta: float):
	if phase!="scanning" or not is_instance_valid(holder): return
	if holder.cinematic_controls_locked: deactivate(); return
	reading = scan(holder.global_position,holder.item_facing())
	play_item_sound("res://assets/levels/"+source_level+"/audio/258.wav",true)
func scan(origin: Vector3,facing: Vector3) -> float:
	var nearest = INF
	for field in get_tree().get_nodes_in_group("buried_minefields"):
		if field.get_world_3d()==get_world_3d(): nearest = minf(nearest,field.distance_to_hazard(origin,facing,2.0))
	for mine in get_tree().get_nodes_in_group("defusable_mines"):
		if mine.get_world_3d()!=get_world_3d() or mine.holder: continue
		var difference = mine.global_position-origin
		if absf(difference.y)>1: continue
		difference.y = 0
		if difference.length()<=2 and (difference.is_zero_approx() or difference.normalized().dot(facing)>=cos(PI/3)): nearest = minf(nearest,difference.length())
	return nearest
func sync_held_pose():
	if is_instance_valid(holder): _update_held_position()

func follows_ground_support() -> bool:
	# MineDetector::MD_ST_FALLING continues after its container releases it.
	return available and is_visible_in_tree() and not is_instance_valid(holder)
