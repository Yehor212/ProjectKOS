shader_type canvas_item;

// Хитання маятником — верх коливається, низ (ноги) зафіксований.
uniform float amplitude : hint_range(0.0, 20.0) = 6.0;
uniform float frequency : hint_range(0.0, 5.0) = 1.5;
uniform float phase_scale : hint_range(0.0, 1.0) = 0.02;

// Candy grain overlay (LAW 28)
uniform sampler2D grain_tex : filter_linear, repeat_enable;
uniform float grain_intensity : hint_range(0.0, 0.10) = 0.03;

// Silhouette tinting — use ONLY alpha from texture, apply exact color (V164)
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform bool use_tint = false;

// Premium 2.5D candy depth (LAW 28 — 4-layer visual pipeline)
uniform float depth_amount : hint_range(0.0, 0.15) = 0.0;
uniform float gloss_amount : hint_range(0.0, 0.3) = 0.0;
uniform float inner_shadow : hint_range(0.0, 0.25) = 0.0;
uniform float rim_light : hint_range(0.0, 0.3) = 0.0;
uniform float vibrance : hint_range(0.0, 0.4) = 0.0;

void vertex() {
	// Маска: квадратичне загасання від верху (1.0) до низу (0.0)
	float mask = pow(1.0 - UV.y, 2.0);
	// Фазовий зсув від позиції у світі — автоматична десинхронізація
	float phase = MODEL_MATRIX[3].x * phase_scale + MODEL_MATRIX[3].y * phase_scale * 0.5;
	// Горизонтальне погойдування маятником
	VERTEX.x += sin(TIME * frequency + phase) * amplitude * mask;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Silhouette mode: replace RGB with tint, keep alpha from texture
	if (use_tint) {
		tex = vec4(tint_color.rgb, tex.a * tint_color.a);
	}
	float grain = texture(grain_tex, UV * 2.0).r;
	tex.rgb += (grain - 0.5) * grain_intensity * tex.a;

	// Premium 2.5D candy depth — lighter top, darker bottom
	tex.rgb -= (UV.y - 0.5) * depth_amount * tex.a;
	// Gloss highlight — smooth white gradient at top
	float gloss = smoothstep(0.35, 0.0, UV.y) * gloss_amount;
	tex.rgb += gloss * tex.a;
	// Inner shadow — edge vignette for 3D candy curvature
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float shadow_fade = smoothstep(0.0, 0.4, edge);
	tex.rgb *= mix(1.0 - inner_shadow, 1.0, shadow_fade);
	// Rim light — thin bright edge highlight
	float rim = smoothstep(0.15, 0.0, edge) * rim_light;
	tex.rgb += rim * tex.a;
	// Vibrance — selective saturation boost
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	tex.rgb = mix(vec3(lum), tex.rgb, 1.0 + vibrance * tex.a);

	COLOR = tex;
}
