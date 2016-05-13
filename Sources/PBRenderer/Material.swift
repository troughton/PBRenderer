//
//  Material.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 3/05/16.
//
//

import Foundation
import SGLMath

protocol Material {
    var materialID : Int { get }
}

//See p13 of Moving Frostbite to PBR course notes
struct DisneyBaseMaterial : Material {

    let materialID: Int = 0
    
    let baseColour : vec3
    let smoothness : Float
    let metalMask : Float
    let reflectance : Float
    
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