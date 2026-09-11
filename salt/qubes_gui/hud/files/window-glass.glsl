#version 330
// Qubes HUD managed file. Owner: salt/qubes_gui/hud.

in vec2 texcoord;

uniform sampler2D tex;
uniform vec2 effective_size;
uniform float border_width;
uniform float corner_radius;

vec4 default_post_processing(vec4 c);

vec4 window_shader() {
    vec2 texsize = vec2(textureSize(tex, 0));
    vec4 source = texture2D(tex, texcoord / texsize, 0);
    // Picom synthesizes the curved border from the original texture's edge
    // color. Do that before lighting, or it paints an unlit arc over the rim.
    source = default_post_processing(source);

    vec2 window_size = max(effective_size, vec2(1.0));
    vec2 position = clamp(texcoord, vec2(0.0), window_size);
    float texcoord_dy = dFdy(texcoord.y);

    // Measure inward from the same rounded rectangle that Picom clips in
    // default_post_processing(), so the inner rim follows the window curve.
    float radius = clamp(corner_radius, 0.0,
                         0.5 * min(window_size.x, window_size.y));
    vec2 rounded_position = abs(position - 0.5 * window_size) -
                            (0.5 * window_size - vec2(radius));
    float signed_distance = length(max(rounded_position, vec2(0.0))) +
                            min(max(rounded_position.x, rounded_position.y),
                                0.0) - radius;
    float distance_to_edge = max(-signed_distance, 0.0);
    float rim = 1.0 - smoothstep(0.0, 30.0, distance_to_edge);

    // Picom's result uses premultiplied alpha. Work in straight RGB, then
    // premultiply again, retaining its opacity and antialiased corner coverage.
    float source_alpha = source.a;
    vec3 straight_rgb = source_alpha > 0.00001
        ? clamp(source.rgb / source_alpha, 0.0, 1.0)
        : vec3(0.0);

    // Preserve saturated application colors and Qubes label pixels.
    float highest_channel = max(straight_rgb.r,
                                max(straight_rgb.g, straight_rgb.b));
    float lowest_channel = min(straight_rgb.r,
                               min(straight_rgb.g, straight_rgb.b));
    float chroma = highest_channel - lowest_channel;
    float color_guard = 1.0 - smoothstep(0.18, 0.45, chroma);

    // Preserve title ink, including neutral labels and low-chroma purple.
    // The packaged i3 renders the whole title in its configured label color;
    // only the dark titlebar background should receive the cyan rim.
    // GLX texture orientation can vary; the derivative identifies the top.
    // i3's side border tracks its logical-pixel scale.
    float hud_scale = clamp(border_width / 3.0, 1.0, 2.5);
    float top_distance = texcoord_dy >= 0.0
        ? position.y
        : window_size.y - position.y;
    float title_band = 1.0 - smoothstep(22.0 * hud_scale,
                                       26.0 * hud_scale, top_distance);
    float title_ink = smoothstep(0.12, 0.25, highest_channel);
    float trusted_label_guard = 1.0 - title_band * title_ink;

    float strength = 0.36 * rim * color_guard * trusted_label_guard;
    vec3 cyan = vec3(0.098039, 0.827451, 1.0); // #19d3ff
    vec3 lit_rgb = 1.0 - (1.0 - straight_rgb) *
                         (1.0 - cyan * strength);
    source.rgb = lit_rgb * source_alpha;

    // Keep the processed alpha; do not repaint the rounded border a second time.
    return source;
}
