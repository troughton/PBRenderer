uniform sampler2D dfg; //constant term for light probe parametised on (NdotV, roughness)
uniform samplerCube diffuseLD; //per-probe integrated light for diffuse reflection
uniform samplerCube specularLD; //per-probe integrated light for specular reflection. Mip-levels map to different roughness values.
uniform int ldMipMaxLevel;

/**************************************
 * Light probe texture-based sampling *
 *************************************/

// N is the normal direction
// R is the mirror vector
vec3 getSpecularDominantDir(vec3 N, vec3 R, float roughness) {
    float smoothness = saturate(1 - roughness);
    float lerpFactor = smoothness * (sqrt(smoothness) + roughness);
    // The result is not normalized as we fetch into a cubemap
    return mix(N, R, lerpFactor);
}

// N is the normal direction
// V is the view vector
// NdotV is the cosine angle between the view vector and the normal
vec3 getDiffuseDominantDir(vec3 N, vec3 V, float NdotV, float roughness) {
    float a = 1.02341f * roughness - 1.51174f;
    float b = -0.511705f * roughness + 0.755868f;
    float lerpFactor = saturate((NdotV * a + b) * roughness);
    // The result is not normalized as we fetch into a cubemap
    return mix(N, V, lerpFactor);
}

vec4 evaluateIBLDiffuse(vec3 N, vec3 V, float NdotV, float roughness) {
    vec3 dominantN = getDiffuseDominantDir(N, V, NdotV, roughness);
    vec4 diffuseLighting = texture(diffuseLD, dominantN);
    
    float diffF = texture(dfg, vec2(NdotV, roughness)).z;
    return vec4(diffuseLighting.rgb * diffF, diffuseLighting.a);
}

float linearRoughnessToMipLevel(float linearRoughness, int mipCount) {
    return (sqrt(linearRoughness) * mipCount);
}

const int DFG_TEXTURE_SIZE = 128;

vec4 evaluateIBLSpecular(vec3 N, vec3 R, float NdotV, float linearRoughness, float roughness, vec3 f0, float f90) {
    vec3 dominantR = getSpecularDominantDir(N, R, roughness);
    
    // Rebuild the function
    // L . D. ( f0.Gv.(1-Fc) + Gv.Fc ) . cosTheta / (4 . NdotL . NdotV)
    NdotV = max(NdotV, 0.5f/DFG_TEXTURE_SIZE);
    float mipLevel = linearRoughnessToMipLevel(linearRoughness, ldMipMaxLevel);
    
    vec4 preLD = textureLod(specularLD, dominantR, mipLevel);
    
    // Sample pre-integrated DFG
    // Fc = (1-H.L)^5
    // PreIntegratedDFG.r = Gv.(1-Fc)
    // PreIntegratedDFG.g = Gv.Fc
    
    vec2 preDFG = texture(dfg, vec2(NdotV, roughness)).xy;
    
    // LD . ( f0.Gv.(1-Fc) + Gv.Fc.f90 )
    return vec4((f0 * preDFG.x + vec3(f90) * preDFG.y) * preLD.rgb, preLD.a);
}

////Parallax correction for reflections in a local light probe.
////https://seblagarde.wordpress.com/2012/09/29/image-based-lighting-approaches-and-parallax-corrected-cubemap/
//vec3 reflectionDirectionForLocalLightProbe(vec4 worldSpacePosition, vec3 worldSpaceReflectionDirection, mat4 cubeMapVolumeWorldToLocal, vec3 cubeMapPositionWS, float linearRoughness,
//                                           out float distIntersectionToShadedPoint,
//                                           out float distIntersectionToProbeCentre) {
//    vec3 rayLS = mat3(cubeMapVolumeWorldToLocal) * worldSpaceReflectionDirection;
//    vec3 positionLS = (cubeMapVolumeWorldToLocal * worldSpacePosition).xyz;
//    
//    vec3 unitary = vec3(1.f);
//    vec3 firstPlaneIntersect = (unitary - positionLS) / rayLS;
//    vec3 secondPlaneIntersect = (-unitary - positionLS) / rayLS;
//    
//    vec3 furthestPlane = max(firstPlaneIntersect, secondPlaneIntersect);
//    float dist = min(furthestPlane.x, min(furthestPlane.y, furthestPlane.z));
//    
//    vec3 intersectPositionWS = worldSpacePosition + worldSpaceReflectionDirection * dist;
//    vec3 reflectionDirectionWS = intersectPositionWS - cubeMapPositionWS;
//    
//    distIntersectionToShadedPoint = dist;
//    distIntersectionToProbeCentre = distance(intersectPositionWS, cubeMapPositionWS);
//    
//    return mix(reflectionDirectionWS, worldSpaceReflectionDirection, linearRoughness);
//}
//
//float computeDistanceBasedLinearRoughness(
//                                   float distIntersectionToShadedPoint,
//                                   float distIntersectionToProbeCenter,
//                                   float linearRoughness) {
//    // To avoid artifacts we clamp to the original linearRoughness
//    // which introduces an acceptable bias and allows conservation
//    // of mirror reflection behavior for a smooth surface.
//    float newLinearRoughness = clamp(distIntersectionToShadedPoint /
//                                       distIntersectionToProbeCenter * linearRoughness, 0, linearRoughness);
//    return mix(newLinearRoughness, linearRoughness, linearRoughness);
//}
//
//struct LightProbe {
//    mat4 boundingVolumeWorldToLocal;
//    vec4 cubeMapPosition;
//    int isEnvironmentMap;
//    int padding;
//    int padding2;
//    int padding3;
//}
//
//void evaluateLightProbe(vec3 N, vec3 V, float NdotV, vec3 R, MaterialRenderingData material, LightProbe lightProbe) {
//    
//    if (useEnvironmentMap) {
//        
//        vec3 result = evaluateIBLDiffuse(N, V, NdotV, material.roughness) * material.albedo;
//        result += evaluateIBLSpecular(N, R, NdotV, material.linearRoughness, material.roughness, material.f0, material.f90);
//        return result;
//        
//    } else {
//        return vec3(0);
//    }
//}
//
//
//
//#define MaxLightProbeCount 64
//
//layout(std140) uniform LightProbe lightProbes[MaxLightProbeCount];
//
//vec3 evaluateIBL(vec3 worldSpacePosition, vec3 N, vec3 V, float NdotV, vec3 R, MaterialRenderingData material, int lightProbeIndices[MaxLightProbeCount + 1]) {
//    vec4 total = vec4(0);
//    
//    int lightProbeCount = lightProbeIndices[0];
//    // Medium range reflections
//    for (int i = 0; i < lightProbeCount && total.a < 1.0; i++) {
//        LightProbe probe = lightProbes[i + 1];
//        
//        vec4 evaluationResult = evaluateLightProbe(N, V, NdotV, R, material, probe);
//        float alpha = saturate(
//        
//    }
//    
//    While local light probes And Alpha < 1 do Evaluate local light probe
//        a = saturate(localLightProbe.a - Alpha) RGB += localLightProbe.rgb * a
//        Alpha = saturate(a + Alpha)
//        // Large range reflections
//        If Alpha < 1 Then
//        Evaluate distant light probe
//        RGB += distantLightProbe.rgb * (1-Alpha)
//    
//}

