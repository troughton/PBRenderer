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
#define LightTypeSphereArea 3
#define LightTypeDiskArea 4

typedef struct LightData {
    float4 colourAndIntensity;
    float4 worldSpacePosition;
    float4 worldSpaceDirection;
    float4 extraData;
    uint lightTypeFlag;
    float inverseSquareAttenuationRadius;
    float2 padding;
} LightData;

float3 decodeStereographic(float2 enc);
float3 decodeStereographic(float2 enc) {
    float3 nn =
        (float3)(enc, 0) * (float3)(2.f, 2.f, 2.f) +
        (float3)(-1.f, -1.f, 1.f);
    float g = native_divide(2.0f, dot(nn, nn));
    float3 n;
    n.xy = g*nn.xy;
    n.z = g - 1;
    return n;
}

#define BasisIndexPositiveX 0
#define BasisIndexPositiveY 1
#define BasisIndexPositiveZ 2
#define BasisIndexNegativeX 3
#define BasisIndexNegativeY 4
#define BasisIndexNegativeZ 5

__constant const float3 positiveXT = (float3)(0, 0, 1);
__constant const float3 positiveXB = (float3)(1, 0, 0);
__constant const float3 positiveXN = (float3)(0, 1, 0);

__constant const float3 positiveYT = (float3)(1, 0, 0);
__constant const float3 positiveYB = (float3)(0, 0, 1);
__constant const float3 positiveYN = (float3)(0, 1, 0);

__constant const float3 positiveZT = (float3)(1, 0, 0);
__constant const float3 positiveZB = (float3)(0, 1, 0);
__constant const float3 positiveZN = (float3)(0, 0, 1);

__constant const float3 negativeXT = (float3)(0, 0, -1);
__constant const float3 negativeXB = (float3)(1, 0, 0);
__constant const float3 negativeXN = (float3)(0, 1, 0);

__constant const float3 negativeYT = (float3)(1, 0, 0);
__constant const float3 negativeYB = (float3)(0, 0, -1);
__constant const float3 negativeYN = (float3)(0, 1, 0);

__constant const float3 negativeZT = (float3)(1, 0, 0);
__constant const float3 negativeZB = (float3)(0, 1, 0);
__constant const float3 negativeZN = (float3)(0, 0, -1);

float3 decode(float2, int);
float3 decode(float2 enc, int basis) {
    float3 normal = decodeStereographic(enc);
    //The normal will be within 90 degrees in x and y of (0, 0, 1)
    
    float3 output;
    switch (basis) {
        case BasisIndexPositiveX:
            output = normal.zxy;
            break;
        case BasisIndexPositiveY:
            output = normal.xzy;
            break;
        case BasisIndexPositiveZ:
            output = normal;
            break;
        case BasisIndexNegativeX:
            output = normal.zxy;
            output.x *= -1;
            break;
        case BasisIndexNegativeY:
            output = normal.xzy;
            output.y *= -1;
            break;
        case BasisIndexNegativeZ:
            output = normal;
            output.z *= -1;
            break;
        default:
            break;
    }
    return output;
}

MaterialData decodeDataFromGBuffers(float3*, uint, float4, float4);
MaterialData decodeDataFromGBuffers(float3 *N, uint gBuffer0, float4 gBuffer1, float4 gBuffer2) {
    const float divideFactor = 0.0009775171065f; // 1 / 1023
    
    uint nX = (gBuffer0 >> 22) & 0b1111111111;
    uint nY = (gBuffer0 >> 12) & 0b1111111111;
    uint smoothness = (gBuffer0 >> 2) & 0b1111111111;
    
    int basisIndex = as_int(gBuffer1.a);
    float2 encodedNormal = (float2)(nX * divideFactor, nY * divideFactor);
    *N = decode(encodedNormal, basisIndex);
    
    
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

float3 getSpecularDominantDirArea(float3 N, float3 R, float NdotV, float roughness);
float3 getSpecularDominantDirArea(float3 N, float3 R, float NdotV, float roughness) {
    // Simple linear approximation
    float lerpFactor = (1 - roughness);
    
    return native_normalize(mix(N, R, lerpFactor));
}

float illuminanceSphereOrDisk(float cosTheta, float sinSigmaSqr);
float illuminanceSphereOrDisk(float cosTheta, float sinSigmaSqr) {
    float sinTheta = native_sqrt(1.0f - cosTheta * cosTheta);
    
    float illuminance = 0.0f;
    // Note: Following test is equivalent to the original formula.
    // There is 3 phase in the curve: cosTheta > sqrt(sinSigmaSqr),
    // cosTheta > -sqrt(sinSigmaSqr) and else it is 0
    // The two outer case can be merge into a cosTheta * cosTheta > sinSigmaSqr
    // and using saturate(cosTheta) instead.
    if (cosTheta * cosTheta > sinSigmaSqr) {
        illuminance = PI * sinSigmaSqr * saturate(cosTheta);
    } else {
        float x = native_sqrt(1.0f / sinSigmaSqr - 1.0f); // For a disk this simplify to x = d / r
        float y = -x * (cosTheta / sinTheta);
        float sinThetaSqrtY = sinTheta * native_sqrt(1.0f - y * y);
        illuminance = (cosTheta * fast_acos(y) - x * sinThetaSqrtY) * sinSigmaSqr + fast_atan(sinThetaSqrtY / x);
    }
    
    return max(illuminance, 0.0f);
}

float calculateDiskIlluminance(float3 worldSpacePosition, float NdotL, float sqrDist, float3 L,  __global LightData *light);
float calculateDiskIlluminance(float3 worldSpacePosition, float NdotL, float sqrDist, float3 L, __global LightData *light) {
    // Disk evaluation
    float cosTheta = NdotL;
    
    float lightRadius = light->extraData.x;
    float sqrLightRadius = lightRadius * lightRadius;
    // Do not let the surface penetrate the light
    float sinSigmaSqr = native_divide(sqrLightRadius, (sqrLightRadius + max(sqrLightRadius, sqrDist)));
    // Multiply by saturate(dot(planeNormal, -L)) to better match ground truth.
    float illuminance = illuminanceSphereOrDisk(cosTheta, sinSigmaSqr) * saturate(dot(light->worldSpaceDirection.xyz, -L));
    
    return illuminance;
}

float calculateSphereIlluminance(float3 worldSpacePosition, float NdotL, float sqrDist, __global LightData *light);
float calculateSphereIlluminance(float3 worldSpacePosition, float NdotL, float sqrDist, __global LightData *light) {
    float cosTheta = clamp(NdotL, -0.999f, 0.999f); // Clamp to avoid edge case
    // We need to prevent the object penetrating into the surface
    // and we must avoid divide by 0, thus the 0.9999f
    
    float lightRadius = light->extraData.x;
    float sqrLightRadius = lightRadius * lightRadius;
    float sinSigmaSqr = min(native_divide(sqrLightRadius, sqrDist), 0.9999f);
    
    return illuminanceSphereOrDisk(cosTheta, sinSigmaSqr);
}


float3 evaluateAreaLight(float3 worldSpacePosition,
                         float3 V, float3 N, float NdotV,
                         float3 albedo, float3 f0, float f90, float linearRoughness,
                         __global LightData *light);
float3 evaluateAreaLight(float3 worldSpacePosition,
                         float3 V, float3 N, float NdotV,
                         float3 albedo, float3 f0, float f90, float linearRoughness,
                         __global LightData *light) {
    float3 Lunormalized = light->worldSpacePosition.xyz - worldSpacePosition;
    float3 L = normalize(Lunormalized);
    float sqrDist = dot(Lunormalized, Lunormalized);
    
    float NdotL = dot(N, L);
    
    float illuminance;
    if (light->lightTypeFlag == LightTypeSphereArea) {
        illuminance = calculateSphereIlluminance(worldSpacePosition, NdotL, sqrDist, light);
    } else {
        illuminance = calculateDiskIlluminance(worldSpacePosition, NdotL, sqrDist, L, light);
    }
    
    NdotL = saturate(NdotL);
    
    L = getSpecularDominantDirArea(N, L, NdotV, linearRoughness * linearRoughness);
    
    float3 lightColour = light->colourAndIntensity.xyz * light->colourAndIntensity.w;
    
    return BRDF(V, L, N, NdotV, NdotL, albedo, f0, f90, linearRoughness) * illuminance * lightColour;
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
        case LightTypeSphereArea:
        case LightTypeDiskArea:
            return evaluateAreaLight(worldSpacePosition, V, N, NdotV, albedo, f0, f90, linearRoughness, light);
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
                           uint gBuffer0, float4 gBuffer1, float4 gBuffer2, float4 gBuffer3, float gBufferDepth,
                             __global LightData *lights, int lightCount, float2 u, float16 cameraToWorldMatrix);

float3 lightAccumulationPass(float4 nearPlaneAndProjectionTerms,
                             uint gBuffer0, float4 gBuffer1, float4 gBuffer2, float4 gBuffer3, float gBufferDepth,
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
    
    lightAccumulation += gBuffer3.xyz;
    
    float3 epilogue = epilogueLighting(lightAccumulation, 1.f);
        
    return epilogue;
}