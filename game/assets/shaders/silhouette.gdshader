shader_type canvas_item;
// Перетворює будь-яку текстуру на чорний силует, зберігаючи alpha-канал.

uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.75);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tint_color.rgb, tex.a * tint_color.a);
}
