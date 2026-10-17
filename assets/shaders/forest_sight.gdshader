shader_type canvas_item;
render_mode unshaded;
uniform vec2 observer;
varying vec2 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	// Keep the known local silhouette readable against a wall. This opening is
	// smaller than the existing edge-peek budget and cannot cross a forest wall.
	vec2 body = (world_point - observer - vec2(0.0, -12.0)) / vec2(12.0, 16.0);
	COLOR.a *= smoothstep(0.8, 1.05, length(body));
}
