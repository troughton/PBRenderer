#version 410

#include "Sampling.glsl"

uniform samplerCube image;
uniform float valueMultiplier;

const uint sampleCount = 256;

in vec2 uv;
layout(location = 0) out vec4 out0;
layout(location = 1) out vec4 out1;
layout(location = 2) out vec4 out2;
layout(location = 3) out vec4 out3;
layout(location = 4) out vec4 out4;
layout(location = 5) out vec4 out5;

vec4 integrateDiffuseCubeLD(vec3 N) {
    vec3 accBrdf = vec3(0);
    for (uint i = 0; i < sampleCount; ++i) {
        vec2 eta = getSample(i, sampleCount);
        vec3 L;
        float NdotL;
        float pdf;
        
        importanceSampleCosDir(eta, N, L, NdotL, pdf);
        
        if (NdotL > 0) {
            vec4 colour = textureLod(image, L, 0) * valueMultiplier;
            accBrdf += colour.xyz;
        }
    }
    
    vec3 vec3Part = accBrdf * (1.0f / sampleCount);
    return vec4(vec3Part, 1.0f);
}

void main() {
    
    vec3 direction0, direction1, direction2, direction3, direction4, direction5;
    cubeMapFaceUVsToDirections(uv, direction0, direction1, direction2, direction3, direction4, direction5);
    
    out0 = integrateDiffuseCubeLD(direction0);
    
    out1 = integrateDiffuseCubeLD(direction1);
    
    out2 = integrateDiffuseCubeLD(direction2);
    
    out3 = integrateDiffuseCubeLD(direction3);
    
    out4 = integrateDiffuseCubeLD(direction4);
    
    out5 = integrateDiffuseCubeLD(direction5);
}