//
//  Geometry.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 13/12/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import SGLMath

func reduce_add<T : FloatingPoint>(_ vector: Vector3<T>) -> T {
    return vector.x + vector.y + vector.z
}

///Beware: here be floating point accuracy dragons
struct FrustumPlane {
    let normalVector : vec3
    let constant : Float
    
    var normalised : FrustumPlane {
        let magnitude = length(normalVector)
        return FrustumPlane(normalVector: self.normalVector / magnitude, constant: self.constant / magnitude)
    }
    
    func distanceTo(_ point: vec3) -> Float {
        return reduce_add(self.normalVector * point) + self.constant
    }
    
    init(normalVector: vec3, constant: Float) {
        self.normalVector = normalVector
        self.constant = constant
    }
    
    init(withPoints points: [vec3]) {
        assert(points.count > 2)
        
        let pointDoubles = points.map { Vector3<Double>(Double($0.x), Double($0.y), Double($0.z)) }
        
        let normalDouble = normalize(cross(pointDoubles[1] - pointDoubles[0], pointDoubles[2] - pointDoubles[0]))
        let normal = vec3(Float(normalDouble.x), Float(normalDouble.y), Float(normalDouble.z))
        let constant = -reduce_add(points[0] * normal)
        
        self.init(normalVector: normal, constant: constant)
        
        assert({
            for point in points {
                if self.distanceTo(point) != 0 {
                    return false
                }
            }
            return true
            }(), "All the points must lie on the resultant plane")
    }
}

private let isGL = true

struct Frustum {
    
    enum PlaneDirection {
        case far
        case near
        case left
        case right
        case top
        case bottom
        
        var extentsOfPlane : [Extent] { //ordered anti-clockwise as viewed from the inside of the frustum
            switch self {
            case .far:
                return [.maxX_MaxY_MaxZ, .minX_MaxY_MaxZ, .minX_MinY_MaxZ, .maxX_MinY_MaxZ]
            case .near:
                return [.maxX_MaxY_MinZ, .maxX_MinY_MinZ, .minX_MinY_MinZ, .minX_MaxY_MinZ]
            case .left:
                return [.minX_MaxY_MaxZ, .minX_MaxY_MinZ, .minX_MinY_MinZ, .minX_MinY_MaxZ]
            case .right:
                return [.maxX_MaxY_MaxZ, .maxX_MinY_MaxZ, .maxX_MinY_MinZ, .maxX_MaxY_MinZ]
            case .top:
                return [.maxX_MaxY_MaxZ, .maxX_MaxY_MinZ, .minX_MaxY_MinZ, .minX_MaxY_MaxZ]
            case .bottom:
                return [.maxX_MinY_MaxZ, .minX_MinY_MaxZ, .minX_MinY_MinZ, .maxX_MinY_MinZ]
            }
        }
        
        static let frustumPlanes : [PlaneDirection] = [.near, .far, .left, .right, .top, .bottom]
    }
    
    let planes : [PlaneDirection : FrustumPlane]
    
    init(worldToCameraMatrix: mat4, projectionMatrix: mat4) {
        let vp = projectionMatrix * worldToCameraMatrix
        
        var planes = [PlaneDirection : FrustumPlane]()
        
        let n1x = (vp[0][3] + vp[0][0])
        let n1y = (vp[1][3] + vp[1][0])
        let n1z = (vp[2][3] + vp[2][0])
        let n1 = vec3(n1x, n1y, n1z)
        planes[.left] = FrustumPlane(normalVector: n1, constant: (vp[3][3] + vp[3][0]))
        
        let n2x = (vp[0][3] - vp[0][0])
        let n2y = (vp[1][3] - vp[1][0])
        let n2z = (vp[2][3] - vp[2][0])
        planes[.right] = FrustumPlane(normalVector: vec3(n2x, n2y, n2z), constant: (vp[3][3] - vp[3][0]))
        
        let n3x = (vp[0][3] - vp[0][0])
        let n3y = (vp[1][3] - vp[1][0])
        let n3z = (vp[2][3] - vp[2][0])
        
        planes[.top] = FrustumPlane(normalVector: vec3(n3x, n3y, n3z), constant: (vp[3][3] - vp[3][0]))
        
        let n4x = (vp[0][3] + vp[0][1])
        let n4y = (vp[1][3] + vp[1][1])
        let n4z = (vp[2][3] + vp[2][1])
        planes[.bottom] = FrustumPlane(normalVector: vec3(n4x, n4y, n4z), constant: (vp[3][3] + vp[3][1]))
        
        let n5xGL = (vp[0][3] + vp[0][2])
        let n5yGL = (vp[1][3] + vp[1][2])
        let n5zGL = (vp[2][3] + vp[2][2])
        
        if isGL {
            planes[.near] = FrustumPlane(normalVector: vec3(n5xGL, n5yGL, n5zGL), constant: (vp[3][3] + vp[3][2]))
        } else {
            planes[.near] = FrustumPlane(normalVector: vec3(vp[0][2], vp[1][2], vp[2][2]), constant: vp[3][2]);
        }
            
        let n6x = (vp[0][3] - vp[0][2])
        let n6y = (vp[1][3] - vp[1][2])
        let n6z = (vp[2][3] - vp[2][2])
        planes[.far] = FrustumPlane(normalVector: vec3(n6x, n6y, n6z), constant: (vp[3][3] - vp[3][2]));
        
        self.planes = planes
    }
    
    func enclosesPoint(_ point: vec3) -> Bool {
        for plane in planes.values {
            if plane.distanceTo(point) < 0 {
                return false
            }
        }
        return true
    }
    
    func containsBox(_ boundingBox: BoundingBox) -> Bool {
        
        for (_, plane) in planes {
            var shouldContinue = false
            for extent in Extent.values {
                if plane.distanceTo(boundingBox.pointAtExtent(extent)) > 0 {
                    shouldContinue = true
                    break
                }
            }
            if !shouldContinue { return false }
        }
        
        return true
    }
    
    func containsSphere(centre: vec3, radius: Float) -> Bool {
        for plane in planes.values {
            let distance = plane.distanceTo(centre)
            if distance <= -radius {
                return false
            }
        }
        return true
    }
    
}
