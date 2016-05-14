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
struct Material {
    
    var baseColour : vec3 = vec3(0.5)
    var smoothness : Float = 0.5
    var metalMask : Float = 0
    var reflectance : Float = 0.5
    
    var f0 : Float {
        return 0.16 * reflectance * reflectance
    }
    
    var perceptuallyLinearRoughness : Float {
        return 1 - self.smoothness
    }
    
    var roughness : Float {
        return self.perceptuallyLinearRoughness * self.perceptuallyLinearRoughness
    }
}