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
    case Colour(vec3)
    
    //Adapted from http://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/
    func kelvinToRGB(_ kelvin: Kelvin) -> vec3 {
        let temperature = kelvin / 100.0
        
        var colour = vec3(0)
        
        
        if temperature <= 66.0 {
            colour.r = 255.0
        } else {
            colour.r = temperature - 60.0
            colour.r = 329.698727446 * pow(colour.r, -0.1332047592)
            colour.r = clamp(colour.r, min: 0.0, max: 255.0)
        }
        
        if temperature <= 66.0 {
            colour.g = temperature
            colour.g = 99.4708025861 * log(colour.g) - 161.1195681661
        } else {
            colour.g = temperature - 60.0
            colour.g = 288.1221695283 * pow(colour.g, -0.0755148492)
        }
        colour.g = clamp(colour.g, min: 0.0, max: 255.0)
        
        
        if temperature >= 66.0 {
            colour.b = 255.0
        } else {
            if temperature <= 19.0 {
                colour.b = 0.0
            } else {
                colour.b = temperature - 10.0
                colour.b = 138.5177312231 * log(colour.b) - 305.0447927307
                colour.b = clamp(colour.b, min: 0.0, max: 255.0)
            }
        }

        return colour * vec3(1.0/255.0)
    }
    
    var rgbColour : vec3 {
        switch self {
        case .Colour(let colour):
            return colour
        case .Temperature(let kelvin):
            return kelvinToRGB(kelvin)
        }
    }
}

enum LightType {
    case Point
    case Spot(innerCutoff: Float, outerCutoff: Float)
    case Directional
    
    private var lightTypeFlag : LightTypeFlag {
        switch self {
        case .Point:
            return .Point
        case .Spot(_, _):
            return .Spot
        case .Directional(_):
            return .Directional
        }
    }
    
    func fillGPULight(gpuLight: inout GPULight) {
        gpuLight.lightTypeFlag = self.lightTypeFlag
        
    }
}

final class Light {
    var sceneNode : SceneNode! = nil {
        didSet {
            self.transformDidChange()
        }
    }
    
    var type : LightType {
        didSet {
            self.backingGPULight.withElement { self.type.fillGPULight(gpuLight: &$0) }
        }
    }
    
    var colour : LightColourMode {
        didSet {
            self.backingGPULight.withElement { $0.colour = self.colour.rgbColour }
        }
    }
    
    var intensity : Candelas {
        get {
            return self.backingGPULight.readOnlyElement.intensity
        }
        set (newValue) {
            self.backingGPULight.withElement { gpuLight in
                gpuLight.intensity = newValue
            }
        }
    }
    
    var falloffRadius : Float {
        didSet {
            self.backingGPULight.withElement { gpuLight in
                let radiusSquared = self.falloffRadius * self.falloffRadius
                let inverseRadiusSquared = 1.0 / radiusSquared
                gpuLight.inverseSquareAttenuationRadius = inverseRadiusSquared
            }
        }
    }
    
    var backingGPULight : GPUBufferElement<GPULight>
    
    init(type: LightType, colour: LightColourMode, intensity: Candelas, falloffRadius: Float, backingGPULight: GPUBufferElement<GPULight>) {
        self.type = type
        self.backingGPULight = backingGPULight
        self.colour = colour
        self.falloffRadius = falloffRadius
        self.intensity = intensity
        
        self.backingGPULight.withElement { gpuLight in
            let radiusSquared = self.falloffRadius * self.falloffRadius
            let inverseRadiusSquared = 1.0 / radiusSquared
            gpuLight.inverseSquareAttenuationRadius = inverseRadiusSquared
            
            gpuLight.colour = self.colour.rgbColour
            
            self.type.fillGPULight(gpuLight: &gpuLight)
        }
    }
    
    func transformDidChange() {
        if let sceneNode = self.sceneNode {
            self.backingGPULight.withElement { $0.lightToWorld = sceneNode.transform.nodeToWorldMatrix }
        }
    }
}

enum LightTypeFlag : UInt32 {
    case Point = 0
    case Directional = 1
    case Spot = 2
}


struct GPULight {
    var lightToWorld : mat4
    var colourAndIntensity : vec4
    var extraData = vec4(0)
    var lightTypeFlag : LightTypeFlag
    var inverseSquareAttenuationRadius : Float
    
    var colour : vec3 {
        get {
            return self.colourAndIntensity.rgb
        }
        set (newColour) {
            self.colourAndIntensity.rgb = newColour
        }
    }
    
    var intensity : Candelas {
        get {
            return self.colourAndIntensity.a
        }
        set (newIntensity) {
            self.colourAndIntensity.a = newIntensity
        }
    }
}
