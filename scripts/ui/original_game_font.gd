extends RefCounted
class_name OriginalGameFont
const COLOR = Color(.294,.8,1)
const PAUSE_COLOR = Color(1,.85,.22)
const PATH = "res://assets/ui/pause/original_font.fnt"
static var variants: Dictionary = {}

static func animated_glyph(code: int, clock: float) -> int:
	if code < 32 or code > 255: return 63
	if variants.is_empty():
		variants = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/pause/source.json"))["variants"]
	# Text_BlinkButtonGlyphs: original atlas variants, 62 ms per phase.
	var phase = fmod(clock,.186)
	if phase < .062: return int(variants["Fwd"][code-32])
	if phase < .124: return int(variants["Rev"][code-32])
	return code
static func apply(label: Label):
	label.add_theme_font_override("font",load(PATH))
	label.add_theme_color_override("font_color",Color(COLOR.r*2,COLOR.g*2,COLOR.b*2,1))
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",0)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,.85))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
