shader_type canvas_item;
// Sniper scope: black outside a round lens, thin crosshair with mil dots and a range
// ladder, a faint tint and a dark rim inside it.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.7778;

float line(float d, float w) {
	return 1.0 - smoothstep(w, w * 1.8, abs(d));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float r = length(p);
	float lens = 0.46;
	// Outside the lens: solid black. It closes in as the player raises the rifle.
	float outside = smoothstep(lens - 0.004, lens + 0.004, r);
	float rim = smoothstep(lens - 0.09, lens, r) * 0.55;

	float hair = max(line(p.x, 0.0011), line(p.y, 0.0011));
	// Heavy posts from the edge, thin wires in the middle.
	float posts = max(line(p.y, 0.0045) * step(0.17, abs(p.x)), line(p.x, 0.0045) * step(0.17, p.y));
	float dots = 0.0;
	for (int i = 1; i <= 4; i++) {
		float o = float(i) * 0.035;
		dots = max(dots, 1.0 - smoothstep(0.0028, 0.0042, length(p - vec2(o, 0.0))));
		dots = max(dots, 1.0 - smoothstep(0.0028, 0.0042, length(p - vec2(-o, 0.0))));
		dots = max(dots, 1.0 - smoothstep(0.0028, 0.0042, length(p - vec2(0.0, o))));
	}
	float ladder = 0.0;
	for (int i = 1; i <= 3; i++) {
		float y = float(i) * 0.07 + 0.14;
		ladder = max(ladder, line(p.y - y, 0.0014) * step(abs(p.x), 0.05 - float(i) * 0.011));
	}
	float marks = max(max(hair, posts), max(dots, ladder)) * (1.0 - outside);

	vec3 tint = vec3(0.02, 0.05, 0.06);
	float alpha = max(outside, max(marks * 0.95, rim)) ;
	alpha = max(alpha, 0.06 * (1.0 - outside));
	COLOR = vec4(mix(tint, vec3(0.0), max(outside, marks)), alpha * amount);
}
