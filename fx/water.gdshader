shader_type spatial;
// Water. Used for the deep pool and, with gentler settings, for every wet patch of floor.
//
//  - ripples: four crossing wave trains plus fine chop, evaluated per pixel from world
//    position, so even a flat quad ripples. The pool's subdivided surface is also displaced.
//  - refraction: what is under the water is drawn bent by the ripples
//  - depth: clear and pale where it is shallow, dark blue where it is deep (Beer's law against
//    the real scene depth)
//  - foam where the water meets a wall or the floor
//  - fresnel: glancing views reflect the sky, steep views see the bottom
//  - caustic light on the bottom, and a sun glint from the lights
// Time comes from `world_time`, so the water slows down with everything else.
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

global uniform float world_time;

uniform vec3 shallow_color : source_color = vec3(0.30, 0.78, 0.80);
uniform vec3 deep_color : source_color = vec3(0.01, 0.13, 0.30);
uniform vec3 sky_color : source_color = vec3(0.85, 0.93, 1.0);
uniform float clarity = 2.4;          // metres of water before it goes to deep_color
uniform float wave_height = 0.03;     // vertex displacement, only matters on a subdivided mesh
uniform float ripple = 1.0;           // strength of the normal ripples
uniform float refraction = 0.03;
uniform float foam_width = 0.16;      // 0 turns foam off (puddles: the whole thing would be foam)
uniform float caustics = 0.35;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying vec3 world_pos;

// Height and slope of the wave field at a point. xy of the result is the slope, z the height.
vec3 waves(vec2 p, float t) {
	vec3 acc = vec3(0.0);
	vec2 dirs[6] = { vec2(1.0, 0.2), vec2(-0.4, 1.0), vec2(0.7, -0.7), vec2(-0.9, -0.3), vec2(0.2, 0.95), vec2(-0.6, 0.5) };
	float freq[6] = { 0.55, 0.85, 1.4, 2.3, 4.1, 6.7 };
	float amp[6] = { 1.0, 0.7, 0.45, 0.28, 0.13, 0.07 };
	float speed[6] = { 0.9, 1.1, 1.5, 1.9, 2.6, 3.2 };
	for (int i = 0; i < 6; i++) {
		vec2 d = normalize(dirs[i]);
		float phase = dot(d, p) * freq[i] + t * speed[i];
		acc.z += sin(phase) * amp[i];
		acc.xy += d * cos(phase) * amp[i] * freq[i];
	}
	return acc;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += waves(world_pos.xz, world_time).z * wave_height;
	world_pos.y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

float linear_depth(vec2 uv, mat4 inv_projection) {
	float raw = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw * 2.0 - 1.0);
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec3 w = waves(world_pos.xz, world_time);
	vec3 n = normalize(vec3(-w.x * 0.11 * ripple, 1.0, -w.y * 0.11 * ripple));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float surface_z = -VERTEX.z;
	float thickness = max(linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX) - surface_z, 0.0);

	// Bend what is under the water. If the bent sample lands on something in front of the
	// surface (a dude standing at the edge), fall back to the straight one.
	vec2 bent_uv = SCREEN_UV + n.xz * refraction * clamp(thickness * 1.5, 0.0, 1.0) / max(surface_z * 0.35, 1.0);
	float bent_thickness = linear_depth(bent_uv, INV_PROJECTION_MATRIX) - surface_z;
	if (bent_thickness < 0.0) {
		bent_uv = SCREEN_UV;
	} else {
		thickness = bent_thickness;
	}
	vec3 below = texture(screen_tex, bent_uv).rgb;

	// Caustics: a moving net of light, only where there is a bottom to fall on.
	vec2 c = world_pos.xz * 1.7 + n.xz * 0.9;
	float net = pow(abs(sin(c.x + world_time * 0.7) * sin(c.y - world_time * 0.55) + sin((c.x + c.y) * 0.71 + world_time * 0.4) * 0.5), 3.0);
	below += vec3(0.75, 0.95, 1.0) * net * caustics * clamp(thickness, 0.0, 1.0) * exp(-thickness * 0.5);

	// Beer's law: the more water the light crosses, the more of it the water keeps.
	float murk = 1.0 - exp(-thickness / clarity);
	vec3 body = mix(shallow_color, deep_color, murk);
	vec3 color = mix(below, body, clamp(murk * 0.92 + 0.06, 0.0, 1.0));

	// Fresnel: look across the water and you see sky, look down and you see in.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	color = mix(color, sky_color, fresnel * 0.75);

	// Foam along every edge, broken up and creeping.
	if (foam_width > 0.0) {
		float edge = 1.0 - smoothstep(0.0, foam_width, thickness);
		float breakup = 0.55 + 0.45 * sin(world_pos.x * 9.0 + world_time * 1.3) * sin(world_pos.z * 8.0 - world_time * 1.1);
		color = mix(color, vec3(0.96, 0.99, 1.0), clamp(edge * breakup * 1.3, 0.0, 0.9));
	}

	// The scene colour under the water is already lit, so it goes out as emission. The lights
	// only add the glint on top.
	ALBEDO = vec3(0.0);
	EMISSION = color;
	ROUGHNESS = 0.035;
	SPECULAR = 0.75;
	METALLIC = 0.0;
}
