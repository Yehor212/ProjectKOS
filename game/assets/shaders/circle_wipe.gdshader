shader_type canvas_item;

// Преміальна кругова маска переходу — м'який wipe з golden edge glow.
// Замінює простий чорний fade для premium-відчуття.
// LAW 18: gl_compatibility (GLES2-safe).

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.0, 0.3) = 0.08;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 edge_glow_color : source_color = vec4(1.0, 0.88, 0.5, 0.7);
uniform float edge_glow_width : hint_range(0.0, 0.15) = 0.06;

void fragment() {
	// Корекція aspect ratio для кола (не еліпса)
	vec2 ratio = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 uv_corrected = (UV - center) * ratio;
	float dist = length(uv_corrected);

	// Максимальний радіус щоб покрити весь екран
	float max_radius = length(vec2(0.5, 0.5) * ratio) + softness;

	// progress 0.0 = повністю прозорий, 1.0 = повністю чорний
	float radius = (1.0 - progress) * max_radius;
	float alpha = smoothstep(radius - softness, radius, dist);

	// Edge glow — warm golden ring at wipe boundary (premium transition)
	float glow_dist = abs(dist - radius);
	float glow_inner = exp(-glow_dist * glow_dist / (2.0 * edge_glow_width * edge_glow_width));
	// Друга смуга (тонша, яскравіша) — серцевина
	float glow_core = exp(-glow_dist * glow_dist / (2.0 * edge_glow_width * edge_glow_width * 0.15));
	float glow_band = glow_inner * edge_glow_color.a + glow_core * edge_glow_color.a * 0.3;
	vec3 glow = edge_glow_color.rgb * glow_band;

	// Фінальний колір: чорна маска + golden edge glow
	COLOR = vec4(glow * (1.0 - alpha), max(alpha, glow_band * 0.4));
}
