shader_type canvas_item;

// Candy grain overlay — noise texture + optional surface texture для тактильної якості (LAW 28).
// Shared NoiseTexture2D generated once via FastNoiseLite in GameData._get_grain_texture().

uniform sampler2D grain_tex : filter_linear, repeat_enable;
uniform float grain_intensity : hint_range(0.0, 0.20) = 0.07;
uniform float grain_scale : hint_range(0.5, 5.0) = 2.0;
uniform float depth_amount : hint_range(0.0, 0.15) = 0.0;
uniform float gloss_amount : hint_range(0.0, 0.3) = 0.0;
uniform float inner_shadow : hint_range(0.0, 0.25) = 0.0;
uniform float rim_light : hint_range(0.0, 0.3) = 0.0;
uniform float vibrance : hint_range(0.0, 0.4) = 0.0;
// Premium surface texture overlay (LAW 28 — Premium Visual Pipeline)
uniform sampler2D surface_texture : hint_default_white;
uniform float texture_blend : hint_range(0.0, 1.0) = 0.0;
// Specular highlight spot (LAW 28 — candy specularity)
uniform float specular_size : hint_range(0.0, 0.5) = 0.0;
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.0;
// Shadow softness for edges (LAW 28 — depth layers)
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float grain = texture(grain_tex, UV * grain_scale).r;
	// Subtle lighten/darken around midpoint — only on opaque areas
	tex.rgb += (grain - 0.5) * grain_intensity * tex.a;
	// Surface texture overlay — blend pattern/texture for material feel
	if (texture_blend > 0.001) {
		vec3 surf = texture(surface_texture, UV).rgb;
		tex.rgb = mix(tex.rgb, tex.rgb * surf, texture_blend * tex.a);
	}
	// 3D curvature — lighter top, darker bottom (premium depth)
	tex.rgb -= (UV.y - 0.5) * depth_amount * tex.a;
	// Gloss highlight — smooth white gradient at top (premium specularity)
	float gloss = smoothstep(0.35, 0.0, UV.y) * gloss_amount;
	tex.rgb += gloss * tex.a;
	// Specular spot — circular highlight for 3D candy bulge
	if (specular_size > 0.001) {
		vec2 spec_center = vec2(0.35, 0.25);
		float spec_dist = distance(UV, spec_center);
		float spec = smoothstep(specular_size, 0.0, spec_dist) * specular_intensity;
		tex.rgb += spec * tex.a;
	}
	// Inner shadow — edge vignette for 3D candy curvature (LAW 28 depth)
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float soft_range = mix(0.4, 0.6, shadow_softness);
	float shadow_fade = smoothstep(0.0, soft_range, edge);
	tex.rgb *= mix(1.0 - inner_shadow, 1.0, shadow_fade);
	// Rim light — thin bright edge highlight (candy specular)
	float rim = smoothstep(0.15, 0.0, edge) * rim_light;
	tex.rgb += rim * tex.a;
	// Vibrance — selective saturation boost (candy color pop)
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	tex.rgb = mix(vec3(lum), tex.rgb, 1.0 + vibrance * tex.a);
	COLOR = tex;
}
