#pragma OPENCL EXTENSION cl_khr_gl_sharing : enable
#pragma OPENCL EXTENSION cl_khr_gl_depth_images : enable

#include "CLMath.cl"
#include "BRDF.cl"

typedef struct MaterialData {
    float3 baseColour;
    float smoothness;
    float metalMask;
    float reflectance;
} MaterialData;

#define LightTypePoint 0
#define LightTypeDirectional 1
#define LightTypeSpot 2


typedef struct LightData {
    float4 colourAndIntensity;
    float4 cameraSpacePosition;
    float4 cameraSpaceDirection;
    float4 extraData;
    uint lightTypeFlag;
    float inverseSquareAttenuationRadius;
    float2 padding;
} LightData;

float3 decode(float2);
float3 decode(float2 enc) {
    float2 fenc = enc*4-2;
    float f = dot(fenc,fenc);
    float g = sqrt(1-f/4);
    float3 n;
    n.xy = fenc*g;
    n.z = 1-f/2;
    return n;
}

MaterialData decodeMaterialFromGBuffers(float4, float4, float4);
MaterialData decodeMaterialFromGBuffers(float4 gBuffer0, float4 gBuffer1, float4 gBuffer2) {
    MaterialData data;
    data.smoothness = gBuffer0.b;
    data.baseColour = gBuffer1.rgb;
    data.metalMask = gBuffer2.g;
    data.reflectance = gBuffer2.b;
    
    return data;
}

void evaluateMaterialData(MaterialData data, float3 *albedo, float3 *f0, float *f90, float *linearRoughness);
void evaluateMaterialData(MaterialData data, float3 *albedo, float3 *f0, float *f90, float *linearRoughness) {
    float3 diffuseF0 = (float3)(0.16 + data.reflectance * data.reflectance);
    *albedo = mix(data.baseColour, (float3)(0), data.metalMask);
    *f0 = mix(diffuseF0, data.baseColour, data.metalMask);
    *f90 = saturate(50.0 * dot(*f0, (float3)(0.33)));
    *linearRoughness = 1 - data.smoothness;
}

float3 calculateCameraSpacePositionFromWindowZ(float, float2, float2, float2);
float3 calculateCameraSpacePositionFromWindowZ(float windowZ,
                                              float2 uv,
                                              float2 nearPlane,
                                              float2 projectionTerms) {
    
    float3 cameraDirection = (float3)(nearPlane * ((uv.xy * 2) - 1), -1);
    float linearDepth = projectionTerms.y / (windowZ - projectionTerms.x);
    return cameraDirection * linearDepth;
}

float smoothDistanceAtt(float squaredDistance, float invSqrAttRadius);
float smoothDistanceAtt(float squaredDistance, float invSqrAttRadius) {
    float factor = squaredDistance * invSqrAttRadius;
    float smoothFactor = saturate(1.0f - factor * factor);
    return smoothFactor * smoothFactor;
}

float getDistanceAtt(float3 unnormalizedLightVector, float invSqrAttRadius);
float getDistanceAtt(float3 unnormalizedLightVector, float invSqrAttRadius) {
    float sqrDist = dot(unnormalizedLightVector, unnormalizedLightVector);
    float attenuation = 1.0f / (max(sqrDist, 0.01f*0.01f));
    attenuation *= smoothDistanceAtt(sqrDist, invSqrAttRadius);
    
    return attenuation;
}

float getAngleAtt(float3 normalizedLightVector, float3 lightDir, float lightAngleScale, float lightAngleOffset);
float getAngleAtt(float3 normalizedLightVector, float3 lightDir, float lightAngleScale, float lightAngleOffset) {
    // On the CPU
    // float lightAngleScale = 1.0f / max(0.001f, (cosInner - cosOuter));
    // float lightAngleOffset = -cosOuter * angleScale;
    
    float cd = dot(lightDir, normalizedLightVector);
    float attenuation = saturate(cd * lightAngleScale + lightAngleOffset);
    // smooth the transition
    attenuation *= attenuation;
    
    return attenuation;
}

float3 evaluatePunctualLight(float3 cameraSpacePosition,
                             float3 V, float3 N, float NdotV,
                             float3 albedo, float3 f0, float f90, float linearRoughness,
                             LightData light);
float3 evaluatePunctualLight(float3 cameraSpacePosition,
                             float3 V, float3 N, float NdotV,
                             float3 albedo, float3 f0, float f90, float linearRoughness,
                            LightData light) {
    
    float4 lightPositionCamera = light.cameraSpacePosition;
    float3 lightDirectionCamera = light.cameraSpaceDirection.xyz;
    
    float3 unnormalizedLightVector;
    float3 L;
    float attenuation = 1;
    
    if (light.lightTypeFlag == LightTypeDirectional) {
        unnormalizedLightVector = lightDirectionCamera.xyz;
        L = fast_normalize(unnormalizedLightVector);
    } else {
        unnormalizedLightVector = lightPositionCamera.xyz - cameraSpacePosition;
        L = fast_normalize(unnormalizedLightVector);
        
        attenuation *= getDistanceAtt(unnormalizedLightVector, light.inverseSquareAttenuationRadius);

        if (light.lightTypeFlag == LightTypeSpot) {
            
            float2 lightAngleScaleAndOffset = light.extraData.xy;
            
            attenuation *= getAngleAtt(L, lightDirectionCamera, lightAngleScaleAndOffset.x, lightAngleScaleAndOffset.y);
        }
    }

    float3 lightColour = light.colourAndIntensity.xyz * light.colourAndIntensity.w;
    
    float NdotL = saturate(dot(N, L));
    
    // lightColor is the outgoing luminance of the light times the user light color
    // i.e with point light and luminous power unit: lightColor = color * phi / (4 * PI)
    float3 luminance = BRDF(V, L, N, NdotV, NdotL, albedo, f0, f90, linearRoughness) * NdotL * lightColour * attenuation;
    
    return luminance;
}

float3 evaluateLighting(float3 cameraSpacePosition,
                        float3 V, float3 N, float NdotV,
                        float3 albedo, float3 f0, float f90, float linearRoughness,
                        LightData light);
float3 evaluateLighting(float3 cameraSpacePosition,
                        float3 V, float3 N, float NdotV,
                        float3 albedo, float3 f0, float f90, float linearRoughness,
                         LightData light) {
    switch (light.lightTypeFlag) {
        case LightTypePoint:
        case LightTypeDirectional:
        case LightTypeSpot:
            return evaluatePunctualLight(cameraSpacePosition, V, N, NdotV, albedo, f0, f90, linearRoughness, light);
    }
    return (float3)(0);
}

//Should be applied in every lighting shader before writing the colour
float3 epilogueLighting(float3 color, float exposureMultiplier);
float3 epilogueLighting(float3 color, float exposureMultiplier) {
    return color * exposureMultiplier;
}

__kernel void lightAccumulationPass(__write_only image2d_t lightAccumulationBuffer, float2 invImageDimensions,
                                    float4 nearPlaneAndProjectionTerms,
                                    __read_only image2d_t gBuffer0Tex, __read_only image2d_t gBuffer1Tex, __read_only image2d_t gBuffer2Tex, __read_only image2d_depth_t gBufferDepthTex,
                                    __global LightData *lights, int lightCount) {

    const sampler_t sampler = CLK_FILTER_NEAREST | CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE;
    
    int2 coord = (int2)(get_global_id(0), get_global_id(1));
    float2 uv = (float2)(coord.x, coord.y) * invImageDimensions;
    
    
    float4 gBuffer0 = read_imagef(gBuffer0Tex, sampler, coord);
    float4 gBuffer1 = read_imagef(gBuffer1Tex, sampler, coord);
    float4 gBuffer2 = read_imagef(gBuffer2Tex, sampler, coord);
    float gBufferDepth = read_imagef(gBufferDepthTex, sampler, coord);
    
    float3 cameraSpacePosition = calculateCameraSpacePositionFromWindowZ(gBufferDepth, uv, nearPlaneAndProjectionTerms.xy, nearPlaneAndProjectionTerms.zw);
    MaterialData material = decodeMaterialFromGBuffers(gBuffer0, gBuffer1, gBuffer2);
    
    float3 albedo;
    float3 f0;
    float f90;
    float linearRoughness;
    evaluateMaterialData(material, &albedo, &f0, &f90, &linearRoughness);


    float3 N = fast_normalize(decode(gBuffer0.xy));
    float3 V = fast_normalize(-cameraSpacePosition);
    float NdotV = fabs(dot(N, V)) + 1e-5f; //bias the result to avoid artifacts
    
    float3 lightAccumulation = (float3)(0, 0, 0);
    
    for (int i = 0; i < lightCount; i++) {
        lightAccumulation += evaluateLighting(cameraSpacePosition, V, N, NdotV, albedo, f0, f90, linearRoughness, lights[i]);
    }
    
    float3 epilogue = epilogueLighting(lightAccumulation, 100.f);
    
    write_imagef(lightAccumulationBuffer, coord, (float4)(epilogue, 1));
}