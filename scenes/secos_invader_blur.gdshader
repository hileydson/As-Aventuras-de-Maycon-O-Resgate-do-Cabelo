shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.003;

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV) * 0.30;
	for (int i = 1; i <= 7; i++) {
		float offset = float(i) * strength;
		color += texture(screen_texture, SCREEN_UV + vec2(0.0, offset)) * 0.05;
		color += texture(screen_texture, SCREEN_UV - vec2(0.0, offset)) * 0.05;
	}
	COLOR = color;
}
