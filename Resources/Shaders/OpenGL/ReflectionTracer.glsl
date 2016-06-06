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
    // Simple linear approximation
    float lerpFactor = (1 - roughness);
    
    return normalize(mix(N, R, lerpFactor));
}

uniform mat4 cameraToPixelClipMatrix;
uniform vec2 depthBufferSize;

const float reflectionTraceMaxSteps = 200.f; // Maximum number of iterations. Higher gives better images but may be slow.
uniform float reflectionTraceMaxDistance; // Maximum camera-space distance to trace before returning a miss.
const float reflectionTraceStrideZCutoff = 0.2f; // More distant pixels are smaller in screen space. This value tells at what point to start relaxing the stride to give higher quality reflections for objects far from the camera.
const float reflectionTraceZThickness = 0.2f; // Camera space thickness to ascribe to each pixel in the depth buffer
const float reflectionTraceStride = 1.f; // Step in horizontal or vertical pixels between samples. This is a float
// because integer math is slow on GPUs, but should be set to an integer >= 1.

float distanceSquared(vec2 a, vec2 b) { a -= b; return dot(a, a); }

void swap(inout float a, inout float b) {
    float t = a;
    a = b;
    b = t;
}

float linearDepthTexelFetch(ivec2 hitPixel) {
    // Load returns 0 for any value accessed out of bounds
    if (hitPixel.x > depthBufferSize.x || hitPixel.y > depthBufferSize.y || hitPixel.x < 0 || hitPixel.y < 0) {
        return 0;
    }
    
    float windowZ = texelFetch(gBufferDepthTexture, hitPixel, 0).r;
    float linearDepth = -projectionTerms.y / (windowZ - projectionTerms.x);
    return linearDepth;
}

// Returns true if the ray hit something
// Assumes negative depth.
bool traceScreenSpaceRay(
                          // Camera-space ray origin, which must be within the view volume
                          vec3 csOrigin,

                          // Unit length camera-space ray direction
                          vec3 csDirection,

                          // Number between 0 and 1 for how far to bump the ray in stride units
                          // to conceal banding artifacts
                          float jitterFraction,

                          // Pixel coordinates of the first intersection with the scene
                          out vec2 hitPixel,
                         
                         //Camera space position of the hit position
                         out vec3 csHitPoint,
                         out vec3 debugColour) {

    vec3 debugColor = vec3(0);
    // Clip ray to a near plane in 3D (doesn't have to be *the* near plane, although that would be a good idea)
    float rayLength = ((csOrigin.z + csDirection.z * reflectionTraceMaxDistance) > -cameraNearFar.x) ?
    (-cameraNearFar.x - csOrigin.z) / csDirection.z :
    reflectionTraceMaxDistance;
    vec3 csEndPoint = csDirection * rayLength + csOrigin;
    
    // Project into screen space
    vec4 H0 = cameraToPixelClipMatrix * vec4(csOrigin, 1.0);
    vec4 H1 = cameraToPixelClipMatrix * vec4(csEndPoint, 1.0);
    
    // There are a lot of divisions by w that can be turned into multiplications
    // at some minor precision loss...and we need to interpolate these 1/w values
    // anyway.
    //
    // Because the caller was required to clip to the near plane,
    // this homogeneous division (projecting from 4D to 2D) is guaranteed
    // to succeed.
    float k0 = 1.0 / H0.w;
    float k1 = 1.0 / H1.w;
    
    // Switch the original points to values that interpolate linearly in 2D
    vec3 Q0 = csOrigin * k0;
    vec3 Q1 = csEndPoint * k1;
    
    // Screen-space endpoints
    vec2 P0 = H0.xy * k0;
    vec2 P1 = H1.xy * k1;
    
    // [Optional clipping to frustum sides here]
    
    // Initialize to off screen
    hitPixel = vec2(-1.0, -1.0);
    
    // If the line is degenerate, make it cover at least one pixel
    // to avoid handling zero-pixel extent as a special case later
    P1 += vec2((distanceSquared(P0, P1) < 0.0001) ? 0.01 : 0.0);
    
    vec2 delta = P1 - P0;
    
    // Permute so that the primary iteration is in x to reduce
    // large branches later
    bool permute = (abs(delta.x) < abs(delta.y));
    if (permute) {
        // More-vertical line. Create a permutation that swaps x and y in the output
        // by directly swizzling the inputs.
        delta = delta.yx;
        P1 = P1.yx;
        P0 = P0.yx;
    }
    
    // From now on, "x" is the primary iteration direction and "y" is the secondary one
    float stepDirection = sign(delta.x);
    float invdx = stepDirection / delta.x;
    vec2 dP = vec2(stepDirection, invdx * delta.y);
    
    // Track the derivatives of Q and k
    vec3 dQ = (Q1 - Q0) * invdx;
    float   dk = (k1 - k0) * invdx;
    
    // Scale derivatives by the desired pixel stride
    dP *= reflectionTraceStride; dQ *= reflectionTraceStride; dk *= reflectionTraceStride;
    
    // Offset the starting values by the jitter fraction
    P0 += dP * jitterFraction; Q0 += dQ * jitterFraction; k0 += dk * jitterFraction;
    
    // Slide P from P0 to P1, (now-homogeneous) Q from Q0 to Q1, and k from k0 to k1
    vec3 Q = Q0;
    float  k = k0;
    
    // We track the ray depth at +/- 1/2 pixel to treat pixels as clip-space solid
    // voxels. Because the depth at -1/2 for a given pixel will be the same as at
    // +1/2 for the previous iteration, we actually only have to compute one value
    // per iteration.
    float prevZMaxEstimate = csOrigin.z;
    float stepCount = 0.0;
    float rayZMax = prevZMaxEstimate, rayZMin = prevZMaxEstimate;
    float sceneZMax = rayZMax + 1e4;
    
    // P1.x is never modified after this point, so pre-scale it by
    // the step direction for a signed comparison
    float end = P1.x * stepDirection;
    
    // We only advance the z field of Q in the inner loop, since
    // Q.xy is never used until after the loop terminates.
    
    vec2 P;
    for (P = P0;
         ((P.x * stepDirection) <= end) &&
         (stepCount < reflectionTraceMaxSteps) &&
         ((rayZMax < sceneZMax - reflectionTraceZThickness) ||
          (rayZMin > sceneZMax)) &&
         (sceneZMax != 0.0);
         P += dP, Q.z += dQ.z, k += dk, stepCount += 1.0) {
        
        // The depth range that the ray covers within this loop
        // iteration.  Assume that the ray is moving in increasing z
        // and swap if backwards.  Because one end of the interval is
        // shared between adjacent iterations, we track the previous
        // value and then swap as needed to ensure correct ordering
        rayZMin = prevZMaxEstimate;
        
        // Compute the value at 1/2 step into the future
        rayZMax = (dQ.z * 0.5 + Q.z) / (dk * 0.5 + k);
        prevZMaxEstimate = rayZMax;
        
        // Since we don't know if the ray is stepping forward or backward in depth,
        // maybe swap. Note that we preserve our original z "max" estimate first.
        if (rayZMin > rayZMax) { swap(rayZMin, rayZMax); }
        
        // Camera-space z of the background
        hitPixel = permute ? P.yx : P;
        sceneZMax = linearDepthTexelFetch(ivec2(hitPixel));
    } // pixel on ray
    
    // Undo the last increment, which ran after the test variables
    // were set up.
    P -= dP; Q.z -= dQ.z; k -= dk; stepCount -= 1.0;
    
    bool hit = (rayZMax >= sceneZMax - reflectionTraceZThickness) && (rayZMin <= sceneZMax);
    
    // If using non-unit stride and we hit a depth surface...
    if ((reflectionTraceStride > 1) && hit) {
        // Refine the hit point within the last large-stride step
        
        // Retreat one whole stride step from the previous loop so that
        // we can re-run that iteration at finer scale
        P -= dP; Q.z -= dQ.z; k -= dk; stepCount -= 1.0;
        
        // Take the derivatives back to single-pixel stride
        float invStride = 1.0 / reflectionTraceStride;
        dP *= invStride; dQ.z *= invStride; dk *= invStride;
        
        // For this test, we don't bother checking thickness or passing the end, since we KNOW there will
        // be a hit point. As soon as
        // the ray passes behind an object, call it a hit. Advance (stride + 1) steps to fully check this
        // interval (we could skip the very first iteration, but then we'd need identical code to prime the loop)
        float refinementStepCount = 0;
        
        // This is the current sample point's z-value, taken back to camera space
        prevZMaxEstimate = Q.z / k;
        rayZMin = prevZMaxEstimate;
        
        // Ensure that the FOR-loop test passes on the first iteration since we
        // won't have a valid value of sceneZMax to test.
        sceneZMax = rayZMin - 1e7;
        
        for (;
             (refinementStepCount <= reflectionTraceStride*1.4) &&
             (rayZMin > sceneZMax) && (sceneZMax != 0.0);
             P += dP, Q.z += dQ.z, k += dk, refinementStepCount += 1.0) {
            
            rayZMin = prevZMaxEstimate;
            
            // Compute the ray camera-space Z value at 1/2 fine step (pixel) into the future
            rayZMax = (dQ.z * 0.5 + Q.z) / (dk * 0.5 + k);
            prevZMaxEstimate = rayZMax;
            rayZMin = min(rayZMax, rayZMin);
            
            hitPixel = permute ? P.yx : P;
            sceneZMax = linearDepthTexelFetch(ivec2(hitPixel));
            
        }
        
        // Undo the last increment, which happened after the test variables were set up
        Q.z -= dQ.z; refinementStepCount -= 1;
        
        // Count the refinement steps as fractions of the original stride. Save a register
        // by not retaining invStride until here
        stepCount += refinementStepCount / reflectionTraceStride;
        //  debugColor = vec3(refinementStepCount / stride);
    } // refinement
    
    Q.xy += dQ.xy * stepCount;
    csHitPoint = Q * (1.0 / k);
    
    // Support debugging. This will compile away if debugColor is unused
    if ((P.x * stepDirection) > end) {
        // Hit the max ray distance -> blue
        debugColor = vec3(0,0,1);
    } else if (stepCount >= reflectionTraceMaxSteps) {
        // Ran out of steps -> red
        debugColor = vec3(1,0,0);
    } else if (sceneZMax == 0.0) {
        // Went off screen -> yellow
        debugColor = vec3(1,1,0);
    } else {
        // Encountered a valid hit -> green
        // ((rayZMax >= sceneZMax - csZThickness) && (rayZMin <= sceneZMax))
        debugColor = vec3(0,1,0);
    }
    
    debugColour = debugColor;
    
    // Does the last point discovered represent a valid hit?
    return hit;
}

vec4 traceReflection(vec3 rayOriginVS, vec3 normalVS, float roughness) {
    
    
    /** Since position is reconstructed in view space, just normalise it to get the vector from the eye to the position and then reflect that around the normal to get the ray direction to trace. */
    
    if (-rayOriginVS.z >= cameraNearFar.y * 0.998f) {
        return vec4(0.f);
    }
    
    vec3 toPositionVS = normalize(rayOriginVS);
    
    vec3 R = reflect(toPositionVS, normalVS);
    vec3 rayDirectionVS = normalize(getSpecularDominantDir(normalVS, R, roughness));
    
    // output rDotV to the alpha channel for use in determining how much to fade the ray
    float rDotV = dot(rayDirectionVS, toPositionVS);
    
    // out parameters
    vec2 hitPixel = vec2(0.0f, 0.0f);
    vec3 hitPoint = vec3(0);
    vec3 debugColour = vec3(0);
    
    float jitter = reflectionTraceStride > 1.0f ? (1 + float((int(gl_FragCoord.x) + int(gl_FragCoord.y)) & 1) * 0.5) : 1.f;
    
    // perform ray tracing - true if hit found, false otherwise
    bool intersection = traceScreenSpaceRay(rayOriginVS, rayDirectionVS, jitter, hitPixel, hitPoint, debugColour);
    
    float depth = texelFetch(gBufferDepthTexture, ivec2(hitPixel), 0).r;
    
    // move hit pixel from pixel position to UVs
    hitPixel /= depthBufferSize;
    if(hitPixel.x > 1.0f || hitPixel.x < 0.0f || hitPixel.y > 1.0f || hitPixel.y < 0.0f){
        intersection = false;
    }
    
    return vec4(hitPixel, depth, rDotV) * (intersection ? 1.0f : 0.0f);
}
