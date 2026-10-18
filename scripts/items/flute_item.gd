extends GameItem
class_name FluteItem

# Flute::HandleMessage/Update and Wolf FLUTE_IDLE/FLUTE_WALK.
@export_file("*.tscn") var original_scene = "res://assets/items/flute/worn.tscn"
@export var source_level = "lvl_04"
var original_visual: OriginalCinematicActor
var rules: Dictionary = {}
var notes: Array[Sprite3D] = []
var note_frames: Array[Texture2D] = []
var note_time = 0.0
var noise_time = 0.0
var random = RandomNumberGenerator.new()

func _init(): class_id = 41

func _ready():
	super._ready()
	if visual: visual.hide()
	original_visual = load(original_scene).instantiate(); add_child(original_visual)
	original_visual.sample_animation("objet",0)
	icon_path = "res://assets/ui/inventory/icon_41.png"
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/flute/rules.json"))
	var level = get_parent()
	if level is ImportedLevel: source_level = level.manifest.level
	var path = "res://assets/levels/"+source_level+"/data/flute.json"
	if level is ImportedLevel and FileAccess.file_exists(path): rules.merge(JSON.parse_string(FileAccess.get_file_as_string(path)),true)
	for file in rules.get("notes",{}).get("frames",[]): note_frames.append(load(file))
	random.randomize()
	reload_localization()

func reload_localization():
	item_label = GameLocalization.text(source_level,42,0).split(":")[0].capitalize()

func attachment_transform(actor: RalphController) -> Transform3D:
	var transform = actor.skeleton.global_transform*actor.legacy_skin.last_matrices[18]
	transform.basis *= GameSpace.EXPORT_TO_GODOT
	return transform

func _update_held_position():
	if holder is RalphController: global_transform = attachment_transform(holder)
	else: super._update_held_position()

func prepare_held_visual(): original_visual.sample_animation("link",0)

func sync_held_pose():
	if not is_instance_valid(holder): return
	# Flute::MSG_PICKUP selects LINK. MSG_HELD_STATE_BEGIN/END only changes
	# sound/emitter state; it never plays FLUTE1/WALKF1/STANDF1 on the prop.
	# Those extra asset clips must not be layered over Wolf's hand motion.
	original_visual.idle_clip = ""
	original_visual.sample_animation("link",0)
	_update_held_position()

func equip_to(actor: Node3D):
	prepare_held_visual()
	super.equip_to(actor)

func use_item(actor: Node3D) -> Dictionary:
	if holder!=actor or not actor is RalphController or not actor.is_on_floor(): return {"success":false}
	if active: deactivate()
	else:
		active = true; noise_time = 0; note_time = 0
		actor.set_state(actor.WolfState.FLUTE_IDLE)
		play_item_sound(rules.get("sound_path","res://assets/items/flute/flute_tune.wav"),true)
		attract_guards()
		activated.emit(actor)
	return {"success":true,"consumed":false}

func deactivate():
	super.deactivate()
	if holder is RalphController and holder.current_state in [holder.WolfState.FLUTE_IDLE,holder.WolfState.FLUTE_WALK]: holder.set_state(holder.WolfState.IDLE)
	if original_visual: original_visual.sample_animation("link" if is_instance_valid(holder) else "objet",0)

func step_player(actor: RalphController,delta: float) -> bool:
	if not active: return false
	if not actor.is_on_floor() or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("run"):
		deactivate(); return false
	var input = Vector2.ZERO if actor.inventory_controls_locked else Input.get_vector("move_left","move_right","move_forward","move_backward")
	var direction = actor.camera_pivot.global_basis*Vector3(input.x,0,input.y)
	direction.y = 0
	if direction.length_squared()>.01:
		direction = direction.normalized()
		actor.skeleton.rotation.y = lerp_angle(actor.skeleton.rotation.y,atan2(direction.x,direction.z),minf(1,actor.rotation_speed*delta))
		actor.set_state(actor.WolfState.FLUTE_WALK)
	else: actor.set_state(actor.WolfState.FLUTE_IDLE)
	actor.velocity = direction*float(rules.get("wolf_speed",2.0))
	actor.velocity.y = 0 if actor.is_on_floor() else maxf(-20,actor.velocity.y-29*delta)
	actor.move_and_slide()
	actor.was_on_floor = actor.is_on_floor()
	actor.check_void_below()
	return true

func attract_guards():
	if not is_instance_valid(holder): return
	for guard in get_tree().get_nodes_in_group("sam_guards"):
		if guard.get_world_3d()!=get_world_3d(): continue
		if global_position.distance_squared_to(guard.global_position)<=pow(float(rules.get("sam_radius",3.0)),2):
			guard.on_flute(global_position,rules.get("hypnosis",{}).get("zones",[]),rules.get("hypnosis",{}))

func item_step(delta: float):
	if active and is_instance_valid(holder):
		if holder.cinematic_controls_locked or holder.current_state in [holder.WolfState.PIT_FALL,holder.WolfState.BLAST_DEATH,holder.WolfState.SAM_DEATH]: deactivate()
		else:
			sync_held_pose()
			attract_guards()
			noise_time -= delta; note_time -= delta
			if noise_time<=0:
				noise_time = .1
				for receiver in get_tree().get_nodes_in_group("loud_noise_receivers"):
					if receiver.get_world_3d()==get_world_3d() and not receiver is OriginalSam: receiver.on_loud_noise(holder.global_position,float(rules.get("noise_radius",6.0)),0)
			if note_time<=0:
				note_time += float(rules.get("notes",{}).get("interval_seconds",2730.0/4096.0))
				spawn_note()
	elif is_instance_valid(holder):
		sync_held_pose()
	else: original_visual.sample_animation("objet",0)
	for note in notes.duplicate():
		var age = float(note.get_meta("age"))+delta
		if age>=4:
			notes.erase(note); note.queue_free(); continue
		note.set_meta("age",age)
		note.global_position += note.get_meta("drift")*delta
		# Emitter_UpdateDriftLift scales vertical speed by normalized age /
		# life (16384ticks here), so lift accelerates gently instead of rising
		# at a constant .75m/s.
		note.global_position.y += age*.75/16.0*delta
		note.modulate.a = minf(1,(4-age)*2)
		note.pixel_size = lerpf(.06,.4,age/4.0)/note.texture.get_width()

func spawn_note():
	if note_frames.is_empty(): return
	var direction = holder.item_facing()
	var nearest: OriginalSam
	for guard in get_tree().get_nodes_in_group("sam_guards"):
		if guard.get_world_3d()!=get_world_3d(): continue
		if global_position.distance_squared_to(guard.global_position)<=400 and (nearest==null or global_position.distance_squared_to(guard.global_position)<global_position.distance_squared_to(nearest.global_position)): nearest=guard
	if nearest: direction = (nearest.global_position-holder.global_position).normalized()
	direction.y = 0; direction = direction.normalized()
	var note = Sprite3D.new(); note.texture = note_frames[random.randi_range(0,note_frames.size()-1)]
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED; note.no_depth_test = false
	note.shaded = false; note.pixel_size = .06/note.texture.get_width()
	note.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(note); note.top_level = true
	note.global_position = holder.global_position+Vector3.UP*1.1+holder.item_facing()*.6+Vector3(random.randf_range(-.1,.1),random.randf_range(-.1,.1),random.randf_range(-.1,.1))
	note.set_meta("age",0.0); note.set_meta("drift",direction)
	notes.append(note)

func detection_report() -> Dictionary:
	if not active or not is_instance_valid(holder): return {}
	var radius = float(rules.get("sam_radius",3.0))
	var closest = radius
	var found = false
	for guard in get_tree().get_nodes_in_group("sam_guards"):
		if guard.get_world_3d()!=get_world_3d(): continue
		var distance = global_position.distance_to(guard.global_position)
		if distance<=closest: closest=distance; found=true
	return {"value":int(closest/radius*65535),"class_id":1} if found else {}

func _exit_tree():
	for note in notes:
		if is_instance_valid(note): note.queue_free()
