#version 410

#include "Sampling.glsl"
#include "BRDF.glsl"

in vec2 uv;
out vec4 colour;

vec4 integrateDFGOnly(float NdotV, float roughness) { //bad results for high NdotV – also test results for diffuse lighting direction with only one face of the cubemap.
    
    const uint sampleCount = 1024;
    
    vec3 N = vec3(0, 0, 1);
    
    vec3 V;
    V.x = sqrt( 1.0f - NdotV * NdotV ); // sin
    V.y = 0;
    V.z = NdotV; // cos
    
    vec4 acc = vec4(0);
    float accWeight = 0;
    
    // Compute pre-integration
    for (uint i = 0; i < sampleCount; ++i) {
        vec2 u = getSample(i, sampleCount);
        
        vec3 H = ImportanceSampleGGX( u, roughness, N );
        vec3 L = 2 * dot( V, H ) * H - V;
        
        float NdotL = saturate( L.z );
        float NdotH = saturate( H.z );
        float VdotH = saturate( dot( V, H ) );
        float G = V_SmithGGXCorrelated(NdotL, NdotV, roughness);
        
        if( NdotL > 0 && G > 0) {
            float G_Vis = G * dot(L, H) / (NdotH * NdotV);
            float Fc = pow( 1 - VdotH, 5 );
            acc.x += (1 - Fc) * G_Vis;
            acc.y += Fc * G_Vis;
        }
        
        // diffuse Disney pre-integration
        u = fract(u + 0.5);
        float pdf;
        // The pdf is not used because it cancels with other terms
        // (The 1/PI from diffuse BRDF and the NdotL from Lambert’s law).
        
        importanceSampleCosDir(u, N, L, NdotL, pdf);
        
        if (NdotL > 0) {
            float LdotH = saturate(dot(L, normalize(V + L)));
            float NdotV = saturate(dot(N, V));
            acc.z += Fr_DisneyDiffuse(NdotV, NdotL, LdotH, sqrt(roughness));
        }
        
        accWeight += 1.0;
    }
    
    return acc * (1.0f / accWeight);
}

void main() {
    float NdotV = uv.x;
    float roughness = uv.y;
    
    colour = integrateDFGOnly(NdotV, roughness);
}