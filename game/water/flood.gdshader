shader_type canvas_item;
// Draws one painted room with live water. A pixel is underwater when the water is above its height.

uniform sampler2D height_map : filter_linear, repeat_disable;
uniform sampler2D aged_cared : filter_linear, repeat_disable;
uniform sampler2D aged_damaged : filter_linear, repeat_disable;
uniform sampler2D cut_mask : hint_default_white, filter_linear, repeat_disable;
// The whole painting, furniture included, for reflections in the water.
uniform sampler2D mirror_source : filter_linear, repeat_disable;
uniform float flood_m = 0.0;
// Rings around a walker: x and y in uv, z is age from 0 to 1.
uniform vec3 ripples[8];
uniform int ripple_count = 0;
uniform float aged = 0.0;
uniform float severity = 0.0;
uniform float floor_line = 0.4805;
uniform float wall_m_per_uv = 5.4;
uniform float creep_m = 0.05;
uniform float quality = 2.0;
// Outdoors there is no wall to meet the reflection, so it fades in over this much of the picture.
uniform float mirror_soft = 0.001;
// 1 the moment a wall breaks, then fading: the water heaves and foams.
uniform float surge = 0.0;
uniform vec3 shallow_color = vec3(0.45, 0.70, 0.71);
uniform vec3 deep_color = vec3(0.1, 0.34, 0.42);

const float OBJECT_FULL_M = 2.5;

float waves(vec2 p, float t) {
	return sin(p.x * 46.0 + t * 1.7) * 0.5 + sin(p.x * 97.0 - t * 2.3 + p.y * 30.0) * 0.3 + sin(p.y * 70.0 + t * 1.1) * 0.2;
}

// Height in metres at a point. Walls are computed, so they stay perfectly smooth.
float height_at(vec2 uv) {
	vec4 map = texture(height_map, uv);
	// Sky and roofs: the water never comes this high, and they must not look damp.
	if (map.r > 0.99) {
		return OBJECT_FULL_M * 40.0;
	}
	if (map.g > 0.5) {
		return max(floor_line - uv.y, 0.0) * wall_m_per_uv;
	}
	float tilt = (uv.x * 0.7 + (uv.y - floor_line) * 0.3 + 0.25 * sin(uv.x * 9.0 + uv.y * 7.0)) * creep_m;
	return map.r * OBJECT_FULL_M + tilt;
}

vec3 with_age(vec2 uv, vec3 color) {
	vec4 cared = texture(aged_cared, uv);
	vec4 damaged = texture(aged_damaged, uv);
	vec4 layer = mix(cared, damaged, severity);
	return mix(color, layer.rgb, layer.a * aged);
}

void fragment() {
	vec2 uv = UV;
	COLOR.a *= texture(cut_mask, uv).a;
	float active = smoothstep(0.0, 0.03, flood_m);
	float level = flood_m + waves(uv, TIME) * 0.012 * active * (1.0 + 8.0 * surge);
	float depth = level - height_at(uv);
	vec3 base = with_age(uv, texture(TEXTURE, uv).rgb);
	if (depth <= 0.0 || flood_m <= 0.001) {
		float damp = 1.0 - smoothstep(0.0, 0.09, -depth);
		COLOR.rgb = base * (1.0 - 0.2 * damp * active);
	} else {
		float strength = clamp(depth * 2.2, 0.0, 1.0);
		vec2 ripple = vec2(sin(uv.y * 64.0 + TIME * 1.3), cos(uv.x * 52.0 + TIME * 1.1)) * 0.0028 * strength;
		// The paintings end in a paper edge, which must not ripple with the water.
		vec2 edge = min(uv, 1.0 - uv);
		ripple *= smoothstep(0.004, 0.03, min(edge.x, edge.y));
		float rings = 0.0;
		for (int i = 0; i < ripple_count; i++) {
			// Flattened, because the water is seen at an angle.
			vec2 away = (uv - ripples[i].xy) * vec2(1.78, 4.2);
			float reach = length(away);
			float ring = (1.0 - smoothstep(0.0, 0.011, abs(reach - ripples[i].z * 0.1))) * (1.0 - ripples[i].z);
			ripple += away / max(reach, 0.001) * ring * 0.004;
			rings += ring;
		}
		vec3 under = with_age(uv + ripple, texture(TEXTURE, uv + ripple).rgb);
		float absorb = 1.0 - exp(-depth * 1.5);
		vec3 water = mix(shallow_color, deep_color, absorb);
		vec3 color = mix(under, water, 0.22 + 0.42 * absorb);
		if (quality > 0.5) {
			float line_y = floor_line - level / wall_m_per_uv;
			vec2 mirror = vec2(uv.x + ripple.x * 2.0, 2.0 * line_y - uv.y + ripple.y);
			if (mirror.y > 0.0 && uv.y > line_y) {
				float fade = exp(-(uv.y - line_y) * 5.0) * smoothstep(0.0, mirror_soft, uv.y - line_y) * smoothstep(0.0, 0.08, mirror.y);
				color = mix(color, with_age(mirror, texture(mirror_source, mirror).rgb) * vec3(0.78, 0.92, 0.96), 0.5 * fade);
			}
		}
		if (quality > 1.5) {
			float caustic = pow(0.5 + 0.5 * sin(uv.x * 120.0 + sin(uv.y * 90.0 + TIME) * 2.0 + TIME * 0.8) * sin(uv.y * 150.0 - TIME * 0.9), 6.0);
			color += caustic * 0.12 * (1.0 - absorb);
		}
		color = mix(color, vec3(0.95, 0.98, 0.97), min(rings, 1.0) * 0.4);
		float foam = 1.0 - smoothstep(0.0, 0.03 + 0.05 * surge, depth);
		float breakup = 0.6 + 0.4 * sin(uv.x * 230.0 + TIME * 2.0) * sin(uv.y * 210.0 - TIME * 1.5);
		COLOR.rgb = mix(color, vec3(0.95, 0.98, 0.97), foam * breakup * 0.8);
	}
}
