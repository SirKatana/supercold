shader_type spatial;
render_mode cull_back, diffuse_burley;
// A body that runs from one colour at the feet to another at the head. The beast in the
// basement is red over green, and no two parts of him ever disagree about where the line is,
// because the mix is taken from the world height, not from the mesh.

uniform vec3 low_colour : source_color = vec3(0.15, 0.85, 0.20);
uniform vec3 high_colour : source_color = vec3(0.95, 0.10, 0.10);
uniform float base_y = 0.0;
uniform float span = 3.0;
uniform float glow : hint_range(0.0, 4.0) = 0.7;

varying float height;

void vertex() {
	height = clamp(((MODEL_MATRIX * vec4(VERTEX, 1.0)).y - base_y) / max(span, 0.001), 0.0, 1.0);
}

void fragment() {
	vec3 colour = mix(low_colour, high_colour, smoothstep(0.0, 1.0, height));
	ALBEDO = colour;
	EMISSION = colour * glow * (0.35 + 0.65 * height);
	ROUGHNESS = 0.55;
}
