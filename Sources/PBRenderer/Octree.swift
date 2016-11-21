//
//  Octree.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 8/06/16.
//
//

import Foundation
import SGLMath

final class OctreeNode<T> {
    
    var values = [T]()
    let boundingVolume : BoundingBox
    fileprivate var children = [OctreeNode<T>?](repeating: nil, count: Extent.lastElement.rawValue)
    
    lazy var boundingSphere : (centre: vec3, radius: Float) = {
        let diameter = max(self.boundingVolume.width, self.boundingVolume.height, self.boundingVolume.depth)
        return (self.boundingVolume.centre, diameter/2)
    }()
    
    fileprivate let _subVolumes : [BoundingBox]
    
    fileprivate static func computeSubVolumesForBox(_ boundingBox: BoundingBox) -> [BoundingBox] {
        var volumes = [BoundingBox?](repeating: nil, count: Extent.lastElement.rawValue)
        
        let centre = boundingBox.centre
        
        for xToggle in 0..<2 {
            for yToggle in 0..<2 {
                for zToggle in 0..<2 {
                    let x = xToggle == 0 ? boundingBox.minPoint.x : boundingBox.maxPoint.x;
                    let y = yToggle == 0 ? boundingBox.minPoint.y : boundingBox.maxPoint.y;
                    let z = zToggle == 0 ? boundingBox.minPoint.z : boundingBox.maxPoint.z;
                    
                    let index = xToggle << 2 | yToggle << 1 | zToggle
                    
                    volumes[index] = (
                        BoundingBox(
                            minPoint: vec3(min(x, centre.x), min(y, centre.y), min(z, centre.z)),
                            maxPoint: vec3(max(x, centre.x), max(y, centre.y), max(z, centre.z))
                        )
                    )
                }
            }
        }
        
        return volumes.flatMap { $0 }
    }
    
    init(boundingVolume: BoundingBox) {
        self.boundingVolume = boundingVolume
        
        _subVolumes = OctreeNode.computeSubVolumesForBox(boundingVolume)
    }
    
    subscript(extent: Extent) -> OctreeNode<T>? {
        return self[extent.rawValue]
    }
    
    fileprivate subscript(index: Int) -> OctreeNode<T>? {
        return self.children[index]
    }
    
    
    func append(_ element: T, boundingBox: BoundingBox) {
        for (i, subVolume) in _subVolumes.enumerated() {
            if subVolume.contains(boundingBox) {
                (self[i] ?? {
                    let node = OctreeNode<T>(boundingVolume: _subVolumes[i])
                    self.children[i] = node
                    return node
                    }())
                    .append(element, boundingBox: boundingBox)
                return
            }
        }
        
        values.append(element)
    }
    
    func traverse(_ function: ([T]) -> ()) {
        function(values)
        for child in children {
            child?.traverse(function)
        }
    }
}
