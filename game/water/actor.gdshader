shader_type canvas_item;
// Cuts a character at the waterline. waterline is the share of the sprite left above water.

uniform float waterline = 1.0;
uniform vec3 water_color = vec3(0.16, 0.42, 0.48);
// A slow rise and fall from the feet up, so nobody stands frozen.
uniform float breath = 0.012;
uniform float breath_speed = 2.1;
uniform float breath_phase = 0.0;

void vertex() {
	VERTEX.y *= 1.0 + breath * sin(TIME * breath_speed + breath_phase);
}

void fragment() {
	if (UV.y > waterline) {
		COLOR.rgb = mix(COLOR.rgb, water_color, 0.7);
		COLOR.a *= 0.35;
	}
}
