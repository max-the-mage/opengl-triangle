#version 330 core

out vec4 f_color;

in vec2 tex_coord;

uniform sampler2D tex1;
uniform sampler2D tex2;

void main() {
    vec2 tex2_coord = tex_coord;
    
    if (texture(tex2, tex2_coord).a == 0.0) {
        f_color = texture(tex1, tex_coord);
    } else if (texture(tex2, tex2_coord).a < 1.0) {
        f_color = mix(
            texture(tex1, tex_coord),
            texture(tex2, tex2_coord),
            0.5
        );
    } else {
        f_color = texture(tex2, tex2_coord);
    }
}