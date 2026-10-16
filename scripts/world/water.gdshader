shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec4 deep_color : source_color = vec4(0.12, 0.38, 0.45, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.35, 0.75, 0.7, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float wave_height = 0.18;
uniform float wave_speed = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

float wave(vec2 p, float t) {
	return sin(p.x * 0.35 + t * 1.3) * 0.5 + sin(p.y * 0.45 - t * 1.1) * 0.35 + sin((p.x + p.y) * 0.9 + t * 2.1) * 0.15;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += wave(world_pos.xz, t) * wave_height;
}

void fragment() {
	float t = TIME * wave_speed;
	// Fake normal from wave derivatives
	float e = 0.5;
	float h = wave(world_pos.xz, t);
	float hx = wave(world_pos.xz + vec2(e, 0.0), t);
	float hz = wave(world_pos.xz + vec2(0.0, e), t);
	vec3 n = normalize(vec3((h - hx) * wave_height * 4.0, 1.0, (h - hz) * wave_height * 4.0));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	// Depth-based shoreline foam
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float diff = clamp(-view.z - (-VERTEX.z), 0.0, 20.0);
	float shore = 1.0 - smoothstep(0.0, 1.6, diff);
	float foam_line = step(0.8, shore + sin(diff * 6.0 - TIME * 2.0) * 0.08);

	// Cartoon sparkle bands
	float bands = step(0.93, sin(world_pos.x * 0.6 + h * 3.0 + TIME) * sin(world_pos.z * 0.5 - TIME * 0.7));

	vec3 col = mix(deep_color.rgb, shallow_color.rgb, shore);
	col = mix(col, foam_color.rgb, max(foam_line, bands * 0.6));
	ALBEDO = col;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	ALPHA = mix(0.88, 0.96, shore);
}
