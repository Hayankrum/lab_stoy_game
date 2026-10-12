shader_type canvas_item;

uniform vec4 panel_color : source_color = vec4(1.0, 1.0, 1.0, 0.92);

uniform vec4 border_color : source_color = vec4(
	0.835,
	0.635,
	0.624,
	1.0
);

uniform float border_size = 0.01;

void fragment()
{
	vec2 uv = UV;

	bool border =
		uv.x < border_size ||
		uv.x > 1.0 - border_size ||
		uv.y < border_size ||
		uv.y > 1.0 - border_size;

	COLOR = border ? border_color : panel_color;
}