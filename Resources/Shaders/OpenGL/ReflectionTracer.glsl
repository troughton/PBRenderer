////http://casual-effects.blogspot.co.nz/2014/08/screen-space-ray-tracing.html
////http://roar11.com/2015/07/screen-space-glossy-reflections/
//
//// By Morgan McGuire and Michael Mara at Williams College 2014
//// Released as open source under the BSD 2-Clause License
//// http://opensource.org/licenses/BSD-2-Clause
//
////This should take place in the light accumulation pass. If there's no result, then we want to blend in the results from the light probes that take place in the GBuffer creation pass  we can do this using alpha blending. i.e. output the reflection ray visibility in the alpha channel of the light accumulation buffer, and then set the blend mode to be (src * (1 - dstAlpha) + dst). We still calculate the light probes' contribution at GBuffer creation, since this will hopefully be more-or-less free (i.e. the ALU units aren't doing much during all the geometry processing).

// N is the normal direction
// R is the mirror vector
vec3 getSpecularDominantDir(vec3 N, vec3 R, float roughness) {
    float smoothness = saturate(1 - roughness);
    float lerpFactor = smoothness * (sqrt(smoothness) + roughness);
    return mix(N, R, lerpFactor);
}

uniform mat4 cameraToPixelClipMatrix;
uniform vec2 depthBufferSize;

const float reflectionTraceMaxSteps = 20.f; // Maximum number of iterations. Higher gives better images but may be slow.
uniform float reflectionTraceMaxDistance; // Maximum camera-space distance to trace before returning a miss.
const float reflectionTraceStrideZCutoff = 0.2f; // More distant pixels are smaller in screen space. This value tells at what point to start relaxing the stride to give higher quality reflections for objects far from the camera.
const float reflectionTraceZThickness = 0.1f; // Camera space thickness to ascribe to each pixel in the depth buffer
const float reflectionTraceStride = 1.f; // Step in horizontal or vertical pixels between samples. This is a float
// because integer math is slow on GPUs, but should be set to an integer >= 1.

float distanceSquared(vec2 a, vec2 b) { a -= b; return dot(a, a); }

bool intersectsDepthBuffer(float z, float minZ, float maxZ) {
    /*
     * Based on how far away from the camera the depth is,
     * adding a bit of extra thickness can help improve some
     * artifacts. Driving this value up too high can cause
     * artifacts of its own.
     */
    float depthScale = min(1.0f, z * reflectionTraceStrideZCutoff);
    z += reflectionTraceZThickness + mix(0.0f, 2.0f, depthScale);
    return (maxZ >= z) && (minZ - reflectionTraceZThickness <= z);
}

void swap(inout float a, inout float b)
{
    float t = a;
    a = b;
    b = t;
}

float linearDepthTexelFetch(ivec2 hitPixel) {
    // Load returns 0 for any value accessed out of bounds
    
    float windowZ = texelFetch(gBufferDepthTexture, hitPixel, 0).r;
    float linearDepth = -projectionTerms.y / (windowZ - projectionTerms.x);
    return linearDepth;
}

// Returns true if the ray hit something
// Assumes negative depth.
bool traceScreenSpaceRay(
                          // Camera-space ray origin, which must be within the view volume
                          vec3 csOrig,

                          // Unit length camera-space ray direction
                          vec3 csDir,

                          // Number between 0 and 1 for how far to bump the ray in stride units
                          // to conceal banding artifacts
                          float jitter,

                          // Pixel coordinates of the first intersection with the scene
                          out vec2 hitPixel) {

    // Clip to the near plane
    float rayLength = ((csOrig.z + csDir.z * reflectionTraceMaxDistance) > cameraNearFar.x) ?
    (cameraNearFar.x - csOrig.z) / csDir.z : reflectionTraceMaxDistance;
    vec3 csEndPoint = csOrig + csDir * rayLength;

    // Project into homogeneous clip space
    vec4 H0 = cameraToPixelClipMatrix * vec4(csOrig, 1.0);
    vec4 H1 = cameraToPixelClipMatrix * vec4(csEndPoint, 1.0);
    float k0 = 1.0 / H0.w, k1 = 1.0 / H1.w;

    // The interpolated homogeneous version of the camera-space points
    vec3 Q0 = csOrig * k0, Q1 = csEndPoint * k1;

    // Screen-space endpoints
    vec2 P0 = H0.xy * k0, P1 = H1.xy * k1;

    // If the line is degenerate, make it cover at least one pixel
    // to avoid handling zero-pixel extent as a special case later
    P1 += vec2((distanceSquared(P0, P1) < 0.0001) ? 0.01 : 0.0);
    vec2 delta = P1 - P0;

    // Permute so that the primary iteration is in x to collapse
    // all quadrant-specific DDA cases later
    bool permute = false;
    if (abs(delta.x) < abs(delta.y)) {
        // This is a more-vertical line
        permute = true;
        delta = delta.yx;
        P0 = P0.yx;
        P1 = P1.yx;
    }

    float stepDir = sign(delta.x);
    float invdx = stepDir / delta.x;

    // Track the derivatives of Q and k
    vec3  dQ = (Q1 - Q0) * invdx;
    float dk = (k1 - k0) * invdx;
    vec2  dP = vec2(stepDir, delta.y * invdx);

    // Scale derivatives by the desired pixel stride and then
    // offset the starting values by the jitter fraction
  //  float strideScale = 1.0f - min(1.0f, csOrig.z * reflectionTraceStrideZCutoff);
    float stride = reflectionTraceStride; //1.0f + strideScale * reflectionTraceStride;
    dP *= stride;
    dQ *= stride;
    dk *= stride;

    P0 += dP * jitter;
    Q0 += dQ * jitter;
    k0 += dk * jitter;


    // Slide P from P0 to P1, (now-homogeneous) Q from Q0 to Q1, k from k0 to k1
//    vec4 PQk = vec4(P0, Q0.z, k0);
//    vec4 dPQk = vec4(dP, dQ.z, dk);
    vec3 Q = Q0;

    // Adjust end condition for iteration direction
    float  end = P1.x * stepDir;

    float k = k0;
    float stepCount = 0.0f;
    float prevZMaxEstimate = csOrig.z;
    float rayZMin = prevZMaxEstimate;
    float rayZMax = prevZMaxEstimate;
    float sceneZMax = rayZMax + 100.0f;
    for(vec2 P = P0;
         ((P.x * stepDir) <= end) &&
         (stepCount < reflectionTraceMaxSteps) &&
        ((rayZMax < sceneZMax - reflectionTraceZThickness) || (rayZMin > sceneZMax))
        && (sceneZMax != 0.0f);
         P += dP, Q.z += dQ.z, k += dk, ++stepCount)
        {
            rayZMin = prevZMaxEstimate;
            rayZMax = (dQ.z * 0.5f + Q.z) / (dk * 0.5f + k);
            prevZMaxEstimate = rayZMax;
            if (rayZMin > rayZMax) {
                float t = rayZMin; rayZMin = rayZMax; rayZMax = t;
                //swap(rayZMin, rayZMax);
            }

            hitPixel = permute ? P.yx : P;
            // You may need hitPixel.y = depthBufferSize.y - hitPixel.y; here if your vertical axis
            // is different than ours in screen space
            sceneZMax = linearDepthTexelFetch(ivec2(hitPixel));
        }

    // Advance Q based on the number of steps
    Q.xy += dQ.xy * stepCount;
    return (rayZMax >= sceneZMax - reflectionTraceZThickness) && (rayZMin < sceneZMax);// intersectsDepthBuffer(sceneZMax, rayZMin, rayZMax);
}

vec4 traceReflection(vec3 cameraSpacePosition, vec3 normalVS, float roughness) {
    
    /** Since position is reconstructed in view space, just normalise it to get the vector from the eye to the position and then reflect that around the normal to get the ray direction to trace. */
    vec3 V = normalize(cameraSpacePosition);
    vec3 R = reflect(V, normalVS);
    vec3 rayDirectionVS = normalize(getSpecularDominantDir(normalVS, R, roughness));
    
    // output rDotV to the alpha channel for use in determining how much to fade the ray
    float rDotV = dot(rayDirectionVS, V);
    
    // out parameters
    vec2 hitPixel = vec2(0.0f, 0.0f);
    
    float jitter = reflectionTraceStride > 1.0f ? float(int(uv.x * 2 + uv.y * 2 - 2) & 1) * 0.5f : 0.0f;
    
    // perform ray tracing - true if hit found, false otherwise
    bool intersection = traceScreenSpaceRay(cameraSpacePosition, rayDirectionVS, jitter, hitPixel);
    
    float depth = texelFetch(gBufferDepthTexture, ivec2(hitPixel), 0).r;
    
    // move hit pixel from pixel position to UVs
    hitPixel /= depthBufferSize;
    if(hitPixel.x > 1.0f || hitPixel.x < 0.0f || hitPixel.y > 1.0f || hitPixel.y < 0.0f){
        intersection = false;
    }
    
    return vec4(hitPixel, depth, rDotV) * (intersection ? 1.0f : 0.0f);
}
