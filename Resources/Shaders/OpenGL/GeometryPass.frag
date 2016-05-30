#version 410

#include "Encoding.glsl"
#include "MaterialData.glsl"
#include "LightProbe.glsl"

layout(location = 0) out uint gBuffer0;
layout(location = 1) out vec4 gBuffer1;
layout(location = 2) out vec4 gBuffer2;
layout(location = 3) out vec4 gBuffer3;

in vec3 worldSpaceViewDirection;
in vec3 vertexNormal;

layout(std140) uniform Material {
    MaterialData material;
};

vec3 evaluateEnvironmentMap(vec3 N, vec3 V, float perceptuallyLinearRoughness, float roughness, vec3 albedo, vec3 f0, float f90) {
    
    float NdotV = dot(N, V);
    vec3 R = reflect(-V, N);
    
    vec3 result = evaluateIBLDiffuse(N, V, NdotV, roughness) * albedo;
    result += evaluateIBLSpecular(N, R, NdotV, perceptuallyLinearRoughness, roughness, f0, f90);
    return result;
}

void main() {
    vec3 N = normalize(vertexNormal);
    vec3 V = normalize(worldSpaceViewDirection);
    
    vec3 albedo;
    vec3 f0;
    float f90;
    float linearRoughness;
    evaluateMaterialData(material, albedo, f0, f90, linearRoughness);
    
    uint out0 = 0;
    vec4 out1 = vec4(0);
    vec4 out2 = vec4(0);
    vec4 out3 = vec4(evaluateEnvironmentMap(N, V, linearRoughness, linearRoughness * linearRoughness, albedo, f0, f90), 0);
    
    encodeDataToGBuffers(material, N, out0, out1, out2);
    gBuffer0 = out0;
    gBuffer1 = out1;
    gBuffer2 = out2;
    gBuffer3 = out3;
}