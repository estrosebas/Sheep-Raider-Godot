extends StaticBody3D
# FallingGate shared switch adapter: native MV_OPEN/MV_CLOSE and single activation.
var definition: Dictionary
var sounds: Dictionary
var visual: OriginalCinematicActor
var inputs: Dictionary = {}
var opened = false
var latched = false
var clip = "closed"
var elapsed = 0.0
var previous = -.001
var audio: AudioStreamPlayer3D
func _ready():
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	visual.sample_animation("closed",0)
	var record = definition.duplicate(true); record.position = [0,0,0]
	OriginalSolidBuilder.build(self,"",[],[record])
	audio = AudioStreamPlayer3D.new(); add_child(audio)
	add_to_group("falling_gates")
func set_switch(sender: Node,on: bool):
	inputs[sender] = on
	if on and int(definition.props.get("0xc",0))!=0: latched = true
	var next = latched or inputs.values().has(true)
	if next==opened: return
	opened = next; visible = true; clip = "mv_open" if opened else "mv_close"; elapsed = 0; previous = -.001
	for shape in find_children("*","CollisionShape3D",true,false): shape.set_deferred("disabled",opened)
func _process(delta):
	if not clip.begins_with("mv_"): return
	elapsed += delta; visual.sample_animation(clip,elapsed)
	for cue in visual.rig.animations[clip].sound_cues:
		if float(cue.time)>previous and float(cue.time)<=elapsed and sounds.has(str(int(cue.sound_id))):
			audio.stream = load(sounds[str(int(cue.sound_id))]); audio.play()
	previous = elapsed
	if elapsed>=float(visual.rig.animations[clip].duration):
		clip = "open" if opened else "closed"; visible = not opened
		visual.sample_animation(clip,0)
func restore_state(saved_open: bool,saved_latched: bool):
	opened = saved_open; latched = saved_latched; clip = "open" if opened else "closed"
	visible = not opened; visual.sample_animation(clip,0)
	for shape in find_children("*","CollisionShape3D",true,false): shape.set_deferred("disabled",opened)
