#version 410

layout(location = 0) out vec4 gBuffer0;
layout(location = 1) out vec4 gBuffer1;

in vec3 vertexNormal;

void main() {
    gBuffer0 = vec4(gl_FragCoord.xyz/800.f, 1.0);
    gBuffer1 = vec4(vertexNormal, 1);
}