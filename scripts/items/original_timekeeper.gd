extends Node3D
class_name OriginalTimeKeeper
enum State { AVAILABLE, RINGING, COLLECTED }
signal collected(level: String)
@export var level_id = "lvl_01"
@export var asset_directory = "res://assets/levels/lvl_01/models/37"
@export_file("*.json") var sound_bank_path = "res://assets/levels/lvl_01/data/ai_audio.json"
@export_node_path("CharacterBody3D") var player_path = NodePath("../Player")
var player: RalphController
var state = State.AVAILABLE
var visual: OriginalCinematicActor
var audio: AudioStreamPlayer3D
var sounds: Dictionary
var phase = 0
var elapsed = 0.0
var previous = -.001
var clip = "clock1"
var hint: Label3D
var model_bounds: AABB
var physical_root: Node3D
var physical_bodies: Array[RID] = []

func _ready() -> void:
	add_to_group("world_interactables")
	player = get_node(player_path)
	visual = load(asset_directory+"/worn.tscn").instantiate()
	add_child(visual)
	model_bounds = (load(asset_directory+"/worn.tres") as Mesh).get_aabb()
	visual.position.y = -model_bounds.position.y
	sounds = JSON.parse_string(FileAccess.get_file_as_string(sound_bank_path))
	audio = AudioStreamPlayer3D.new()
	audio.max_distance = 25
	add_child(audio)
	hint = Label3D.new()
	hint.text = "E · Reloj secreto"
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.position.y = model_bounds.size.y+.25
	hint.pixel_size = .005
	add_child(hint)
	hint.hide()
	if OriginalProgress.has_clock(level_id): state = State.COLLECTED
	visual.idle("clock1")
	call_deferred("_snap_to_ground")

func build_collision():
	var path = "res://assets/levels/"+level_id+"/data/solid_boxes.json"
	if not FileAccess.file_exists(path): return
	for entry in JSON.parse_string(FileAccess.get_file_as_string(path)):
		if entry.class_name!="TimeKeeper" or int(entry.res)!=int(get_meta("original_resource",-1)): continue
		# ScnObject boxes are world-aligned, independent of CLOCK1's artwork yaw.
		# Own them here so SnapToGround cannot leave a floating static duplicate.
		physical_root = Node3D.new(); physical_root.name = "ClockCollision"
		add_child(physical_root); physical_root.top_level = true
		physical_root.global_transform = Transform3D(Basis.IDENTITY,global_position)
		var record = entry.duplicate(true); record.position = [0,0,0]
		OriginalSolidBuilder.build(physical_root,"",[],[record])
		for body in physical_root.find_children("*","StaticBody3D",true,false): physical_bodies.append(body.get_rid())
		break

func _snap_to_ground() -> void:
	# Wait until terrain transforms are registered with the physics server.
	# Deferred _ready alone can run before the imported collision is queryable.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree(): return
	# ScnObject::SnapToGround searches from 50 native units above the pivot.
	# Wolf's respawn probe starts 3m above and can hit this alcove's roof.
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.5,global_position-Vector3.UP*30)
	var excluded: Array[RID] = [player.get_rid()]
	excluded.append_array(physical_bodies); query.exclude = excluded
	query.collision_mask = 1
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): global_position.y = hit["position"].y
	if physical_root==null: build_collision()
	if physical_root: physical_root.global_position = global_position

func can_interact(actor: RalphController) -> bool:
	if state != State.AVAILABLE or OriginalProgress.has_clock(level_id) or not actor.can_use_item() or is_instance_valid(actor.carried_sheep): return false
	if not actor.is_on_floor() and (actor.velocity.y > 0 or actor.ground_drop() > .15): return false
	# ScanInteractables uses gaps between model boxes, not origin distance.
	# Use the imported bounds in CLOCK1 and Wolf's horizontal body radius.
	var point = visual.to_local(actor.global_position)
	point.z = -point.z # Exported mesh bounds precede GameSpace's Z reflection.
	var nearest = point.clamp(model_bounds.position,model_bounds.end)
	var gap = Vector2(point.x-nearest.x,point.z-nearest.z).abs()-Vector2(.35,.35)
	return gap.max(Vector2.ZERO).length() <= .6 and absf(actor.global_position.y-global_position.y) <= .5

func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	if not actor.item_actions.begin([{"clip":"timekeeper_use","enter":func(): actor.item_actions.face(global_position)}]): return false
	var before = OriginalProgress.bonus_points
	OriginalProgress.award_clock(level_id)
	state = State.RINGING
	phase = 0
	_enter_clip("clock2")
	collected.emit(level_id)
	var amount = OriginalProgress.bonus_points-before
	actor.inventory.wheel.show_message(GameLocalization.ui("Reloj secreto · +%d %s de bonificación") % [amount,GameLocalization.ui("punto") if amount == 1 else GameLocalization.ui("puntos")])
	return true

func _enter_clip(name: String) -> void:
	clip = name
	elapsed = 0
	previous = -.001
	visual.idle_clip = ""
	visual.sample_animation(clip,0)

func _process(delta: float) -> void:
	hint.visible = false
	if state != State.RINGING: return
	elapsed += delta
	visual.sample_animation(clip,elapsed)
	for cue in visual.rig["animations"][clip]["sound_cues"]:
		if float(cue["time"]) > previous and float(cue["time"]) <= elapsed:
			var sound = AudioStreamPlayer3D.new()
			add_child(sound)
			sound.stream = load(sounds[str(int(cue["sound_id"]))])
			sound.finished.connect(sound.queue_free)
			sound.play()
	previous = elapsed
	if elapsed < float(visual.rig["animations"][clip]["duration"]): return
	phase += 1
	if phase == 1:
		_enter_clip("clock3")
		var stream: AudioStreamWAV = load(sounds["248"]).duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		audio.stream = stream
		audio.play()
	elif phase == 2:
		audio.stop()
		_enter_clip("clock4")
	else:
		state = State.COLLECTED
		visual.idle("clock1")
