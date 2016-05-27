#version 410

#include "Encoding.glsl"
#include "MaterialData.glsl"

layout(location = 0) out uint gBuffer0;
layout(location = 1) out vec4 gBuffer1;
layout(location = 2) out vec4 gBuffer2;
layout(location = 3) out vec4 gBuffer3;

in vec3 vertexNormal;

layout(std140) uniform Material {
    MaterialData material;
};

void main() {
    uint out0 = 0;
    vec4 out1 = vec4(0);
    vec4 out2 = vec4(0);
    vec4 out3 = vec4(0);
    
    encodeDataToGBuffers(material, normalize(vertexNormal), out0, out1, out2);
    gBuffer0 = out0;
    gBuffer1 = out1;
    gBuffer2 = out2;
    gBuffer3 = out3;
}