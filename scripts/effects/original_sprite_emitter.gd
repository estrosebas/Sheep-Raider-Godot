extends Node3D
class_name OriginalSpriteEmitter
var frames: Array[Texture2D] = []
var particles: Array = []
var emitting = false
var life = .5
var period = .5
var rise_speed = 2.0
var size_start = .16
var size_end = .64
var spread = 0.0
var frame_index = 0
var elapsed = 0.0
var emitted_total = 0
var world_space = false
func configure(paths: Array,capacity: int = 3) -> void:
	for path in paths: frames.append(load(path))
	for i in range(capacity):
		var sprite = Sprite3D.new()
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.hide()
		add_child(sprite)
		sprite.top_level = world_space
		particles.append({"sprite":sprite,"age":life,"velocity":Vector3.ZERO})
func _process(delta: float) -> void:
	for particle in particles:
		particle["age"] += delta
		var sprite: Sprite3D = particle["sprite"]
		if particle["age"] >= life:
			sprite.hide()
			continue
		sprite.position += particle["velocity"]*delta
		sprite.pixel_size = lerpf(size_start,size_end,particle["age"]/life)/sprite.texture.get_width()
	if not emitting or frames.is_empty():
		elapsed = 0
		return
	elapsed += delta
	while elapsed >= period:
		elapsed -= period
		for particle in particles:
			if particle["age"] < life: continue
			var sprite: Sprite3D = particle["sprite"]
			sprite.texture = frames[posmod(frame_index,frames.size())]
			if world_space: sprite.global_position = global_position
			else: sprite.position = Vector3.ZERO
			sprite.show()
			particle["age"] = 0
			particle["velocity"] = Vector3(randf_range(-spread,spread),rise_speed,randf_range(-spread,spread))
			emitted_total += 1
			break
func clear() -> void:
	emitting = false
	for particle in particles:
		particle["age"] = life
		particle["sprite"].hide()
