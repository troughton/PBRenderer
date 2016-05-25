#version 410

#include "Encoding.glsl"
#include "MaterialData.glsl"

layout(location = 0) out vec4 gBuffer0;
layout(location = 1) out vec4 gBuffer1;
layout(location = 2) out vec4 gBuffer2;

in vec3 vertexNormal;

layout(std140) uniform Material {
    MaterialData material;
};

void main() {
    vec4 out0 = vec4(encode(normalize(vertexNormal)), 0, 0);
    vec4 out1 = vec4(0);
    vec4 out2 = vec4(0);
    
    encodeMaterialToGBuffers(material, out0, out1, out2);
    gBuffer0 = out0;
    gBuffer1 = out1;
    gBuffer2 = out2;
}