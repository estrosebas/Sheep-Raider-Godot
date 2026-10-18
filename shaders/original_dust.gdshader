shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D dust_texture : filter_nearest, repeat_disable;
uniform float grey = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 texel = texture(dust_texture, UV);
	ALBEDO = texel.rgb * grey;
	ALPHA = texel.a;
}
