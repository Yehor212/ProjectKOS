shader_type canvas_item;
// Noise-based dissolve для переходів між раундами.
// gl_compatibility safe: тільки texture sampling + step().

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale : hint_range(0.5, 20.0) = 6.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform float edge_width : hint_range(0.0, 0.15) = 0.06;

// Простий hash-based noise (не потребує зовнішньої текстури)
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amp * noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float n = fbm(UV * noise_scale);
	// Dissolve threshold
	float threshold = progress;
	float alpha_cut = step(threshold, n);
	// Edge glow
	float edge = smoothstep(threshold - edge_width, threshold, n) * (1.0 - alpha_cut);
	vec4 final_color = mix(tex, edge_color, edge);
	final_color.a = tex.a * (alpha_cut + edge);
	COLOR = final_color;
}
