/************************************
 ************* BRDF *****************
 ***********************************/

#include "Utilities.cl"

float3 F_Schlick(float3 f0, float f90, float u);
float3 F_Schlick(float3 f0, float f90, float u) {
    //Use a Spherical Gaussian approximation as in Real Shading in Unreal Engine 4,  Siggraph 2013.
    return f0 + (f90 - f0) * native_exp2((-5.55473f * u - 6.98316f) * u);  //native_powr(1.f - u, 5.f);
}

float F_Schlick_Float(float f0, float f90, float u);
float F_Schlick_Float(float f0, float f90, float u) {
    //Use a Spherical Gaussian approximation as in Real Shading in Unreal Engine 4,  Siggraph 2013.
    return f0 + (f90 - f0) * native_exp2((-5.55473f * u - 6.98316f) * u);  //native_powr(1.f - u, 5.f);
}


float Fr_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float linearRoughness);

float Fr_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float linearRoughness) {
    float energyBias = mix(0.f, 0.5f, linearRoughness);
    float energyFactor = mix(1.0f, 0.6622516556f, linearRoughness);
    float fd90 = energyBias + 2.0f * LdotH*LdotH * linearRoughness;
    float f0 = 1.0f;
    
    float lightScatter = F_Schlick_Float(f0, fd90, NdotL);
    float viewScatter = F_Schlick_Float(f0, fd90, NdotV);
    
    return lightScatter * viewScatter * energyFactor;
}

float V_SmithGGXCorrelated(float NdotL, float NdotV, float alphaG);
float V_SmithGGXCorrelated(float NdotL, float NdotV, float alphaG) {
    float alphaG2 = alphaG * alphaG;
    
    float Lambda_GGXV = NdotL * native_sqrt((-NdotV * alphaG2 + NdotV) * NdotV + alphaG2);
    
    float Lambda_GGXL = NdotV * native_sqrt((-NdotL * alphaG2 + NdotL) * NdotL + alphaG2);
    
    return native_divide(0.5f, max(Lambda_GGXV + Lambda_GGXL, 1e-6f));
}

float D_GGX(float NdotH, float m);
float D_GGX(float NdotH, float m) {
    float m2 = m * m;
    float f = (NdotH * m2 - NdotH) * NdotH + 1;
    return native_divide(m2, (f * f));
}

float3 BRDF(float3 V, float3 L, float3 N, float NdotV, float NdotL, float3 albedo, float3 f0, float f90, float linearRoughness);
float3 BRDF(float3 V, float3 L, float3 N, float NdotV, float NdotL, float3 albedo, float3 f0, float f90, float linearRoughness) {
    
    float roughness = linearRoughness * linearRoughness;
    
    float3 H = native_normalize(V + L);
    float LdotH = saturate(dot(L, H));
    float NdotH = saturate(dot(N, H));
    
    //Specular
    float3 F = F_Schlick(f0, f90, LdotH);
    float Vis = V_SmithGGXCorrelated(NdotV, NdotL, roughness);
    float D = D_GGX(NdotH, roughness);
    float3 Fr = D * F * Vis * INV_PI;
    
    //Diffuse
    float Fd = Fr_DisneyDiffuse(NdotV, NdotL, LdotH, linearRoughness) * INV_PI;
    
    return Fd * albedo + Fr;
}