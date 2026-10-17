shader_type canvas_item;
render_mode unshaded;
uniform vec2 observer;
uniform sampler2D sight_depth : filter_nearest, repeat_disable;
varying vec2 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 delta = world_point - observer;
	float ray = fract(atan(delta.y, delta.x) / 6.2831853 + 1.0);
	float surface = texture(sight_depth, vec2(ray, 0.5)).r * 260.0;
	// Only foliage rises above fog. Fade its far tips before the next corridor.
	float depth = 1.0 - smoothstep(surface + 28.0, surface + 60.0, length(delta));
	vec2 body = (world_point - observer - vec2(0.0, -13.0)) / vec2(19.0, 25.0);
	float cover = smoothstep(0.8, 1.15, length(body));
	// COLOR already contains the texture sample and vertex tint.
	COLOR.rgb *= depth;
	COLOR.a *= cover;
}
