#version 410
layout(location = 0) in vec4 position;

out vec2 uv;

void main() {
    uv = (position.xy + 1)/2;
    gl_Position = position;
}