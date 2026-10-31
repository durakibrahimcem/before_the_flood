shader_type canvas_item;
// Cuts a character at the waterline. waterline is the share of the sprite left above water.

uniform float waterline = 1.0;
uniform vec3 water_color = vec3(0.16, 0.42, 0.48);

void fragment() {
	if (UV.y > waterline) {
		COLOR.rgb = mix(COLOR.rgb, water_color, 0.7);
		COLOR.a *= 0.35;
	}
}
