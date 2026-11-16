shader_type canvas_item;

uniform vec4 derin : source_color = vec4(0.04, 0.24, 0.40, 1.0);
uniform vec4 acik : source_color = vec4(0.10, 0.44, 0.62, 1.0);
uniform float olcek = 60.0;

void fragment() {
	vec2 p = UV * olcek;
	float t = TIME * 0.6;
	float genis = 0.5 + 0.5 * sin(p.x * 0.21 + p.y * 0.17 + t * 0.2);
	float dalga = sin(p.x * 1.3 + t) * sin(p.y * 1.1 - t * 0.8) + 0.5 * sin((p.x + p.y) * 2.1 + t * 1.7);
	float kopuk = smoothstep(0.95, 1.4, dalga);
	vec4 renk = mix(derin, acik, 0.25 + 0.3 * genis);
	COLOR = renk + vec4(vec3(kopuk * 0.16), 0.0);
}
