#version 410

#include "Sampling.glsl"

uniform samplerCube image;

const uint sampleCount = 32;

in vec2 uv;
layout(location = 0) out vec4 out0;
layout(location = 1) out vec4 out1;
layout(location = 2) out vec4 out2;
layout(location = 3) out vec4 out3;
layout(location = 4) out vec4 out4;
layout(location = 5) out vec4 out5;

vec4 integrateDiffuseCubeLD(vec3 N) {
    
    vec3 accBrdf(0);
    for (uint i = 0; i < sampleCount; ++i) {
        vec2 eta = getSample(i, sampleCount);
        vec3 L;
        float NdotL;
        float pdf;
        
        importanceSampleCosDir(eta, N, L, NdotL, pdf);
        
        if (NdotL > 0) {
            vec4 colour = texture(image, L);
            accBrdf += colour.xyz;
        }
    }
    
    vec3 vec3Part = accBrdf * (1.0f / sampleCount);
    return vec4(vec3Part, 1.0f);
}

void main() {
    
    vec3 direction0 = cubeMapFaceUVToDirection(uv, 0);
    out0 = integrateDiffuseCubeLD(direction0);
    
    vec3 direction1 = cubeMapFaceUVToDirection(uv, 1);
    out1 = integrateDiffuseCubeLD(direction1);
    
    vec3 direction2 = cubeMapFaceUVToDirection(uv, 2);
    out2 = integrateDiffuseCubeLD(direction2);
    
    vec3 direction3 = cubeMapFaceUVToDirection(uv, 3);
    out3 = integrateDiffuseCubeLD(direction3);
    
    vec3 direction4 = cubeMapFaceUVToDirection(uv, 4);
    out4 = integrateDiffuseCubeLD(direction4);
    
    vec3 direction5 = cubeMapFaceUVToDirection(uv, 5);
    out5 = integrateDiffuseCubeLD(direction5);
}