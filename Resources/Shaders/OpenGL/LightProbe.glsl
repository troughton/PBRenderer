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

vec3 evaluateIBLDiffuse(vec3 N, vec3 V, float NdotV, float roughness) {
    vec3 dominantN = getDiffuseDominantDir(N, V, NdotV, roughness);
    vec3 diffuseLighting = texture(diffuseLD, dominantN).rgb;
    
    float diffF = texture(dfg, vec2(NdotV, roughness)).z;
    return diffuseLighting * diffF;
}

float linearRoughnessToMipLevel(float linearRoughness, int mipCount) {
    return (sqrt(linearRoughness) * mipCount);
}

const int DFG_TEXTURE_SIZE = 128;

vec3 evaluateIBLSpecular(vec3 N, vec3 R, float NdotV, float linearRoughness, float roughness, vec3 f0, float f90) {
    vec3 dominantR = getSpecularDominantDir(N, R, roughness);
    
    // Rebuild the function
    // L . D. ( f0.Gv.(1-Fc) + Gv.Fc ) . cosTheta / (4 . NdotL . NdotV)
    NdotV = max(NdotV, 0.5f/DFG_TEXTURE_SIZE);
    float mipLevel = linearRoughnessToMipLevel(linearRoughness, ldMipMaxLevel);
    
    vec3 preLD = textureLod(specularLD, dominantR, mipLevel).rgb;
    
    // Sample pre-integrated DFG
    // Fc = (1-H.L)^5
    // PreIntegratedDFG.r = Gv.(1-Fc)
    // PreIntegratedDFG.g = Gv.Fc
    
    vec2 preDFG = texture(dfg, vec2(NdotV, roughness)).xy;
    
    // LD . ( f0.Gv.(1-Fc) + Gv.Fc.f90 )
    return (f0 * preDFG.x + vec3(f90) * preDFG.y) * preLD;
}

