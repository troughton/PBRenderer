#version 410

#include "Sampling.glsl"
#include "BRDF.glsl"

out vec4 colour;

uniform int textureSize;
uniform int mipCount;

vec4 integrateSpecularCubeLD(vec3 V, vec3 N, float roughness, samplerCube image) {
    vec3 accBrdf(0);
    float accBrdfWeight = 0;
    
    for (uint i=0; i<sampleCount; ++i) {
        vec2 eta = getSample(i, sampleCount);
        vec3 H = ImportanceSampleGGX(eta, roughness, N);
        vec3 L = 2 * dot(V, H) * H - V;
        
        float NdotL = dot(N, L);
        
        if (NdotL >0) {
            // Use pre-filtered importance sampling (i.e use lower mipmap
            // level for fetching sample with low probability in order
            // to reduce the variance).
            // (Reference: GPU Gem3)
            //
            // Since we pre-integrate the result for normal direction,
            // N == V and then NdotH == LdotH. This is why the BRDF pdf
            // can be simplifed from:
            //      pdf = D_GGX_Divide_Pi(NdotH, roughness)*NdotH/(4*LdotH);
            // to
            //      pdf = D_GGX_Divide_Pi(NdotH, roughness) / 4; //
            // The mipmap level is clamped to something lower than 8x8
            // in order to avoid cubemap filtering issues.
            //
            // - OmegaS: Solid angle associated with a sample
            // - OmegaP: Solid angle associated with a pixel of the cubemap.
            
            float NdotH = saturate(dot(N, H));
            float LdotH = saturate(dot(L, H));
            float pdf = D_GGX(NdotH, roughness) / (4 * PI);
            float omegaS = 1.0 / (sampleCount * pdf);
            float omegaP = 4.0 * (float)M_PI / (6.0 * textureSize * textureSize);
            float mipLevel = clamp(0.5 * log2(omegaS/omegaP), 0, mipCount);
            vec4 Li = textureLod(image, L, mipLevel);
            
            accBrdf += vec3(Li.x, Li.y, Li.z) * NdotL;
            accBrdfWeight += NdotL;
        }
    }
    vec3 xyz = accBrdf * (1.0f / accBrdfWeight);
    return vec4(xyz.x, xyz.y, xyz.z, 1.f);
}

void main() {
}