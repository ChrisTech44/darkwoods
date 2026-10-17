shader_type canvas_item;
// Boat-landing lake: depth shading from the shore, drifting wave crests, foam
// lapping at the banks, rings around the dock pilings, and glints wherever a
// light (flashlight, dock lantern) falls. Quantised to 2 px to sit with the art.

uniform vec4 deep_color : source_color = vec4(0.04, 0.14, 0.17, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.31, 0.32, 1.0);
uniform vec4 crest_color : source_color = vec4(0.40, 0.60, 0.58, 1.0);
uniform vec4 foam_color : source_color = vec4(0.80, 0.87, 0.80, 1.0);
// Water rectangles in world space (x, y, width, height); their union is the lake.
uniform vec4 rects[4];
uniform int rect_count = 0;
uniform vec2 pilings[8];
uniform int piling_count = 0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Pixels from this point to the nearest bank (inside the union of rects).
float shore(vec2 p) {
	float best = -100000.0;
	for (int i = 0; i < rect_count; i++) {
		vec2 lo = rects[i].xy;
		vec2 hi = rects[i].xy + rects[i].zw;
		best = max(best, min(min(p.x - lo.x, hi.x - p.x), min(p.y - lo.y, hi.y - p.y)));
	}
	return best;
}

void fragment() {
	vec2 px = floor(world / 2.0) * 2.0;
	float t = TIME;
	float d = shore(px);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, clamp(d / 80.0, 0.0, 1.0));
	// A slow swell shades broad patches of the surface.
	col *= 0.88 + noise(px * 0.012 + vec2(t * 0.05, t * 0.03)) * 0.24;
	// Classic pixel water: short highlight dashes, one band every 6 px, each
	// band drifting sideways at its own speed and direction.
	float band = floor(px.y / 6.0);
	float lane = mod(px.y, 6.0);
	float drift = t * (5.0 + hash(vec2(band, 3.0)) * 9.0) * (mod(band, 2.0) < 1.0 ? 1.0 : -1.0);
	float dash = noise(vec2((px.x + drift) / 18.0, band * 1.7));
	col = mix(col, crest_color.rgb, step(0.70, dash) * (1.0 - step(1.0, lane)) * 0.75);
	col = mix(col, crest_color.rgb, step(0.80, dash) * step(2.0, lane) * (1.0 - step(3.0, lane)) * 0.3);
	// Foam laps in and out along the banks, with a darker wet band behind it.
	float lap = 3.0 + 2.0 * sin(t * 1.3 + noise(px * 0.05) * 6.283);
	col *= 1.0 - step(lap, d) * (1.0 - step(lap + 5.0, d)) * 0.3;
	col = mix(col, foam_color.rgb, (1.0 - step(lap, d)) * 0.8);
	// Expanding rings where the dock pilings meet the water.
	for (int i = 0; i < piling_count; i++) {
		float r = length(px - pilings[i]);
		if (r < 24.0) {
			col = mix(col, crest_color.rgb, step(0.8, sin(r * 0.6 - t * 3.0)) * (1.0 - r / 24.0) * 0.7);
		}
	}
	COLOR = vec4(col, 1.0);
}

void light() {
	// Lit water: diffuse light plus moving sparkles on the wave tops.
	vec2 px = floor(world / 2.0) * 2.0;
	float glint = step(0.88, noise(px * 0.23 + vec2(TIME * 1.7, -TIME * 1.1)));
	LIGHT = vec4(COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY + glint * LIGHT_COLOR.rgb * LIGHT_ENERGY * 0.7, LIGHT_COLOR.a);
}
