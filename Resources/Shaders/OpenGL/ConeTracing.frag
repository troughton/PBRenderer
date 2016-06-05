#version 410

#include "Utilities.glsl"
#include "Encoding.glsl"
#include "MaterialData.glsl"
#include "BRDF.glsl"

uniform sampler2D lightAccumulationBuffer; // convolved color buffer - all mip levels
uniform sampler2D rayTracingBuffer; // ray-tracing buffer

uniform usampler2D gBuffer0Texture;
uniform sampler2D gBuffer1Texture;
uniform sampler2D gBuffer2Texture;
uniform sampler2D gBufferDepthTexture;

uniform mat4 worldToCameraMatrix;

in vec3 cameraDirection;
in vec2 uv;

uniform vec2 projectionTerms;
uniform vec2 nearPlane;
uniform vec2 depthBufferSize;
uniform int mipCount;
uniform float reflectionTraceMaxDistance;
const float cb_fadeStart = 0.9f;// determines where to start screen edge fading off effect
const float cb_fadeEnd = 0.98f; // determines where to end screen edge fading off effect


vec4 calculateCameraSpacePositionFromWindowZ(float windowZ,
                                             vec3 cameraDirection,
                                             vec2 projectionTerms) {
    
    float linearDepth = projectionTerms.y / (windowZ - projectionTerms.x);
    return vec4(cameraDirection * linearDepth, 1);
}

vec3 viewSpacePositionFromDepth(vec2 uv, float depth) {
    vec3(nearPlane * ((uv.xy * 2) - 1), -1);
    float linearDepth = projectionTerms.y / (depth - projectionTerms.x);
    return cameraDirection * linearDepth;
    
}

///////////////////////////////////////////////////////////////////////////////////////
// Cone tracing methods
///////////////////////////////////////////////////////////////////////////////////////

float roughnessToConeAngle(float roughness)
{
    
    //Via http://forums.odforce.net/topic/20682-bsdf-bonanza-ggx-microfacets-disney-brdf-and-more/
    float expNumerator = 1.386294361f; //ln(4)
    float expDivisor = 6.f - 4.f / (roughness * roughness * roughness * roughness);
    float cosTheta = exp(expNumerator / expDivisor);
    
    float theta = saturate(fast_acos(cosTheta));
    
    return theta;
}

float isoscelesTriangleOpposite(float adjacentLength, float coneTheta)
{
    // simple trig and algebra - soh, cah, toa - tan(theta) = opp/adj, opp = tan(theta) * adj, then multiply * 2.0f for isosceles triangle base
    return 2.0f * tan(coneTheta) * adjacentLength;
}

float isoscelesTriangleInRadius(float a, float h)
{
    float a2 = a * a;
    float fh2 = 4.0f * h * h;
    return (a * (sqrt(a2 + fh2) - a)) / (4.0f * h);
}

vec4 coneSampleWeightedColor(vec2 samplePos, float mipChannel, float gloss)
{
    vec3 sampleColor = textureLod(lightAccumulationBuffer, samplePos, mipChannel).rgb;
    return vec4(sampleColor * gloss, gloss);
}

float isoscelesTriangleNextAdjacent(float adjacentLength, float incircleRadius)
{
    // subtract the diameter of the incircle to get the adjacent side of the next level on the cone
    return adjacentLength - (incircleRadius * 2.0f);
}

///////////////////////////////////////////////////////////////////////////////////////

out vec4 blendedColour;

vec4 calculateScreenSpaceReflection(vec3 cameraSpacePosition, vec3 cameraSpaceNormal, MaterialRenderingData material) {
    // get screen-space ray intersection point
    vec4 raySS = texelFetch( rayTracingBuffer, ivec2(gl_FragCoord.xy), 0).xyzw;
    if(raySS.w <= 0.0f) // either means no hit or the ray faces back towards the camera
    {
        // no data for this point - a fallback like localized environment maps should be used
        return vec4(0);
    }
    
    vec3 positionVS = cameraSpacePosition;
    // since calculations are in view-space, we can just normalize the position to point at it
    vec3 toPositionVS = normalize(positionVS);
    vec3 normalVS = cameraSpaceNormal;
    
    // get specular power from roughness
    float gloss = 1 - material.linearRoughness;
    
    // convert to cone angle (maximum extent of the specular lobe aperture)
    // only want half the full cone angle since we're slicing the isosceles triangle in half to get a right triangle
    float coneTheta = roughnessToConeAngle(material.roughness) * 0.5f;
    
    // P1 = positionSS, P2 = raySS, adjacent length = ||P2 - P1||
    vec2 deltaP = raySS.xy - uv.xy;
    float adjacentLength = length(deltaP);
    vec2 adjacentUnit = normalize(deltaP);
    
    vec4 totalColor = vec4(0.0f, 0.0f, 0.0f, 0.0f);
    float remainingAlpha = 1.0f;
    float maxMipLevel = float(mipCount) - 1.0f;
    float glossMult = gloss;
    // cone-tracing using an isosceles triangle to approximate a cone in screen space
    for(int i = 0; i < 14; ++i)
    {
        // intersection length is the adjacent side, get the opposite side using trig
        float oppositeLength = isoscelesTriangleOpposite(adjacentLength, coneTheta);
        
        // calculate in-radius of the isosceles triangle
        float incircleSize = isoscelesTriangleInRadius(oppositeLength, adjacentLength);
        
        // get the sample position in screen space
        vec2 samplePos = uv.xy + adjacentUnit * (adjacentLength - incircleSize);
        
        // convert the in-radius into screen size then check what power N to raise 2 to reach it - that power N becomes mip level to sample from
        float mipChannel = clamp(log2(incircleSize * max(depthBufferSize.x, depthBufferSize.y)), 0.0f, maxMipLevel);
        
        /*
         * Read color and accumulate it using trilinear filtering and weight it.
         * Uses pre-convolved image (color buffer) and glossiness to weigh color contributions.
         * Visibility is accumulated in the alpha channel. Break if visibility is 100% or greater (>= 1.0f).
         */
        vec4 newColor = coneSampleWeightedColor(samplePos, mipChannel, glossMult);
        
        remainingAlpha -= newColor.a;
        if(remainingAlpha < 0.0f)
        {
            newColor.rgb *= (1.0f - abs(remainingAlpha));
        }
        totalColor += newColor;
        
        if(totalColor.a >= 1.0f)
        {
            break;
        }
        
        adjacentLength = isoscelesTriangleNextAdjacent(adjacentLength, incircleSize);
        glossMult *= gloss;
    }
    
    vec3 toEye = -toPositionVS;
    
    // fade rays close to screen edge
    vec2 boundary = abs(raySS.xy - vec2(0.5f, 0.5f)) * 2.0f;
    const float fadeDiffRcp = 1.0f / (cb_fadeEnd - cb_fadeStart);
    float fadeOnBorder = 1.0f - saturate((boundary.x - cb_fadeStart) * fadeDiffRcp);
    fadeOnBorder *= 1.0f - saturate((boundary.y - cb_fadeStart) * fadeDiffRcp);
    fadeOnBorder = smoothstep(0.0f, 1.0f, fadeOnBorder);
    
    vec3 rayHitPositionVS = viewSpacePositionFromDepth(raySS.xy, raySS.z);
    float fadeOnDistance = 1.0f - saturate(distance(rayHitPositionVS, positionVS) / reflectionTraceMaxDistance);
    // ray tracing steps stores rdotv in w component - always > 0 due to check at start of this method
    float fadeOnPerpendicular = saturate(mix(0.0f, 1.0f, saturate(raySS.w * 4.0f)));
    float fadeOnRoughness = saturate(mix(0.0f, 1.0f, gloss * 4.0f));
    float totalFade = fadeOnBorder * fadeOnDistance * fadeOnPerpendicular * fadeOnRoughness * (1.0f - saturate(remainingAlpha));
    
    vec3 specular = F_Schlick(material.f0, material.f90, abs(dot(normalVS, toEye))) * INV_PI;
    
    return vec4(totalColor.rgb * specular * totalFade, 1.0f);
}

void main() {
    
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    
    float gBufferDepth = texelFetch(gBufferDepthTexture, pixelCoord, 0).r;
    uint gBuffer0 = texelFetch(gBuffer0Texture, pixelCoord, 0).r;
    vec4 gBuffer1 = texelFetch(gBuffer1Texture, pixelCoord, 0);
    vec4 gBuffer2 = texelFetch(gBuffer2Texture, pixelCoord, 0);

    vec3 cameraSpacePosition = calculateCameraSpacePositionFromWindowZ(gBufferDepth, cameraDirection, projectionTerms).xyz;
    vec3 N;
    
    MaterialData material = decodeDataFromGBuffers(N, gBuffer0, gBuffer1, gBuffer2);
    MaterialRenderingData renderingMaterial = evaluateMaterialData(material);
    
    N = (worldToCameraMatrix * vec4(N, 0)).xyz;
    
    vec4 lightAccumulation = texelFetch( lightAccumulationBuffer, pixelCoord, 0);
    
    vec4 screenSpaceReflections = calculateScreenSpaceReflection(cameraSpacePosition, N, renderingMaterial);
    
    blendedColour = lightAccumulation + screenSpaceReflections;
}