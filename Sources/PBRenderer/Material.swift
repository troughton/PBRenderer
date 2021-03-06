//
//  Material.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 3/05/16.
//
//

import Foundation
import SGLMath

public struct MaterialTextureMask : OptionSet {
    public let rawValue : Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let baseColour = MaterialTextureMask(rawValue: 1)
    public static let emissive = MaterialTextureMask(rawValue: 2)
    public static let smoothness = MaterialTextureMask(rawValue: 4)
    public static let metalMask = MaterialTextureMask(rawValue: 8)
    public static let reflectance = MaterialTextureMask(rawValue: 16)
}

//See p13 of Moving Frostbite to PBR course notes
public struct Material {
    
    public var baseColour : vec4 = vec4(0.5)
    public var emissive : vec4 = vec4(0)
    
    public var smoothness : Float = 0.5
    public var metalMask : Float = 0
    public var reflectance : Float = 0.5
    public var materialTextureMask : MaterialTextureMask = []
    
    public var f0 : vec3 {
        return lerp(from: vec3(0.16 * reflectance * reflectance), to: self.baseColour.rgb, t: self.metalMask)
    }
    
    public var albedo : vec3 {
        return lerp(from: self.baseColour.rgb, to: vec3(0), t: self.metalMask)
    }
    
    public var perceptuallyLinearRoughness : Float {
        return 1 - self.smoothness
    }
    
    public var roughness : Float {
        return self.perceptuallyLinearRoughness * self.perceptuallyLinearRoughness
    }
}