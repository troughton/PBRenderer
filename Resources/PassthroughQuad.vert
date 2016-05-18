#version 410
layout(location = 0) in vec4 position;

uniform vec3 nearPlane;

out vec2 uv;
out vec3 cameraDirection;

void main() {
    uv = (position.xy + 1)/2;
    cameraDirection = vec3(position.xy * nearPlane.xy, nearPlane.z);
    gl_Position = position;
}