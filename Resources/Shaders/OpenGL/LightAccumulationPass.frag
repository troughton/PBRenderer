#version 410

#include "Encoding.glsl"

out vec4 outputColour;
in vec2 uv;
in vec3 cameraDirection;

uniform sampler2D gBuffer0Texture;
uniform sampler2D gBuffer1Texture;
uniform sampler2D gBuffer2Texture;
uniform sampler2D gBufferDepthTexture;

uniform vec2 depthRange;
uniform vec3 matrixTerms;

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

#define LightGridElements 131072 //32MB buffer, matching what's on the CPU side.

uniform sampler1D lightGrid;

#define ClusteredGridScale 16

vec3 calculateLightingClustered(LightData lights[], vec2 cameraNearFar, vec2 uv, vec3 cameraSpacePosition, vec3 worldSpacePosition, vec3 V, vec3 N, float NdotV, MaterialRenderingData material) {
    uvec3 grid = uvec3(2 * ClusteredGridScale, 1 * ClusteredGridScale, 8 * ClusteredGridScale);
    
    vec2 screenPosition = uv;
    float zPosition = (-cameraSpacePosition.z - cameraNearFar.x) / (cameraNearFar.y - cameraNearFar.x);
    
    vec3 clusterPosition = uvec3(uint(screenPosition.x * grid.x), uint(screenPosition.y * grid.y), uint(zPosition * grid.z));
    uint cluster_index = (clusterPosition.y * grid.x + clusterPosition.x) * grid.z + clusterPosition.z;
    
    int lightIndexBlock[4];
    fill_array4(lightIndexBlock, ivec4(texelFetch(lightGrid, cluster_index)));
    
    int list_size = lightIndexBlock[0] & 255;
    int list_index = lightIndexBlock[0] >> 8;
    int light_count = list_size;
    
    vec3 lightAccumulation = vec3(0.0f, 0.0f, 0.0f);
    
    for (int k = 2; k < list_size + 2; k++) {
        int lightIndex = (lightIndexBlock[(k & 7)>>1] >> ((k&1)<<4)) & 0xFFFF;
        if ((k & 7) == 7) { fill_array4(lightIndexBlock, ivec4(texelFetch(lightGrid, light_index++))); } //Follow the linked list through all of the tiles in this cluster.
        
        LightData light = lights[lightIndex];
        lightAccumulation += evaluateLighting(worldSpacePosition, V, N, NdotV, material);
    
    //    [flatten] if (mUI.visualizeLightCount)
    //    {
    //        lit = (float(light_count) * rcp(255.0f)).xxx;
    //    }
    
    //    lightAccumulation += (float3)(light_count == 0 ? 0.1 : 0, light_count == 1 ? 0.1 : 0, light_count == 2 ? 0.1 : 0);
    
    return lightAccumulation;
}

vec3 lightAccumulationPass(vec4 nearPlaneAndProjectionTerms, vec2 cameraNearFar,
                             uint gBuffer0, vec4 gBuffer1, vec4 gBuffer2, float gBufferDepth,
                             __global LightData *lights, vec2 uv, mat4 cameraToWorldMatrix) {
    
    vec4 cameraSpacePosition = calculateCameraSpacePositionFromWindowZ(gBufferDepth, uv, nearPlaneAndProjectionTerms.xy, nearPlaneAndProjectionTerms.zw);
    vec3 worldSpacePosition = cameraToWorldMatrix * cameraSpacePosition;
    
    vec3 N;
    
    MaterialData material = decodeDataFromGBuffers(N, gBuffer0, gBuffer1, gBuffer2);
    
    MaterialRenderingData renderingMaterial = evaluateMaterialData(material);
    
    vec3 V = normalize((cameraToWorldMatrix * vec4(-cameraSpacePosition.xyz, 0)).xyz);
    float NdotV = abs(dot(N, V)) + 1e-5f; //bias the result to avoid artifacts
    
    vec3 lightAccumulation = calculateLightingClustered(lightGrid, lights, cameraNearFar, uv, cameraSpacePosition.xyz, worldSpacePosition, V, N, NdotV, renderingMaterial);
    
    vec3 epilogue = epilogueLighting(lightAccumulation, 1.f);
    
    return epilogue;
}

void main() {
    float gBufferDepth = texture(gBufferDepthTexture, uv).r;
    vec4 gBuffer0 = texture(gBuffer0Texture, uv);
    vec4 gBuffer1 = texture(gBuffer1Texture, uv);
    vec4 gBuffer2 = texture(gBuffer2Texture, uv);
    
    vec3 normal = normalize(decode(gBuffer0.xy));
    
    MaterialData data = decodeMaterialFromGBuffers(gBuffer0, gBuffer1, gBuffer2);
    
    vec3 cameraSpacePosition = CalculateCameraSpacePositionFromWindow(gBufferDepth, cameraDirection, depthRange, matrixTerms);
    
    outputColour = vec4(max(dot(normal, vec3(0, 0, 1)), 0) * data.baseColour, 1);
}