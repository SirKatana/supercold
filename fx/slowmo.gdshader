shader_type canvas_item;
// Cold vignette and slight desaturation, driven by 1 - world_scale.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Standing in a fart cloud: everything goes sickly green.
uniform float stink : hint_range(0.0, 1.0) = 0.0;
// Head under water: blue, dim at the edges, and everything wobbles.
uniform float underwater : hint_range(0.0, 1.0) = 0.0;
uniform float wobble_time = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV + vec2(sin(SCREEN_UV.y * 22.0 + wobble_time * 2.1), cos(SCREEN_UV.x * 19.0 + wobble_time * 1.7)) * 0.0045 * underwater;
	vec4 c = texture(screen_tex, uv);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 cold = mix(c.rgb, vec3(grey) * vec3(0.93, 0.98, 1.06), amount * 0.22);
	float edge = smoothstep(0.30, 0.80, length(SCREEN_UV - vec2(0.5)) * 1.15);
	cold = mix(cold, cold * vec3(0.50, 0.68, 0.92), edge * amount * 0.6);
	cold = mix(cold, cold * vec3(0.62, 0.95, 0.35) + vec3(0.04, 0.09, 0.0), stink * 0.32);
	float deep_edge = smoothstep(0.15, 0.85, length(SCREEN_UV - vec2(0.5)) * 1.2);
	cold = mix(cold, cold * vec3(0.30, 0.62, 0.85) + vec3(0.0, 0.05, 0.10), underwater * (0.62 + 0.3 * deep_edge));
	COLOR = vec4(cold, 1.0);
}
