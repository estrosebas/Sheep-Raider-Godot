extends Node3D
class_name RalphRunDust

const LIFE = 2608.0/4096
const BASE_INTERVAL = 163.0/4096
var textures: Array[Texture2D] = []
var particles: Array[Dictionary] = []
var spawn_timer = 0.0
var spawned_total = 0
@export var capacity = 32

func _ready() -> void:
	# Spawned particles stay in world space while Ralph moves away.
	top_level = true
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/run_dust/source.json"))
	for frame in data["frames"]:
		var texture: Texture2D = load(frame["path"])
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2.ZERO,texture.get_size()-Vector2.ONE)
		atlas.filter_clip = true
		textures.append(atlas)
	for i in range(capacity):
		var sprite = Sprite3D.new()
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.no_depth_test = false
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var material = ShaderMaterial.new()
		material.shader = preload("res://shaders/original_dust.gdshader")
		sprite.material_override = material
		sprite.hide()
		add_child(sprite)
		particles.append({"sprite":sprite,"age":LIFE,"direction":Vector3.ZERO})

func update_dust(delta: float, emitting: bool, point: Vector3, facing: Vector3, speed: float, maximum: float) -> void:
	for particle in particles:
		if particle["age"] >= LIFE:
			particle["sprite"].hide()
			continue
		particle["age"] += delta
		var sprite: Sprite3D = particle["sprite"]
		sprite.global_position += (particle["direction"]+Vector3.UP*0.2)*delta
		var fraction = clampf(particle["age"]/LIFE,0,1)
		var size = lerpf(0.4,1.2,fraction)
		sprite.pixel_size = size / sprite.texture.get_width()
		# Original grey is texture modulation, rather than an alpha fade.
		var grey = fraction*4 if fraction < 0.25 else (1-fraction)*4/3
		sprite.material_override.set_shader_parameter("grey",grey)
	if not emitting:
		spawn_timer = 0
		return
	spawn_timer += delta
	var interval = BASE_INTERVAL*maximum/maxf(speed,0.5)
	while spawn_timer >= interval:
		spawn_timer -= interval
		for particle in particles:
			if particle["age"] >= LIFE:
				var sprite: Sprite3D = particle["sprite"]
				sprite.texture = textures[randi()%textures.size()]
				sprite.material_override.set_shader_parameter("dust_texture",sprite.texture.atlas)
				sprite.global_position = point+Vector3.UP*0.2
				sprite.material_override.set_shader_parameter("grey",0.0)
				sprite.show()
				particle["age"] = 0.0
				particle["direction"] = -facing.normalized()
				spawned_total += 1
				break

func clear() -> void:
	spawn_timer = 0
	for particle in particles:
		particle["age"] = LIFE
		particle["sprite"].hide()
