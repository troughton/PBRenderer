#define LightTypePoint 0
#define LightTypeDirectional 1
#define LightTypeSpot 2
#define LightTypeSphereArea 3
#define LightTypeDiskArea 4
#define LightTypeTubeArea 5

#include "Utilities.glsl"
#include "BRDF.glsl"

layout(std140) struct LightData {
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

float calculateTubeIlluminance(vec3 N, vec3 Lunormalized, LightData light, float lightLength) {
    vec3 L01 = light.worldSpaceDirection.xyz * lightLength;
    vec3 ToLight0 = Lunormalized - 0.5 * L01;
    vec3 ToLight1 = Lunormalized + 0.5 * L01;

    float LengthSqr0 = dot( ToLight0, ToLight0 );
    float LengthSqr1 = dot( ToLight1, ToLight1 );
    float rLength0 = inversesqrt( LengthSqr0 );
    float rLength1 = inversesqrt( LengthSqr1 );
    float Length0 = LengthSqr0 * rLength0;
    float Length1 = LengthSqr0 * rLength0;

//    DistanceAttenuation = rcp( ( Length0 * Length1 + dot( ToLight0, ToLight1 ) ) * 0.5 + 1 );
    return saturate( 0.5 * ( dot(N, ToLight0) * rLength0 + dot(N, ToLight1) * rLength1 ) );
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
    float lightLength = light.extraData.y;
    
    float NdotL = saturate(dot(N, L));
    
    float illuminance;
    if (light.lightTypeFlag == LightTypeSphereArea) {
        illuminance = calculateSphereIlluminance(worldSpacePosition, NdotL, sqrDist, light);
    } else if (light.lightTypeFlag == LightTypeDiskArea) {
        illuminance = calculateDiskIlluminance(worldSpacePosition, NdotL, sqrDist, L, light);
    } else if (light.lightTypeFlag == LightTypeTubeArea) {
        illuminance = calculateTubeIlluminance(N, Lunormalized, light, lightLength);
    }
    
    illuminance *= smoothDistanceAtt(sqrDist, light.inverseSquareAttenuationRadius);
    
    float lobeEnergy = 1;
    float alpha = sqr(material.roughness);
    
    float sphereAngle = saturate( lightRadius * inverseDistanceToLight);
    lobeEnergy *= sqr( alpha / saturate( alpha + 0.5 * sphereAngle ) );

    V = normalize(V);
    N = normalize(N);
    vec3 R = reflect(-V, N);
    R = getSpecularDominantDirArea(N, R, NdotV, material.roughness);
    
    if (lightLength > 1) { // for tube lights (at the moment)
        // Closest point on line segment to ray
        vec3 L01 = light.worldSpaceDirection.xyz * lightLength;
        vec3 L0 = Lunormalized - 0.5 * L01;
        vec3 L1 = Lunormalized + 0.5 * L01;
        
        // Shortest distance
        float a = sqr(lightLength);
        float b = dot( R, L01 );
        float t = saturate( dot( L0, b*R - L01 ) / (a - b*b) );
        
        L = L0 + t * L01;
        return vec3(0);
    }
   
    vec3 closestPointOnRay = dot(Lunormalized, R) * R;
    vec3 centreToRay = closestPointOnRay - Lunormalized;
    vec3 closestPointOnSphere = Lunormalized + centreToRay * saturate(lightRadius * inversesqrt(dot(centreToRay, centreToRay)));
    
    L = normalize(closestPointOnSphere);
    NdotL = saturate(dot(N, L));
    
    vec3 specular = BRDFSpecular(V, L, N, NdotV, NdotL, material);
    vec3 diffuse = BRDFDiffuse(V, L, N, NdotV, NdotL, material);
    
    vec3 lightColour = light.colourAndIntensity.xyz * light.colourAndIntensity.w;
    
    return (diffuse + specular) * illuminance * lightColour;
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
            break;
        case LightTypeSphereArea:
        case LightTypeDiskArea:
        case LightTypeTubeArea:
            return evaluateAreaLight(worldSpacePosition, V, N, NdotV, material, light);
            break;
        default:
            return vec3(0);
            break;
    }
    
}
