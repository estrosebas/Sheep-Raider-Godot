extends Node3D
class_name OriginalBreakableGround
# IceGround breaks on explosive KILL; SnowyGround collapses under non-Wolf solids.
var definition: Dictionary
var visual: OriginalCinematicActor
var body: StaticBody3D
var bounds: AABB
var breaking = false
var broken = false
var elapsed = 0.0
var audio: AudioStreamPlayer3D
var sounds: Dictionary
func _ready():
	audio = AudioStreamPlayer3D.new(); add_child(audio); audio.max_distance = 50
	var bank = get_parent().asset_directory+"/data/ai_audio.json"
	sounds = JSON.parse_string(FileAccess.get_file_as_string(bank))
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	visual.idle_clip = ""; visual.sample_animation("stand0",0)
	var solids = OriginalSolidBuilder.build(self,"",[],[{"class_name":definition.class_name,"res":definition.res,"position":[0,0,0],"boxes":definition.boxes}])
	body = solids.get_child(0)
	var box = definition.boxes[0]
	var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
	var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
	bounds = AABB(lo,hi-lo)
	add_to_group("blast_targets"); add_to_group("breakable_ground"); add_to_group("checkpoint_controllers")
	get_parent().get_node("Player").respawned.connect(reset_ground)
func set_collision(on: bool):
	for shape in body.get_children(): if shape is CollisionShape3D: shape.set_deferred("disabled",not on)
func break_ground():
	if breaking or broken: return
	breaking = true; elapsed = 0; visual.sample_animation("explod1",0)
	play_cues(-.001,0)
	if int(definition.class_id)==76: set_collision(false)
func on_blast(_origin: Vector3):
	if int(definition.class_id)==77: break_ground()
func _physics_process(delta: float):
	if not breaking and not broken and int(definition.class_id)==76:
		var top = AABB(global_position+bounds.position+Vector3.UP*(bounds.size.y-.01),Vector3(bounds.size.x,.21,bounds.size.z))
		for actor in get_tree().get_nodes_in_group("ice_cubes")+get_tree().get_nodes_in_group("snowballs")+get_tree().get_nodes_in_group("sheep_targets")+get_tree().get_nodes_in_group("game_items"):
			if not actor.is_visible_in_tree() or actor.get_world_3d()!=get_world_3d(): continue
			if actor is GameItem and (actor.holder or not actor.available): continue
			if actor is OriginalSheep and actor.carried_by: continue
			var point = actor.global_position
			if actor.has_method("bottom"): point.y = actor.bottom()
			if top.has_point(point): break_ground(); break
	if breaking:
		play_cues(elapsed,elapsed+delta)
		elapsed += delta; visual.sample_animation("explod1",elapsed)
		if elapsed>=float(visual.rig.animations.explod1.duration): broken = true; breaking = false; set_collision(false)
func reset_ground():
	# SnowyGround has no native Reset override, so its collapse survives a death.
	if int(definition.class_id)==76: return
	broken = false; breaking = false; elapsed = 0; set_collision(true); visual.sample_animation("stand0",0)
func capture_world_state() -> Dictionary: return {"broken":broken or breaking}
func restore_world_state(saved: Dictionary):
	broken = bool(saved.get("broken",false)); breaking = false; elapsed = 0; set_collision(not broken)
	visual.sample_animation("explod1" if broken else "stand0",999 if broken else 0)

func play_cues(previous: float,current: float):
	for cue in visual.rig.animations.explod1.sound_cues:
		if float(cue.time)>previous and float(cue.time)<=current and sounds.has(str(int(cue.sound_id))):
			audio.stream = load(sounds[str(int(cue.sound_id))]); audio.play()
