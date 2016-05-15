//
//  PunctualLight.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 13/05/16.
//
//

import Foundation
import SGLMath

typealias Kelvin = Float

/** Luminous efficacy. */
typealias LumensPerWatt = Float

typealias ExposureValue = Float

typealias CandelasPerMetreSq = Float

//Luminous Intensity
typealias Candelas = Float

//Using K = 12.5
func luminanceFromEV(_ ev: ExposureValue) -> CandelasPerMetreSq {
    return pow(2, ev - 3)
}

enum LightColourMode {
    case Temperature(Kelvin)
    case Colour(vec4)
}

struct Light {
    var colour : LightColourMode
    var intensity : Candelas
    
    let falloffRadius : Float
}