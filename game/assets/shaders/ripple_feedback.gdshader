shader_type canvas_item;
// Premium ripple distortion від точки дотику — correct answer feedback.
// Dual-harmonic хвиля + Gaussian falloff (Source #15: emotionally impactful game feel).
// gl_compatibility safe: sin() + distance() + exp().

uniform vec2 ripple_center = vec2(0.5, 0.5);
uniform float ripple_strength : hint_range(0.0, 0.05) = 0.015;
uniform float ripple_frequency : hint_range(5.0, 40.0) = 18.0;
uniform float ripple_speed : hint_range(1.0, 15.0) = 8.0;
uniform float ripple_time : hint_range(0.0, 2.0) = 0.0;
uniform float ripple_fade : hint_range(0.5, 5.0) = 2.5;

void fragment() {
	vec2 uv = UV;
	float dist = distance(uv, ripple_center);
	// Основна хвиля
	float wave1 = sin(dist * ripple_frequency - ripple_time * ripple_speed);
	// Вторинна гармоніка — половинна частота, зсунута фаза (Source #8: layer sines)
	float wave2 = sin(dist * ripple_frequency * 0.5 - ripple_time * ripple_speed * 0.7) * 0.3;
	float wave = wave1 + wave2;
	// Squared Gaussian falloff — м'якші краї (Source #10: fast start, slow finish)
	float attenuation = exp(-(dist * dist) * ripple_fade * 3.0) * max(0.0, 1.0 - ripple_time * 0.8);
	// Зміщення UV вздовж напрямку від центру
	vec2 direction = normalize(uv - ripple_center + vec2(0.0001));
	uv += direction * wave * ripple_strength * attenuation;
	COLOR = texture(TEXTURE, uv);
}
