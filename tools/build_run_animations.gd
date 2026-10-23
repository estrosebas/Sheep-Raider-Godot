extends SceneTree

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_run_data.json"))
	data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_catapult_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_sam_attacks.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_sam_attacks.json")).animations,true)
	if FileAccess.file_exists("res://assets/models/ralph_water_data.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_water_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_interaction_data.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_interaction_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_cover_data.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_cover_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_held_idle_data.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_held_idle_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_crush_data.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_crush_data.json")).animations,true)
	var model: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_data.json"))
	if FileAccess.file_exists("res://assets/models/ralph_elastic_data.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_elastic_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_flute_data.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_flute_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_shark_data.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_shark_data.json")),true)
	var library: AnimationLibrary = load("res://assets/models/ralph_animations.tres")
	if FileAccess.file_exists("res://assets/models/ralph_climb_data.json"):
		data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_climb_data.json")),true)
	data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_sneak_data.json")),true)
	for name in data["animations"]:
		var source = data["animations"][name]
		var animation = Animation.new()
		animation.length = source["duration"]
		var is_idle = name == "idle" or name.begins_with("idle_stand") or name in ["held_item_idle","rocket_idle","sneak_idle"]
		var is_native_fall = name == "fall" or name.begins_with("swim") or name.begins_with("elastic_") or name.begins_with("climb_")
		var is_sam_attack = name in ["sam_hit","sam_caught","sam_death","catapult_turn"]
		var is_interaction = name.begins_with("push_") or name.begins_with("fan_blow_") or name.begins_with("bush_") or name.begins_with("cover_") or name.begins_with("flute_") or name in ["shark_death","bull_death","crush_death","held_item_fidget"]
		animation.loop_mode = Animation.LOOP_LINEAR if is_idle or is_native_fall or name in ["cover_hidden","push_loop","fan_blow_idle","fan_blow_turn","run", "run_recover", "rocket_ride", "sheep_carry_idle", "sheep_carry_tired", "sheep_carry_walk", "sheep_carry_sneak", "sheep_carry_fall","held_item_idle"] else Animation.LOOP_NONE
		if name in ["flute_idle","flute_walk"]: animation.loop_mode = Animation.LOOP_LINEAR
		if name=="sneak_idle": animation.loop_mode = Animation.LOOP_LINEAR
		if name=="catapult_turn": animation.loop_mode = Animation.LOOP_LINEAR
		for joint in range(model["joints"].size()):
			var offset = model["joints"][joint]["offset"]
			var rest = Vector3(offset[0], offset[1], offset[2])
			var rotation_track = animation.add_track(Animation.TYPE_ROTATION_3D)
			var position_track = animation.add_track(Animation.TYPE_POSITION_3D)
			var scale_track = animation.add_track(Animation.TYPE_SCALE_3D)
			var path = NodePath("Skeleton3D:joint_%02d" % joint)
			animation.track_set_path(rotation_track, path)
			animation.track_set_path(position_track, path)
			animation.track_set_path(scale_track, path)
			for frame_index in range(source["frames"].size()):
				var frame = source["frames"][frame_index]
				var pose = frame["joints"][joint]
				var r = pose["rot"]
				var p = pose["pos"]
				var s = pose["scale"]
				# Mat44::SetRotYXZ operates on row vectors. For the exported Y
				# reflection, its clockwise keys become Godot Rz * Rx * Ry.
				# decode() already negated Y/Z: undo its extra Z sign here.
				var rotation = Basis.from_euler(Vector3(r[0], r[1], -r[2]), EULER_ORDER_ZXY).get_rotation_quaternion() if is_sam_attack or is_interaction or is_idle or is_native_fall or name.begins_with("sheep_") or name in ["fall_death","pickup_start","pickup_end","item_take_out","item_stow","throw_place","throw_end","held_item_idle"] else Basis.from_euler(Vector3(r[0], r[1], r[2]), EULER_ORDER_YXZ).get_rotation_quaternion()
				var position = rest + Vector3(p[0], p[1], p[2])
				var scale = Vector3(s[0], s[1], s[2])
				# RUNF2 uses scale to collapse thighs/shins and stretch rotating feet.
				# Its keys start at each segment boundary; close the loop continuously.
				if is_interaction or is_idle or is_native_fall or name in ["run", "rocket_ride","pickup_start","pickup_end","item_take_out","item_stow","throw_place","throw_end","held_item_idle"] or name.begins_with("sheep_"):
					var time = 0.0 if frame_index == 0 else source["frames"][frame_index - 1]["time"]
					animation.rotation_track_insert_key(rotation_track, time, rotation)
					animation.position_track_insert_key(position_track, time, position)
					animation.scale_track_insert_key(scale_track, time, scale)
					if frame_index == 0 and animation.loop_mode == Animation.LOOP_LINEAR:
						animation.rotation_track_insert_key(rotation_track, animation.length, rotation)
						animation.position_track_insert_key(position_track, animation.length, position)
						animation.scale_track_insert_key(scale_track, animation.length, scale)
					continue
				# First pose exists at time zero, avoiding a rest-pose flash.
				if frame_index == 0:
					animation.rotation_track_insert_key(rotation_track, 0.0, rotation)
					animation.position_track_insert_key(position_track, 0.0, position)
					animation.scale_track_insert_key(scale_track, 0.0, scale)
				animation.rotation_track_insert_key(rotation_track, frame["time"], rotation)
				animation.position_track_insert_key(position_track, frame["time"], position)
				animation.scale_track_insert_key(scale_track, frame["time"], scale)
		if library.has_animation(name):
			library.remove_animation(name)
		library.add_animation(name, animation)
		print("Added ", name, ": ", animation.length, " seconds")
	quit(ResourceSaver.save(library, "res://assets/models/ralph_animations.tres"))
