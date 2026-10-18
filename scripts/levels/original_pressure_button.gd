extends Node3D
class_name OriginalPressureButton
# SensibleButton::PostLoadInit/Update: OFF raised, ON occupied, no solid body.
var definition: Dictionary
var visual: OriginalCinematicActor
var pressed = false
var enabled = true
var occupants: Array = []
var sound: AudioStreamPlayer3D
var sound_path = ""

func _ready():
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	visual.sample_animation("off",.01)
	enabled = int(definition.props.get("0x8",0)) != 12
	visible = enabled
	sound = AudioStreamPlayer3D.new(); add_child(sound)
	if ResourceLoader.exists(sound_path): sound.stream = load(sound_path)
	add_to_group("sheep_attractors")
	add_to_group("pressure_buttons")
	call_deferred("ground_button")

func ground_button():
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,global_position+Vector3.DOWN*3)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): global_position.y = hit.position.y

func scent_position() -> Vector3: return global_position
func scent_strength() -> float:
	return 6.0 if enabled and int(definition.props.get("0x8",0)) != 14 else 0.0

func _physics_process(_delta: float):
	occupants.clear()
	if enabled:
		var box = definition.boxes[0]; var a = box.min; var b = box.max
		var lo = GameSpace.original_point(Vector3(a[0],b[1],b[2]))
		var hi = GameSpace.original_point(Vector3(b[0],a[1],a[2]))
		var query = PhysicsShapeQueryParameters3D.new(); var shape = BoxShape3D.new()
		shape.size = hi-lo; query.shape = shape
		query.transform.origin = global_position+(lo+hi)/2
		for hit in get_world_3d().direct_space_state.intersect_shape(query,64):
			var body = hit.collider
			if body is RalphController or body is OriginalSheep or (body is CharacterBody3D and body.get_meta("original_class","") == "Rock"):
				if body is OriginalSheep and (body.carried_by or body.dead): continue
				occupants.append(body)
				if occupants.size() == 4: break
	var next = not occupants.is_empty()
	if next != pressed:
		pressed = next
		visual.sample_animation("on" if pressed else "off",.01)
		if sound.stream: sound.play()
	for resource in definition.targets:
		for target in get_parent().get_children():
			if int(target.get_meta("original_resource",-1)) == int(resource) and target.has_method("set_switch"):
				target.set_switch(self,pressed)
