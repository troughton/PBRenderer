#include "Utilities.glsl"

sampler2D depthBuffer;// scene depth buffer used in ray tracing step
sampler2D lightAccumulationBuffer; // convolved color buffer - all mip levels
sampler2D rayTracingBuffer; // ray-tracing buffer

sampler2D indirectSpecularBuffer; // indirect specular light buffer used for fallback

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
    vec3 sampleColor = lightAccumulationBuffer.SampleLevel(sampTrilinearClamp, samplePos, mipChannel).rgb;
    return vec4(sampleColor * gloss, gloss);
}

float isoscelesTriangleNextAdjacent(float adjacentLength, float incircleRadius)
{
    // subtract the diameter of the incircle to get the adjacent side of the next level on the cone
    return adjacentLength - (incircleRadius * 2.0f);
}

///////////////////////////////////////////////////////////////////////////////////////

out vec4 blendedColour;

void main() {
    ivec3 loadIndices = int3(pIn.posH.xy, 0);
    // get screen-space ray intersection point
    vec4 raySS = rayTracingBuffer.Load(loadIndices).xyzw;
    vec3 fallbackColor = indirectSpecularBuffer.Load(loadIndices).rgb;
    if(raySS.w <= 0.0f) // either means no hit or the ray faces back towards the camera
    {
        // no data for this point - a fallback like localized environment maps should be used
        return vec4(fallbackColor, 1.0f);
    }
    float depth = depthBuffer.Load(loadIndices).r;
    vec3 positionSS = vec3(pIn.tex, depth);
    float linearDepth = linearizeDepth(depth);
    vec3 positionVS = pIn.viewRay * linearDepth;
    // since calculations are in view-space, we can just normalize the position to point at it
    vec3 toPositionVS = normalize(positionVS);
    vec3 normalVS = normalBuffer.Load(loadIndices).rgb;
    
    // get specular power from roughness
    vec4 specularAll = specularBuffer.Load(loadIndices);
    float gloss = 1.0f - specularAll.a;
    float specularPower = roughnessToSpecularPower(specularAll.a);
    
    // convert to cone angle (maximum extent of the specular lobe aperture)
    // only want half the full cone angle since we're slicing the isosceles triangle in half to get a right triangle
    float coneTheta = specularPowerToConeAngle(specularPower) * 0.5f;
    
    // P1 = positionSS, P2 = raySS, adjacent length = ||P2 - P1||
    vec2 deltaP = raySS.xy - positionSS.xy;
    float adjacentLength = length(deltaP);
    vec2 adjacentUnit = normalize(deltaP);
    
    vec4 totalColor = vec4(0.0f, 0.0f, 0.0f, 0.0f);
    float remainingAlpha = 1.0f;
    float maxMipLevel = (float)cb_numMips - 1.0f;
    float glossMult = gloss;
    // cone-tracing using an isosceles triangle to approximate a cone in screen space
    for(int i = 0; i < 14; ++i)
    {
        // intersection length is the adjacent side, get the opposite side using trig
        float oppositeLength = isoscelesTriangleOpposite(adjacentLength, coneTheta);
        
        // calculate in-radius of the isosceles triangle
        float incircleSize = isoscelesTriangleInRadius(oppositeLength, adjacentLength);
        
        // get the sample position in screen space
        vec2 samplePos = positionSS.xy + adjacentUnit * (adjacentLength - incircleSize);
        
        // convert the in-radius into screen size then check what power N to raise 2 to reach it - that power N becomes mip level to sample from
        float mipChannel = clamp(log2(incircleSize * max(cb_depthBufferSize.x, cb_depthBufferSize.y)), 0.0f, maxMipLevel);
        
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
    vec3 specular = calculateFresnelTerm(specularAll.rgb, abs(dot(normalVS, toEye))) * CNST_1DIVPI;
    
    // fade rays close to screen edge
    vec2 boundary = abs(raySS.xy - vec2(0.5f, 0.5f)) * 2.0f;
    const float fadeDiffRcp = 1.0f / (cb_fadeEnd - cb_fadeStart);
    float fadeOnBorder = 1.0f - saturate((boundary.x - cb_fadeStart) * fadeDiffRcp);
    fadeOnBorder *= 1.0f - saturate((boundary.y - cb_fadeStart) * fadeDiffRcp);
    fadeOnBorder = smoothstep(0.0f, 1.0f, fadeOnBorder);
    vec3 rayHitPositionVS = viewSpacePositionFromDepth(raySS.xy, raySS.z);
    float fadeOnDistance = 1.0f - saturate(distance(rayHitPositionVS, positionVS) / cb_maxDistance);
    // ray tracing steps stores rdotv in w component - always > 0 due to check at start of this method
    float fadeOnPerpendicular = saturate(lerp(0.0f, 1.0f, saturate(raySS.w * 4.0f)));
    float fadeOnRoughness = saturate(lerp(0.0f, 1.0f, gloss * 4.0f));
    float totalFade = fadeOnBorder * fadeOnDistance * fadeOnPerpendicular * fadeOnRoughness * (1.0f - saturate(remainingAlpha));
    
    blendedColour = vec4(mix(fallbackColor, totalColor.rgb * specular, totalFade), 1.0f);
}