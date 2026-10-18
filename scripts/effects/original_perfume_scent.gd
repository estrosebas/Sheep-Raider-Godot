extends Node3D
var particles = []
var frames: Array[Texture2D] = []
var elapsed = 0.0
var emitted_total = 0
const LIFE = 45056.0/4096
const PERIOD = 1408.0/4096
func _ready():
	for path in JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/perfume/source.json")).frames: frames.append(load(path))
	for i in range(32):
		var sprite = Sprite3D.new()
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.hide()
		add_child(sprite)
		particles.append({"sprite":sprite,"age":LIFE})
func _process(delta: float):
	var perfume = get_parent()
	if not perfume.active or not perfume.deployed:
		clear(); return
	for particle in particles:
		if particle.age >= LIFE: continue
		particle.age += delta
		var sprite: Sprite3D = particle.sprite
		if particle.age >= LIFE: sprite.hide(); continue
		var strength = maxf(0,.8-absf(1.3-sprite.position.y))/.8
		if perfume.wind_this_frame: sprite.position += perfume.blow_heading*4.5*strength*delta
		sprite.position.y += .15*delta
		sprite.pixel_size = lerpf(.16,.64,particle.age/LIFE)/sprite.texture.get_width()
	elapsed += delta
	while elapsed >= PERIOD:
		elapsed -= PERIOD
		for particle in particles:
			if particle.age < LIFE: continue
			particle.age = 0
			particle.sprite.texture = frames[randi()%frames.size()]
			particle.sprite.position = Vector3(randf_range(-.08,.08),.4,randf_range(-.08,.08))
			particle.sprite.show()
			emitted_total += 1
			break
func clear():
	elapsed = 0
	for particle in particles: particle.age = LIFE; particle.sprite.hide()
