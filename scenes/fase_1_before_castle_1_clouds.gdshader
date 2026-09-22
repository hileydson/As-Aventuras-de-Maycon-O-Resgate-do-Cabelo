shader_type canvas_item;
render_mode unshaded;

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
	vec3 cloud_1 = cloud_shape(uv, vec2(fract(0.08 + TIME * 0.0024), 0.13), vec2(0.145, 0.074));
	vec3 cloud_2 = cloud_shape(uv, vec2(fract(0.43 + TIME * 0.0031), 0.27), vec2(0.105, 0.054));
	vec3 cloud_3 = cloud_shape(uv, vec2(fract(0.76 + TIME * 0.0018), 0.10), vec2(0.175, 0.082));
	vec3 cloud_4 = cloud_shape(uv, vec2(fract(0.25 + TIME * 0.0038), 0.39), vec2(0.082, 0.043));
	vec3 cloud_5 = cloud_shape(uv, vec2(fract(0.92 + TIME * 0.0029), 0.34), vec2(0.061, 0.032));
	float body = clamp(cloud_1.x + cloud_2.x + cloud_3.x + cloud_4.x + cloud_5.x, 0.0, 1.0);
	float core = clamp(cloud_1.y + cloud_2.y + cloud_3.y + cloud_4.y + cloud_5.y, 0.0, 1.0);
	float underside = clamp(cloud_1.z + cloud_2.z + cloud_3.z + cloud_4.z + cloud_5.z, 0.0, 1.0);
	vec3 cloud_color = mix(vec3(0.70, 0.68, 0.72), vec3(0.93, 0.91, 0.91), core);
	cloud_color = mix(cloud_color, vec3(0.34, 0.28, 0.32), underside * 0.46);
	float alpha = body * mix(0.34, 0.56, core) * (1.0 - underside * 0.14);
	COLOR = vec4(cloud_color, alpha);
}
