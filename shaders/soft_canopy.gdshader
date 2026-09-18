shader_type canvas_item;
render_mode unshaded;
uniform vec4 leaf_tint : source_color = vec4(0.78, 0.85, 0.64, 1.0);
uniform float saturation : hint_range(0.0, 1.0) = 0.42;
uniform float lighten : hint_range(0.0, 1.0) = 0.35;
// Preserve node opacity without sampling the texture twice.
varying vec4 canopy_modulate;
void vertex() {
	canopy_modulate = COLOR;
}
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float gray = dot(ink.rgb, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(vec3(gray), ink.rgb, saturation);
	ink.rgb = mix(muted, leaf_tint.rgb, lighten);
	COLOR = canopy_modulate * ink;
}
