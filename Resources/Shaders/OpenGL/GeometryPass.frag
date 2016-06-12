#version 410

#include "Encoding.glsl"
#include "MaterialData.glsl"
#include "LightProbe.glsl"
#include "Camera.glsl"

layout(std140) uniform;

layout(location = 0) out uint gBuffer0;
layout(location = 1) out vec4 gBuffer1;
layout(location = 2) out vec4 gBuffer2;
layout(location = 3) out vec4 gBuffer3;

in vec4 worldSpacePosition;
in vec3 worldSpaceViewDirection;
in vec3 vertexNormal;

uniform bool useEnvironmentMap;

uniform samplerBuffer materials;
uniform int materialIndex;

MaterialData materialAtIndex(int materialIndex) {
    int indexInBuffer = 3 * materialIndex;
    MaterialData data;
    data.baseColour = texelFetch(materials, indexInBuffer);
    data.emissive = texelFetch(materials, indexInBuffer + 1);
    
    vec4 extraData = texelFetch(materials, indexInBuffer + 2);
    data.smoothness = extraData.x;
    data.metalMask = extraData.y;
    data.reflectance = extraData.z;
    
    return data;
}

uniform float exposure;

void main() {
    vec3 N = normalize(vertexNormal);
    vec3 V = normalize(worldSpaceViewDirection);
    float NdotV = saturate(dot(N, V));
    vec3 R = reflect(-V, N);
    
    MaterialData material = materialAtIndex(materialIndex);
    
    MaterialRenderingData renderingMaterial = evaluateMaterialData(material);
    
    uint out0 = 0;
    vec4 out1 = vec4(0);
    vec4 out2 = vec4(0);
    
    vec3 radiosity = material.emissive.rgb + evaluateIBL(worldSpacePosition, N, V, NdotV, R, renderingMaterial);
    vec4 out3 = vec4(epilogueLighting(radiosity, exposure), 1);
    
    encodeDataToGBuffers(material, N, out0, out1, out2);
    gBuffer0 = out0;
    gBuffer1 = out1;
    gBuffer2 = out2;
    gBuffer3 = out3;
}