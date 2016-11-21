//
//  MathExtensions.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 12/05/16.
//
//

import Foundation
import SGLMath

extension Quaternion {
    public static var identity : Quaternion {
        return Quaternion(1, 0, 0, 0)
    }
}

/** multiple must be a power of two. http://stackoverflow.com/questions/3407012/c-rounding-up-to-the-nearest-multiple-of-a-number */
func roundUpToNearestMultiple(numToRound: Int, of multiple: Int) -> Int {
    assert(multiple > 0 && ((multiple & (multiple - 1)) == 0));
    
    let notTerm = ~(multiple - 1)
    return (numToRound + multiple - 1) & notTerm;
}

public func lerp<T : ArithmeticType>(from: T, to: T, percentage: T) -> T {
    return from + (to - from) * percentage
}

public func degrees<T : FloatingPointArithmeticType>(radians: T) -> T {
    return radians * 57.2957795131
}

public func radians<T : FloatingPointArithmeticType>(degrees: T) -> T{
    return degrees * 0.01745329252
}

func clamp<T : ArithmeticType>(_ x: T, min: T, max: T) -> T {
    if x < min {
        return min
    } else if x > max {
        return max
    } else {
        return x
    }
}

public func *<T:FloatingPoint>(lhs: Quaternion<T>, rhs: Quaternion<T>) -> Quaternion<T> {
    var x = lhs.w * rhs.x +
        lhs.x * rhs.w
    x += lhs.y * rhs.z -
        lhs.z * rhs.y
    var y = lhs.w * rhs.y +
        lhs.y * rhs.w
    y += lhs.z * rhs.x -
        lhs.x * rhs.z
    var z = lhs.w * rhs.z +
        lhs.z * rhs.w
    z += lhs.x * rhs.y -
        lhs.y * rhs.x
    var w = lhs.w * rhs.w -
        lhs.x * rhs.x
    w -= lhs.y * rhs.y
    w -= lhs.z * rhs.z
    
    return Quaternion(x, y, z, w);
}

public func *=<T:FloatingPoint>(lhs: inout Quaternion<T>, rhs: Quaternion<T>) {
    lhs = lhs * rhs
}

func dot<T:FloatingPoint>(_ lhs: Quaternion<T>, _ rhs: Quaternion<T>)  -> T {
    return lhs.w * rhs.w + lhs.x * rhs.x +  lhs.y * rhs.y + lhs.z * rhs.z;
}

func length_q<T:FloatingPoint>(_ q: Quaternion<T>) -> T {
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

func *<T>(lhs: Quaternion<T>, rhs: Matrix4x4<T>) -> Matrix4x4<T> {
    return Matrix4x4(withQuaternion: lhs) * rhs
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

func cos<T : FloatingPointArithmeticType>(_ x : T) -> T {
    if let x = x as? Float {
        return T(cosf(x))
    } else if let x = x as? Double {
        return T(cos(x))
    } else {
        fatalError()
    }
}

func sin<T : FloatingPointArithmeticType>(_ x : T) -> T {
    if let x = x as? Float {
        return T(sinf(x))
    } else if let x = x as? Double {
        return T(sin(x))
    } else {
        fatalError()
    }
}

func atan2<T : FloatingPointArithmeticType>(_ x : T, _ y: T) -> T {
    if let x = x as? Float, let y = y as? Float {
        return T(atan2f(x, y))
    } else if let x = x as? Double, let y = y as? Double {
        return T(atan2(x, y))
    } else {
        fatalError()
    }
}

func asin<T : FloatingPointArithmeticType>(_ x : T) -> T {
    if let x = x as? Float {
        return T(asinf(x))
    } else if let x = x as? Double {
        return T(asin(x))
    } else {
        fatalError()
    }
}

func clamp<T : FloatingPointArithmeticType>(_ x : T, _ low: T, _ high: T) -> T {
    if let x = x as? Float, let low = low as? Float, let high = high as? Float  {
        return T(min(max(x, low), high))
    } else if let x = x as? Double, let low = low as? Double, let high = high as? Double {
        return T(min(max(x, low), high))
    } else {
        fatalError()
    }
}

extension Quaternion where T : FloatingPoint {
    public init(angle: T, axis: Vector3<T>) {
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
    
    public init(eulerAngles: Vector3<T>) {
        
        let cX = cos(eulerAngles.x * T(0.5));
        let cY = cos(eulerAngles.y * T(0.5));
        let cZ = cos(eulerAngles.z * T(0.5));
        
        let sX = sin(eulerAngles.x * T(0.5));
        let sY = sin(eulerAngles.y * T(0.5));
        let sZ = sin(eulerAngles.z * T(0.5))
        
        self.w = cX * cY * cZ + sX * sY * sZ;
        self.x = sX * cY * cZ - cX * sY * sZ;
        self.y = cX * sY * cZ + sX * cY * sZ;
        self.z = cX * cY * sZ - sX * sY * cZ;
    }
    
    public var eulerAngles : Vector3<T> {
        return Vector3(self.pitch, self.yaw, self.roll);
    }
    
    var roll : T {
        let factor1 = (self.x * self.y + self.w * self.z)
        let factor2 = self.w * self.w + self.x * self.x - self.y * self.y - self.z * self.z
        let result = atan2(T(2) * factor1, factor2);
        return result
    }
    
    var pitch : T {
        let factor1 = (self.y * self.z + self.w * self.x)
        var factor2 = self.w * self.w
            factor2 -= self.x * self.x - self.y * self.y
            factor2 += self.z * self.z
        return atan2(T(2) * factor1, factor2);
    }
    
    var yaw : T {
        let factor = (self.x * self.z - self.w * self.y)
        let clamped = clamp(-2 * factor, -1, 1)
        return asin(clamped);
    }
}


public func normalize(_ x: Quaternion<Float>) -> Quaternion<Float> {
    //http://stackoverflow.com/questions/11667783/quaternion-and-normalization
    let qmagsq = Double(x.x * x.x + x.y * x.y + x.z * x.z + x.w * x.w)
    
    if (abs(1.0 - qmagsq) < 2.107342e-08) {
        return x * Float(2.0 / (1.0 + qmagsq));
    }
    else {
        return x * (1.0 / Float(sqrt(qmagsq)));
    }
}

public func normalize(_ x: Quaternion<Double>) -> Quaternion<Double> {
    //http://stackoverflow.com/questions/11667783/quaternion-and-normalization
    let qmagsq = (x.x * x.x + x.y * x.y + x.z * x.z + x.w * x.w)
    
    if (abs(1.0 - qmagsq) < 2.107342e-08) {
        return x * (2.0 / (1.0 + qmagsq));
    }
    else {
        return x * (1.0 / sqrt(qmagsq));
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
    public init(withQuaternion quaternion: Quaternion<T>) {
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



    public func slerp<T>(from : Quaternion<T>, to: Quaternion<T>, t: T) -> Quaternion<T> {
    // Calculate angle between them.
    let cosHalfTheta = dot(from, to);
    
    // if this == other or this == -other then theta = 0 and we can return this
    if (abs(cosHalfTheta) >= 1.0) {
        return from;
    }
    
    // Calculate temporary values.
        var halfTheta : T
        var sinHalfTheta : T
        if let val = cosHalfTheta as? Float {
            halfTheta = unsafeBitCast(acosf(val), to: T.self)
            sinHalfTheta = unsafeBitCast(sqrtf(1.0 - val * val), to: T.self)
        } else if let val = cosHalfTheta as? Double {
            halfTheta = unsafeBitCast(acos(val), to: T.self)
            sinHalfTheta = unsafeBitCast(sqrt(1.0 - val * val), to: T.self)
        } else {
            fatalError()
        }
    
        var x : T, y : T, z : T, w : T;
    
    // if theta = 180 degrees then result is not fully defined
    // we could rotate around any axis normal to qa or qb
    if (abs(sinHalfTheta) < 0.001){
        w = (from.w * 0.5 + to.w * 0.5);
        x = (from.x * 0.5 + to.x * 0.5);
        y = (from.y * 0.5 + to.y * 0.5);
        z = (from.z * 0.5 + to.z * 0.5);
    } else {
        
        var ratioA : T
        var ratioB : T
        
        if let halfTheta = halfTheta as? Float, let sinHalfTheta = sinHalfTheta as? Float, let t = t as? Float {
            ratioA = unsafeBitCast(sinf((1 - t) * halfTheta) / sinHalfTheta, to: T.self)
            ratioB = unsafeBitCast(sinf(t * halfTheta) / sinHalfTheta, to: T.self)
        } else if let halfTheta = halfTheta as? Double, let sinHalfTheta = sinHalfTheta as? Double, let t = t as? Double {
            ratioA = unsafeBitCast(sin((1 - t) * halfTheta) / sinHalfTheta, to: T.self)
            ratioB = unsafeBitCast(sin(t * halfTheta) / sinHalfTheta, to: T.self)
        } else {
            fatalError()
        }
    
        //calculate quaternion.
        w = (from.w * ratioA + to.w * ratioB);
        x = (from.x * ratioA + to.x * ratioB);
        y = (from.y * ratioA + to.y * ratioB);
        z = (from.z * ratioA + to.z * ratioB);
    }
    return Quaternion<T>(x, y, z, w);
    }



public func lerp<genType:VectorType>(from: genType, to: genType, t: genType.Element) -> genType where
    genType.Element:FloatingPointArithmeticType
     {
    return from + t * (to - from)
}


public func distanceSquared<T: FloatingPointArithmeticType
    >(_ a: Vector3<T>, _ b: Vector3<T>) -> T {
    
    let dX = a.x - b.x
    let dY = a.y - b.y
    let dZ = a.z - b.z
    
    return dX * dX + dY * dY + dZ * dZ
}

extension Matrix4x4 {
    //From the G3D10 engine source code
    init(pixelScaleMatrixWithWidth screenWidth: T, height screenHeight: T) {
        let sx = screenWidth * T(0.5)
        let sy = screenHeight * T(0.5)
        
        self = Matrix4x4(sx, 0, 0, 0,
                          0, sy, 0, 0,
                          0, 0, 1, 0,
                          sx, sy, 0, 1)
    }
}

extension Vector4 {
    static var up : Vector4 { return Vector4(0, 1, 0, 0) }
    static var right : Vector4 { return Vector4(1, 0, 0, 0) }
    static var forward : Vector4 { return Vector4(0, 0, 1, 0) }
}
