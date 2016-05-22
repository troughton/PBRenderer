//
//  Material.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 3/05/16.
//
//

import Foundation
import SGLMath

//See p13 of Moving Frostbite to PBR course notes
public struct Material {
    
    public var baseColour : vec3 = vec3(0.5)
    
    public var smoothness : Float = 0.5
    public var metalMask : Float = 0
    public var reflectance : Float = 0.5
    
    public var f0 : Float {
        return 0.16 * reflectance * reflectance
    }
    
    public var perceptuallyLinearRoughness : Float {
        return 1 - self.smoothness
    }
    
    public var roughness : Float {
        return self.perceptuallyLinearRoughness * self.perceptuallyLinearRoughness
    }
}