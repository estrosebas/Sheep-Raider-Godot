extends AudioStreamPlayer3D
# sound_mgr.cpp::Sound_SetDistanceFalloff(200,5000,0,1): centimeters.
# Keep Godot's spatial panning, but reproduce the native linear volume curve.
var native_falloff = false
var source_volume_db = 0.0
static func distance_gain(distance: float) -> float:
	return clampf((50.0-distance)/48.0,0.0,1.0)
func configure_native(enabled: bool,base_db: float = 0.0):
	native_falloff = enabled; source_volume_db = base_db
	attenuation_model = ATTENUATION_DISABLED if enabled else ATTENUATION_INVERSE_DISTANCE
	max_distance = 0 if enabled else 30
	volume_db = base_db
	if enabled: update_gain()
func update_gain():
	var camera = get_viewport().get_camera_3d()
	if camera:
		var gain = distance_gain(global_position.distance_to(camera.global_position))
		volume_db = source_volume_db+linear_to_db(maxf(gain,.00001))
func _process(_delta):
	if playing and native_falloff: update_gain()
