// Original D3D7 and repository WebGL multiply encoded RGB.
// No source_color hint: decode only AFTER modulation.
uniform sampler2D albedo_texture : filter_nearest, repeat_disable;
uniform sampler2D albedo_texture_linear : filter_linear, repeat_disable;
uniform bool use_linear_filter = false;
uniform float vertex_color_scale = 1.0;
uniform vec3 original_tint_color = vec3(0.0);
uniform float original_tint_amount = 0.0;

vec4 sample_page(vec2 uv) {
	if (use_linear_filter) {
		return texture(albedo_texture_linear, uv);
	}
	return texture(albedo_texture, uv);
}

vec3 legacy_output(vec3 rgb) {
	vec3 c = clamp(mix(rgb,original_tint_color,original_tint_amount), vec3(0.0), vec3(1.0));
	if (OUTPUT_IS_SRGB) {
		return c;
	}
	// Forward+/Mobile expects linear ALBEDO; Compatibility expects encoded RGB.
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92,
		lessThanEqual(c, vec3(0.04045)));
}
