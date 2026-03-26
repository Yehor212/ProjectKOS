shader_type canvas_item;
// Premium glow для idle hints — 8-way Gaussian edge detection + eased pulse.
// gl_compatibility safe: texture sampling + exp() + smoothstep().

uniform vec4 glow_color : source_color = vec4(1.0, 0.95, 0.4, 1.0);
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float pulse_speed : hint_range(0.5, 6.0) = 2.0;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.1;
uniform float glow_spread : hint_range(0.005, 0.1) = 0.03;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Eased pulse — smoothstep замість лінійного sine (Source #8: quadratic = soft feel)
	float raw_pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float pulse = raw_pulse * raw_pulse * (3.0 - 2.0 * raw_pulse);
	float intensity = glow_intensity * pulse;
	// 8-way Gaussian edge detection (cardinal + diagonal) — Source #13 pattern
	float s = glow_spread;
	float alpha_c = tex.a;
	float alpha_u = texture(TEXTURE, UV + vec2(0.0, -s)).a;
	float alpha_d = texture(TEXTURE, UV + vec2(0.0, s)).a;
	float alpha_l = texture(TEXTURE, UV + vec2(-s, 0.0)).a;
	float alpha_r = texture(TEXTURE, UV + vec2(s, 0.0)).a;
	// Діагональні з меншою вагою (0.707 = 1/sqrt(2))
	float diag_w = 0.707;
	float alpha_ul = texture(TEXTURE, UV + vec2(-s, -s) * diag_w).a;
	float alpha_ur = texture(TEXTURE, UV + vec2(s, -s) * diag_w).a;
	float alpha_dl = texture(TEXTURE, UV + vec2(-s, s) * diag_w).a;
	float alpha_dr = texture(TEXTURE, UV + vec2(s, s) * diag_w).a;
	// Weighted edge sum: cardinal 1.0, diagonal 0.707
	float edge_sum = abs(alpha_c - alpha_u) + abs(alpha_c - alpha_d)
		+ abs(alpha_c - alpha_l) + abs(alpha_c - alpha_r)
		+ (abs(alpha_c - alpha_ul) + abs(alpha_c - alpha_ur)
		+ abs(alpha_c - alpha_dl) + abs(alpha_c - alpha_dr)) * diag_w;
	// Gaussian falloff замість hard smoothstep (Source #13)
	float edge_norm = edge_sum / 6.828; // Нормалізація (4 + 4*0.707)
	float edge = exp(-(1.0 - edge_norm) * (1.0 - edge_norm) / (2.0 * edge_softness * edge_softness));
	edge = clamp(edge * edge_norm * 4.0, 0.0, 1.0);
	// Внутрішнє glow (м'яке, additive)
	vec3 inner_glow = glow_color.rgb * intensity * alpha_c * 0.25;
	// Edge glow (сильніше на краях, Gaussian = плавне)
	vec3 edge_glow = glow_color.rgb * intensity * edge * 0.75;
	COLOR = vec4(tex.rgb + inner_glow + edge_glow, tex.a);
}
