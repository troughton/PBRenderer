#version 410

layout(location = 0) out vec4 position;
layout(location = 1) out vec3 worldSpaceNormal;

in vec3 vertexNormal;

void main() {
    position = vec4(gl_FragCoord.xyz/800.f, 1.0);
    worldSpaceNormal = vertexNormal;
}