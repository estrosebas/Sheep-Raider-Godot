extends Node3D

# Wolf::RunAirFallStep -> Fx0_Start / SetState -> Fx0_Stop.
var actor: RalphController
var visual: OriginalCinematicActor
var active = false
const OFFSET = Vector3(0,1.5,0)

func _ready() -> void:
	actor = get_parent()
	visual = load("res://assets/effects/dizzy/worn.tscn").instantiate()
	add_child(visual)
	visual.sample_animation("turn1",0)
	stop()

func start() -> void:
	active = true
	visual.idle("turn1")
	visual.sample_animation("turn1",0)
	update_attachment()
	show()

func stop() -> void:
	active = false
	if visual: visual.idle_clip = ""
	hide()

func update_attachment() -> void:
	if not active or actor.legacy_skin.last_matrices.is_empty(): return
	var joint: Transform3D = actor.skeleton.global_transform*actor.legacy_skin.last_matrices[0]
	global_transform = joint*Transform3D(Basis.IDENTITY,OFFSET)
