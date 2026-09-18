shader_type canvas_item;
render_mode unshaded;
uniform float source_width = 578.0;
uniform float feather = 0.075;
varying float local_x;
void vertex() {
	// Atlas UVs refer to the whole sheet, so use sprite geometry instead.
	local_x = VERTEX.x / max(source_width, 1.0);
}
void fragment() {
	float edge = smoothstep(0.0, feather, local_x) * smoothstep(0.0, feather, 1.0 - local_x);
	COLOR.a *= edge;
}
