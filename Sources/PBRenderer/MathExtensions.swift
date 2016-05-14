//
//  MathExtensions.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 12/05/16.
//
//

import Foundation
import SGLMath

/** multiple must be a power of two. http://stackoverflow.com/questions/3407012/c-rounding-up-to-the-nearest-multiple-of-a-number */
func roundUpToNearestMultiple(numToRound: Int, of multiple: Int) -> Int {
    assert(multiple > 0 && ((multiple & (multiple - 1)) == 0));
    
    let notTerm = ~(multiple - 1)
    return (numToRound + multiple - 1) & notTerm;
}

func *<T:FloatingPoint>(lhs: Quaternion<T>, rhs: Quaternion<T>) -> Quaternion<T> {
    let w = lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
    var x = lhs.w * rhs.x + lhs.x * rhs.w
    x += lhs.y * rhs.z - lhs.z * rhs.y
    let y = lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x
    var z = lhs.w * rhs.z + lhs.x * rhs.y
    z -= lhs.y * rhs.x + lhs.z * rhs.w;
    
    return Quaternion<T>(x, y, z, w)
}

func dot<T:FloatingPoint>(_ lhs: Quaternion<T>, _ rhs: Quaternion<T>)  -> T {
    return lhs.w * rhs.w + lhs.x * rhs.x +  lhs.y * rhs.y + lhs.z * rhs.z;
}

func length_q<T:FloatingPoint>(q: Quaternion<T>) -> T {
    let unsafeQ = unsafeBitCast(q, to: Vector4<T>.self)
    return length(unsafeQ)
}

func conjugate<T>(_ q: Quaternion<T>) -> Quaternion<T> {
    return Quaternion<T>(-q.x, -q.y, -q.z, q.w)
}

func inverse<T:FloatingPoint>(_ q: Quaternion<T>) -> Quaternion<T> {
    let lengthSquared = dot(q, q)
    let scale = T(1) / lengthSquared
    return conjugate(q) * scale
}

func *<T>(lhs: Matrix4x4<T>, rhs: Quaternion<T>) -> Matrix4x4<T> {
    return lhs * Matrix4x4(withQuaternion: rhs)
}

func *<T>(quaternion: Quaternion<T>, vector: Vector3<T>) -> Vector3<T> {
    var rotatedQuaternion = Quaternion(vector.x, vector.y, vector.z, 0.0);
    rotatedQuaternion = (quaternion * rotatedQuaternion) * inverse(quaternion)
    
    return Vector3<T>(rotatedQuaternion.x, rotatedQuaternion.y, rotatedQuaternion.z);
}

extension Matrix4x4 {
    var upperLeft : Matrix3x3<T> {
        return Matrix3x3(self[0][0], self[0][1], self[0][2],
                            self[1][0], self[1][1], self[1][2],
                            self[2][0], self[2][1], self[2][2])
    }
}

extension Quaternion where T : FloatingPoint {
    init(angle: T, axis: Vector3<T>) {
        let halfAngle = angle * 0.5;
        let scale : T
        let w : T
        if let halfAngle = halfAngle as? Float {
            scale = unsafeBitCast(sin(halfAngle), to: T.self)
            w = unsafeBitCast(cos(halfAngle), to: T.self)
        } else if let halfAngle = halfAngle as? Double {
            scale = unsafeBitCast(sin(halfAngle), to: T.self)
            w = unsafeBitCast(cos(halfAngle), to: T.self)
        } else {
            fatalError()
        }
        self = Quaternion(scale * axis.x, scale * axis.y, scale * axis.z, w);
    }
}

extension Quaternion where T : FloatingPoint {
    init(_ m: Matrix4x4<T>) {
        var n4 : T; // the norm of quaternion multiplied by 4
        var tr = m[0][0]
        tr += m[1][1]
        tr += m[2][2]; // trace of matrix
        
        let condition1 = m[0][0] > m[1][1]
        let condition2 = m[0][0] > m[2][2]
        if (tr > 0.0){
            let x = m[1][2] - m[2][1]
            let y = m[2][0] - m[0][2]
            let z = m[0][1] - m[1][0]
            let w = tr + 1.0
            self = Quaternion(x, y, z, w);
            n4 = self.w;
            
        } else if condition1 && condition2 {
            var x = 1.0 + m[0][0]
            x -= m[1][1]
            x -= m[2][2]
            let y = m[1][0] + m[0][1]
            let z = m[2][0] + m[0][2]
            let w = m[1][2] - m[2][1]
            self = Quaternion(x, y, z, w);
            n4 = self.x;
        } else if ( m[1][1] > m[2][2] ){
            let x = m[1][0] + m[0][1]
            var y = 1.0 + m[1][1]
            y -= m[0][0]
            y -= m[2][2]
            let z = m[2][1] + m[1][2]
            let w = m[2][0] - m[0][2]
            self = Quaternion( x, y, z, w );
            n4 = self.y;
        } else {
            let x = m[2][0] + m[0][2]
            let y = m[2][1] + m[1][2]
            var z = 1.0 + m[2][2]
            z -= m[0][0]
            z -= m[1][1]
            let w = m[0][1] - m[1][0]
            
            self = Quaternion(x, y, z, w);
            n4 = self.z;
        }
        
        if let val = n4 as? Float {
            n4 = unsafeBitCast(sqrt(val), to: T.self)
        } else if let val = n4 as? Double {
            n4 = unsafeBitCast(sqrt(val), to: T.self)
        } else {
            fatalError()
        }
        
        self *= 0.5 / n4
    }
}

extension Matrix4x4 where T : FloatingPointArithmeticType {
    init(withQuaternion quaternion: Quaternion<T>) {
        let normalised = normalize(unsafeBitCast(quaternion, to: Vector4<T>.self))
        
        let (x, y, z, w) = (normalised.x, normalised.y, normalised.z, normalised.w)
        let (_2x, _2y, _2z, _2w) = (x + x, y + y, z + z, w + w)
        
        var vec1 = Vector4<T>()
        vec1.x = 1.0 - _2y * y - _2z * z
        vec1.y = _2x * y + _2w * z
        vec1.z = _2x * z - _2w * y
        
        var vec2 = Vector4<T>()
        vec2.x = _2x * y - _2w * z
        vec2.y =  1.0 - _2x * x - _2z * z
        vec2.z = _2y * z + _2w * x
        
        var vec3 = Vector4<T>()
        vec3.x = _2x * z + _2w * y
        vec3.y = _2y * z - _2w * x
        vec3.z = 1.0 - _2x * x - _2y * y
        
        self.init(vec1,
                   vec2,
                   vec3,
                   Vector4<T>(0.0, 0.0,0.0, 1.0));
    }

}
