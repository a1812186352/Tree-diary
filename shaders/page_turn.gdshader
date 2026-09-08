shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool revealing = false;
uniform vec4 paper_color : source_color = vec4(0.961, 0.945, 0.898, 1.0);
uniform float curl_strength : hint_range(0.0, 1.0) = 0.75;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.30;
uniform float grain_strength : hint_range(0.0, 0.05) = 0.012;

float grain(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float p = clamp(progress, 0.0, 1.0);
	// The sloping crease first touches the lower-right corner, then bows as
	// the lifted paper crosses the page. All shading is fixed to paper space.
	float lift = sin(p * 3.14159265);
	float bow = sin(UV.y * 3.14159265) * 0.13 * curl_strength * lift;
	float page_axis = UV.x + 0.32 * UV.y + bow;
	float edge = mix(1.52, -0.25, p);
	float inside = revealing ? edge - page_axis : page_axis - edge;
	float aa = max(fwidth(inside), 0.0005);
	float coverage = smoothstep(-aa, aa, inside);
	float curl_width = 0.018 + 0.13 * curl_strength * lift;
	float fold = clamp(inside / curl_width, 0.0, 1.0);
	float fold_mask = 1.0 - smoothstep(0.72, 1.0, fold);
	// Dark hinge, lit rounded ridge, then the softly shaded paper reverse.
	float hinge = exp(-max(inside, 0.0) / 0.006) * 0.15;
	float ridge = exp(-pow((fold - 0.27) / 0.20, 2.0)) * 0.09;
	float reverse_shade = 0.095 * sin(fold * 3.14159265);
	vec3 tone = paper_color.rgb + vec3((ridge - reverse_shade) * fold_mask - hinge);
	float fibers = grain(floor(UV * vec2(1920.0, 1080.0))) - 0.5;
	float broad_fibers = grain(floor(UV * vec2(420.0, 860.0))) - 0.5;
	tone += (fibers + broad_fibers * 0.4) * grain_strength;
	float outside = max(-inside, 0.0);
	float shadow_width = 0.016 + 0.075 * lift;
	float shadow = exp(-outside / shadow_width) * shadow_strength * (0.85 - 0.25 * lift);
	shadow *= 1.0 - smoothstep(shadow_width * 2.0, shadow_width * 3.5, outside);
	float alpha = coverage + (1.0 - coverage) * shadow;
	vec3 shade_color = vec3(0.30, 0.25, 0.18);
	vec3 final_color = (tone * coverage + shade_color * (1.0 - coverage) * shadow) / max(alpha, 0.0001);
	COLOR = vec4(final_color, alpha);
}
