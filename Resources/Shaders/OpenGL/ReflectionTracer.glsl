//http://casual-effects.blogspot.co.nz/2014/08/screen-space-ray-tracing.html
//http://roar11.com/2015/07/screen-space-glossy-reflections/

// By Morgan McGuire and Michael Mara at Williams College 2014
// Released as open source under the BSD 2-Clause License
// http://opensource.org/licenses/BSD-2-Clause


uniform mat4 cameraToClipMatrix;
uniform sampler2D depthBuffer;

//uniform ivec2 depthBufferSize;

float distanceSquared(vec2 a, vec2 b) { a -= b; return dot(a, a); }

bool intersectsDepthBuffer(float z, float minZ, float maxZ) {
    /*
     * Based on how far away from the camera the depth is,
     * adding a bit of extra thickness can help improve some
     * artifacts. Driving this value up too high can cause
     * artifacts of its own.
     */
    float depthScale = min(1.0f, z * strideZCutoff);
    z += zThickness + mix(0.0f, 2.0f, depthScale);
    return (maxZ >= z) && (minZ - zThickness <= z);
}

void swap(inout float a, inout float b)
{
    float t = a;
    a = b;
    b = t;
}

float linearDepthTexelFetch(ivec2 hitPixel) {
    // Load returns 0 for any value accessed out of bounds
    return lineariseDepth(texelFetch(depthBuffer, hitPixel, 0).r, nearPlaneZ, farPlaneZ);
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
                          out vec2 hitPixel,
                          
                          // Camera space location of the ray hit
                          out vec3 hitPoint) {
    
    // Clip to the near plane
    float rayLength = ((csOrig.z + csDir.z * maxDistance) > nearPlaneZ) ?
    (nearPlaneZ - csOrig.z) / csDir.z : maxDistance;
    vec3 csEndPoint = csOrig + csDir * rayLength;
    
    // Project into homogeneous clip space
    vec4 H0 = cameraToClipMatrix * vec4(csOrig, 1.0);
//    H0.xy *= depthBufferSize;
    vec4 H1 = cameraToClipMatrix * vec4(csEndPoint, 1.0);
//    H1.xy *= depthBufferSize;
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
        permute = true; delta = delta.yx; P0 = P0.yx; P1 = P1.yx;
    }
    
    float stepDir = sign(delta.x);
    float invdx = stepDir / delta.x;
    
    // Track the derivatives of Q and k
    vec3  dQ = (Q1 - Q0) * invdx;
    float dk = (k1 - k0) * invdx;
    vec2  dP = vec2(stepDir, delta.y * invdx);
    
     // Scale derivatives by the desired pixel stride and then
     // offset the starting values by the jitter fraction
     float strideScale = 1.0f - min(1.0f, csOrig.z * strideZCutoff);
     float stride = 1.0f + strideScale * stride;
     dP *= stride;
     dQ *= stride;
     dk *= stride;
     
     P0 += dP * jitter;
     Q0 += dQ * jitter;
     k0 += dk * jitter;

    
    // Slide P from P0 to P1, (now-homogeneous) Q from Q0 to Q1, k from k0 to k1
     vec4 PQk = vec4(P0, Q0.z, k0);
     vec4 dPQk = vec4(dP, dQ.z, dk);
     vec3 Q = Q0;
    
    // Adjust end condition for iteration direction
    float  end = P1.x * stepDir;
    
     float stepCount = 0.0f;
     float prevZMaxEstimate = csOrig.z;
     float rayZMin = prevZMaxEstimate;
     float rayZMax = prevZMaxEstimate;
     float sceneZMax = rayZMax + 100.0f;
     for(;
          ((PQk.x * stepDir) <= end) && (stepCount < maxSteps) &&
          !intersectsDepthBuffer(sceneZMax, rayZMin, rayZMax) &&
          (sceneZMax != 0.0f);
          ++stepCount)
         {
             rayZMin = prevZMaxEstimate;
             rayZMax = (dPQk.z * 0.5f + PQk.z) / (dPQk.w * 0.5f + PQk.w);
             prevZMaxEstimate = rayZMax;
             if(rayZMin > rayZMax)
                 {
                     swap(rayZMin, rayZMax);
                     }
             
             hitPixel = permute ? PQk.yx : PQk.xy;
             // You may need hitPixel.y = depthBufferSize.y - hitPixel.y; here if your vertical axis
             // is different than ours in screen space
             sceneZMax = linearDepthTexelFetch(depthBuffer, ivec2(hitPixel));
             
             PQk += dPQk;
            }
     
     // Advance Q based on the number of steps
     Q.xy += dQ.xy * stepCount;
     hitPoint = Q * (1.0f / PQk.w);
     return intersectsDepthBuffer(sceneZMax, rayZMin, rayZMax);
}

out vec4 outColour;
 
void main() {
     ivec2 loadIndices = ivec2(gl_FragCoord.xy);
     vec3 normalVS = normalBuffer.Load(loadIndices).xyz;
     if(!any(normalVS))
         {
             return 0.0f;
             }
     
     float depth = texelFetch(depthBuffer, loadIndices).r;
     vec3 rayOriginVS = pIn.viewRay * lineariseDepth(depth);
     
     /*
       * Since position is reconstructed in view space, just normalize it to get the
       * vector from the eye to the position and then reflect that around the normal to
       * get the ray direction to trace.
       */
     vec3 toPositionVS = normalize(rayOriginVS);
     vec3 rayDirectionVS = normalize(reflect(toPositionVS, normalVS));
     
     // output rDotV to the alpha channel for use in determining how much to fade the ray
     float rDotV = dot(rayDirectionVS, toPositionVS);
     
     // out parameters
     vec2 hitPixel = vec2(0.0f, 0.0f);
     vec3 hitPoint = vec3(0.0f, 0.0f, 0.0f);
     
     float jitter = stride > 1.0f ? float(int(uv.x + uv.y) & 1) * 0.5f : 0.0f;
     
     // perform ray tracing - true if hit found, false otherwise
     bool intersection = traceScreenSpaceRay(rayOriginVS, rayDirectionVS, jitter, hitPixel, hitPoint);
     
     depth = texelFetch(depthBuffer, ivec2(hitPixel)).r;
     
     // move hit pixel from pixel position to UVs
     hitPixel *= vec2(texelWidth, texelHeight);
     if(hitPixel.x > 1.0f || hitPixel.x < 0.0f || hitPixel.y > 1.0f || hitPixel.y < 0.0f)
         {
             intersection = false;
        }
     
     outColour = vec4(hitPixel, depth, rDotV) * (intersection ? 1.0f : 0.0f);
}
