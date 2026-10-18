shader_type spatial;
// ARCHIVED option 3: alpha blending with a depth prepass. The user preferred
// option 2, which hides rear faces and avoids the overlapping-corner look.
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded, fog_disabled;
#include "legacy_color.gdshaderinc"
#include "legacy_skin.gdshaderinc"
void fragment() {
	vec4 t = sample_page(UV);
	if (t.a < 0.03) discard;
	ALBEDO = legacy_output(t.rgb * COLOR.rgb * vertex_color_scale);
	ALPHA = t.a;
}
