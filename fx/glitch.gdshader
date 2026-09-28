shader_type canvas_item;
// The lift on its way down to a floor that is not on the buttons: the picture tears into bands,
// the colours come apart, and the whole thing rolls. `amount` is 0 while the lift behaves.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

float noise(vec2 at) {
	return fract(sin(dot(at, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Bands of the picture slide sideways, a few at a time.
	float band = floor(uv.y * 24.0);
	float roll = noise(vec2(band, floor(time * 12.0)));
	float slip = (roll - 0.5) * 0.18 * amount * step(0.62, roll);
	uv.x = fract(uv.x + slip);
	// A slow vertical roll, like a picture that will not hold.
	uv.y = fract(uv.y + amount * 0.02 * sin(time * 3.0));
	float split = 0.012 * amount;
	vec4 colour;
	colour.r = texture(screen, uv + vec2(split, 0.0)).r;
	colour.g = texture(screen, uv).g;
	colour.b = texture(screen, uv - vec2(split, 0.0)).b;
	colour.a = 1.0;
	// Scanlines, grain, and the picture dimming as it gives up.
	float lines = 0.85 + 0.15 * sin(uv.y * 900.0);
	float grain = noise(uv * vec2(640.0, 360.0) + time) * 0.22 * amount;
	colour.rgb = colour.rgb * mix(1.0, lines, amount) * mix(1.0, 0.55, amount) + grain;
	COLOR = mix(texture(screen, SCREEN_UV), colour, clamp(amount * 1.4, 0.0, 1.0));
}
