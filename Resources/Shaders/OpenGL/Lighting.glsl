#define LightTypePoint 0
#define LightTypeDirectional 1
#define LightTypeSpot 2
#define LightTypeSphereArea 3
#define LightTypeDiskArea 4

#include "Utilities.glsl"
#include "BRDF.glsl"

struct LightData {
    vec4 colourAndIntensity;
    vec4 worldSpacePosition;
    vec4 worldSpaceDirection;
    vec4 extraData;
    uint lightTypeFlag;
    float inverseSquareAttenuationRadius;
    vec2 padding;
};

float smoothDistanceAtt(float squaredDistance, float invSqrAttRadius) {
    float factor = squaredDistance * invSqrAttRadius;
    float smoothFactor = saturate(1.0f - factor * factor);
    return smoothFactor * smoothFactor;
}

float getDistanceAtt(vec3 unnormalizedLightVector, float invSqrAttRadius) {
    float sqrDist = dot(unnormalizedLightVector, unnormalizedLightVector);
    float attenuation = 1.f / max(sqrDist, 0.0001f);
    attenuation *= smoothDistanceAtt(sqrDist, invSqrAttRadius);
    
    return attenuation;
}

float getAngleAtt(vec3 normalizedLightVector, vec3 lightDir, float lightAngleScale, float lightAngleOffset) {
    // On the CPU
    // float lightAngleScale = 1.0f / max(0.001f, (cosInner - cosOuter));
    // float lightAngleOffset = -cosOuter * angleScale;
    
    float cd = dot(lightDir, normalizedLightVector);
    float attenuation = saturate(cd * lightAngleScale + lightAngleOffset);
    // smooth the transition
    attenuation *= attenuation;
    
    return attenuation;
}

vec3 getSpecularDominantDirArea(vec3 N, vec3 R, float NdotV, float roughness) {
    // Simple linear approximation
    float lerpFactor = (1 - roughness);
    
    return native_normalize(mix(N, R, lerpFactor));
}

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
        float x = sqrt(1.0f / sinSigmaSqr - 1.0f); // For a disk this simplify to x = d / r
        float y = -x * (cosTheta / sinTheta);
        float sinThetaSqrtY = sinTheta * sqrt(1.0f - y * y);
        illuminance = (cosTheta * fast_acos(y) - x * sinThetaSqrtY) * sinSigmaSqr + fast_atan(sinThetaSqrtY / x);
    }
    
    return max(illuminance, 0.0f);
}

float calculateDiskIlluminance(vec3 worldSpacePosition, float NdotL, float sqrDist, vec3 L, LightData light) {
    // Disk evaluation
    float cosTheta = NdotL;
    
    float lightRadius = light.extraData.x;
    float sqrLightRadius = lightRadius * lightRadius;
    // Do not let the surface penetrate the light
    float sinSigmaSqr = sqrLightRadius / (sqrLightRadius + max(sqrLightRadius, sqrDist));
    // Multiply by saturate(dot(planeNormal, -L)) to better match ground truth.
    float illuminance = illuminanceSphereOrDisk(cosTheta, sinSigmaSqr) * saturate(dot(light.worldSpaceDirection.xyz, -L));
    
    return illuminance;
}

float calculateSphereIlluminance(vec3 worldSpacePosition, float NdotL, float sqrDist, LightData light) {
    float cosTheta = clamp(NdotL, -0.999f, 0.999f); // Clamp to avoid edge case
    // We need to prevent the object penetrating into the surface
    // and we must avoid divide by 0, thus the 0.9999f
    
    float lightRadius = light.extraData.x;
    float sqrLightRadius = lightRadius * lightRadius;
    float sinSigmaSqr = min((sqrLightRadius / sqrDist), 0.9999f);
    
    return illuminanceSphereOrDisk(cosTheta, sinSigmaSqr);
}


vec3 evaluateAreaLight(vec3 worldSpacePosition,
                         vec3 V, vec3 N, float NdotV,
                         MaterialRenderingData material,
                         LightData light) {
    vec3 Lunormalized = light.worldSpacePosition.xyz - worldSpacePosition;
    vec3 L = normalize(Lunormalized);
    float sqrDist = dot(Lunormalized, Lunormalized);
    
    float NdotL = dot(N, L);
    
    float illuminance;
    if (light.lightTypeFlag == LightTypeSphereArea) {
        illuminance = calculateSphereIlluminance(worldSpacePosition, NdotL, sqrDist, light);
    } else {
        illuminance = calculateDiskIlluminance(worldSpacePosition, NdotL, sqrDist, L, light);
    }
    
    NdotL = saturate(NdotL);
    
    L = getSpecularDominantDirArea(N, L, NdotV, material.roughness);
    
    vec3 lightColour = light.colourAndIntensity.xyz * light.colourAndIntensity.w;
    
    return BRDF(V, L, N, NdotV, NdotL, material) * illuminance * lightColour;
}

vec3 evaluatePunctualLight(vec3 worldSpacePosition,
                             vec3 V, vec3 N, float NdotV,
                             MaterialRenderingData material,
                             LightData light) {
    
    vec4 lightPositionWorld = light.worldSpacePosition;
    vec3 lightDirectionWorld = light.worldSpaceDirection.xyz;
    
    vec3 unnormalizedLightVector;
    vec3 L;
    float attenuation = 1;
    
    if (light.lightTypeFlag == LightTypeDirectional) {
        unnormalizedLightVector = lightDirectionWorld.xyz;
        L = normalize(unnormalizedLightVector);
    } else {
        unnormalizedLightVector = lightPositionWorld.xyz - worldSpacePosition;
        L = normalize(unnormalizedLightVector);
        
        attenuation *= getDistanceAtt(unnormalizedLightVector, light.inverseSquareAttenuationRadius);
        
        if (light.lightTypeFlag == LightTypeSpot) {
            
            float2 lightAngleScaleAndOffset = light.extraData.xy;
            
            attenuation *= getAngleAtt(L, lightDirectionWorld, lightAngleScaleAndOffset.x, lightAngleScaleAndOffset.y);
        }
    }
    
    vec3 lightColour = light.colourAndIntensity.xyz * light.colourAndIntensity.w;
    
    float NdotL = saturate(dot(N, L));
    
    // lightColor is the outgoing luminance of the light times the user light color
    // i.e with point light and luminous power unit: lightColor = color * phi / (4 * PI)
    vec3 luminance = BRDF(V, L, N, NdotV, NdotL, material) * NdotL * lightColour * attenuation;
    
    return luminance;
}

vec3 evaluateLighting(vec3 worldSpacePosition,
                        vec3 V, vec3 N, float NdotV,
                        MaterialRenderingData material,
                        LightData light) {
    switch (light->lightTypeFlag) {
        case LightTypePoint:
        case LightTypeDirectional:
        case LightTypeSpot:
            return evaluatePunctualLight(worldSpacePosition, V, N, NdotV, material, light);
            break;
        case LightTypeSphereArea:
        case LightTypeDiskArea:
            return evaluateAreaLight(worldSpacePosition, V, N, NdotV, material, light);
            break;
        default:
            return vec3(0);
            break;
    }
    
}
