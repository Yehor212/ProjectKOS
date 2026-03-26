shader_type canvas_item;

// Мульти-зонний шейдер "Alive" — тварини дихають, моргають, реагують.
// Зони: вуха (top 12%), голова (top 35%), тіло/живіт (35-70%), ноги (>80%) заанкерені.

// --- Авто-анімація (TIME) ---
uniform float sway_amplitude : hint_range(0.0, 15.0) = 5.0;
uniform float sway_frequency : hint_range(0.5, 4.0) = 1.5;
uniform float phase_scale : hint_range(0.0, 0.1) = 0.02;
uniform float breathe_amount : hint_range(0.0, 5.0) = 2.0;
uniform float breathe_speed : hint_range(0.3, 2.0) = 0.8;
uniform float head_bob_amount : hint_range(0.0, 4.0) = 1.5;
uniform float head_bob_speed : hint_range(0.5, 3.0) = 1.2;
uniform float ear_wiggle_amount : hint_range(0.0, 3.0) = 1.0;
uniform float ear_wiggle_speed : hint_range(1.0, 6.0) = 2.5;

// --- Reactive (GDScript tweens) ---
uniform float squish : hint_range(-0.5, 0.5) = 0.0;
uniform float hop : hint_range(-20.0, 20.0) = 0.0;
uniform float excitement : hint_range(0.5, 3.0) = 1.0;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform float sleep_factor : hint_range(0.0, 1.0) = 0.0;

// --- Per-animal blink zone (GDScript personality) ---
uniform float blink_y_min : hint_range(0.0, 0.5) = 0.18;
uniform float blink_y_max : hint_range(0.2, 0.7) = 0.32;

// Candy grain overlay (LAW 28)
uniform sampler2D grain_tex : filter_linear, repeat_enable;
uniform float grain_intensity : hint_range(0.0, 0.10) = 0.03;

// Premium 2.5D candy depth (LAW 28 — 4-layer visual pipeline)
uniform float depth_amount : hint_range(0.0, 0.15) = 0.0;
uniform float gloss_amount : hint_range(0.0, 0.3) = 0.0;
uniform float inner_shadow : hint_range(0.0, 0.25) = 0.0;
uniform float rim_light : hint_range(0.0, 0.3) = 0.0;
uniform float vibrance : hint_range(0.0, 0.4) = 0.0;

void vertex() {
	float t = TIME * excitement;
	float phase = MODEL_MATRIX[3].x * phase_scale
				+ MODEL_MATRIX[3].y * phase_scale * 0.5;

	// Маска ніг — заанкерені (UV.y > 0.8)
	float foot_anchor = smoothstep(0.8, 0.7, UV.y);
	// Коефіцієнт сну — гасить усю анімацію до 20%
	float alive = 1.0 - sleep_factor * 0.8;

	// 1. Sway — маятник (зберігає поведінку sway.gdshader)
	float sway_mask = pow(1.0 - UV.y, 2.0);
	VERTEX.x += sin(t * sway_frequency + phase) * sway_amplitude * sway_mask * alive;

	// 2. Дихання — живіт розширюється/стискається по X
	float breathe_mask = sin(UV.y * 3.14159) * foot_anchor;
	VERTEX.x += sin(t * breathe_speed + phase * 2.0) * breathe_amount
			  * breathe_mask * (UV.x - 0.5) * 2.0 * alive;

	// 3. Head bob — голова (top 35%) рухається окремо
	float head_mask = smoothstep(0.35, 0.0, UV.y);
	VERTEX.y += sin(t * head_bob_speed + phase + 1.0) * head_bob_amount * head_mask * alive;
	VERTEX.x += sin(t * head_bob_speed * 0.7 + phase + 2.5) * head_bob_amount * 0.3 * head_mask * alive;

	// 4. Ear wiggle — верхівка (top 12%) тремтить швидко
	float ear_mask = smoothstep(0.12, 0.0, UV.y);
	VERTEX.x += sin(t * ear_wiggle_speed + phase * 3.0) * ear_wiggle_amount * ear_mask * alive;

	// 5. Squish — organic squash-stretch (reactive)
	VERTEX.x *= 1.0 + squish;
	VERTEX.y *= 1.0 - squish * 0.7;

	// 6. Hop — вертикальний стрибок (reactive, ноги стоять)
	VERTEX.y -= hop * foot_anchor;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Blink — затемнення зони очей (per-animal blink_y_min/max, UV.x 0.25-0.75)
	float blink_y = smoothstep(blink_y_min, blink_y_min + 0.04, UV.y)
				  * smoothstep(blink_y_max, blink_y_max - 0.04, UV.y);
	float blink_x = smoothstep(0.25, 0.35, UV.x) * smoothstep(0.75, 0.65, UV.x);
	tex.rgb = mix(tex.rgb, tex.rgb * 0.3, blink_y * blink_x * blink);

	// Glow — тепле сяйво при збудженні / proximity
	tex.rgb = mix(tex.rgb, vec3(1.0, 0.95, 0.7), glow_intensity * 0.2);

	// Grain texture overlay (LAW 28)
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
