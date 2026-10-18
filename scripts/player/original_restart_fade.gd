extends CanvasLayer
class_name OriginalRestartFade

# Fade_StartRestart/Fade_Update and Wolf::Reset: last second to black,
# checkpoint reset while covered, then Fade_StartOut(0x1000).
const DURATION = 1.0
var overlay: ColorRect
var iris_enabled = false
var material: ShaderMaterial

func _ready() -> void:
	layer = 90
	overlay = ColorRect.new()
	overlay.color = Color(0,0,0,0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/restart_iris.gdshader")
	material.set_shader_parameter("iris_enabled",iris_enabled)
	overlay.material = material
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_amount(amount: float) -> void:
	# Fade_DrawOverlay quantizes its 0..31 level into ARGB4444 alpha.
	var level = clampi(int(clampf(amount,0,1)*31),0,31)
	overlay.color.a = float(level/2)/15.0
	material.set_shader_parameter("amount",clampf(amount,0,1))

func set_iris(enabled: bool) -> void:
	iris_enabled = enabled
	if material: material.set_shader_parameter("iris_enabled",enabled)
