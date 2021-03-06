#define LightTypePoint 0
#define LightTypeDirectional 1
#define LightTypeSpot 2
#define LightTypeSphereArea 3
#define LightTypeDiskArea 4
#define LightTypeRectangleArea 5
#define LightTypeTriangleArea 6
#define LightTypeSunArea 7

#include "Utilities.glsl"
#include "BRDF.glsl"
#include "LTC.glsl"

uniform sampler2D ltcMaterialGGX;
uniform sampler2D ltcAmplitudeGGX;

uniform sampler2D ltcMaterialDisney;

uniform samplerBuffer lightPoints;

uniform sampler2DShadow shadowMapDepthTexture;

uniform mat4 worldToLightClipMatrix;

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
    
    return normalize(mix(N, R, lerpFactor));
}

float ShadowCalculation(vec3 worldSpacePosition) {
    
    #define EPSILON 0.01
    #define ShadowMapSize 4096.f
    
    vec4 clipSpacePosition = worldToLightClipMatrix * vec4(worldSpacePosition, 1);
    vec3 projCoords = clipSpacePosition.xyz / clipSpacePosition.w;
//    projCoords.y *= -1;
    projCoords = projCoords * 0.5 + 0.5;
    
    float xOffset = 1.0/ShadowMapSize;
    float yOffset = 1.0/ShadowMapSize;
    
    float factor = 0.0;
    
    for (int y = -1 ; y <= 1 ; y++) {
        for (int x = -1 ; x <= 1 ; x++) {
            vec2 offsets = vec2(x * xOffset, y * yOffset);
            vec3 uvC = vec3(projCoords.xy + offsets, projCoords.z - EPSILON);
            factor += texture(shadowMapDepthTexture, uvC);
        }
    }
    
    return factor / 9.f;
}

vec3 evaluateSunArea(vec3 worldSpacePosition, vec3 V, vec3 N, float NdotV, MaterialRenderingData material, LightData light) {
    float sunIlluminanceInLux = light.colourAndIntensity.w;
    vec3 sunDirection = light.worldSpaceDirection.xyz;
    float sunAngularRadius = light.extraData.x;
    
    vec3 D = sunDirection;
    float r = sin(sunAngularRadius);
    float d = cos(sunAngularRadius);
    
    vec3 R = reflect(-V, N);
    
    // closest point to a disk (since radius is small, this is a good approxmation)
    float DdotR = dot(D, R);
    vec3 S = R - DdotR * D;
    vec3 L = DdotR < d ? normalize(d * D + normalize(S) * r) : R;
    
    float NdotD = saturate(dot(N, D));
    float illuminance = sunIlluminanceInLux * NdotD;
    
    float NdotL = dot(N, L);
    
    vec3 specular = BRDFSpecular(V, L, N, NdotV, NdotL, material);
    vec3 diffuse = BRDFDiffuse(V, D, N, NdotV, NdotD, material);
    
    vec3 lightColour = light.colourAndIntensity.xyz;
    
    return (diffuse * material.albedo + specular) * illuminance * lightColour * ShadowCalculation(worldSpacePosition);
}


float illuminanceSphereOrDisk(float cosTheta, float sinSigmaSqr) {
    float sinTheta = sqrt(1.0f - cosTheta * cosTheta);
    
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
    float inverseDistanceToLight = inversesqrt(sqrDist);
    
    float lightRadius = light.extraData.x;
    
    vec3 lightColour = light.colourAndIntensity.xyz * light.colourAndIntensity.w;
    
//    float lobeEnergy = 1;
//    float alpha = sqr(material.roughness);
//    
//    float sphereAngle = saturate( lightRadius * inverseDistanceToLight);
//    lobeEnergy *= sqr( alpha / saturate( alpha + 0.5 * sphereAngle ) );

    V = normalize(V);
    N = normalize(N);
    vec3 R = reflect(-V, N);
    R = getSpecularDominantDirArea(N, R, NdotV, material.roughness);
   
    vec3 closestPointOnRay = dot(Lunormalized, R) * R;
    vec3 centreToRay = closestPointOnRay - Lunormalized;
    vec3 closestPointOnSphere = Lunormalized + centreToRay * saturate(lightRadius * inversesqrt(dot(centreToRay, centreToRay)));
    
    L = normalize(closestPointOnSphere);

    float NdotL = saturate(dot(N, L));
    
    float illuminance;
    if (light.lightTypeFlag == LightTypeSphereArea) {
        illuminance = calculateSphereIlluminance(worldSpacePosition, NdotL, sqrDist, light);
    } else {
        illuminance = calculateDiskIlluminance(worldSpacePosition, NdotL, sqrDist, L, light);
    }

    illuminance *= smoothDistanceAtt(dot(closestPointOnSphere, closestPointOnSphere), light.inverseSquareAttenuationRadius);
    
    vec3 specular = BRDFSpecular(V, L, N, NdotV, NdotL, material);
    vec3 diffuse = BRDFDiffuse(V, L, N, NdotV, NdotL, material);
    
    
    return (diffuse + specular) * illuminance * lightColour;
}


// using LTCs
vec3 evaluatePolygonAreaLight(vec3 worldSpacePosition, vec3 N, vec3 V, vec4 points[4], MaterialRenderingData material, LightData light) {
    
    bool isTwoSided = light.extraData.y != 0;
    
    float cosTheta = dot(N, V);
    
    vec2 ltcUV = LTC_Coords(cosTheta, material.roughness);
    
    mat3 matrixInverseDisney = LTC_Matrix(ltcMaterialDisney, ltcUV);
    vec3 diffuse = LTC_Evaluate(N, V, worldSpacePosition, matrixInverseDisney, points, isTwoSided);
    diffuse *= material.albedo;
    
    
    vec3 lightColour = light.colourAndIntensity.xyz * light.colourAndIntensity.w;
    
#ifdef NoSpecular
    vec3 result = diffuse * lightColour;
    
#else
    mat3 matrixInverseGGX = LTC_Matrix(ltcMaterialGGX, ltcUV);
    vec3 specular = LTC_Evaluate(N, V, worldSpacePosition, matrixInverseGGX, points, isTwoSided);
    vec2 schlick = texture(ltcAmplitudeGGX, ltcUV).xy;
    specular *= material.f0 * schlick.x + (material.f90) * schlick.y;

    vec3 result = (specular + diffuse) * lightColour;
    
#endif
    
    result /= 2.0 * PI;
    
    return result;
}

vec3 evaluateTriangleAreaLight(vec3 worldSpacePosition, vec3 N, vec3 V, MaterialRenderingData material, LightData light) {
    int lightPointsOffset = floatBitsToInt(light.extraData.x);
    
    vec4 lastTwoPoints = texelFetch(lightPoints, lightPointsOffset + 2);
    vec4 points[4] = vec4[4](texelFetch(lightPoints, lightPointsOffset),
                             texelFetch(lightPoints, lightPointsOffset + 1),
                             lastTwoPoints,
                             lastTwoPoints);
    
    return evaluatePolygonAreaLight(worldSpacePosition, N, V, points, material, light);
}

vec3 evaluateRectangleAreaLight(vec3 worldSpacePosition, vec3 N, vec3 V, MaterialRenderingData material, LightData light) {
    int lightPointsOffset = floatBitsToInt(light.extraData.x);
    
    vec4 points[4] = vec4[4](texelFetch(lightPoints, lightPointsOffset),
                             texelFetch(lightPoints, lightPointsOffset + 1),
                             texelFetch(lightPoints, lightPointsOffset + 2),
                             texelFetch(lightPoints, lightPointsOffset + 3));
    
    return evaluatePolygonAreaLight(worldSpacePosition, N, V, points, material, light);
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
            
            vec2 lightAngleScaleAndOffset = light.extraData.xy;
            
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
    
    switch (light.lightTypeFlag) {
        case LightTypePoint:
        case LightTypeDirectional:
        case LightTypeSpot:
            return evaluatePunctualLight(worldSpacePosition, V, N, NdotV, material, light);
        case LightTypeSphereArea:
        case LightTypeDiskArea:
            return evaluateAreaLight(worldSpacePosition, V, N, NdotV, material, light);
        case LightTypeRectangleArea:
            return evaluateRectangleAreaLight(worldSpacePosition, N, V, material, light);
        case LightTypeTriangleArea:
            return evaluateTriangleAreaLight(worldSpacePosition, N, V, material, light);
        case LightTypeSunArea:
            return evaluateSunArea(worldSpacePosition, V, N, NdotV, material, light);
        default:
            return vec3(0);
    }
    
}
