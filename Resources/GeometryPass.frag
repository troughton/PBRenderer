#version 410

#include "Encoding.glsl"

layout(location = 0) out vec4 gBuffer0;
layout(location = 1) out vec4 gBuffer1;

in vec3 vertexNormal;

layout(std140) uniform Material {
    vec3 baseColour;
    float smoothness;
    float metalMask;
    float reflectance;
} material;

void main() {
    gBuffer0 = vec4(encode(vertexNormal), 0, 0);
    gBuffer1 = vec4(material.baseColour, 1);
}