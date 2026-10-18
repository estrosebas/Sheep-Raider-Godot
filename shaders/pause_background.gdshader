shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	float light = dot(scene, vec3(0.299, 0.587, 0.114));
	// PS1 reference: preserve scene detail beneath a subdued blue/purple wash.
	vec3 blue = vec3(light) * vec3(0.62, 0.64, 1.0);
	COLOR = vec4(mix(scene, blue, 0.72) * 0.72, 1.0);
}
