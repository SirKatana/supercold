shader_type canvas_item;
// Cold vignette and slight desaturation, driven by 1 - world_scale.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 cold = mix(c.rgb, vec3(grey) * vec3(0.93, 0.98, 1.06), amount * 0.4);
	float edge = smoothstep(0.30, 0.80, length(SCREEN_UV - vec2(0.5)) * 1.15);
	cold = mix(cold, cold * vec3(0.50, 0.68, 0.92), edge * amount * 0.6);
	COLOR = vec4(cold, 1.0);
}
