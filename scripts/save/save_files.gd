@static_unload
extends RefCounted
class_name SaveFiles

const VERSION = 1
const STUDIO_SCENE = "res://scenes/hub/Studio.tscn"
const AUTO_SLOT = 0
static var directory = "user://saves"
static var pending: Dictionary = {}
static var startup_offered = false
static var studio_initialized = false
static var resume_checkpoint: Dictionary = {}

static func slot_path(slot: int) -> String:
	if slot == AUTO_SLOT: return directory+"/autosave.json"
	return directory+"/slot_%d.json" % slot

static func valid(record: Variant) -> bool:
	if not record is Dictionary: return false
	if record.get("version") != VERSION: return false
	if record.get("level") == "studio": return valid_studio_record(record)
	if record.get("level") != "lvl_00" and OriginalProgress.valid_level(str(record.get("level",""))): return valid_imported_record(record)
	if record.get("level") != "lvl_00": return false
	if not record.get("checkpoint") is Dictionary or not record.get("inventory") is Array or not record.get("training") is Dictionary or not record.get("world") is Dictionary: return false
	if int(record["checkpoint"].get("index",-1)) not in range(6) or not record["checkpoint"].get("reached") is Array: return false
	var training: Dictionary = record["training"]
	if not valid_vector(training.get("position")) or int(training.get("index",-1)) not in range(21) or not training.get("yaw") is float and not training.get("yaw") is int: return false
	var world: Dictionary = record["world"]
	for key in ["falling","mailboxes","rocks","items"]:
		if not world.get(key) is Array: return false
	if not world.get("platforms") is Dictionary or not world.get("gate_open") is bool: return false
	for item in record["inventory"]:
		if not item is Dictionary or not item.get("id") is String or int(item.get("class_id",-1)) != 10: return false
	for item in world["items"]:
		if not item is Dictionary or not item.get("id") is String or not valid_vector(item.get("position")) or not valid_vector(item.get("home")) or not item.get("available") is bool: return false
	for rock in world["rocks"]:
		if not rock is Dictionary or not valid_vector(rock.get("position")) or not rock.has("resource"): return false
	for rock in world["falling"]:
		if not rock is Dictionary or not rock.has("resource") or not rock.get("active") is bool: return false
	for box in world["mailboxes"]:
		if not box is Dictionary or not box.has("resource") or not box.get("opened") is bool or not box.get("committed") is bool: return false
	if record.has("progress") and not OriginalProgress.valid(record["progress"]): return false
	return true

static func valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for coordinate in value:
		if not coordinate is float and not coordinate is int: return false
		if not is_finite(float(coordinate)) or absf(float(coordinate)) > 10000: return false
	return true

static func read_slot(slot: int) -> Dictionary:
	if slot not in range(0,4): return {}
	var path = slot_path(slot)
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 1024*1024: return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK: return {}
	var wrapper = json.data
	if not wrapper is Dictionary or not wrapper.get("payload") is String: return {}
	var payload: String = wrapper["payload"]
	if wrapper.get("sha256") != payload.sha256_text(): return {}
	if json.parse(payload) != OK: return {}
	var record = json.data
	return record if valid(record) else {}

static func write_slot(slot: int, snapshot: Dictionary) -> Error:
	if slot not in range(0,4) or not valid(snapshot): return ERR_INVALID_DATA
	var error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return error
	var record = snapshot.duplicate(true)
	record["saved_at"] = Time.get_datetime_string_from_system()
	record["saved_at_us"] = int(Time.get_unix_time_from_system()*1000000)
	record["progress"] = OriginalProgress.snapshot()
	var payload = JSON.stringify(record)
	var path = slot_path(slot)
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return error
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(path+".bak")
		error = DirAccess.rename_absolute(path,path+".bak")
		if error != OK: return error
	error = DirAccess.rename_absolute(path+".tmp",path)
	if error != OK and FileAccess.file_exists(path+".bak"): DirAccess.rename_absolute(path+".bak",path)
	if error == OK:
		OriginalProgress.timekeeper_unsaved = false
		OriginalProgress.completion_unsaved = false
		OriginalProgress.bonus_unsaved = false
		remember_checkpoint(record)
	return error

static func vector(value: Vector3) -> Array: return [value.x,value.y,value.z]
static func to_vector(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])

static func scene_for_level(level: String) -> String:
	if level == "studio": return STUDIO_SCENE
	if not OriginalProgress.valid_level(level): return ""
	var path = "res://scenes/levels/Level%02d.tscn"%int(level.trim_prefix("lvl_"))
	return path if ResourceLoader.exists(path) else ""

static func valid_imported_record(record: Dictionary) -> bool:
	var checkpoint = record.get("checkpoint")
	if not checkpoint is Dictionary or int(checkpoint.get("index",-2)) < -1 or int(checkpoint.get("index",-2)) >= 64: return false
	if record.level == "lvl_01" and int(checkpoint.index) >= 8: return false
	if not valid_vector(checkpoint.get("position")) or not valid_vector(checkpoint.get("camera")): return false
	if not checkpoint.get("facing") is int and not checkpoint.get("facing") is float: return false
	if not record.get("inventory") is Array or not record.get("world") is Dictionary: return false
	for item in record.inventory:
		if not item is Dictionary or not item.get("id") is String or int(item.get("class_id",-1)) not in range(200): return false
	for key in ["items","sheep","mailboxes"]:
		if not record.world.get(key) is Array: return false
	for item in record.world.items:
		if not item is Dictionary or not item.get("id") is String or not valid_vector(item.get("position")) or not valid_vector(item.get("home")) or not item.get("available") is bool: return false
	for sheep in record.world.sheep:
		if not sheep is Dictionary or not valid_vector(sheep.get("position")) or not sheep.get("resource") is int and not sheep.get("resource") is float: return false
	for mailbox in record.world.mailboxes:
		if not mailbox is Dictionary or not mailbox.has("resource") or not mailbox.get("opened") is bool or not mailbox.get("committed") is bool: return false
		if not mailbox.get("containers",[]) is Array: return false
		for container in mailbox.get("containers",[]):
			if not container is Dictionary or not container.has("resource") or not valid_vector(container.get("position")) or container.get("state") not in ["sealed","fall","open"] or not container.get("held") is bool: return false
	if not record.world.get("rocks",[]) is Array: return false
	for rock in record.world.get("rocks",[]):
		if not rock is Dictionary or not rock.has("resource") or not rock.get("broken") is bool: return false
	if not record.world.get("pushables",[]) is Array: return false
	if not record.world.get("gates",[]) is Array: return false
	if not record.world.get("mobile_platforms",[]) is Array: return false
	for platform in record.world.get("mobile_platforms",[]):
		if not platform is Dictionary or not platform.has("resource") or (not platform.get("distance") is int and not platform.get("distance") is float): return false
		if not is_finite(float(platform.distance)) or float(platform.distance)<0: return false
	for gate in record.world.get("gates",[]):
		if not gate is Dictionary or not gate.has("resource") or not gate.get("opened") is bool or not gate.get("latched") is bool: return false
	if not record.world.get("weighted_platforms",[]) is Array: return false
	for platform in record.world.get("weighted_platforms",[]):
		if not platform is Dictionary or not platform.get("resource") is int and not platform.get("resource") is float: return false
		if not platform.get("height") is float and not platform.get("height") is int or not is_finite(float(platform.height)) or absf(float(platform.height))>10000: return false
	for rock in record.world.get("pushables",[]):
		if not rock is Dictionary or not rock.has("resource") or not valid_vector(rock.get("position")): return false
	if not record.get("lessons") is Dictionary: return false
	if record.has("progress") and not OriginalProgress.valid(record.progress): return false
	return true

static func slot_description(record: Dictionary) -> String:
	if record.is_empty(): return GameLocalization.ui("Vacía")
	if record.level == "studio": return GameLocalization.ui("Plató")+" - "+GameLocalization.ui("Ovejas extraídas: %d/%d")%[int(record.progress.get("sheep_extracted",0)),OriginalProgress.TOTAL_SHEEP]
	var index = int(record.checkpoint.index)
	var level = int(str(record.level).trim_prefix("lvl_"))
	return GameLocalization.ui("Nivel %02d")%level+" - "+(GameLocalization.ui("Inicio") if index < 0 else "Checkpoint %d"%(index+1))

static func valid_studio_record(record: Dictionary) -> bool:
	var point = record.get("checkpoint",{})
	if not point is Dictionary or not valid_vector(point.get("position")) or not valid_vector(point.get("camera")): return false
	if not point.get("facing") is float and not point.get("facing") is int: return false
	if not OriginalProgress.valid(record.get("progress")): return false
	var resume = record.get("resume_checkpoint",{})
	return resume is Dictionary and (resume.is_empty() or (resume.get("level") != "studio" and valid(resume)))

static func remember_checkpoint(record: Dictionary) -> void:
	if not valid(record): return
	resume_checkpoint = record.get("resume_checkpoint",{}).duplicate(true) if record.level == "studio" else record.duplicate(true)
	if not resume_checkpoint.is_empty(): resume_checkpoint["progress"] = OriginalProgress.snapshot()

static func remember_level_exit(level: Node) -> void:
	var save = level.get_node_or_null("CheckpointSave")
	if save and SaveFiles.valid(save.snapshot): remember_checkpoint(save.snapshot)

static func latest_slot() -> Dictionary:
	var latest: Dictionary = {}
	for slot in [1,2,3,AUTO_SLOT]:
		var record = read_slot(slot)
		if record.is_empty(): continue
		var newer = str(record.get("saved_at",""))>str(latest.get("saved_at",""))
		var same_second = str(record.get("saved_at",""))==str(latest.get("saved_at",""))
		if latest.is_empty() or newer or (same_second and int(record.get("saved_at_us",0))>=int(latest.get("saved_at_us",0))): latest = record
	return latest

static func save_level_completion(level: Node) -> Error:
	var checkpoint = level.get_node_or_null("CheckpointSave")
	var resume: Dictionary = {}
	if checkpoint:
		checkpoint.capture_checkpoint()
		if valid(checkpoint.snapshot):
			resume = checkpoint.snapshot.duplicate(true)
			resume["progress"] = OriginalProgress.snapshot()
	# Completion returns to the original studio, rather than spawning back in
	# the finished level's goal/checkpoint. Older manual files remain unchanged.
	var spawn = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/scene/data/manifest.json")).spawn
	var point = GameSpace.from_export(Vector3(spawn.pos[0],spawn.pos[1],spawn.pos[2]))
	var record = {"version":VERSION,"level":"studio","checkpoint":{"index":-1,"position":vector(point),"facing":0.0,"camera":[0,0,0]},"progress":OriginalProgress.snapshot(),"resume_checkpoint":resume}
	return write_slot(AUTO_SLOT,record)

static func initialize_studio() -> Dictionary:
	# Restore disk progress only at startup, never overwrite fresh unsaved wins
	# on a normal return from a level or the laboratory.
	var record: Dictionary = {}
	if valid(pending) and pending.level == "studio":
		record = pending.duplicate(true); pending = {}
	elif not studio_initialized and resume_checkpoint.is_empty() and not OriginalProgress.completion_unsaved and not OriginalProgress.timekeeper_unsaved: record = latest_slot()
	if not record.is_empty() or (not studio_initialized and resume_checkpoint.is_empty() and not OriginalProgress.completion_unsaved and not OriginalProgress.timekeeper_unsaved):
		OriginalProgress.restore(record.get("progress",{}))
		resume_checkpoint = {}
		if not record.is_empty(): remember_checkpoint(record)
	studio_initialized = true; startup_offered = true
	return record
