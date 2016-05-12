#version 410

out vec4 outputColor;
in vec2 uv;

void main() {
    outputColor = vec4(uv, 0, 1);
}