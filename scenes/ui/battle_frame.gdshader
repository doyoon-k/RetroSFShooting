shader_type canvas_item;

uniform sampler2D frame_artwork : source_color, filter_nearest, repeat_disable;
varying vec4 frame_modulate;

void vertex() {
	frame_modulate = COLOR;
}

// Remove the white windows and their light gray edges before filtering.
// Premultiplied samples keep white from bleeding into the frame when scaled.
vec4 keyed_texel(vec2 pixel, vec2 pixel_size) {
	vec2 sample_uv = (pixel + vec2(0.5)) * pixel_size;
	vec4 sample_color = texture(frame_artwork, sample_uv);
	float white = min(sample_color.r, min(sample_color.g, sample_color.b));
	// The source's antialiasing also leaves darker gray pixels beside white.
	// Expand the window mask by one texel without keying the gray frame art.
	if (white > 0.0 && white < 0.9) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 neighbor = texture(frame_artwork, sample_uv + vec2(float(x), float(y)) * pixel_size).rgb;
				white = max(white, min(neighbor.r, min(neighbor.g, neighbor.b)));
			}
		}
	}
	sample_color.a *= 1.0 - step(0.9, white);
	// Key hints belong to the live console. Hide the baked-in J badge.
	if (pixel.x > 477.0 && distance(pixel, vec2(513.0, 938.0)) < 49.0) {
		sample_color.a = 0.0;
	}
	sample_color.rgb *= sample_color.a;
	return sample_color;
}

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE - vec2(0.5);
	vec2 origin = floor(pixel);
	vec2 weight = fract(pixel);
	vec4 top = mix(
		keyed_texel(origin, TEXTURE_PIXEL_SIZE),
		keyed_texel(origin + vec2(1.0, 0.0), TEXTURE_PIXEL_SIZE), weight.x);
	vec4 bottom = mix(
		keyed_texel(origin + vec2(0.0, 1.0), TEXTURE_PIXEL_SIZE),
		keyed_texel(origin + vec2(1.0), TEXTURE_PIXEL_SIZE), weight.x);
	vec4 artwork = mix(top, bottom, weight.y);
	if (artwork.a > 0.0) {
		artwork.rgb /= artwork.a;
	}
	COLOR = artwork * frame_modulate;
}
