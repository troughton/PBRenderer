
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

uniform bool visualiseLightCount;

vec4 calculateCameraSpacePositionFromWindowZ(float windowZ,
                                             vec3 cameraDirection,
                                             vec2 projectionTerms) {
    
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
    
    if (visualiseLightCount) {
        lightAccumulation = vec3(light_count / 255.f) / exposure;
    }
    
    //    [flatten] if (mUI.visualizeLightCount)
    //    {
    //        lit = (float(light_count) * rcp(255.0f)).xxx;
    //    }
    
    
    return lightAccumulation;
}