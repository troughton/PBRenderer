#version 410

#define NoSpecular
#include "LightAccumulation.glsl"

uniform vec4 nearPlaneAndProjectionTerms;
uniform vec2 cameraNearFar;
uniform usampler2D gBuffer0Texture;
uniform sampler2D gBuffer1Texture;
uniform sampler2D gBuffer2Texture;
uniform sampler2D gBufferDepthTexture;

uniform mat4 cameraToWorldMatrix;
uniform float exposure;

vec3 lightAccumulationPass(vec4 nearPlaneAndProjectionTerms, vec2 cameraNearFar,
                           uint gBuffer0, vec4 gBuffer1, vec4 gBuffer2, float gBufferDepth,
                           vec2 uv, mat4 cameraToWorldMatrix) {
    
    vec4 cameraSpacePosition = calculateCameraSpacePositionFromWindowZ(gBufferDepth, uv, nearPlaneAndProjectionTerms.xy, nearPlaneAndProjectionTerms.zw);
    vec3 worldSpacePosition = (cameraToWorldMatrix * cameraSpacePosition).xyz;
    
    vec3 N;
    
    MaterialData material = decodeDataFromGBuffers(N, gBuffer0, gBuffer1, gBuffer2);
    
    MaterialRenderingData renderingMaterial = evaluateMaterialDataNoSpeculars(material);
    
    vec3 V = normalize((cameraToWorldMatrix * vec4(-cameraSpacePosition.xyz, 0)).xyz);
    float NdotV = abs(dot(N, V)) + 1e-5f; //bias the result to avoid artifacts
    
    vec3 lightAccumulation = calculateLightingClustered(cameraNearFar, uv, cameraSpacePosition.xyz, worldSpacePosition, V, N, NdotV, renderingMaterial);
    
    vec3 epilogue = epilogueLighting(lightAccumulation, exposure);
    
    return epilogue;
}


void main() {
    
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    
    float gBufferDepth = texelFetch(gBufferDepthTexture, pixelCoord, 0).r;
    uint gBuffer0 = texelFetch(gBuffer0Texture, pixelCoord, 0).r;
    vec4 gBuffer1 = texelFetch(gBuffer1Texture, pixelCoord, 0);
    vec4 gBuffer2 = texelFetch(gBuffer2Texture, pixelCoord, 0);
    
    vec3 lightAccumulation = lightAccumulationPass(nearPlaneAndProjectionTerms, cameraNearFar, gBuffer0, gBuffer1, gBuffer2, gBufferDepth, uv, cameraToWorldMatrix);
    
    outputColour = vec4(lightAccumulation, 1);
}