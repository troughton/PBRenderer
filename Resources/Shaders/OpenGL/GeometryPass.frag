#version 410

#include "Encoding.glsl"
#include "MaterialData.glsl"
#include "LightProbe.glsl"
#include "Camera.glsl"

layout(location = 0) out uint gBuffer0;
layout(location = 1) out vec4 gBuffer1;
layout(location = 2) out vec4 gBuffer2;
layout(location = 3) out vec4 gBuffer3;

in vec3 worldSpaceViewDirection;
in vec3 vertexNormal;

uniform bool useEnvironmentMap;

#define MaxMaterialCount 16

layout(std140) uniform Material {
    MaterialData materials[MaxMaterialCount];
};

uniform int materialIndex;

vec3 evaluateEnvironmentMap(vec3 N, vec3 V, MaterialRenderingData material) {
    
    if (useEnvironmentMap) {
    
        float NdotV = dot(N, V);
        vec3 R = reflect(-V, N);
    
        vec3 result = evaluateIBLDiffuse(N, V, NdotV, material.roughness) * material.albedo;
        result += evaluateIBLSpecular(N, R, NdotV, material.linearRoughness, material.roughness, material.f0, material.f90);
        return result;
        
    } else {
        return vec3(0);
    }
}

uniform float exposure;

void main() {
    vec3 N = normalize(vertexNormal);
    vec3 V = normalize(worldSpaceViewDirection);
    
    MaterialData material = materials[materialIndex];
    
    MaterialRenderingData renderingMaterial = evaluateMaterialData(material);
    
    uint out0 = 0;
    vec4 out1 = vec4(0);
    vec4 out2 = vec4(0);
    
    vec3 radiosity = evaluateEnvironmentMap(N, V, renderingMaterial) + material.emissive.rgb;
    vec4 out3 = vec4(epilogueLighting(radiosity, exposure), 0);
    
    encodeDataToGBuffers(material, N, out0, out1, out2);
    gBuffer0 = out0;
    gBuffer1 = out1;
    gBuffer2 = out2;
    gBuffer3 = out3;
}