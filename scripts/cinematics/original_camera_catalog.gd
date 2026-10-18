extends RefCounted
class_name OriginalCameraCatalog
const PATH = "res://assets/cinematics/camera_catalog.json"
static var data: Dictionary = {}
static func ensure():
	if data.is_empty(): data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
static func sequence(path: String) -> Dictionary:
	ensure()
	for record in data.sequences.values():
		if record.get("source","")==path: return record
	return {"kind":"camera_animation","return_transition":"none"}
static func entry_for(directory: String) -> Dictionary:
	ensure(); return data.entries.get(directory,{})
static func named(identity: String) -> Dictionary:
	ensure(); return data.sequences.get(identity,{})
static func next_sequence(path: String) -> Dictionary:
	return named(sequence(path).get("next",""))
static func apply_return(player,transition: String):
	if transition!="iris": return
	player.restart_fade.set_iris(true)
	player.restart_fade.set_amount(1)
	player.restart_fade_remaining = OriginalRestartFade.DURATION
