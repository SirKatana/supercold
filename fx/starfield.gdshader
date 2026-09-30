shader_type sky;
// The sky on the station: stars, a faint band of milky light and a dark gradient, instead of
// the flat colour every floor in the tower uses. Cheap on purpose -- it is hashed noise on the
// view direction, no texture and no loop over a star list.

uniform vec3 base_colour : source_color = vec3(0.02, 0.03, 0.06);
uniform vec3 band_colour : source_color = vec3(0.16, 0.14, 0.26);
// How many cells the sphere is cut into: more cells, more and smaller stars.
uniform float density = 190.0;
uniform float brightness = 1.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	vec3 q = vec3(hash13(p), hash13(p + 17.1), hash13(p + 41.7));
	return q;
}

// Smoothed value noise on a direction. Hashing floor(dir * n) straight off leaves the cell
// grid visible as flat facets, which is what the band looked like before.
float value_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(cell);
	float n100 = hash13(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(cell + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// One layer of stars: the direction is cut into cells, each cell holds at most one star, and
// the star is drawn as a small round falloff around its own position inside the cell.
float star_layer(vec3 dir, float cells, float cut, float size) {
	vec3 scaled = dir * cells;
	vec3 cell = floor(scaled);
	vec3 inside = fract(scaled) - 0.5;
	float roll = hash13(cell);
	if (roll < cut) {
		return 0.0;
	}
	vec3 offset = (hash33(cell + 5.2) - 0.5) * 0.7;
	float d = length(inside - offset);
	float mag = (roll - cut) / max(1.0 - cut, 0.0001);
	// A hard core with a soft halo, so the bright ones read as bright rather than as blobs.
	float core = smoothstep(size, 0.0, d);
	float halo = smoothstep(size * 4.0, 0.0, d) * 0.25;
	return (core + halo) * (0.25 + mag * mag * 1.75);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	// Dark above, a little lift toward the horizon so the floor edge is not a hard cut.
	float up = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 colour = mix(base_colour * 1.6, base_colour * 0.45, up);

	// A band of faint light across the sphere, like a galaxy seen edge on.
	float band = exp(-pow(dot(dir, normalize(vec3(0.35, 0.55, -0.75))) * 2.6, 2.0));
	// Two octaves of smooth noise, so the band has cloud in it and no facets.
	float mottle = value_noise(dir * 7.0) * 0.6 + value_noise(dir * 19.0) * 0.3 + 0.25;
	colour += band_colour * band * mottle * 0.45;

	float stars = star_layer(dir, density, 0.988, 0.055)
		+ star_layer(dir, density * 0.45, 0.982, 0.075) * 0.8
		+ star_layer(dir, density * 2.3, 0.994, 0.040) * 0.5;
	// A few of them take a colour: blue-white and amber, the way real ones do.
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.86, 0.66),
		hash13(floor(dir * density * 0.5) + 3.7));
	colour += tint * stars * brightness;

	COLOR = colour;
}
