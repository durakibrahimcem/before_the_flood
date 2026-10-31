shader_type canvas_item;
// A sheet of crayon strokes that scribbles itself away, one row at a time, to show the new era.

uniform float progress = 0.0;
uniform vec4 crayon : source_color = vec4(0.18, 0.36, 0.46, 1.0);

const float ROWS = 9.0;

float grain(vec2 cell) {
	return fract(sin(dot(floor(cell), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float slanted = UV.y + (UV.x - 0.5) * 0.09 + sin(UV.x * 11.0) * 0.009;
	float row = floor(slanted * ROWS);
	float along = mod(row, 2.0) < 1.0 ? UV.x : 1.0 - UV.x;
	float streak = grain(vec2(UV.x * 7.0, UV.y * 240.0));
	float head = progress * (ROWS + 1.0) - row;
	float gone = smoothstep(along - 0.04, along + 0.02, head + (streak - 0.5) * 0.14);
	COLOR = vec4(crayon.rgb * (0.86 + 0.2 * streak), 1.0 - gone);
}
