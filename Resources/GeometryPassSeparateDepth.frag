#version 410

#include "Encoding.glsl"
#include "MaterialData.glsl"

layout(location = 0) out vec4 gBuffer0;
layout(location = 1) out vec4 gBuffer1;
layout(location = 4) out float gBufferDepth;

in vec3 vertexNormal;

layout(std140) uniform Material {
    MaterialData material;
};

void main() {
    gBuffer0 = vec4(encode(vertexNormal), 0, 0);
    gBuffer1 = vec4(material.baseColour, 1);
    
    gBufferDepth = gl_FragCoord.z;
}