#version 410

#include "Encoding.glsl"
#include "Lighting.glsl"
#include "Camera.glsl"

#define MAX_NUM_TOTAL_LIGHTS 512

uniform samplerBuffer lights;

LightData lightAtIndex(int lightIndex) {
    int indexInBuffer = 5 * lightIndex;
    LightData data;
    
    data.colourAndIntensity = texelFetch(lights, indexInBuffer);
    data.worldSpacePosition = texelFetch(lights, indexInBuffer + 1);
    data.worldSpaceDirection  = texelFetch(lights, indexInBuffer + 2);
    data.extraData = texelFetch(lights, indexInBuffer + 3);
    
    vec4 typeAndRadius = texelFetch(lights, indexInBuffer + 4);
    data.lightTypeFlag = floatBitsToUint(typeAndRadius.x);
    data.inverseSquareAttenuationRadius = typeAndRadius.y;
    
    return data;
}

out vec4 outputColour;
in vec2 uv;

vec4 calculateCameraSpacePositionFromWindowZ(float windowZ,
                                               vec2 uv,
                                               vec2 nearPlane,
                                               vec2 projectionTerms) {
    
    vec3 cameraDirection = vec3(nearPlane * (uv.xy * 2 - 1), -1);
    float linearDepth = projectionTerms.y / (windowZ - projectionTerms.x);
    return vec4(cameraDirection * linearDepth, 1);
}

void fill_array4(inout int array[4], ivec4 src)
{
    array[0] = src.x;
    array[1] = src.y;
    array[2] = src.z;
    array[3] = src.w;
}

uniform usamplerBuffer lightGrid;

#define ClusteredGridScale 16

vec3 calculateLightingClustered(vec2 cameraNearFar, vec2 uv, vec3 cameraSpacePosition, vec3 worldSpacePosition, vec3 V, vec3 N, float NdotV, MaterialRenderingData material) {
    uvec3 grid = uvec3(2 * ClusteredGridScale, 1 * ClusteredGridScale, 4 * ClusteredGridScale);
    
    vec2 screenPosition = uv;
    float zPosition = (-cameraSpacePosition.z - cameraNearFar.x) / (cameraNearFar.y - cameraNearFar.x);
    
    uvec3 clusterPosition = uvec3(uint(screenPosition.x * grid.x), uint(screenPosition.y * grid.y), uint(zPosition * grid.z));
    uint cluster_index = (clusterPosition.y * grid.x + clusterPosition.x) * grid.z + clusterPosition.z;
    
    int lightIndexBlock[4];
    fill_array4(lightIndexBlock, ivec4(texelFetch(lightGrid, int(cluster_index))));
    
    int list_size = lightIndexBlock[0] & 255;
    int list_index = lightIndexBlock[0] >> 8;
    int light_count = list_size;
    
    vec3 lightAccumulation = vec3(0.0f, 0.0f, 0.0f);
    
    for (int k = 2; k < list_size + 2; k++) {
        int lightIndex = (lightIndexBlock[(k & 7)>>1] >> ((k&1)<<4)) & 0xFFFF;
        if ((k & 7) == 7) { fill_array4(lightIndexBlock, ivec4(texelFetch(lightGrid, list_index++))); } //Follow the linked list through all of the tiles in this cluster.
        
        LightData light = lightAtIndex(lightIndex);
        lightAccumulation += evaluateLighting(worldSpacePosition, V, N, NdotV, material, light);
    }
    
    //    [flatten] if (mUI.visualizeLightCount)
    //    {
    //        lit = (float(light_count) * rcp(255.0f)).xxx;
    //    }
    
    
    return lightAccumulation;
}


uniform float exposure;

vec3 lightAccumulationPass(vec4 nearPlaneAndProjectionTerms, vec2 cameraNearFar,
                             uint gBuffer0, vec4 gBuffer1, vec4 gBuffer2, float gBufferDepth,
                             vec2 uv, mat4 cameraToWorldMatrix) {
    
    vec4 cameraSpacePosition = calculateCameraSpacePositionFromWindowZ(gBufferDepth, uv, nearPlaneAndProjectionTerms.xy, nearPlaneAndProjectionTerms.zw);
    vec3 worldSpacePosition = (cameraToWorldMatrix * cameraSpacePosition).xyz;
    
    vec3 N;
    
    MaterialData material = decodeDataFromGBuffers(N, gBuffer0, gBuffer1, gBuffer2);
    
    MaterialRenderingData renderingMaterial = evaluateMaterialData(material);
    
    vec3 V = normalize((cameraToWorldMatrix * vec4(-cameraSpacePosition.xyz, 0)).xyz);
    float NdotV = abs(dot(N, V)) + 1e-5f; //bias the result to avoid artifacts
    
    vec3 lightAccumulation = calculateLightingClustered(cameraNearFar, uv, cameraSpacePosition.xyz, worldSpacePosition, V, N, NdotV, renderingMaterial);
    
    vec3 epilogue = epilogueLighting(lightAccumulation, exposure);
    
    return epilogue;
}
    
    
uniform vec4 nearPlaneAndProjectionTerms;
uniform vec2 cameraNearFar;
uniform usampler2D gBuffer0Texture;
uniform sampler2D gBuffer1Texture;
uniform sampler2D gBuffer2Texture;
uniform sampler2D gBufferDepthTexture;

    
uniform mat4 cameraToWorldMatrix;

void main() {
    
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    
    float gBufferDepth = texelFetch(gBufferDepthTexture, pixelCoord, 0).r;
    uint gBuffer0 = texelFetch(gBuffer0Texture, pixelCoord, 0).r;
    vec4 gBuffer1 = texelFetch(gBuffer1Texture, pixelCoord, 0);
    vec4 gBuffer2 = texelFetch(gBuffer2Texture, pixelCoord, 0);
    
    vec3 lightAccumulation = lightAccumulationPass(nearPlaneAndProjectionTerms, cameraNearFar, gBuffer0, gBuffer1, gBuffer2, gBufferDepth, uv, cameraToWorldMatrix);
    
    outputColour = vec4(lightAccumulation, 1);
}