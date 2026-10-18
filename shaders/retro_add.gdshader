shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, fog_disabled;

#include "legacy_color.gdshaderinc"
#include "legacy_skin.gdshaderinc"

void fragment() {
	vec4 t = sample_page(UV);
	if (!use_linear_filter && t.a < 0.03) {
		discard;
	}
	ALBEDO = legacy_output(t.rgb * COLOR.rgb * vertex_color_scale);
	// Extraction already inverted the game alpha.
	ALPHA = t.a;
}
