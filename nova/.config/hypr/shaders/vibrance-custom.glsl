#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragcolor;
// Vibrance shader with added contrast
// from https://github.com/hyprwm/hyprland/issues/1140#issuecomment-1614863627

const vec3 vib_rgb_balance = vec3(1.0, 1.0, 1.0);
const float vib_vibrance = 0.15;
const vec3 vib_coeffvibrance = vib_rgb_balance * -vib_vibrance;

// Contrast adjustment constant
const float contrast = 1.1; // Adjust between 0.5 and 2.0

void main() {
    vec4 pixcolor = texture(tex, v_texcoord);
    vec3 color = pixcolor.rgb;
    
    // Calculate luma
    vec3 vib_coefluma = vec3(0.212656, 0.715158, 0.072186);
    float luma = dot(vib_coefluma, color);
    float max_color = max(color.r, max(color.g, color.b));
    float min_color = min(color.r, min(color.g, color.b));
    float color_saturation = max_color - min_color;
    
    vec3 p_col = (sign(vib_coeffvibrance) * color_saturation - 1.0) * vib_coeffvibrance + 1.0;
    vec3 adjustedcolor = mix(vec3(luma), color, p_col);

    // Apply contrast
    adjustedcolor = ((adjustedcolor - 0.5) * contrast) + 0.5;

    fragcolor = vec4(adjustedcolor, pixcolor.a);
}

