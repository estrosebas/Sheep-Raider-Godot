extends StaticBody3D
class_name OriginalBreakableRocks
var visual_scene = "res://assets/levels/lvl_01/models/34/worn.tscn"
var definition: Dictionary
var visual: OriginalCinematicActor
var broken = false
var elapsed = 0.0
func _ready() -> void:
	add_to_group("blast_targets")
	visual = load(visual_scene).instantiate()
	add_child(visual)
	visual.sample_animation("stand1",0)
	var record = definition.duplicate(true)
	record["position"] = [0,0,0]
	OriginalSolidBuilder.build(self,"",[],[record])
func on_blast(_point: Vector3) -> void:
	if broken: return
	broken = true
	elapsed = 0
func _process(delta: float) -> void:
	if not broken: return
	elapsed += delta
	visual.sample_animation("boom01",elapsed)
	if elapsed >= float(visual.rig["animations"]["boom01"]["duration"]):
		hide()
		for child in find_children("*","CollisionShape3D",true,false): child.set_deferred("disabled",true)

func restore_saved_state(was_broken: bool):
	broken = was_broken
	elapsed = float(visual.rig.animations.boom01.duration) if broken else 0
	visible = not broken
	visual.sample_animation("boom01" if broken else "stand1",elapsed)
	for shape in find_children("*","CollisionShape3D",true,false): shape.set_deferred("disabled",broken)
