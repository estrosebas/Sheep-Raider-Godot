extends Node

var snapshot: Dictionary = {}

func _ready():
	capture_checkpoint()

func capture_checkpoint():
	var player: RalphController = get_parent().get_node("Player")
	snapshot = {"version":SaveFiles.VERSION,"level":"studio",
		"checkpoint":{"index":-1,"position":SaveFiles.vector(player.global_position),"facing":player.skeleton.rotation.y,"camera":SaveFiles.vector(player.camera_pivot.rotation)},
		"progress":OriginalProgress.snapshot(),"resume_checkpoint":SaveFiles.resume_checkpoint.duplicate(true)}

func restore_checkpoint(record: Dictionary) -> bool:
	if not SaveFiles.valid(record) or record.level != "studio": return false
	OriginalProgress.restore(record.progress)
	SaveFiles.remember_checkpoint(record)
	get_parent().refresh_progress()
	return true
