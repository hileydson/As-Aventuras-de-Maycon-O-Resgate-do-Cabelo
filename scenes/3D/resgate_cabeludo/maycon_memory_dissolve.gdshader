// Adapted from JamScars' CC0 Godot 4+ 3D Vertical Dissolve Shader:
// https://godotshaders.com/shader/godot-4-vertical-dissolve-shader/
// World height synchronises all skinned surfaces with the emerging 2D sprite.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform sampler2D noise_texture : repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 border_color : source_color = vec4(1.0, 0.79, 0.34, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float floor_y = 0.0;
uniform float body_height = 2.0;
uniform bool reveal = false;
uniform bool billboard = false;
varying vec3 world_pos;

void vertex() {
	mat4 model = MODEL_MATRIX;
	if (billboard) {
		model = mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * model;
	}
	world_pos = (model * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 original = texture(albedo_texture, UV) * base_color;
	if (original.a < 0.05) { discard; }
	float height = (world_pos.y - floor_y) / max(body_height, 0.01);
	float noise = texture(noise_texture, UV * 3.0 + vec2(progress * 0.1, -progress * 0.4)).r;
	float wave = sin(world_pos.x * 10.0 + progress * 6.0) * 0.025;
	float distance = height + wave + (noise - 0.5) * 0.12 - progress;
	float border = 0.0;
	if (progress <= 0.0) {
		if (reveal) { discard; }
	} else if (progress >= 1.0) {
		if (!reveal) { discard; }
	} else {
		if ((reveal && distance > 0.0) || (!reveal && distance < 0.0)) { discard; }
		border = 1.0 - smoothstep(0.0, 0.07, abs(distance));
	}
	ALBEDO = mix(original.rgb, border_color.rgb, border);
	ALPHA = original.a;
	EMISSION = border_color.rgb * border * 2.2;
}
