shader_type spatial;
// ARCHIVED option 1: double-sided depth cutout. Discarded in favour of
// option 2 because the user still saw overlapping corners between cards.
render_mode depth_draw_opaque, cull_disabled, unshaded, fog_disabled;
#include "legacy_color.gdshaderinc"
#include "legacy_skin.gdshaderinc"
void fragment() {
	vec4 t = sample_page(UV);
	if (t.a < 0.03) discard;
	ALBEDO = legacy_output(t.rgb * COLOR.rgb * vertex_color_scale);
}
