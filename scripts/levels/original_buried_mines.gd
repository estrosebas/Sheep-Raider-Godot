extends Node3D
class_name OriginalBuriedMines
var definition: Dictionary
var assets: Dictionary
var sounds: Dictionary
var player: RalphController
var explosion: OriginalCinematicActor
var audio: AudioStreamPlayer3D
var elapsed = 0.0
var exploding = false
var cooldown = 0.0
func _ready():
	player = get_parent().get_node("Player")
	explosion = load(assets.explosion.directory+"/worn.tscn").instantiate(); add_child(explosion); explosion.hide()
	audio = AudioStreamPlayer3D.new(); add_child(audio); audio.max_distance = 50
	add_to_group("buried_minefields"); add_to_group("checkpoint_controllers")
	player.respawned.connect(reset_field)
func dangerous(point: Vector3) -> bool:
	return OriginalSam.contains(point,definition.zones) and not OriginalSam.contains(point,definition.safe_zones)
func distance_to_hazard(origin: Vector3,facing: Vector3,limit: float) -> float:
	# RayToHazard advances through hazard and safe AABB edges (no random mines).
	var cuts: Array[float] = [0.0,limit]
	for zone in definition.zones+definition.safe_zones:
		for axis in [0,2]:
			var component = facing[axis]
			if absf(component)<.000001: continue
			var lo = float(zone.min[axis])*.01; var hi = float(zone.max[axis])*.01
			if axis==2: lo = -float(zone.max[axis])*.01; hi = -float(zone.min[axis])*.01
			for edge in [lo,hi]:
				var t = (edge-origin[axis])/component
				if t>0 and t<limit: cuts.append(t)
	cuts.sort()
	for i in range(cuts.size()-1):
		var midpoint = (cuts[i]+cuts[i+1])*.5
		if dangerous(origin+facing*midpoint): return cuts[i]
	return INF
func _physics_process(delta: float):
	if exploding:
		var previous = elapsed; elapsed += delta
		explosion.sample_animation("boom",elapsed)
		for cue in explosion.rig.animations.boom.sound_cues:
			if previous<float(cue.time) and elapsed>=float(cue.time): play_cue(int(cue.sound_id))
		if elapsed>=float(explosion.rig.animations.boom.duration): explosion.hide(); exploding = false; cooldown = 20
		return
	if cooldown>0: cooldown = maxf(0,cooldown-delta); return
	if player.cinematic_controls_locked or player.restart_fade_remaining>0: return
	for target in [player]+get_tree().get_nodes_in_group("sheep_targets"):
		if target.get_world_3d()!=get_world_3d() or not target.is_visible_in_tree(): continue
		if target is OriginalSheep and (target.carried_by or target.dead): continue
		if dangerous(target.global_position): detonate_at(target.global_position); break
func detonate_at(point: Vector3):
	if exploding or cooldown>0: return
	exploding = true; elapsed = 0; global_position = point
	explosion.show(); explosion.sample_animation("boom",0)
	for cue in explosion.rig.animations.boom.sound_cues:
		if float(cue.time)==0: play_cue(int(cue.sound_id))
	for target in get_tree().get_nodes_in_group("blast_targets")+[player]:
		if target==self or target.get_world_3d()!=get_world_3d(): continue
		var d = target.global_position-point
		if Vector2(d.x,d.z).length()<=3 and absf(d.y)<=3:
			if target.has_method("on_blast"): target.on_blast(point)
			elif target is RalphController: target.set_state(target.WolfState.BLAST_DEATH)
func play_cue(id: int):
	if sounds.has(str(id)): audio.stream = load(sounds[str(id)]); audio.play()
func reset_field(): exploding = false; elapsed = 0; cooldown = 0; explosion.hide(); audio.stop()
func capture_world_state() -> Dictionary: return {}
func restore_world_state(_saved: Dictionary): reset_field()
