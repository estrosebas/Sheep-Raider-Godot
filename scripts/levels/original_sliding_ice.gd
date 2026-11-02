extends CharacterBody3D
class_name OriginalSlidingIce
const REBOUND_SPEED = 3.0
const REBOUND_DECELERATION = 8.0
# SlidingIceCube: native8m/s travel, one short port-tuned rebound.
var definition: Dictionary
var visual: OriginalCinematicActor
var shape: CollisionShape3D
var bounds: AABB
var home: Vector3
var direction = Vector3.ZERO
var speed = 0.0
var bounced = false
var fall_time = 0.0
var sounds: Dictionary
var slide_audio: AudioStreamPlayer3D
var hit_audio: AudioStreamPlayer3D
var player: RalphController
var saved_riders: Dictionary = {}

func _ready():
	collision_layer = 3; collision_mask = 1; floor_snap_length = .12
	process_physics_priority = -20
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	visual.idle_clip = ""; visual.sample_animation("stand2",0)
	var box = definition.boxes[0]
	var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
	var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
	bounds = AABB(lo,hi-lo)
	shape = CollisionShape3D.new(); shape.shape = BoxShape3D.new()
	shape.shape.size = bounds.size; shape.position = bounds.get_center(); add_child(shape)
	slide_audio = AudioStreamPlayer3D.new(); add_child(slide_audio)
	hit_audio = AudioStreamPlayer3D.new(); add_child(hit_audio)
	for audio in [slide_audio,hit_audio]: audio.max_distance = 50; audio.unit_size = 2
	player = get_parent().get_node("Player")
	add_to_group("world_interactables"); add_to_group("ice_cubes")
	add_to_group("blast_targets"); add_to_group("checkpoint_controllers")
	player.respawned.connect(reset_cube)
	call_deferred("remember_home")

func remember_home(): home = global_position
func bottom() -> float: return global_position.y+bounds.position.y
func box_at(point: Vector3) -> AABB: return AABB(point+bounds.position,bounds.size)
func can_interact(actor: RalphController) -> bool:
	var difference = actor.global_position-global_position
	return speed==0 and actor.can_use_item() and actor.is_on_floor() and not actor.carried_sheep and difference.y<1.0 and difference.y>-.6 and Vector2(difference.x,difference.z).length()<2.2
func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	var away = global_position-actor.global_position
	var axis = Vector3(signf(away.x),0,0) if absf(away.x)>absf(away.z) else Vector3(0,0,signf(away.z))
	if not allows_direction(axis): return false
	# Wolf::PUSH_ICECUBE waits for ICEPUSH1, sends USE, then ICEPUSH2.
	return actor.item_actions.begin([{"clip":"ice_push_start","enter":func(): actor.item_actions.face(global_position)}, {"clip":"ice_push_end","enter":func(): start_slide(axis)}])
func allows_direction(axis: Vector3) -> bool:
	return (absf(axis.x)>.5 and bool(definition.props["0x4"])) or (absf(axis.z)>.5 and bool(definition.props["0x8"]))
func start_slide(axis: Vector3) -> bool:
	if not allows_direction(axis): return false
	direction = axis; speed = 8; bounced = false
	return true
func allowed(point: Vector3) -> bool:
	return definition.zones.is_empty() or OriginalSam.contains(point,definition.zones)
func begin_rebound():
	if bounced: return
	# About0.54m of clearance fits Ralph's native36cm body and a margin.
	direction = -direction; speed = minf(speed,REBOUND_SPEED)
	bounced = true; cue(127,hit_audio)
func riders() -> Array:
	var result = []
	var top = box_at(global_position)
	for actor in get_tree().get_nodes_in_group("player")+get_tree().get_nodes_in_group("sheep_targets")+get_tree().get_nodes_in_group("game_items"):
		if not actor is Node3D or actor.get_world_3d()!=get_world_3d() or not actor.is_visible_in_tree(): continue
		if actor is GameItem and (actor.holder or not actor.available): continue
		if actor is OriginalSheep and actor.carried_by: continue
		var p = actor.global_position
		if p.x>=top.position.x-.15 and p.x<=top.end.x+.15 and p.z>=top.position.z-.15 and p.z<=top.end.z+.15 and absf(p.y-top.end.y)<.22: result.append(actor)
	return result
func _physics_process(delta: float):
	var ice_action = player.item_actions.busy and player.animation_player.current_animation in ["ice_push_start","ice_push_end"]
	if player.cinematic_controls_locked and not ice_action: return
	var cargo = riders()
	for rider in saved_riders.keys():
		if not is_instance_valid(rider): saved_riders.erase(rider)
		elif rider not in cargo: rider.platform_floor_layers = saved_riders[rider]; saved_riders.erase(rider)
	for rider in cargo:
		if rider is CharacterBody3D and not saved_riders.has(rider): saved_riders[rider] = rider.platform_floor_layers; rider.platform_floor_layers = 0
	var before = global_position
	if bounced: speed = move_toward(speed,0,REBOUND_DECELERATION*delta)
	fall_time += delta
	velocity = direction*speed; velocity.y = -clampf(fall_time*40,2,15)
	if speed>0 and not allowed(global_position+Vector3(velocity.x,0,velocity.z)*delta):
		# Authored travel limits also need a rebound: stopping here used to
		# bypass the wall-hit branch and leave the cube glued to the endpoint.
		if not bounced: begin_rebound()
		else: speed = 0
		velocity.x = direction.x*speed; velocity.z = direction.z*speed
		if not allowed(global_position+Vector3(velocity.x,0,velocity.z)*delta): speed = 0; velocity.x = 0; velocity.z = 0
	move_and_slide()
	if is_on_floor(): fall_time = 0
	if speed>0 and is_on_wall() and not bounced:
		begin_rebound()
	var shift = global_position-before
	for rider in cargo:
		rider.global_position += shift
		if rider is GameItem: rider.home_position = rider.global_position
	if speed>0 and not slide_audio.playing: cue(124,slide_audio,true)
	elif speed==0: slide_audio.stop()
func cue(id: int,audio: AudioStreamPlayer3D,loop=false):
	if not sounds.has(str(id)): return
	var stream: AudioStreamWAV = load(sounds[str(id)]).duplicate()
	if loop: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = roundi(stream.mix_rate*stream.get_length())
	audio.stream = stream; audio.play()
func on_blast(_origin: Vector3): pass # Native cube does not break on MSG_KILL.
func reset_cube():
	global_position = home; speed = 0; velocity = Vector3.ZERO; fall_time = 0; bounced = false; slide_audio.stop()
	for rider in saved_riders:
		if is_instance_valid(rider): rider.platform_floor_layers = saved_riders[rider]
	saved_riders.clear()
func capture_world_state() -> Dictionary: return {"position":SaveFiles.vector(global_position)}
func restore_world_state(saved: Dictionary):
	reset_cube()
	if SaveFiles.valid_vector(saved.get("position")): global_position = SaveFiles.to_vector(saved.position)
