#version 410
layout(location = 0) in vec4 position;

uniform mat4 modelToClipMatrix;

void main() {
    colour = vec4(0, 1, 0, 1);
    gl_Position = modelToClipMatrix * position;
}