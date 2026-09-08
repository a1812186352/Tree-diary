shader_type canvas_item;
render_mode unshaded;

uniform vec2 top_fade = vec2(0.40, 0.54);
varying vec4 vertex_tint;

float mirrored(float value) {
	return 1.0 - abs(mod(value, 2.0) - 1.0);
}

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 source_uv = UV;
	float sample_y = clamp(source_uv.y, 0.0, 1.0);
	// Repeat only the bottom soil band, never the sky.
	if (source_uv.y > 1.0) {
		sample_y = 1.0 - 0.22 * mirrored((source_uv.y - 1.0) / 0.22);
	}
	vec4 ink = texture(TEXTURE, vec2(mirrored(source_uv.x), sample_y));
	ink.a *= smoothstep(top_fade.x, top_fade.y, source_uv.y);
	// BookFrame owns the fixed page-edge mask.
	COLOR = ink * vertex_tint;
}
