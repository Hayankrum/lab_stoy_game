shader_type canvas_item;

uniform float progresso  : hint_range(0.0, 1.0) = 0.0;
uniform vec4  cor        : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool  invertido  = false;
uniform float suavidade  : hint_range(0.0, 0.5) = 0.05;

void fragment() {
	float pos   = (UV.x + UV.y) * 0.5;
	float borda = progresso * (1.0 + suavidade * 2.0) - suavidade;
	float alpha = smoothstep(borda - suavidade, borda + suavidade, pos);
	if (invertido) {
		COLOR = vec4(cor.rgb, alpha);
	} else {
		COLOR = vec4(cor.rgb, 1.0 - alpha);
	}
}