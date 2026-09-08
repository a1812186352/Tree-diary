shader_type canvas_item;
render_mode unshaded;
uniform bool sticker = false;
uniform float paper_width = 9.0;
uniform vec4 paper_color : source_color = vec4(1.0, 0.98, 0.91, 1.0);
varying vec4 tint;

void vertex() {
    tint = COLOR;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float edge = tex.a;
    if (sticker) {
        for (int i = 0; i < 12; i++) {
            float angle = float(i) * 6.2831853 / 12.0;
            vec2 offset = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * paper_width;
            edge = max(edge, texture(TEXTURE, UV + offset).a);
        }
        COLOR = vec4(mix(paper_color.rgb, tex.rgb, tex.a), edge) * tint;
    } else {
        COLOR = tex * tint;
    }
}
