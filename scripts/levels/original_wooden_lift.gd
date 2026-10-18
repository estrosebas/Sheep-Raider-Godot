extends AnimatableBody3D
class_name OriginalWoodenLift
# WoodenLift: authored endpoint MAXZVALUE, speed property *30 native units/s.
var definition: Dictionary
var visual: OriginalCinematicActor
var home_y = 0.0
var on_y = 0.0
var speed = 0.0
var inputs: Dictionary = {}
var sound: AudioStreamPlayer3D
var sound_path = ""

func _ready():
	sync_to_physics = false
	home_y = float(definition.pos[1]); on_y = float(definition.props["0xc"])*.01
	speed = float(definition.props["0x10"])*.3
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	for box in definition.boxes:
		var a = box.min; var b = box.max
		var lo = GameSpace.original_point(Vector3(a[0],b[1],b[2]))
		var hi = GameSpace.original_point(Vector3(b[0],a[1],a[2]))
		var shape = BoxShape3D.new(); shape.size = hi-lo
		var collision = CollisionShape3D.new(); collision.shape = shape; collision.position = (lo+hi)/2
		add_child(collision)
	sound = AudioStreamPlayer3D.new(); add_child(sound)
	if ResourceLoader.exists(sound_path):
		var stream = load(sound_path).duplicate()
		if stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = stream.get_length()*stream.mix_rate
		sound.stream = stream
	add_to_group("moving_platforms")

func set_switch(sender: Node,on: bool): inputs[sender] = on

func _physics_process(delta: float):
	var next = move_toward(position.y,on_y if inputs.values().has(true) else home_y,speed*delta)
	var moving = not is_equal_approx(next,position.y)
	position.y = next
	if moving and sound.stream and not sound.playing: sound.play()
	elif not moving: sound.stop()
