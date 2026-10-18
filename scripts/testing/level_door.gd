extends Node3D
class_name LabLevelDoor
const ORIGINAL_LEVEL_LABELS = ["0","1","2","3","4","B1","5","6","7","8","B2","9","10","11","12","13","14","X"]
@export var level_scene = "res://scenes/levels/Level00.tscn"
@export var level_label = "Nivel 00"
@export var resume_saved_checkpoint = false
@export var sequential_progress = false
var visual: OriginalCinematicActor
var label: Label3D
var entering = false
var time = 0.0
var actor: RalphController
func _ready() -> void:
	visual = load("res://assets/hub/studio_door/worn.tscn").instantiate()
	add_child(visual)
	visual.sample_animation("close2",0)
	label = Label3D.new()
	label.text = level_label+"\nE: entrar"
	label.position = Vector3(0,2.8,0)
	label.font_size = 48
	label.pixel_size = .008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	label.hide()
	add_to_group("world_interactables")
func can_interact(player: Node3D) -> bool:
	return is_unlocked() and not entering and player.can_use_item() and player.global_position.distance_to(global_position) < 2.8 and ResourceLoader.exists(level_scene)
func can_show_status(player: RalphController) -> bool:
	# DoorLevel::MSG_QUERY_ACTION also describes an uncompleted/locked level.
	return not entering and is_visible_in_tree() and player.can_use_item() and not player.inventory.wheel_open and player.global_position.distance_to(global_position)<2.8
func level_identity() -> String:
	var basename = level_scene.get_file().get_basename()
	if not basename.begins_with("Level"): return ""
	var identity = "lvl_"+basename.trim_prefix("Level")
	return identity if OriginalProgress.valid_level(identity) else ""
func status_text() -> String:
	var identity = level_identity()
	if identity.is_empty(): return GameLocalization.ui("Entrar al ")+level_label
	var number = int(identity.trim_prefix("lvl_"))
	var status = 2 # DOORLEVELSTR_NOT_COMPLETED
	if OriginalProgress.is_completed(identity):
		status = 4 if number==0 or OriginalProgress.has_clock(identity) else 3
	# Native MLT class-string list171, including localized level/status wording.
	return "%s %s: %s"%[GameLocalization.text("scene",171,1),ORIGINAL_LEVEL_LABELS[number],GameLocalization.text("scene",171,status)]
func is_unlocked() -> bool:
	if not sequential_progress: return true
	return OriginalProgress.is_level_unlocked(level_identity())
func interact(player: Node3D) -> bool:
	if not can_interact(player): return false
	actor = player
	actor.interrupt_actions()
	actor.cinematic_controls_locked = true
	actor.restart_fade.set_amount(0)
	entering = true
	time = 0
	return true
func _process(delta: float) -> void:
	if not entering: return
	time += delta
	visual.sample_animation("open",time)
	var duration = float(visual.rig["animations"]["open"]["duration"])
	actor.restart_fade.set_amount(clampf((time-duration)/.5,0,1))
	if time >= duration+.5:
		entering = false
		if get_parent().scene_file_path != SaveFiles.STUDIO_SCENE: SaveFiles.remember_level_exit(get_parent())
		var record = SaveFiles.resume_checkpoint
		var matching = not record.is_empty() and SaveFiles.scene_for_level(str(record.level)) == level_scene and not OriginalProgress.is_completed(str(record.level))
		SaveFiles.pending = record.duplicate(true) if resume_saved_checkpoint and matching else {"restart":true}
		SaveFiles.startup_offered = true
		get_node("/root/LevelLoading").enter_from_door(level_scene)
