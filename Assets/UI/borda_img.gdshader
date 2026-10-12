shader_type canvas_item;

uniform float radius = 25.0;
uniform float border_size = 3.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {

    vec2 size = vec2(1.0) / TEXTURE_PIXEL_SIZE;
    vec2 pos = UV * size;

    vec2 half_size = size * 0.5;

    vec2 p = pos - half_size;

    vec2 b = half_size - vec2(radius);

    vec2 d = abs(p) - b;

    float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;

    vec4 tex = texture(TEXTURE, UV);

    if (dist > 0.0) {
        discard;
    }

    if (dist > -border_size) {
        COLOR = border_color;
    } else {
        COLOR = tex;
    }
}