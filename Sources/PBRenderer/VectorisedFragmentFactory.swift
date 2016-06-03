//
//  VectorisedFragmentFactory.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 31/05/16.
//
//

#if os(OSX)

import Foundation
import simd
import SGLMath

struct LightBounds
{
    var p1 : (Int, Int, Int) = (0, 0, 0)
    var p2 : (Int, Int, Int) = (0, 0, 0)
};


func GenerateLightBounds(light: Light, lightPositionView: vec3, box: inout LightBounds, camera: Camera, dim: LightGridDimensions) {
    // compute view space quad

    
    let mCameraNearFar = vec4(camera.zNear, camera.zFar, 0.0, 0.0);
    
    var clipRegion = ComputeClipRegion(lightPosView: lightPositionView.xyz, lightRadius: light.falloffRadius, cameraProj: camera.projectionMatrix, cameraNearFar: mCameraNearFar)
    clipRegion = (clipRegion + 1.0) / 2; // map coordinates to [0..1]
    
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
    let dist_z = light.falloffRadius / (mCameraNearFar.y - mCameraNearFar.x);
    
    var intZBounds = (0, 0);
    intZBounds.0 = Int((center_z - dist_z) * Float(dim.depth))
    intZBounds.1 = Int((center_z + dist_z) * Float(dim.depth))
    
    if (intZBounds.0 < 0) { intZBounds.0 = 0; }
    if (intZBounds.1 >= dim.depth) { intZBounds.1 = dim.depth - 1; }
    
    box.p1.0 = intClipRegion.0;
    box.p2.0 = intClipRegion.2;
    box.p1.1 = intClipRegion.1;
    box.p2.1 = intClipRegion.3;
    
    box.p1.2 = intZBounds.0;
    box.p2.2 = intZBounds.1;
}

func CoarseRasterizeLights(lights: [Light], lightPositions: [vec3], bounds: inout [LightBounds], camera: Camera, dim: LightGridDimensions)
{
    let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)!
    let group = dispatch_group_create()!
    
    bounds.withUnsafeMutableBufferPointer { (bounds) -> Void in
        for idx in 0..<lights.count {
            if !lights[idx].isOn { continue }
            dispatch_group_async(group, queue) {
                var box = LightBounds()
                GenerateLightBounds(light: lights[idx], lightPositionView: lightPositions[idx], box: &box, camera: camera, dim: dim)
                bounds[idx] = box
            }
        }
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

struct Fragment {
    let cellIndex : Int;
    let lightIndex : Int;
    var coverage : UInt64 = 0;
    
    init(cellIndex: Int, lightIndex: Int) {
        self.cellIndex = cellIndex
        self.lightIndex = lightIndex
    }
}

    func ComputeCoverage(cellIndex: Int, lightPosition: vec3, lightSize: Float, cameraProj11: Float, cameraProj22: Float, cameraZNear: Float, cameraZFar: Float, lightGrid: LightGridBuilder) -> UInt64
{
    
    let dim = lightGrid.dim
    let cz = cellIndex % (dim.depth / 4);
    let cx = (cellIndex / (dim.depth / 4)) % (dim.width / 4);
    let cy = cellIndex / (dim.depth / 4 * dim.width / 4);
    
    var coverage = UInt64(0);
    for zz in 0...3 {
        // Z
        let z = cz * 4 + zz;
        
        let cameraZDiff = cameraZFar - cameraZNear
        let divisor = Float(dim.depth)
        let minZ = Float(z - 0) / divisor * cameraZDiff + cameraZNear;
        let maxZ = Float(z + 1) / divisor * cameraZDiff + cameraZNear;
        
        let centerZ = (minZ + maxZ) * 0.5;
        let normalZ = centerZ - lightPosition.z;
        
        let d0Z = normalZ * lightPosition.z;
        let min_d1Z = -d0Z + normalZ * minZ;
        let min_d2Z = -d0Z + normalZ * maxZ;
        
        // X
        let minZmulX = 2.0 / Float(dim.width) * minZ / cameraProj11;
        let minZaddX = -minZ / cameraProj11;
        let maxZmulX = 2.0 / Float(dim.width) * maxZ / cameraProj11;
        let maxZaddX = -maxZ / cameraProj11;
        
        var min_d1X = float4(0)
        var min_d2X = float4(0)
        var normal2X = float4(0)
        
        for xx in 0...3 {
            let x = cx * 4 + xx;
            
            let minZminX = Float(x - 0) * minZmulX + minZaddX;
            let minZmaxX = Float(x + 1) * minZmulX + minZaddX;
            let maxZminX = Float(x - 0) * maxZmulX + maxZaddX;
            let maxZmaxX = Float(x + 1) * maxZmulX + maxZaddX;
            
            let centerX = (minZminX + minZmaxX + maxZminX + maxZmaxX) * 0.25;
            let normalX = centerX - lightPosition.x;
            
            let d0X = normalX * lightPosition.x;
            min_d1X[xx] = -d0X + min(normalX * minZminX, normalX * minZmaxX);
            min_d2X[xx] = -d0X + min(normalX * maxZminX, normalX * maxZmaxX);
            normal2X[xx] = normalX * normalX;
        }
        
        
        // Y
        let minZmulY = -2.0 / Float(dim.height) * minZ / cameraProj22
        let minZaddY = minZ / cameraProj22
        let maxZmulY = -2.0 / Float(dim.height) * maxZ / cameraProj22
        let maxZaddY = maxZ / cameraProj22
        
        var min_d1Y = float4(0)
        var min_d2Y = float4(0)
        var normal2Y = float4(0)
        
        for yy in 0...3 {
            let y = cy * 4 + yy;
            
            let minZminY = Float(y - 0) * minZmulY + minZaddY;
            let minZmaxY = Float(y + 1) * minZmulY + minZaddY;
            let maxZminY = Float(y - 0) * maxZmulY + maxZaddY;
            let maxZmaxY = Float(y + 1) * maxZmulY + maxZaddY;
            
            let centerY = (minZminY + minZmaxY + maxZminY + maxZmaxY) * 0.25;
            let normalY = centerY - lightPosition.y;
            
            let d0Y = normalY * lightPosition.y;
            min_d1Y[yy] = -d0Y + min(normalY * minZminY, normalY * minZmaxY);
            min_d2Y[yy] = -d0Y + min(normalY * maxZminY, normalY * maxZmaxY);
            normal2Y[yy] = normalY * normalY;
        }
        
        // rasterize a Z slice
        for yy in 0...3 {
            for xx in 0...3 {
                let fineIndex = lightGrid.getFineIndex(xx, yy) * 4 + zz;
                
                var normal2 = normalZ * normalZ;
                normal2 += normal2X[xx];
                normal2 += normal2Y[yy];
                
                let min_d1 = min_d1X[xx] + min_d1Y[yy] + min_d1Z;
                let min_d2 = min_d2X[xx] + min_d2Y[yy] + min_d2Z;
                let min_d = min(min_d1, min_d2);
                
                var separated = min_d * min_d > lightSize * lightSize * normal2;
                if (min_d < 0) { separated = false; }
                
                let one = UInt64(1);
                if (!separated) {
                    coverage |= one << UInt64(fineIndex);
                }
            }
        }
    }
    
    return coverage;
}

func FineRasterizeLights(lights: [Light], lightPositions: [vec3], fragments: inout [Fragment], camera: Camera, lightGridBuilder: LightGridBuilder)
{
    let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)!
    let group = dispatch_group_create()!
    
    
    let cameraProj11 = camera.projectionMatrix[0][0]
    let cameraProj22 = camera.projectionMatrix[1][1]
    
    fragments.withUnsafeMutableBufferPointer { (fragments) -> () in
        
        for idx in 0..<fragments.count {
            dispatch_group_async(group, queue) {
                let lightIndex = fragments[idx].lightIndex
                let light = lights[lightIndex]
                let lightPosition = lightPositions[lightIndex]
                fragments[idx].coverage = ComputeCoverage(cellIndex: fragments[idx].cellIndex, lightPosition: lightPosition, lightSize: light.falloffRadius,
                                                          cameraProj11: cameraProj11, cameraProj22: cameraProj22, cameraZNear: camera.zNear, cameraZFar: camera.zFar,
                                                          lightGrid: lightGridBuilder)
            }
        }
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

#endif
