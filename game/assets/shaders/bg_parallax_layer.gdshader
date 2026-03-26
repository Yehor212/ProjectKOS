shader_type canvas_item;

// Легке горизонтальне плавання для фонових PNG шарів (хмари, дерева).
// LAW 18: gl_compatibility. Vertex-only — мінімальне навантаження.

uniform float drift_speed : hint_range(0.0, 0.02) = 0.005;
uniform float drift_amount : hint_range(0.0, 0.1) = 0.03;
uniform float vertical_bob : hint_range(0.0, 0.02) = 0.005;
uniform float time_scale : hint_range(0.0, 1.0) = 1.0;

// Candy grain overlay (LAW 28)
uniform sampler2D grain_tex : filter_linear, repeat_enable;
uniform float grain_intensity : hint_range(0.0, 0.10) = 0.02;

// Silhouette tinting — use ONLY alpha from texture, apply exact color (V164)
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform bool use_tint = false;

void vertex() {
	float t = TIME * time_scale;
	VERTEX.x += sin(t * drift_speed * 6.283 + VERTEX.y * 0.001) * drift_amount * 100.0;
	VERTEX.y += sin(t * drift_speed * 4.0 + VERTEX.x * 0.001) * vertical_bob * 50.0;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Silhouette mode: replace RGB with tint, keep alpha from texture
	if (use_tint) {
		tex = vec4(tint_color.rgb, tex.a * tint_color.a);
	}
	float grain = texture(grain_tex, UV * 3.0).r;
	tex.rgb += (grain - 0.5) * grain_intensity * tex.a;
	COLOR = tex;
}
