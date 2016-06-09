#version 410
in vec4 lightSpacePosition;

#include "LightAccumulation.glsl"

uniform vec2 cameraNearFar;
uniform vec2 projectionTerms;
uniform usampler2D gBuffer0Texture;
uniform sampler2D gBuffer1Texture;
uniform sampler2D gBuffer2Texture;
uniform sampler2D gBufferDepthTexture;

uniform mat4 cameraToWorldMatrix;
uniform mat4 worldToCameraMatrix;
uniform float exposure;

in vec3 cameraDirection;

#ifdef SSR
layout(location=1) out vec4 reflectionTraceResult;
#endif

#include "ReflectionTracer.glsl"

vec4 lightAccumulationPass(vec2 projectionTerms, vec2 cameraNearFar,
                             uint gBuffer0, vec4 gBuffer1, vec4 gBuffer2, float gBufferDepth,
                             vec2 uv, mat4 cameraToWorldMatrix) {
    
    vec4 cameraSpacePosition = calculateCameraSpacePositionFromWindowZ(gBufferDepth, cameraDirection, projectionTerms);
    vec3 worldSpacePosition = (cameraToWorldMatrix * cameraSpacePosition).xyz;
    
    vec3 N;
    
    MaterialData material = decodeDataFromGBuffers(N, gBuffer0, gBuffer1, gBuffer2);
    
    MaterialRenderingData renderingMaterial = evaluateMaterialData(material);
    
    vec3 V = normalize((cameraToWorldMatrix * vec4(-cameraSpacePosition.xyz, 0)).xyz);
    float NdotV = abs(dot(N, V)) + 1e-5f; //bias the result to avoid artifacts
    
    vec3 lightAccumulation = calculateLightingClustered(cameraNearFar, uv, cameraSpacePosition.xyz, worldSpacePosition, V, N, NdotV, renderingMaterial);
    
    vec3 epilogue = epilogueLighting(lightAccumulation, exposure);
    
    
    vec3 viewSpaceNormal = (worldToCameraMatrix * vec4(N, 0)).xyz;
    
#ifdef SSR
    reflectionTraceResult = traceReflection(cameraSpacePosition.xyz, viewSpaceNormal, renderingMaterial.roughness);
    
    return vec4(epilogue, reflectionTraceResult.w == 0.0 ? 0 : 1);
#else
    return vec4(epilogue, 1);
    
#endif
}


void main() {
    
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    
    float gBufferDepth = texelFetch(gBufferDepthTexture, pixelCoord, 0).r;
    uint gBuffer0 = texelFetch(gBuffer0Texture, pixelCoord, 0).r;
    vec4 gBuffer1 = texelFetch(gBuffer1Texture, pixelCoord, 0);
    vec4 gBuffer2 = texelFetch(gBuffer2Texture, pixelCoord, 0);
    
    vec4 accumulatedLight = lightAccumulationPass(projectionTerms, cameraNearFar, gBuffer0, gBuffer1, gBuffer2, gBufferDepth, uv, cameraToWorldMatrix);
    
    outputColour = accumulatedLight;
}