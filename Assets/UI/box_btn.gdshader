shader_type canvas_item;

render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Vidro
uniform float blur_strength = 1.5;
uniform float transparency = 0.12;

// Borda em pixels
uniform float border_size = 2.0;

// Tamanho real do botão
uniform vec2 rect_size = vec2(100.0, 100.0);

uniform vec4 glass_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.35);

void fragment() {
	// =====================
	// BLUR
	// =====================
	vec4 blur = vec4(0.0);

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset =
				vec2(float(x), float(y))
				* blur_strength
				* SCREEN_PIXEL_SIZE;

			blur += texture(
				SCREEN_TEXTURE,
				SCREEN_UV + offset
			);
		}
	}

	blur /= 9.0;

	vec4 glass = mix(
		blur,
		glass_color,
		transparency
	);

	// =====================
	// BORDA UNIFORME
	// =====================

	float dist_left   = UV.x * rect_size.x;
	float dist_right  = (1.0 - UV.x) * rect_size.x;
	float dist_top    = UV.y * rect_size.y;
	float dist_bottom = (1.0 - UV.y) * rect_size.y;

	float dist = min(
		min(dist_left, dist_right),
		min(dist_top, dist_bottom)
	);

	float border = 1.0 - smoothstep(
		border_size,
		border_size + 1.0,
		dist
	);

	glass.rgb = mix(
		glass.rgb,
		border_color.rgb,
		border * border_color.a
	);

	COLOR = glass;
}