//
//  File.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 4/06/16.
//
//

import Foundation
import SGLMath

public enum Extent : Int {
    case MinX_MinY_MinZ = 0b000
    case MinX_MinY_MaxZ = 0b001
    case MinX_MaxY_MinZ = 0b010
    case MinX_MaxY_MaxZ = 0b011
    case MaxX_MinY_MinZ = 0b100
    case MaxX_MinY_MaxZ = 0b101
    case MaxX_MaxY_MinZ = 0b110
    case MaxX_MaxY_MaxZ = 0b111
    case LastElement
    
    static let MaxXFlag = 0b100
    static let MaxYFlag = 0b010
    static let MaxZFlag = 0b001
    
    static let values = (0..<Extent.LastElement.rawValue).map { rawValue -> Extent in return Extent(rawValue: rawValue)! }
}

public struct BoundingBox {
    
    public static let baseBox = BoundingBox(minPoint: vec3(Float.infinity), maxPoint: vec3(-Float.infinity))
    
    public let minPoint : vec3, maxPoint: vec3
    
    public var width : Float {
        return self.maxX - self.minX;
    }
    
    public var depth : Float {
        return self.maxZ - self.minZ;
    }
    
    public var height : Float {
        return self.maxY - self.minY;
    }
    
    public var volume : Float {
        return self.depth * self.width * self.height;
    }
    
    public var minX : Float { return self.minPoint.x }
    public var minY : Float { return self.minPoint.y }
    public var minZ : Float { return self.minPoint.z }
    public var maxX : Float { return self.maxPoint.x }
    public var maxY : Float { return self.maxPoint.y }
    public var maxZ : Float { return self.maxPoint.z }
    
    
    public var centreX : Float {
        return (self.minX + self.maxX)/2;
    }
    
    public var centreY : Float {
        return (self.minY + self.maxY)/2;
    }
    
    public var centreZ : Float {
        return (self.minZ + self.maxZ)/2
    }
    
    public var centre : vec3 {
        return vec3(self.centreX, self.centreY, self.centreZ);
    }
    
    public var size : vec3 {
        return self.maxPoint - self.minPoint
    }
    
    public func containsPoint(_ point: vec3) -> Bool {
        return point.x >= self.minX &&
            point.x <= self.maxX &&
            point.y >= self.minY &&
            point.y <= self.maxY &&
            point.z >= self.minZ &&
            point.z <= self.maxZ;
    }
    
    /**
     * Returns the vertex of self box in the direction described by direction.
     * @param direction The direction to look in.
     * @return The vertex in that direction.
     */
    public func pointAtExtent(_ extent: Extent) -> vec3 {
        let useMaxX = extent.rawValue & Extent.MaxXFlag != 0
        let useMaxY = extent.rawValue & Extent.MaxYFlag != 0
        let useMaxZ = extent.rawValue & Extent.MaxZFlag != 0
        
        return vec3(useMaxX ? self.maxX : self.minX, useMaxY ? self.maxY : self.minY, useMaxZ ? self.maxZ : self.minZ)
    }
    
    /**
     * @param otherBox The box to check intersection with.
     * @return Whether self box is intersecting with the other box.
     */
    public func intersectsWith(_ otherBox: BoundingBox) -> Bool {
        return !(self.maxX < otherBox.minX ||
            self.minX > otherBox.maxX ||
            self.maxY < otherBox.minY ||
            self.minY > otherBox.maxY ||
            self.maxZ < otherBox.minZ ||
            self.minZ > otherBox.maxZ);
    }
    
    public func contains(_ otherBox: BoundingBox) -> Bool {
        return
            self.minX < otherBox.minX &&
                self.maxX > otherBox.maxX &&
                self.minY < otherBox.minY &&
                self.maxY > otherBox.maxY &&
                self.minZ < otherBox.minZ &&
                self.maxZ > otherBox.maxZ
    }
    
    public static func combine(_ a : BoundingBox, _ b : BoundingBox) -> BoundingBox {
        return BoundingBox(minPoint: min(a.minPoint, b.minPoint), maxPoint: max(a.maxPoint, b.maxPoint))
    }
    
    
    /**
     * Transforms this bounding box from its local space to the space described by nodeToSpaceTransform.
     * The result is guaranteed to be axis aligned – that is, with no rotation in the destination space.
     * It may or may not have the same width, height, or depth as its source.
     * @param nodeToSpaceTransform The transformation from local to the destination space.
     * @return this box in the destination coordinate system.
     */
    public func axisAlignedBoundingBoxInSpace(nodeToSpaceTransform : mat4) -> BoundingBox {
        
        var minX = Float.infinity, minY = Float.infinity, minZ = Float.infinity
        var maxX = -Float.infinity, maxY = -Float.infinity, maxZ = -Float.infinity
        
        //Compute all the vertices for the box.
        for xToggle in 0..<2 {
            for yToggle in 0..<2 {
                for zToggle in 0..<2 {
                    let x = xToggle == 0 ? minPoint.x : maxPoint.x;
                    let y = yToggle == 0 ? minPoint.y : maxPoint.y;
                    let z = zToggle == 0 ? minPoint.z : maxPoint.z;
                    let vertex = vec3(x, y, z);
                    let transformedVertex = nodeToSpaceTransform * Vector4(vertex, 1);
                    
                    if (transformedVertex.x < minX) { minX = transformedVertex.x; }
                    if (transformedVertex.y < minY) { minY = transformedVertex.y; }
                    if (transformedVertex.z < minZ) { minZ = transformedVertex.z; }
                    if (transformedVertex.x > maxX) { maxX = transformedVertex.x; }
                    if (transformedVertex.y > maxY) { maxY = transformedVertex.y; }
                    if (transformedVertex.z > maxZ) { maxZ = transformedVertex.z; }
                }
            }
        }
        
        return BoundingBox(minPoint: vec3(minX, minY, minZ), maxPoint: vec3(maxX, maxY, maxZ));
    }
    
    public func maxZForBoundingBoxInSpace(nodeToSpaceTransform : mat4) -> Float {
        
        var maxZ = -Float.infinity
        
        //Compute all the vertices for the box.
        for xToggle in 0..<2 {
            for yToggle in 0..<2 {
                for zToggle in 0..<2 {
                    let x = xToggle == 0 ? minPoint.x : maxPoint.x;
                    let y = yToggle == 0 ? minPoint.y : maxPoint.y;
                    let z = zToggle == 0 ? minPoint.z : maxPoint.z;
                    let vertex = vec3(x, y, z);
                    let transformedVertex = nodeToSpaceTransform * Vector4(vertex, 1);
                    
                    if (transformedVertex.z > maxZ) { maxZ = transformedVertex.z; }
                }
            }
        }
        
        return maxZ;
    }
}

