#version 410
layout(location = 0) in vec4 position;

out vec3 cameraDirection;
out vec2 uv;

uniform vec2 nearPlane;

void main() {
    uv = (position.xy + 1)/2;
    cameraDirection = vec3(nearPlane * position.xy, -1);
    gl_Position = position;
}

