shader_type canvas_item;

uniform vec2 survivor_uv = vec2(0.5);
uniform vec2 facing = vec2(0.0, 1.0);
uniform bool flashlight_on = true;

void fragment() {
	vec2 offset = (UV - survivor_uv) * vec2(384.0, 216.0);
	float distance = length(offset);
	float local_light = 1.0 - smoothstep(45.0, 115.0, distance);
	float cone = smoothstep(0.76, 0.92, dot(normalize(offset + vec2(0.001)), facing));
	float beam = cone * (1.0 - smoothstep(75.0, 170.0, distance));
	float light = max(local_light * 0.75, flashlight_on ? beam : 0.0);
	COLOR = vec4(0.02, 0.035, 0.05, mix(0.63, 0.03, light));
}
