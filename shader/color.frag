#version 330 core

out vec4 f_color;

in vec3 our_color;
in vec2 tex_coord;

uniform sampler2D tex1;

void main() {
    f_color = texture(tex1, tex_coord) * vec4(our_color, 1.0);
}