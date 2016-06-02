#include "Utilities.glsl"

struct MaterialData {
    vec4 baseColour;
    vec4 emissive;
    float smoothness;
    float metalMask;
    float reflectance;
    float padding;
};

struct MaterialRenderingData {
    vec3 albedo;
    vec3 f0;
    float f90;
    float linearRoughness;
    float roughness;
};

MaterialRenderingData evaluateMaterialData(in MaterialData data) {
    MaterialRenderingData outData;
    
    vec3 diffuseF0 = vec3(0.16 + data.reflectance * data.reflectance);
    outData.albedo = mix(data.baseColour.rgb, vec3(0), data.metalMask);
    outData.f0 = mix(diffuseF0, data.baseColour.rgb, data.metalMask);
    outData.f90 = saturate(50.0 * dot(outData.f0, vec3(0.33)));
    outData.linearRoughness = 1 - data.smoothness;
    outData.roughness = outData.linearRoughness * outData.linearRoughness;
    
    return outData;
}

MaterialRenderingData evaluateMaterialDataNoSpecular(in MaterialData data) {
    MaterialRenderingData outData;
    
    vec3 diffuseF0 = vec3(0.16 + data.reflectance * data.reflectance);
    outData.albedo = mix(data.baseColour.rgb, vec3(0), data.metalMask);
    outData.f0 = mix(diffuseF0, data.baseColour.rgb, data.metalMask);
    
    outData.albedo = mix(outData.albedo, outData.f0, data.metalMask);
    
    outData.f90 = saturate(50.0 * dot(outData.f0, vec3(0.33)));
    outData.linearRoughness = 1 - data.smoothness;
    outData.roughness = outData.linearRoughness * outData.linearRoughness;
    
    return outData;
}