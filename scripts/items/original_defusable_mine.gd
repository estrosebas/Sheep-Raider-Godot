extends GameItem
class_name OriginalDefusableMine
# mine.cpp: code uses two bits per beat, least-significant pair first.
enum State { ARMED, PLAYBACK, INPUT, SAFE, COUNTDOWN, EXPLODING, EXPLODED, REARMING }
var mine_definition: Dictionary
var mine_assets: Dictionary
var sounds: Dictionary
var source_level = ""
var original_visual: OriginalCinematicActor
var explosion: OriginalCinematicActor
var player: RalphController
var state = State.ARMED
var enabled = true
var clock = 0.0
var elapsed = 0.0
var step_start = 0.0
var seq_index = 0
var hit = false
var failed = false
var played_beat = false
var lights_shown = 0
var shown_direction = -1
var dormant = true
var wave_radius = 0.0
var session = false
var saved_lock = false
var panel: CanvasLayer
var ring: MeshInstance3D
var final_audio: AudioStreamPlayer3D
var reset_position = Vector3.ZERO
var initial_position = Vector3.ZERO
var ready_world = false
var pending_world_state: Dictionary = {}

func _ready():
	class_id = 64
	super._ready()
	player = get_tree().get_first_node_in_group("player")
	item_label = GameLocalization.ui("Mina")
	icon_path = "res://assets/ui/inventory/icon_64.png"
	if not ResourceLoader.exists(icon_path): icon_path = ""
	original_visual = load(mine_definition.directory+"/worn.tscn").instantiate(); add_child(original_visual)
	explosion = load(mine_assets.explosion.directory+"/worn.tscn").instantiate(); add_child(explosion); explosion.hide()
	final_audio = AudioStreamPlayer3D.new(); add_child(final_audio)
	ring = MeshInstance3D.new(); add_child(ring)
	var paint = StandardMaterial3D.new(); paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; paint.albedo_color = Color(.12,.6,1,.7)
	ring.material_override = paint
	panel = preload("res://scripts/ui/original_mine_panel.gd").new(); panel.mine = self; add_child(panel)
	add_to_group("world_interactables"); add_to_group("defusable_mines"); add_to_group("blast_targets")
	add_to_group("checkpoint_controllers")
	player.respawned.connect(_after_respawn)
	call_deferred("initialize_world")

func initialize_world():
	initial_position = global_position
	enabled = not bool(mine_definition.get("staged",false))
	if enabled:
		var ray = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*2,global_position+Vector3.DOWN*4,1)
		ray.exclude = [player.get_rid()]
		var floor_hit = get_world_3d().direct_space_state.intersect_ray(ray)
		if not floor_hit.is_empty(): global_position.y = floor_hit.position.y+.02
	reset_position = global_position; home_position = global_position; ready_world = true
	reset_mine()
	if not pending_world_state.is_empty(): restore_mine_state(pending_world_state); pending_world_state = {}

func deploy_at(point: Vector3):
	enabled = true; global_position = point; reset_position = point; home_position = point
	reset_mine()

func reset_mine():
	end_session(); holder = null; deployed = false; active = false
	global_position = reset_position; velocity_reset()
	state = State.ARMED; elapsed = 0; failed = false; hit = false
	available = enabled; visible = enabled; original_visual.show(); explosion.hide(); ring.hide()
	original_visual.sample_animation("red",0)

func velocity_reset():
	rotation = Vector3.ZERO

func _after_respawn():
	call_deferred("reset_after_inventory")
func reset_after_inventory():
	if player.inventory.state.items.has(item_id):
		end_session(); state = State.SAFE; store()
	else: reset_mine()

func restore():
	if ready_world: reset_mine()

func can_pickup(actor: RalphController) -> bool:
	return enabled and state==State.SAFE and super.can_pickup(actor)

func can_interact(actor: RalphController) -> bool:
	if not enabled or not available or is_instance_valid(holder) or actor.cinematic_controls_locked or not actor.can_use_item(): return false
	if not actor.is_on_floor(): return false
	var difference = actor.global_position-global_position
	return absf(difference.y)<.5 and Vector2(difference.x,difference.z).length()<=1.0 and (state==State.SAFE or (state==State.ARMED and dormant))

func action_label(_actor): return GameLocalization.ui("Coger") if state==State.SAFE else GameLocalization.ui("Desactivar mina")
func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	if state==State.SAFE: kept = true; return collect(actor.inventory)
	begin_defuse(actor); return true

func begin_defuse(actor: RalphController):
	actor.interrupt_actions(); actor.set_state(actor.WolfState.IDLE)
	saved_lock = actor.cinematic_controls_locked; actor.cinematic_controls_locked = true
	actor.velocity = Vector3.ZERO
	session = true; set_phase(State.PLAYBACK)

func set_phase(next: State):
	state = next; elapsed = 0; shown_direction = -1; played_beat = false
	lights_shown = 0
	if next in [State.PLAYBACK,State.INPUT]:
		seq_index = 0; step_start = clock; hit = false; failed = false
	if next==State.SAFE:
		end_session(); original_visual.sample_animation("green",0)
	if next not in [State.PLAYBACK,State.INPUT]: final_audio.stop()

func end_session():
	if session and is_instance_valid(player): player.cinematic_controls_locked = saved_lock
	session = false
	if final_audio: final_audio.stop()
	shown_direction = -1

func press_direction(direction: int):
	if state!=State.INPUT: return
	var target = step_start+1.0
	if absf(clock-target)<=.25+.000001 and direction==int(mine_definition.pattern[seq_index]) and not failed and not hit:
		hit = true; shown_direction = direction; play_cue(131)
	else: failed = true; hit = false; play_cue(214)

func _input(event):
	if not session or not event is InputEventKey or not event.pressed or event.echo: return
	var key = event.physical_keycode if event.physical_keycode else event.keycode
	var directions = {KEY_W:0,KEY_UP:0,KEY_D:1,KEY_RIGHT:1,KEY_A:2,KEY_LEFT:2,KEY_S:3,KEY_DOWN:3}
	if not directions.has(key): return
	if state==State.INPUT: press_direction(directions[key])
	get_viewport().set_input_as_handled()

func item_step(delta: float):
	if not ready_world or not enabled: return
	if session and player.current_state in [player.WolfState.SAM_DEATH,player.WolfState.BLAST_DEATH,player.WolfState.PIT_FALL]:
		end_session(); set_phase(State.ARMED)
	clock += delta; elapsed += delta
	var phase = fposmod(clock+float(mine_definition.phase_seconds),3.0)
	var was_dormant = dormant; dormant = phase<1.5
	wave_radius = (phase-1.5)*2.0/1.5 if not dormant else 0.0
	if was_dormant and not dormant and state==State.ARMED: play_cue(125)
	if player.cinematic_controls_locked and not session: draw_ring(false); return
	if state==State.ARMED:
		var red_length = float(original_visual.rig.animations.red.duration)
		var visual_time = fposmod(clock,red_length+float(original_visual.rig.animations.green.duration))
		original_visual.sample_animation("red" if visual_time<red_length else "green",visual_time if visual_time<red_length else visual_time-red_length)
	if state in [State.PLAYBACK,State.INPUT]: step_defuse()
	elif state==State.ARMED and not dormant and not is_instance_valid(holder):
		for target in get_tree().get_nodes_in_group("player")+get_tree().get_nodes_in_group("blast_targets")+get_tree().get_nodes_in_group("carryable_rocks"):
			if target==self or target is OriginalDefusableMine or target.get_world_3d()!=get_world_3d() or not target.is_visible_in_tree(): continue
			var difference = target.global_position-global_position
			if absf(difference.y)<=wave_radius*.5 and Vector2(difference.x,difference.z).length()<=wave_radius:
				set_phase(State.COUNTDOWN); break
	elif state==State.COUNTDOWN and elapsed>=float(0x2aa)/4096: explode()
	elif state==State.EXPLODING:
		var previous = elapsed-delta
		explosion.sample_animation("boom",elapsed)
		for cue in explosion.rig.animations.boom.sound_cues:
			if previous<float(cue.time) and elapsed>=float(cue.time): play_cue(int(cue.sound_id))
		if elapsed>=float(explosion.rig.animations.boom.duration): explosion.hide(); set_phase(State.EXPLODED)
	elif state==State.EXPLODED and elapsed>=20: original_visual.show(); set_phase(State.REARMING)
	elif state==State.REARMING and elapsed>=5 and dormant: set_phase(State.ARMED)
	draw_ring(state==State.ARMED and not dormant and not is_instance_valid(holder))

func step_defuse():
	var since = clock-step_start
	var lights = mini(4,1+int(since*3)) if since<1.25 else 0
	if lights!=lights_shown:
		if lights>0 and lights<4: play_cue(126)
		lights_shown = lights
	if state==State.PLAYBACK:
		shown_direction = int(mine_definition.pattern[seq_index]) if since>=1 and since<1.5 else -1
		if since>=1 and not played_beat: played_beat = true; play_cue(131)
		var last = seq_index==mine_definition.pattern.size()-1
		if last and since>=1.5 and not final_audio.playing: play_final()
		if since>=(3.5 if last else 1.5):
			seq_index += 1; step_start = clock; played_beat = false; lights_shown = 0
			if seq_index>=mine_definition.pattern.size(): final_audio.stop(); set_phase(State.INPUT)
	elif state==State.INPUT and since>=1.5:
		if failed or not hit: explode()
		else:
			seq_index += 1; step_start = clock; hit = false; shown_direction = -1; lights_shown = 0
			if seq_index>=mine_definition.pattern.size(): set_phase(State.SAFE)

func play_cue(identity: int):
	if not sounds.has(str(identity)): return
	sound.stream = load(sounds[str(identity)]); sound.play()
func play_final():
	if not sounds.has("132"): return
	var stream: AudioStreamWAV = load(sounds["132"]).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = roundi(stream.mix_rate*stream.get_length())
	final_audio.stream = stream; final_audio.play()

func draw_ring(on: bool):
	ring.visible = on
	if not on: return
	var mesh = ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(48):
		for angle in [i*TAU/48,(i+1)*TAU/48]: mesh.surface_add_vertex(Vector3(cos(angle)*wave_radius,.04,sin(angle)*wave_radius))
	mesh.surface_end(); ring.mesh = mesh

func explode():
	if state in [State.EXPLODING,State.EXPLODED]: return
	end_session(); set_phase(State.EXPLODING)
	original_visual.hide(); explosion.show(); explosion.sample_animation("boom",0); ring.hide()
	for cue in explosion.rig.animations.boom.sound_cues:
		if float(cue.time)==0: play_cue(int(cue.sound_id))
	for target in get_tree().get_nodes_in_group("blast_targets")+get_tree().get_nodes_in_group("player"):
		if target==self or target is OriginalDefusableMine or target.get_world_3d()!=get_world_3d(): continue
		var difference = target.global_position-global_position
		if Vector2(difference.x,difference.z).length()>3 or absf(difference.y)>3: continue
		if target.has_method("on_blast"): target.on_blast(global_position)
		elif target is RalphController: target.set_state(target.WolfState.BLAST_DEATH)

func on_blast(_origin: Vector3):
	if enabled and state not in [State.EXPLODING,State.EXPLODED]: set_phase(State.COUNTDOWN)

func equip_to(actor: Node3D):
	state = State.SAFE; super.equip_to(actor); original_visual.sample_animation("link",0)
func _update_held_position():
	if holder is RalphController:
		global_transform = holder.skeleton.global_transform*holder.legacy_skin.last_matrices[18]
		global_basis *= GameSpace.EXPORT_TO_GODOT
	else: super._update_held_position()
func use_item(actor: Node3D) -> Dictionary:
	if not actor is RalphController or not actor.is_on_floor(): return {"success":false}
	return {"success":actor.item_actions.begin([
		{"clip":"throw_place","exit":func():
			var placement = OriginalPlacement.probe(actor,self,true)
			if placement.is_empty():
				actor.item_actions.stages[actor.item_actions.index+1] = {"clip":"placement_refused"}; return
			holder = null; global_position = placement.position; rotation = Vector3.ZERO
			OriginalPlacement.follow_support(self,placement); reset_position = global_position
			available = true; deployed = true; show(); original_visual.show(); original_visual.sample_animation("red",0)
			actor.inventory.state.remove(item_id); set_phase(State.REARMING)},
		{"clip":"throw_end"}]),"consumed":false}

func capture_mine_state() -> Dictionary:
	return {"enabled":enabled,"position":SaveFiles.vector(reset_position),"safe":state==State.SAFE}
func restore_mine_state(record: Dictionary):
	enabled = bool(record.get("enabled",not mine_definition.get("staged",false)))
	if SaveFiles.valid_vector(record.get("position")): reset_position = SaveFiles.to_vector(record.position)
	reset_mine()
	if record.get("safe",false): set_phase(State.SAFE)
	if player.inventory.state.items.has(item_id): state = State.SAFE; store()
func capture_world_state(): return capture_mine_state()
func restore_world_state(record: Dictionary):
	if not ready_world: pending_world_state = record.duplicate(true)
	else: restore_mine_state(record)
func _exit_tree(): end_session()
