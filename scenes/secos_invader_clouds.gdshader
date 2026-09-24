shader_type canvas_item;
render_mode unshaded;
uniform float speed_multiplier = 1.0;

float ellipse_distance(vec2 point, vec2 center, vec2 radius) {
	return length((point - center) / radius) - 1.0;
}

vec3 cloud_shape(vec2 uv, vec2 center, vec2 scale) {
	float wrapped_x = fract(uv.x - center.x + 0.5) - 0.5;
	vec2 point = vec2(wrapped_x, uv.y - center.y) / scale;
	float distance_to_cloud = ellipse_distance(point, vec2(-0.82, 0.08), vec2(0.30, 0.25));
	distance_to_cloud = min(distance_to_cloud, ellipse_distance(point, vec2(-0.58, -0.02), vec2(0.46, 0.38)));
	distance_to_cloud = min(distance_to_cloud, ellipse_distance(point, vec2(-0.31, -0.23), vec2(0.44, 0.54)));
	distance_to_cloud = min(distance_to_cloud, ellipse_distance(point, vec2(0.02, -0.35), vec2(0.51, 0.66)));
	distance_to_cloud = min(distance_to_cloud, ellipse_distance(point, vec2(0.34, -0.18), vec2(0.46, 0.52)));
	distance_to_cloud = min(distance_to_cloud, ellipse_distance(point, vec2(0.61, -0.03), vec2(0.39, 0.38)));
	distance_to_cloud = min(distance_to_cloud, ellipse_distance(point, vec2(0.82, 0.10), vec2(0.27, 0.24)));
	distance_to_cloud = min(distance_to_cloud, ellipse_distance(point, vec2(-0.36, 0.15), vec2(0.48, 0.26)));
	distance_to_cloud = min(distance_to_cloud, ellipse_distance(point, vec2(0.08, 0.17), vec2(0.62, 0.29)));
	distance_to_cloud = min(distance_to_cloud, ellipse_distance(point, vec2(0.52, 0.15), vec2(0.38, 0.25)));
	float body = 1.0 - smoothstep(-0.07, 0.14, distance_to_cloud);
	float core = 1.0 - smoothstep(-0.38, -0.04, distance_to_cloud);
	float underside = body * smoothstep(-0.02, 0.42, point.y);
	return vec3(body, core, underside);
}

void fragment() {
	vec2 uv = UV;
	float fall = TIME * 0.12 * speed_multiplier;
	vec3 cloud_1 = cloud_shape(uv, vec2(0.08, fract(0.13 + fall * 0.72)), vec2(0.17, 0.083));
	vec3 cloud_2 = cloud_shape(uv, vec2(0.43, fract(0.62 + fall * 0.94)), vec2(0.12, 0.063));
	vec3 cloud_3 = cloud_shape(uv, vec2(0.76, fract(0.31 + fall * 0.82)), vec2(0.19, 0.092));
	vec3 cloud_4 = cloud_shape(uv, vec2(0.25, fract(0.88 + fall * 1.11)), vec2(0.10, 0.054));
	vec3 cloud_5 = cloud_shape(uv, vec2(0.92, fract(0.49 + fall * 1.02)), vec2(0.08, 0.045));
	float body = clamp(cloud_1.x + cloud_2.x + cloud_3.x + cloud_4.x + cloud_5.x, 0.0, 1.0);
	float core = clamp(cloud_1.y + cloud_2.y + cloud_3.y + cloud_4.y + cloud_5.y, 0.0, 1.0);
	vec3 cloud_color = mix(vec3(0.13, 0.12, 0.24), vec3(0.29, 0.25, 0.42), core);
	COLOR = vec4(cloud_color, body * mix(0.16, 0.27, core));
}
