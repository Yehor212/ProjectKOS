shader_type canvas_item;
// Преміальний перламутровий sweep для заблокованих карток міні-ігор.
// Голографічний ефект: основний промінь + тепло→холод перехід + edge glow.
// LAW 18: gl_compatibility (GLES2-safe).

uniform float speed : hint_range(0.1, 3.0) = 0.45;
uniform float band_width : hint_range(0.02, 0.3) = 0.10;
uniform float pause : hint_range(0.0, 4.0) = 2.5;
uniform float time_offset = 0.0;
// Перламутрові кольори: теплий → холодний перехід
uniform vec4 warm_color : source_color = vec4(1.0, 0.92, 0.75, 0.22);
uniform vec4 cool_color : source_color = vec4(0.85, 0.92, 1.0, 0.18);
// Edge highlight — яскрава серцевина промінь
uniform float edge_intensity : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	float cycle = 1.0 + pause;
	float t = mod(TIME * speed + time_offset, cycle);
	// Нормалізований прогрес sweep (0→1 за час active фази)
	float sweep = clamp(t, 0.0, 1.0);

	// Основний діагональний промінь
	float diag = (UV.x + UV.y) * 0.5;
	float dist = abs(diag - sweep);
	float gauss = exp(-dist * dist / (2.0 * band_width * band_width));

	// Тонший вторинний промінь (інший кут — глибина)
	float diag2 = (UV.x * 0.7 + UV.y * 0.3) * 0.5;
	float dist2 = abs(diag2 - sweep * 0.85);
	float gauss2 = exp(-dist2 * dist2 / (2.0 * band_width * band_width * 2.5)) * 0.25;

	// Комбінований sweep
	float total = max(gauss, gauss2);

	// Перламутровий колір: warm→cool перехід залежно від позиції на sweep
	float color_blend = smoothstep(0.0, 1.0, diag);
	vec3 pearl_color = mix(warm_color.rgb, cool_color.rgb, color_blend);
	float pearl_alpha = mix(warm_color.a, cool_color.a, color_blend);

	// Edge highlight — яскрава серцевина для глибини (вужчий gaussian)
	float narrow_bw = band_width * 0.4;
	float edge = exp(-dist * dist / (2.0 * narrow_bw * narrow_bw));
	vec3 final_color = pearl_color + vec3(edge * edge_intensity);

	COLOR = vec4(final_color, pearl_alpha * total);
}
