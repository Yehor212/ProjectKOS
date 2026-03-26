shader_type canvas_item;

// Дрижання мильної плівки — vertex wobble з фазовим зсувом.
uniform float speed : hint_range(0.5, 5.0) = 2.5;
uniform float amount : hint_range(0.0, 10.0) = 3.0;
uniform float iridescence : hint_range(0.0, 1.0) = 0.0;

// Candy grain overlay — subtle surface texture (LAW 28).
uniform sampler2D grain_tex : filter_linear, repeat_enable;
uniform float grain_intensity : hint_range(0.0, 0.15) = 0.05;

void vertex() {
	// Фазовий зсув від позиції — кожен пузир дрижить незалежно
	float phase = MODEL_MATRIX[3].x * 0.02 + MODEL_MATRIX[3].y * 0.01;
	VERTEX.x += sin(TIME * speed + VERTEX.y * 0.08 + phase) * amount;
	VERTEX.y += cos(TIME * speed * 0.7 + VERTEX.x * 0.08 + phase) * amount * 0.6;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Grain overlay
	float grain = texture(grain_tex, UV * 2.5).r;
	tex.rgb += (grain - 0.5) * grain_intensity * tex.a;
	// Iridescence — soap bubble rainbow from UV angle + fresnel edge
	if (iridescence > 0.001) {
		float angle = atan(UV.y - 0.5, UV.x - 0.5);
		float edge_dist = length(UV - 0.5) * 2.0;
		float phase = angle * 2.0 + edge_dist * 3.0;
		vec3 iri = vec3(
			sin(phase) * 0.5 + 0.5,
			sin(phase + 2.094) * 0.5 + 0.5,
			sin(phase + 4.189) * 0.5 + 0.5
		);
		float fresnel = pow(edge_dist, 1.5);
		tex.rgb = mix(tex.rgb, iri, iridescence * fresnel * 0.35 * tex.a);
		tex.rgb += fresnel * iridescence * 0.08 * tex.a;
	}
	COLOR = tex;
}
