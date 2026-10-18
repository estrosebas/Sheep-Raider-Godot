shader_type spatial;
// ACCEPTED option 2: alpha cutout + depth writing + backface culling.
// Keeps native geometry/animation while preventing rear-face overlaps.
render_mode depth_draw_opaque, cull_back, unshaded, fog_disabled;
#include "legacy_color.gdshaderinc"
#include "legacy_skin.gdshaderinc"
void fragment() {
	vec4 t = sample_page(UV);
	if (t.a < 0.03) discard;
	ALBEDO = legacy_output(t.rgb * COLOR.rgb * vertex_color_scale);
}
