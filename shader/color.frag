#version 330 core

out vec4 f_color;
in vec3 our_color;

void main() {
    f_color = vec4(our_color, 1.0);
}