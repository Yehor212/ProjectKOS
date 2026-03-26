shader_type canvas_item;

// Premium анімований фон — боке, градієнтне дихання, патерн-оверлей,
// процедурні деталі за темою, глибинне боке, радіальне підсвічування.
// Конфігурується через uniform'и для кожної теми. LAW 18: gl_compatibility.

// --- Core uniforms ---
uniform float time_scale : hint_range(0.0, 1.0) = 1.0;
uniform float bokeh_intensity : hint_range(0.0, 0.5) = 0.12;
uniform float bokeh_count : hint_range(2.0, 8.0) = 5.0;
uniform float bokeh_size : hint_range(0.02, 0.15) = 0.06;
uniform float bokeh_speed : hint_range(0.0, 0.5) = 0.15;
uniform vec4 bokeh_color : source_color = vec4(1.0, 1.0, 1.0, 0.08);
uniform vec4 bokeh_color_2 : source_color = vec4(1.0, 1.0, 1.0, 0.08);
uniform float gradient_shift : hint_range(0.0, 0.05) = 0.015;
uniform float gradient_speed : hint_range(0.0, 2.0) = 0.4;
uniform float pattern_intensity : hint_range(0.0, 0.15) = 0.0;
uniform float pattern_scale : hint_range(5.0, 40.0) = 20.0;
uniform int pattern_type : hint_range(0, 2) = 0; // 0=none, 1=dots, 2=waves
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.0;

// --- Theme-specific procedural detail ---
uniform int theme_id : hint_range(0, 11) = 0;
uniform float detail_intensity : hint_range(0.0, 0.3) = 0.0;
uniform float detail_scale : hint_range(1.0, 50.0) = 10.0;
uniform float detail_speed : hint_range(0.0, 1.0) = 0.2;
uniform vec4 detail_color : source_color = vec4(1.0, 1.0, 1.0, 0.1);

// --- Radial highlight & horizon ---
uniform vec2 highlight_pos = vec2(0.8, 0.15);
uniform float highlight_radius : hint_range(0.0, 0.5) = 0.0;
uniform float highlight_intensity : hint_range(0.0, 0.3) = 0.0;
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 0.8, 0.15);
uniform float horizon_glow : hint_range(0.0, 0.2) = 0.0;
uniform float horizon_y : hint_range(0.0, 1.0) = 0.75;
uniform vec4 horizon_color : source_color = vec4(1.0, 0.9, 0.7, 0.1);

// --- Modern post-processing ---
uniform float chromatic_aberration : hint_range(0.0, 0.03) = 0.0;

// --- Candy grain overlay (LAW 28) ---
uniform sampler2D grain_tex : filter_linear, repeat_enable;
uniform float grain_intensity : hint_range(0.0, 0.10) = 0.02;

// --- Helper: pseudo-random hash ---
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// --- Value noise (smooth random) ---
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep interpolation
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// --- FBM (Fractal Brownian Motion) — organic layered noise ---
float fbm(vec2 p, int octaves) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++) {
		if (i >= octaves) break;
		val += amp * value_noise(p * freq);
		freq *= 2.0;
		amp *= 0.5;
	}
	return val;
}

// --- Ordered dithering (Bayer 4x4) — eliminates gradient banding ---
float bayer4(vec2 pos) {
	ivec2 p = ivec2(mod(pos, 4.0));
	int idx = p.x + p.y * 4;
	// Bayer 4x4 matrix values normalized to [0,1)
	float b[16] = float[16](
		0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0,
		12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
		3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0,
		15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
	);
	return b[idx];
}

// ============================================================
// THEME DETAIL FUNCTIONS — кожна тема має унікальний візерунок
// ============================================================

// 0: Meadow — плаваючі кульбабки вгору
float meadow_detail(vec2 uv, float t, float sc) {
	float acc = 0.0;
	for (float i = 0.0; i < 6.0; i += 1.0) {
		vec2 cell = floor(uv * sc + vec2(0.0, -t * 0.3 + i * 3.7));
		float h = hash21(cell + i * 17.3);
		if (h > 0.7) {
			vec2 local = fract(uv * sc + vec2(0.0, -t * 0.3 + i * 3.7)) - 0.5;
			local.x += sin(t * 0.5 + h * 6.28) * 0.15;
			// Хрестик — кульбабка
			float cross_sdf = min(abs(local.x), abs(local.y));
			acc += smoothstep(0.04, 0.01, cross_sdf) * smoothstep(0.2, 0.08, length(local));
		}
	}
	return clamp(acc, 0.0, 1.0);
}

// 1: Forest — мерехтливе сонячне світло крізь листя (FBM-based)
float forest_detail(vec2 uv, float t, float sc) {
	// FBM створює органічні плями сонячного світла
	float n1 = fbm(uv * sc + vec2(t * 0.08, t * 0.06), 3);
	float n2 = fbm(uv * sc * 1.5 + vec2(-t * 0.05, t * 0.1) + 50.0, 3);
	// Порогове значення — тільки яскраві плями
	float dapple = smoothstep(0.35, 0.65, n1) * smoothstep(0.3, 0.6, n2);
	// Повільна пульсація
	dapple *= 0.6 + 0.4 * sin(t * 0.2 + n1 * 6.28);
	return clamp(dapple, 0.0, 1.0);
}

// 2: Ocean — каустики з domain warping для органічних форм
float ocean_detail(vec2 uv, float t, float sc) {
	// Маска: лише нижні 60% екрану (UV.y=0 top, 1 bottom)
	float mask = smoothstep(0.5, 0.25, uv.y);
	vec2 p = uv * sc;
	// Domain warping — зміщуємо координати noise для органічних каустик
	float warp_x = value_noise(p + vec2(t * 0.4, 0.0));
	float warp_y = value_noise(p + vec2(0.0, t * 0.3) + 100.0);
	vec2 warped = p + vec2(warp_x, warp_y) * 1.5;
	// Каустики через інтерференцію warped синусоїд
	float c1 = sin(warped.x + t * 0.8) * sin(warped.y * 0.7 + t * 0.6);
	float c2 = sin(warped.x * 2.3 + t * 0.5) * sin(warped.y * 1.7 + t * 0.9);
	float caustic = (c1 + c2 * 0.5) * 0.5 + 0.5;
	caustic = caustic * caustic;
	return caustic * mask;
}

// 3: Science — гексагональна сітка
float science_detail(vec2 uv, float t, float sc) {
	vec2 p = uv * sc;
	// Hex grid math
	vec2 s = vec2(1.0, 1.732);
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p + s * 0.5, s) - s * 0.5;
	float da = length(a);
	float db = length(b);
	float hex = min(da, db);
	// Тонкі лінії на краях гексагонів
	float line = smoothstep(0.45, 0.42, hex);
	// Пульсація яскравості
	line *= 0.7 + 0.3 * sin(t * 0.5 + (da < db ? dot(floor(p / s), vec2(1.0)) : dot(floor((p + s * 0.5) / s), vec2(1.0))));
	return line;
}

// 4: Space — зоряне поле з мерехтінням
float space_detail(vec2 uv, float t, float sc) {
	float acc = 0.0;
	vec2 cell = floor(uv * sc);
	for (float dx = -1.0; dx <= 1.0; dx += 1.0) {
		for (float dy = -1.0; dy <= 1.0; dy += 1.0) {
			vec2 c = cell + vec2(dx, dy);
			float h = hash21(c);
			if (h > 0.92) {
				vec2 star_pos = (c + vec2(hash21(c + 1.0), hash21(c + 2.0))) / sc;
				float d = length(uv - star_pos) * sc;
				float brightness = exp(-d * d * 80.0);
				// Мерехтіння
				brightness *= 0.6 + 0.4 * sin(t * 2.0 + h * 6.28);
				// Розмір за хешем
				brightness *= 0.5 + h * 0.5;
				acc += brightness;
			}
		}
	}
	return clamp(acc, 0.0, 1.0);
}

// 5: City — силуети будівель внизу
float city_detail(vec2 uv, float t, float sc) {
	float columns = sc;
	float col_idx = floor(uv.x * columns);
	float h = hash21(vec2(col_idx, 0.0));
	float building_top = 1.0 - h * 0.35 - 0.05; // Верхній край будівлі (0.60-0.95)
	float in_building = step(building_top, uv.y);
	// Вікна — сітка жовтих крапок
	vec2 win_grid = fract(vec2(uv.x * columns * 3.0, (uv.y - building_top) * 20.0));
	float window = step(0.3, win_grid.x) * step(win_grid.x, 0.7)
				 * step(0.2, win_grid.y) * step(win_grid.y, 0.7);
	// Деякі вікна вимкнені
	float win_hash = hash21(floor(vec2(uv.x * columns * 3.0, (uv.y - building_top) * 20.0)));
	window *= step(0.4, win_hash);
	// Мерехтіння вікон
	window *= 0.7 + 0.3 * sin(t * 0.8 + win_hash * 6.28);
	return in_building * (0.3 + window * 0.7);
}

// 6: Puzzle — плаваючі геометричні фігури
float puzzle_detail(vec2 uv, float t, float sc) {
	float acc = 0.0;
	for (float i = 0.0; i < 5.0; i += 1.0) {
		float h = hash21(vec2(i * 13.7, i * 7.3));
		vec2 center = vec2(
			fract(h * 3.7 + sin(t * 0.2 + i) * 0.12),
			fract(h * 7.1 + cos(t * 0.15 + i * 1.3) * 0.1)
		);
		vec2 local = uv - center;
		// Обертання
		float angle = t * 0.3 + i * 1.256;
		vec2 rotated = vec2(
			local.x * cos(angle) - local.y * sin(angle),
			local.x * sin(angle) + local.y * cos(angle)
		);
		// Diamond SDF: |x| + |y| < size
		float size = 0.03 + h * 0.02;
		float diamond = abs(rotated.x) + abs(rotated.y);
		acc += smoothstep(size, size * 0.7, diamond);
	}
	return clamp(acc, 0.0, 1.0);
}

// 7: Music — звукові хвилі
float music_detail(vec2 uv, float t, float sc) {
	float acc = 0.0;
	for (float i = 0.0; i < 4.0; i += 1.0) {
		float freq = sc * (0.8 + i * 0.4);
		float phase = i * 1.57 + t * (0.4 + i * 0.15);
		float amplitude = 0.03 * (1.0 - abs(uv.y - 0.5) * 1.5);
		float wave_y = 0.5 + sin(uv.x * freq + phase) * amplitude;
		float wave_y2 = 0.5 + sin(uv.x * freq * 1.5 + phase * 0.7) * amplitude * 0.6;
		float d = min(abs(uv.y - wave_y), abs(uv.y - wave_y2));
		acc += smoothstep(0.008, 0.002, d);
	}
	return clamp(acc, 0.0, 1.0);
}

// 8: Garden — падаючі пелюстки
float garden_detail(vec2 uv, float t, float sc) {
	float acc = 0.0;
	for (float i = 0.0; i < 6.0; i += 1.0) {
		vec2 cell = floor(uv * sc + vec2(t * 0.1 + i * 2.3, t * 0.25 + i * 1.7));
		float h = hash21(cell + i * 11.1);
		if (h > 0.65) {
			vec2 local = fract(uv * sc + vec2(t * 0.1 + i * 2.3, t * 0.25 + i * 1.7)) - 0.5;
			// Обертання для еліптичної пелюстки
			float angle = h * 6.28 + t * 0.5;
			vec2 rotated = vec2(
				local.x * cos(angle) - local.y * sin(angle),
				local.x * sin(angle) + local.y * cos(angle)
			);
			// Еліпс
			float ellipse = length(rotated * vec2(1.0, 2.5));
			acc += smoothstep(0.12, 0.06, ellipse);
		}
	}
	return clamp(acc, 0.0, 1.0);
}

// 9: Candy — діагональні цукеркові смуги
float candy_detail(vec2 uv, float t, float sc) {
	float stripe = sin((uv.x + uv.y) * sc + t * 0.5) * 0.5 + 0.5;
	// Другий шар під іншим кутом
	float stripe2 = sin((uv.x * 0.7 - uv.y * 1.3) * sc * 0.6 + t * 0.3) * 0.5 + 0.5;
	// М'які смуги, не різкі
	stripe = smoothstep(0.3, 0.7, stripe);
	stripe2 = smoothstep(0.35, 0.65, stripe2);
	return (stripe + stripe2 * 0.4) * 0.7;
}

// 10: Arctic — падаючі сніжинки
float arctic_detail(vec2 uv, float t, float sc) {
	float acc = 0.0;
	for (float i = 0.0; i < 6.0; i += 1.0) {
		vec2 scroll = vec2(sin(t * 0.2 + i * 1.7) * 0.05, t * (0.15 + i * 0.03));
		vec2 cell = floor(uv * sc + scroll + i * 5.3);
		float h = hash21(cell + i * 7.7);
		if (h > 0.75) {
			vec2 local = fract(uv * sc + scroll + i * 5.3) - 0.5;
			local.x += sin(t * 0.4 + h * 6.28) * 0.1; // Бічний дрейф
			float d = length(local);
			float flake_size = 0.03 + h * 0.04;
			acc += smoothstep(flake_size, flake_size * 0.3, d);
		}
	}
	return clamp(acc, 0.0, 1.0);
}

// 11: Sunset — органічні хмарні смуги (FBM domain warping)
float sunset_detail(vec2 uv, float t, float sc) {
	float acc = 0.0;
	for (float i = 0.0; i < 4.0; i += 1.0) {
		float y_pos = 0.2 + i * 0.2;
		// FBM domain warp — хмари мають органічну форму
		float warp = fbm(vec2(uv.x * sc * 0.5 + t * 0.1 + i * 5.0, i * 3.7), 3) * 0.04;
		float band_y = y_pos + warp;
		float band = exp(-pow((uv.y - band_y) / 0.04, 2.0));
		// FBM для варіації щільності хмари
		float density = fbm(vec2(uv.x * sc + t * 0.15, y_pos * 10.0 + i), 2);
		band *= smoothstep(0.3, 0.6, density);
		acc += band;
	}
	return clamp(acc, 0.0, 1.0);
}

// ============================================================
// MAIN FRAGMENT
// ============================================================

void fragment() {
	float t = TIME * time_scale;

	// 1. Тонке градієнтне дихання — UV вертикально коливається
	float shift = sin(t * gradient_speed) * gradient_shift;
	vec2 shifted_uv = vec2(UV.x, clamp(UV.y + shift, 0.0, 1.0));
	vec4 base = texture(TEXTURE, shifted_uv);

	vec3 final_color = base.rgb;

	// 2. Radial highlight — sun/moon/lamp glow
	if (highlight_intensity > 0.001) {
		float hl_dist = length(UV - highlight_pos) / max(highlight_radius, 0.01);
		float hl = exp(-hl_dist * hl_dist * 2.0) * highlight_intensity;
		final_color += highlight_color.rgb * hl;
	}

	// 3. Horizon glow — atmospheric band
	if (horizon_glow > 0.001) {
		float hz = exp(-pow((UV.y - horizon_y) / 0.15, 2.0)) * horizon_glow;
		final_color += horizon_color.rgb * hz;
	}

	// 4. Depth-layered bokeh — far (small, slow) + near (large, fast)
	float bokeh_acc = 0.0;
	for (float i = 0.0; i < 8.0; i += 1.0) {
		if (i >= bokeh_count) break;
		float phase = i * 1.618; // golden ratio spacing
		bool is_near = i >= bokeh_count * 0.5;
		float sz_mult = is_near ? 1.2 : 0.6;
		float spd_mult = is_near ? 1.5 : 0.5;
		// Parallax: far шар рухається протилежно gradient breathing
		float parallax = is_near ? 1.0 : -0.5;
		vec2 center = vec2(
			fract(sin(phase * 12.9898) * 43758.5453),
			fract(cos(phase * 78.233) * 43758.5453)
		);
		center.x += sin(t * bokeh_speed * spd_mult + phase) * 0.08;
		center.y += cos(t * bokeh_speed * spd_mult * 0.7 + phase * 1.3) * 0.06;
		center.y += shift * parallax; // Parallax depth
		float sz = bokeh_size * sz_mult * (0.7 + 0.3 * sin(phase * 2.0));
		float d = length(UV - center) / sz;
		float gauss = exp(-d * d * 3.0);
		bokeh_acc += gauss * (0.6 + 0.4 * sin(phase));
	}
	// Reinhard tone mapping — preserves overlapping bokeh glow
	bokeh_acc = bokeh_acc / (1.0 + bokeh_acc);

	// 5. Патерн-оверлей (dots або waves)
	float pat = 0.0;
	if (pattern_type == 1) {
		vec2 grid = fract(UV * pattern_scale);
		pat = smoothstep(0.3, 0.25, length(grid - 0.5));
	} else if (pattern_type == 2) {
		pat = (sin(UV.x * pattern_scale + t * 0.5) * 0.5 + 0.5)
			* (sin(UV.y * pattern_scale * 0.5 + t * 0.3) * 0.5 + 0.5);
		pat += (sin(UV.x * pattern_scale * 2.3 + t * 0.7) * 0.5 + 0.5)
			 * (sin(UV.y * pattern_scale * 1.7 + t * 0.4) * 0.5 + 0.5) * 0.3;
		pat = clamp(pat, 0.0, 1.0);
	}

	// 6. Bokeh blending — dual-color screen blend
	vec3 near_bokeh = bokeh_color_2.rgb;
	vec3 far_bokeh = bokeh_color.rgb;
	// Micro hue shifts — warm/cool variation
	far_bokeh.r += sin(bokeh_acc * 6.283) * 0.03;
	far_bokeh.b += cos(bokeh_acc * 6.283) * 0.03;
	// Blend far + near weighted by accumulation
	vec3 blended_bokeh = mix(far_bokeh, near_bokeh, bokeh_acc * 0.5);
	vec3 bokeh_contribution = blended_bokeh * bokeh_acc * bokeh_intensity;
	final_color = final_color + bokeh_contribution * (1.0 - final_color);
	final_color = mix(final_color, vec3(1.0), pat * pattern_intensity);

	// 7. Animated grain texture overlay (LAW 28) — temporal variation
	vec2 grain_uv = UV * 4.0 + vec2(fract(t * 0.73), fract(t * 1.17));
	float grain = texture(grain_tex, grain_uv).r;
	final_color += (grain - 0.5) * grain_intensity;

	// 8. Theme-specific procedural detail layer
	if (detail_intensity > 0.001) {
		float detail = 0.0;
		float ds = detail_speed > 0.001 ? t * detail_speed : 0.0;
		if (theme_id == 0) { detail = meadow_detail(UV, ds, detail_scale); }
		else if (theme_id == 1) { detail = forest_detail(UV, ds, detail_scale); }
		else if (theme_id == 2) { detail = ocean_detail(UV, ds, detail_scale); }
		else if (theme_id == 3) { detail = science_detail(UV, ds, detail_scale); }
		else if (theme_id == 4) { detail = space_detail(UV, ds, detail_scale); }
		else if (theme_id == 5) { detail = city_detail(UV, ds, detail_scale); }
		else if (theme_id == 6) { detail = puzzle_detail(UV, ds, detail_scale); }
		else if (theme_id == 7) { detail = music_detail(UV, ds, detail_scale); }
		else if (theme_id == 8) { detail = garden_detail(UV, ds, detail_scale); }
		else if (theme_id == 9) { detail = candy_detail(UV, ds, detail_scale); }
		else if (theme_id == 10) { detail = arctic_detail(UV, ds, detail_scale); }
		else if (theme_id == 11) { detail = sunset_detail(UV, ds, detail_scale); }
		// Screen blend — detail adds light, never darkens
		vec3 d_col = detail_color.rgb;
		final_color = final_color + d_col * detail * detail_intensity * (1.0 - final_color);
	}

	// 9. Aspect-ratio-correct vignette — proper circle on any screen
	vec2 vign_uv = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float vign = length(vign_uv) * 1.414;
	vign = smoothstep(0.3, 1.0, vign) * vignette_strength;
	final_color *= 1.0 - vign;

	// 10. Chromatic aberration — subtle RGB split at edges for premium polish
	if (chromatic_aberration > 0.001) {
		float ca_strength = chromatic_aberration * vign * 2.0; // Stronger at vignette edges
		vec2 ca_offset = UV - 0.5;
		vec2 ca_dir = ca_offset * ca_strength / max(length(ca_offset), 0.001);
		float r = texture(TEXTURE, shifted_uv + ca_dir).r;
		float b = texture(TEXTURE, shifted_uv - ca_dir).b;
		// Blend chromatic channels with existing color
		final_color.r = mix(final_color.r, r, 0.3);
		final_color.b = mix(final_color.b, b, 0.3);
	}

	// 11. S-curve contrast — candy color pop
	final_color = final_color * final_color * (3.0 - 2.0 * final_color);

	// 12. Ordered dithering — eliminates gradient color banding on mobile
	vec2 screen_pos = UV / SCREEN_PIXEL_SIZE;
	float dither = (bayer4(screen_pos) - 0.5) / 255.0;
	final_color += dither;

	COLOR = vec4(final_color, base.a);
}
