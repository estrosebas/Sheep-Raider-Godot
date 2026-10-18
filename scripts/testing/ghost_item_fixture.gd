extends Node3D

var scared_time = 0.0
var label: Label3D

func _ready() -> void:
	add_to_group("ghost_targets")
	label = Label3D.new()
	label.text = "Fantasma de prueba"
	label.position.y = 2.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	label.hide()
	var mesh = MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	mesh.mesh.radius = 0.35
	mesh.mesh.height = 1.5
	mesh.position.y = 1.0
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.9, 1.0)
	mesh.material_override = material
	add_child(mesh)

func on_ghost_boo(_actor: Node3D) -> void:
	scared_time = 3.0
	label.text = "¡Bú!"

func _process(delta: float) -> void:
	if scared_time > 0.0:
		scared_time = maxf(0.0, scared_time - delta)
		if scared_time == 0.0:
			label.text = "Fantasma de prueba"
