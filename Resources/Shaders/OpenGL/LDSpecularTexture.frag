#version 410

#include "Sampling.glsl"
#include "BRDF.glsl"

uniform int resolution;

//On the CPU:
//float mip = (float)mipLevel/mipCount;
//float perceptuallyLinearRoughness = mip * mip;
//float roughness = perceptuallyLinearRoughness * perceptuallyLinearRoughness;
uniform float roughness;

uniform samplerCube image;
uniform float valueMultiplier;

const uint sampleCount = 32;

in vec2 uv;
layout(location = 0) out vec4 out0;
layout(location = 1) out vec4 out1;
layout(location = 2) out vec4 out2;
layout(location = 3) out vec4 out3;
layout(location = 4) out vec4 out4;
layout(location = 5) out vec4 out5;

vec4 integrateSpecularCubeLD(vec3 V, vec3 N, float roughness) {
    vec4 accBrdf = vec4(0);
    float accBrdfWeight = 0;
    
    for (uint i=0; i < sampleCount; ++i) {
        vec2 eta = getSample(i, sampleCount);
        vec3 H = ImportanceSampleGGX(eta, roughness, N);
        vec3 L = 2 * dot(V, H) * H - V;
        
        float NdotL = dot(N, L);
        
        if (NdotL > 0) {
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
            float pdf = D_GGX(NdotH, roughness) * INV_PI / 4;
            float omegaS = 1.0 / (sampleCount * pdf);
            float omegaP = 4.0 * PI / (6.0 * resolution * resolution);
            float sampleMipLevel = clamp(0.5 * log2(omegaS/omegaP), 0, 8);
            vec4 Li = textureLod(image, L, sampleMipLevel) * valueMultiplier;
            
            accBrdf += Li * NdotL;
            accBrdfWeight += NdotL;
        }
    }
    return accBrdf * (1.0f / accBrdfWeight);
}

void main() {
    
    vec3 direction0, direction1, direction2, direction3, direction4, direction5;
    cubeMapFaceUVsToDirections(uv, direction0, direction1, direction2, direction3, direction4, direction5);
    
    out0 = integrateSpecularCubeLD(direction0, direction0, roughness);
    
    out1 = integrateSpecularCubeLD(direction1, direction1, roughness);
    
    out2 = integrateSpecularCubeLD(direction2, direction2, roughness);
    
    out3 = integrateSpecularCubeLD(direction3, direction3, roughness);
    
    out4 = integrateSpecularCubeLD(direction4, direction4, roughness);
    
    out5 = integrateSpecularCubeLD(direction5, direction5, roughness);
}

