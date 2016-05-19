/************************************
 ************* BRDF *****************
 ***********************************/

#include "Utilities.glsl"

vec3 F_Schlick(vec3 f0, float f90, float u) {
    return f0 + (f90 - f0) * pow(1.f - u, 5.f);
}

float Fr_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float linearRoughness);

float Fr_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float linearRoughness) {
    float energyBias = mix(0, 0.5, linearRoughness);
    float energyFactor = mix(1.0, 1.0 / 1.51, linearRoughness);
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


vec3 BRDF(vec3 V, vec3 L, vec3 N, float NdotV, float NdotL, vec3 albedo, vec3 f0, float f90, float linearRoughness) {
    
    float roughness = linearRoughness * linearRoughness;
    
    vec3 H = normalize(V + L);
    float LdotH = saturate(dot(L, H));
    float NdotH = saturate(dot(N, H));
    
    //Specular
    vec3 F = F_Schlick(f0, f90, LdotH);
    float Vis = V_SmithGGXCorrelated(NdotV, NdotL, roughness);
    float D = D_GGX(NdotH, roughness);
    vec3 Fr = D * F * Vis / PI;
    
    //Diffuse
    float Fd = Fr_DisneyDiffuse(NdotV, NdotL, LdotH, linearRoughness) / PI;
    
    return Fd * albedo + Fr;
}