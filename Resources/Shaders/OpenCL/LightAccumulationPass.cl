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
    float4 worldSpacePosition;
    float4 worldSpaceDirection;
    float4 extraData;
    uint lightTypeFlag;
    float inverseSquareAttenuationRadius;
    float2 padding;
} LightData;

float3 decode(float2);
float3 decode(float2 enc) {
    float2 fenc = enc*4-2;
    float f = dot(fenc,fenc);
    float g = native_sqrt(1-f/4);
    float3 n;
    n.xy = fenc*g;
    n.z = 1-f/2;
    return n;
}

MaterialData decodeDataFromGBuffers(float3*, uint, float4, float4);
MaterialData decodeDataFromGBuffers(float3 *N, uint gBuffer0, float4 gBuffer1, float4 gBuffer2) {
    const float divideFactor = 0.0009775171065f; // 1 / 1023
    
    uint nX = (gBuffer0 >> 22) & 0b1111111111;
    uint nY = (gBuffer0 >> 12) & 0b1111111111;
    uint smoothness = (gBuffer0 >> 2) & 0b1111111111;
    float2 encodedNormal = (float2)(nX * divideFactor, nY * divideFactor);
    encodedNormal = encodedNormal * 2.f - 1.f;
    *N = decode(encodedNormal);
    
    MaterialData data;
    data.smoothness = (float)(smoothness * divideFactor);
    data.baseColour = gBuffer1.xyz;
    data.metalMask = gBuffer2.y;
    data.reflectance = gBuffer2.z;
    
    return data;
}

void evaluateMaterialData(MaterialData data, float3 *albedo, float3 *f0, float *f90, float *linearRoughness);
void evaluateMaterialData(MaterialData data, float3 *albedo, float3 *f0, float *f90, float *linearRoughness) {
    float3 diffuseF0 = (float3)(0.16f + data.reflectance * data.reflectance);
    *albedo = mix(data.baseColour, (float3)(0), data.metalMask);
    *f0 = mix(diffuseF0, data.baseColour, data.metalMask);
    *f90 = saturate(50.0f * dot(*f0, (float3)(0.33f, 0.33f, 0.33f)));
    *linearRoughness = 1.f - data.smoothness;
}

float4 calculateCameraSpacePositionFromWindowZ(float, float2, float2, float2);
float4 calculateCameraSpacePositionFromWindowZ(float windowZ,
                                              float2 uv,
                                              float2 nearPlane,
                                              float2 projectionTerms) {
    
    float3 cameraDirection = (float3)(nearPlane * (uv.xy * 2 - 1), -1);
    float linearDepth = native_divide(projectionTerms.y, (windowZ - projectionTerms.x));
    return (float4)(cameraDirection * linearDepth, 1);
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
    float attenuation = native_recip(max(sqrDist, 0.0001f));
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

float3 evaluatePunctualLight(float3 worldSpacePosition,
                             float3 V, float3 N, float NdotV,
                             float3 albedo, float3 f0, float f90, float linearRoughness,
                             __global LightData *light);
float3 evaluatePunctualLight(float3 worldSpacePosition,
                             float3 V, float3 N, float NdotV,
                             float3 albedo, float3 f0, float f90, float linearRoughness,
                           __global LightData *light) {
    
    float4 lightPositionWorld = light->worldSpacePosition;
    float3 lightDirectionWorld = light->worldSpaceDirection.xyz;
    
    float3 unnormalizedLightVector;
    float3 L;
    float attenuation = 1;
    
    if (light->lightTypeFlag == LightTypeDirectional) {
        unnormalizedLightVector = lightDirectionWorld.xyz;
        L = native_normalize(unnormalizedLightVector);
    } else {
        unnormalizedLightVector = lightPositionWorld.xyz - worldSpacePosition;
        L = native_normalize(unnormalizedLightVector);
        
        attenuation *= getDistanceAtt(unnormalizedLightVector, light->inverseSquareAttenuationRadius);

        if (light->lightTypeFlag == LightTypeSpot) {
            
            float2 lightAngleScaleAndOffset = light->extraData.xy;
            
            attenuation *= getAngleAtt(L, lightDirectionWorld, lightAngleScaleAndOffset.x, lightAngleScaleAndOffset.y);
        }
    }

    float3 lightColour = light->colourAndIntensity.xyz * light->colourAndIntensity.w;
    
    float NdotL = saturate(dot(N, L));
    
    // lightColor is the outgoing luminance of the light times the user light color
    // i.e with point light and luminous power unit: lightColor = color * phi / (4 * PI)
    float3 luminance = BRDF(V, L, N, NdotV, NdotL, albedo, f0, f90, linearRoughness) * NdotL * lightColour * attenuation;
    
    return luminance;
}

float3 evaluateLighting(float3 worldSpacePosition,
                        float3 V, float3 N, float NdotV,
                        float3 albedo, float3 f0, float f90, float linearRoughness,
                        __global LightData *light);
float3 evaluateLighting(float3 worldSpacePosition,
                        float3 V, float3 N, float NdotV,
                        float3 albedo, float3 f0, float f90, float linearRoughness,
                         __global LightData *light) {
    switch (light->lightTypeFlag) {
        case LightTypePoint:
        case LightTypeDirectional:
        case LightTypeSpot:
            return evaluatePunctualLight(worldSpacePosition, V, N, NdotV, albedo, f0, f90, linearRoughness, light);
        break;
        default:
            return (float3)(0);
            break;
    }
    
}

//Should be applied in every lighting shader before writing the colour
float3 epilogueLighting(float3 color, float exposureMultiplier);
float3 epilogueLighting(float3 color, float exposureMultiplier) {
    return color * exposureMultiplier;
}

float3 lightAccumulationPass(float4 nearPlaneAndProjectionTerms,
                           uint gBuffer0, float4 gBuffer1, float4 gBuffer2, float gBufferDepth,
                             __global LightData *lights, int lightCount, float2 u, float16 cameraToWorldMatrix);

float3 lightAccumulationPass(float4 nearPlaneAndProjectionTerms,
                             uint gBuffer0, float4 gBuffer1, float4 gBuffer2, float gBufferDepth,
                             __global LightData *lights, int lightCount,float2 uv, float16 cameraToWorldMatrix) {

    float4 cameraSpacePosition = calculateCameraSpacePositionFromWindowZ(gBufferDepth, uv, nearPlaneAndProjectionTerms.xy, nearPlaneAndProjectionTerms.zw);
    float3 worldSpacePosition = multiplyMatrixVector(cameraToWorldMatrix, cameraSpacePosition).xyz;
    
    float3 N;
    
    MaterialData material = decodeDataFromGBuffers(&N, gBuffer0, gBuffer1, gBuffer2);
    
    float3 albedo;
    float3 f0;
    float f90;
    float linearRoughness;
    evaluateMaterialData(material, &albedo, &f0, &f90, &linearRoughness);

    float3 V = native_normalize(multiplyMatrixVector(cameraToWorldMatrix, (float4)(-cameraSpacePosition.xyz, 0)).xyz);
    float NdotV = fabs(dot(N, V)) + 1e-5f; //bias the result to avoid artifacts
    
    float3 lightAccumulation = (float3)(0, 0, 0);
    
    for (int i = 0; i < lightCount; i++) {
        lightAccumulation += evaluateLighting(worldSpacePosition, V, N, NdotV, albedo, f0, f90, linearRoughness, &lights[i]);
    }
    
    float3 epilogue = epilogueLighting(lightAccumulation, 100.f);
        
    return epilogue;
}