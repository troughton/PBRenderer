//
//  FragmentFactory.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 31/05/16.
//
//
//  Adapted from https://software.intel.com/en-us/articles/forward-clustered-shading

import Foundation
import SGLMath

final class FragmentFactory
{
    var masks = [UInt64](repeating: 0, count: 48)
    
    init() {
        
        for k in 0..<16 {
            let b = UInt64(k % 4);
            let a = UInt64(k / 4);
            
            let one = UInt64(1);
            var x_segment = UInt64(0);
            var y_segment = UInt64(0);
            var z_segment = UInt64(0);
            
            if b >= a {
                for l in a...b {
                    for m in 0..<UInt64(16) {
                        let c = ((l / 2) % 2 + ((m / 8) % 2) * 2)
                        let d = ((l % 2) + ((m / 4) % 2) * 2)
                        let e = (((l / 2) % 2) * 2 + (m / 8) % 2)
                        let f = ((l % 2) * 2 + (m / 4) % 2)
                        
                        x_segment |= one << (c * 16 + d * 4 + (m % 4));
                        y_segment |= one << (e * 16 + f * 4 + (m % 4));
                        z_segment |= one << (m * 4 + l);
                        
                    }
                }
            }
            
            masks[0 + k] = x_segment;
            masks[16 + k] = y_segment;
            masks[32 + k] = z_segment;
        }
    }
    
    func coverage(x1: Int, x2: Int, y1: Int, y2: Int, z1: Int, z2: Int) -> UInt64 {
        let x_segment = masks[0 + x1 * 4 + x2];
        let y_segment = masks[16 + y1 * 4 + y2];
        let z_segment = masks[32 + z1 * 4 + z2];
        let coverage = x_segment & y_segment & z_segment;
        return coverage;
    }
}

// Bounds computation utilities, similar to GPUQuad.hlsl
func UpdateClipRegionRoot(nc: Float,          // Tangent plane x/y normal coordinate (view space)
    lc: Float,          // Light x/y coordinate (view space)
    lz: Float,          // Light z coordinate (view space)
    lightRadius: Float,
    cameraScale: Float, // Project scale for coordinate (_11 or _22 for x/y respectively)
    clipMin: inout Float,
    clipMax: inout Float) {
    let nz = (lightRadius - nc * lc) / lz;
    let pz = (lc * lc + lz * lz - lightRadius * lightRadius) / (lz - (nz / nc) * lc);
    
    if (pz > 0.0) {
        let c = -nz * cameraScale / nc;
        if (nc > 0.0)
        {                      // Left side boundary
            clipMin = max(clipMin, c);
        }
        else
        {                       // Right side boundary
            clipMax = min(clipMax, c);
        }
    }
}

func UpdateClipRegion(lc: Float,          // Light x/y coordinate (view space)
    lz: Float,          // Light z coordinate (view space)
    lightRadius: Float,
    cameraScale: Float, // Project scale for coordinate (_11 or _22 for x/y respectively)
    clipMin: inout Float,
    clipMax: inout Float)
{
    let rSq = lightRadius * lightRadius;
    let lcSqPluslzSq = lc * lc + lz * lz;
    let d = rSq * lc * lc - lcSqPluslzSq * (rSq - lz * lz);
    
    if (d > 0) {
        let a = lightRadius * lc;
        let b = sqrtf(d);
        let nx0 = (a + b) / lcSqPluslzSq;
        let nx1 = (a - b) / lcSqPluslzSq;
        
        UpdateClipRegionRoot(nc: nx0, lc: lc, lz: lz, lightRadius: lightRadius, cameraScale: cameraScale, clipMin: &clipMin, clipMax: &clipMax);
        UpdateClipRegionRoot(nc: nx1, lc: lc, lz: lz, lightRadius: lightRadius, cameraScale: cameraScale, clipMin: &clipMin, clipMax: &clipMax);
    }
}

// Returns bounding box [min.xy, max.xy] in clip [-1, 1] space.
func ComputeClipRegion(lightPosView: vec3, lightRadius: Float,
                       cameraProj: mat4, cameraNearFar: vec4) -> vec4
{
    // Early out with empty rectangle if the light is too far behind the view frustum
    var clipRegion = vec4(1, 1, 0, 0);
    if (lightPosView.z + lightRadius >= cameraNearFar.x) {
        var clipMin = vec2(-1.0, -1.0);
        var clipMax = vec2(1.0, 1.0);
        
        UpdateClipRegion(lc: lightPosView.x, lz: lightPosView.z, lightRadius: lightRadius, cameraScale: cameraProj[0][0], clipMin: &clipMin.x, clipMax: &clipMax.x);
        UpdateClipRegion(lc: -lightPosView.y, lz: lightPosView.z, lightRadius: lightRadius, cameraScale: cameraProj[1][1], clipMin: &clipMin.y, clipMax: &clipMax.y);
        
        clipRegion = vec4(clipMin.x, clipMin.y, clipMax.x, clipMax.y);
    }
    
    return clipRegion;
}

func GenerateLightFragments(fragmentFactory: FragmentFactory, builder: LightGridBuilder,
                            camera: Camera, light: Light, lightIndex: Int)
{
    let dim = builder.dim
    let mCameraNearFar = vec4(camera.zNear, camera.zFar, 0.0, 0.0);
    let mCameraProj = camera.projectionMatrix
    
    var lightPositionView = camera.sceneNode.transform.worldToNodeMatrix * light.sceneNode.transform.worldSpacePosition
    lightPositionView.z *= -1;
    lightPositionView.y *= -1;
    // compute view space quad
    var clipRegion = ComputeClipRegion(lightPosView: lightPositionView.xyz, lightRadius: light.falloffRadiusOrInfinity, cameraProj: mCameraProj, cameraNearFar: mCameraNearFar)
    clipRegion = (clipRegion + vec4(1.0, 1.0, 1.0, 1.0)) * 0.5; // map coordinates to [0..1]
    
    var intClipRegion = (0, 0, 0, 0);
    intClipRegion.0 = Int(clipRegion[0] * Float(dim.width));
    intClipRegion.1 = Int(clipRegion[1] * Float(dim.height));
    intClipRegion.2 = Int(clipRegion[2] * Float(dim.width));
    intClipRegion.3 = Int(clipRegion[3] * Float(dim.height));
    
    if (intClipRegion.0 < 0) { intClipRegion.0 = 0; }
    if (intClipRegion.1 < 0) { intClipRegion.1 = 0; }
    if (intClipRegion.2 >= dim.width) { intClipRegion.2 = dim.width - 1; }
    if (intClipRegion.3 >= dim.height) { intClipRegion.3 = dim.height - 1; }
    
    let center_z = (lightPositionView.z - mCameraNearFar.x) / (mCameraNearFar.y - mCameraNearFar.x);
    let dist_z = light.falloffRadiusOrInfinity / (mCameraNearFar.y - mCameraNearFar.x);
    
    var intZBounds = (0, 0);
    intZBounds.0 = Int((center_z - dist_z) * Float(dim.depth))
    intZBounds.1 = Int((center_z + dist_z) * Float(dim.depth))
    
    if (intZBounds.0 < 0) { intZBounds.0 = 0; }
    if (intZBounds.1 >= dim.depth) { intZBounds.1 = dim.depth - 1; }
    
    var y = intClipRegion.1 / 4
    
    while y <= intClipRegion.3 / 4 {
        
        var x = intClipRegion.0 / 4
        while x <= intClipRegion.2 / 4 {
            
            var z = intZBounds.0 / 4
            while z <= intZBounds.1 / 4 {
                let x1 = clamp(intClipRegion.0 - x * 4, min: 0, max: 3);
                let x2 = clamp(intClipRegion.2 - x * 4, min: 0, max: 3);
                let y1 = clamp(intClipRegion.1 - y * 4, min: 0, max: 3);
                let y2 = clamp(intClipRegion.3 - y * 4, min: 0, max: 3);
                let z1 = clamp(intZBounds.0 - z * 4, min: 0, max: 3);
                let z2 = clamp(intZBounds.1 - z * 4, min: 0, max: 3);
        
                let coverage = fragmentFactory.coverage(x1: x1, x2: x2, y1: y1, y2: y2, z1: z1, z2: z2);
                
                builder.pushFragment(cellIndex: dim.cellIndex(x: x, y: y, z: z), lightIndex: Int32(lightIndex), coverage: coverage);
                z += 1
            }
            x += 1
        }
        y += 1
    }
}

#if os(OSX)
private var fragments = [Fragment]()
#endif
    
//Requires that all lights be in a single buffer
func RasterizeLights(builder: LightGridBuilder, viewerCamera: Camera, lights: [Light]) {
    
    let fragmentFactory = FragmentFactory()
    
    #if os(OSX)
        //We expect the simd path to be faster – Swift on Linux doesn't support the simd module yet, which SGLMath makes use of.

        var bounds = [LightBounds](repeating: LightBounds(), count: lights.count)

        let lightPositions = lights.map { (light) -> vec3 in
            var lightPositionView = viewerCamera.sceneNode.transform.worldToNodeMatrix * light.sceneNode.transform.worldSpacePosition
            lightPositionView.z *= -1;
            lightPositionView.y *= -1;
            return lightPositionView.xyz
        }
        
        let dim = builder.dim
        
        CoarseRasterizeLights(lights: lights, lightPositions: lightPositions, bounds: &bounds, camera: viewerCamera, dim: dim)
        
        
        fragments.removeAll(keepingCapacity: true)
        
        for (i, region) in bounds.enumerated() {
            
            var y = region.p1.1 / 4
            while y <= region.p2.1 / 4 {
                var x = region.p1.0 / 4
                while x <= region.p2.0 / 4 {
                    var z = region.p1.2 / 4
                    
                    while z <= region.p2.2 / 4 {
                        
                        let fragment = Fragment(cellIndex: dim.cellIndex(x: x, y: y, z: z), lightIndex: i)
                        fragments.append(fragment)
                        
                        z += 1
                    }
                    
                    
                    x += 1
                }
                
                
                y += 1
            }
        }
        
        FineRasterizeLights(lights: lights, lightPositions: lightPositions, fragments: &fragments, camera: viewerCamera, lightGridBuilder: builder);
        
        for fragment in fragments {
            builder.pushFragment(cellIndex: fragment.cellIndex, lightIndex: Int32(lights[fragment.lightIndex].backingGPULight.bufferIndex), coverage: fragment.coverage)
        }
        #else
        // warning: scalar version does coarser (AABB) culling
        for light in lights where light.isOn {
            let lightIndex = light.backingGPULight.bufferIndex
            GenerateLightFragments(fragmentFactory: fragmentFactory, builder: builder, camera: viewerCamera, light: light, lightIndex: lightIndex);
        }
    #endif
}
