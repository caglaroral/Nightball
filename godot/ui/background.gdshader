shader_type canvas_item;
// Menu backdrop: dark gradient, two slowly drifting coloured glows and faint pitch lines.

uniform vec4 top_color : source_color = vec4(0.07, 0.10, 0.12, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.03, 0.04, 0.05, 1.0);
uniform vec4 glow_a : source_color = vec4(0.18, 0.75, 0.42, 1.0);
uniform vec4 glow_b : source_color = vec4(0.25, 0.45, 0.95, 1.0);
uniform float glow_strength = 0.22;
uniform float line_strength = 0.035;

float glow(vec2 uv, vec2 centre, float radius) {
	float d = length((uv - centre) * vec2(1.6, 1.0));
	return exp(-d * d / (radius * radius));
}

void fragment() {
	vec2 uv = UV;
	vec3 color = mix(top_color.rgb, bottom_color.rgb, uv.y);
	float t = TIME * 0.06;
	vec2 a = vec2(0.25 + 0.08 * sin(t * 1.3), 0.3 + 0.06 * cos(t));
	vec2 b = vec2(0.78 + 0.07 * cos(t * 1.1), 0.72 + 0.05 * sin(t * 0.9));
	color += glow_a.rgb * glow(uv, a, 0.42) * glow_strength;
	color += glow_b.rgb * glow(uv, b, 0.38) * glow_strength;

	// Halfway line and centre circle of a pitch, very faint.
	vec2 p = (uv - 0.5) * vec2(1.78, 1.0);
	float line = 1.0 - smoothstep(0.0015, 0.004, abs(p.x));
	float circle = 1.0 - smoothstep(0.0015, 0.004, abs(length(p) - 0.22));
	color += vec3(line + circle) * line_strength;

	// Vignette.
	float v = smoothstep(1.15, 0.35, length(uv - 0.5) * 1.4);
	COLOR = vec4(color * mix(0.65, 1.0, v), 1.0);
}
