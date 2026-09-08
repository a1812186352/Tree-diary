shader_type canvas_item;
render_mode unshaded;

// Continuous paper gradient; no source pixels or compressed video are stretched.
uniform vec4 media_rect = vec4(0.125, 0.0, 0.75, 1.0);
uniform vec4 top_left : source_color = vec4(0.94, 0.90, 0.83, 1.0);
uniform vec4 bottom_left : source_color = vec4(0.92, 0.87, 0.79, 1.0);
uniform vec4 top_right : source_color = vec4(0.96, 0.94, 0.90, 1.0);
uniform vec4 bottom_right : source_color = vec4(0.94, 0.90, 0.83, 1.0);

void fragment() {
	vec2 media_uv = (UV - media_rect.xy) / media_rect.zw;
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), media_uv);
	vec4 left = mix(top_left, bottom_left, blend.y);
	vec4 right = mix(top_right, bottom_right, blend.y);
	vec4 colour = mix(left, right, blend.x);
	COLOR = vec4(colour.rgb, 1.0);
}
