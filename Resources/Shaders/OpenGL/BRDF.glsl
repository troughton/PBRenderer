/************************************
 ************* BRDF *****************
 ***********************************/

#include "Utilities.glsl"
#include "MaterialData.glsl"

vec3 F_Schlick(vec3 f0, float f90, float u) {
    return f0 + (f90 - f0) * exp2((-5.55473f * u - 6.98316f) * u);  //native_powr(1.f - u, 5.f);
}

float Fr_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float linearRoughness);

float Fr_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float linearRoughness) {
    float energyBias = mix(0.f, 0.5f, linearRoughness);
    float energyFactor = mix(1.0f, 1.0f / 1.51f, linearRoughness);
    float fd90 = energyBias + 2.0 * LdotH*LdotH * linearRoughness;
    vec3 f0 = vec3(1.0f, 1.0f, 1.0f);
    float lightScatter = F_Schlick(f0, fd90, NdotL).r;
    float viewScatter = F_Schlick(f0, fd90, NdotV).r;
    
    return lightScatter * viewScatter * energyFactor;
}

float V_SmithGGXCorrelated(float NdotL, float NdotV, float alphaG) {
    float alphaG2 = alphaG * alphaG;
    
    float Lambda_GGXV = NdotL * sqrt((-NdotV * alphaG2 + NdotV) * NdotV + alphaG2);
    
    float Lambda_GGXL = NdotV * sqrt((-NdotL * alphaG2 + NdotL) * NdotL + alphaG2);
    
    return 0.5f / max(Lambda_GGXV + Lambda_GGXL, 1e-6);
}

float D_GGX(float NdotH, float m) {
    float m2 = m * m;
    float f = (NdotH * m2 - NdotH) * NdotH + 1;
    return m2 / (f * f);
}


vec3 BRDF(vec3 V, vec3 L, vec3 N, float NdotV, float NdotL, MaterialRenderingData material) {
    
    vec3 H = normalize(V + L);
    float LdotH = saturate(dot(L, H));
    float NdotH = saturate(dot(N, H));
    
    //Specular
    vec3 F = F_Schlick(material.f0, material.f90, LdotH);
    float Vis = V_SmithGGXCorrelated(NdotV, NdotL, material.roughness);
    float D = D_GGX(NdotH, material.roughness);
    vec3 Fr = D * F * Vis * INV_PI;
    
    //Diffuse
    float Fd = Fr_DisneyDiffuse(NdotV, NdotL, LdotH, material.linearRoughness) * INV_PI;
    
    return Fd * material.albedo + Fr;
}