//
//  PunctualLight.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 13/05/16.
//
//

import Foundation
import SGLMath

public typealias Kelvin = Float

public typealias Lux = Float
public typealias Lumens = Float
/** Luminous efficacy. */
public typealias LumensPerWatt = Float

public typealias ExposureValue = Float

public typealias CandelasPerMetreSq = Float

//Luminous Intensity
public typealias Candelas = Float

//Using K = 12.5
func luminanceFromEV(_ ev: ExposureValue) -> CandelasPerMetreSq {
    return pow(2, ev - 3)
}

public enum LightColourMode {
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
    
   public var rgbColour : vec3 {
        switch self {
        case .Colour(let colour):
            return colour
        case .Temperature(let kelvin):
            return kelvinToRGB(kelvin)
        }
    }
}

public enum LightIntensity {
    case LuminousPower(Lumens)
    case Luminance(CandelasPerMetreSq)
    case LuminousIntensity(Candelas)
    case Illuminance(Lux)
    
    public init(unit: LightIntensity, value: Float) {
        switch unit {
        case .LuminousPower(_):
            self = .LuminousPower(value)
        case .Illuminance(_):
            self = .Illuminance(value)
        case .Luminance(value):
            self = .Luminance(value)
        case .LuminousIntensity(_):
            self = .LuminousIntensity(value)
        default:
            fatalError()
        }
    }
    
    public func toLuminousIntensity(forLightType lightType: LightType) -> Candelas {
        
        switch self {
        case let .LuminousIntensity(candelas):
            return candelas
        case let .Luminance(candelasPerMetreSq):
            return candelasPerMetreSq * lightType.surfaceArea
        case let .LuminousPower(lumens):
            switch lightType {
            case .Point:
                return lumens / (4 * Float(M_PI))
            case .Spot(innerCutoff: _, outerCutoff: _):
                return lumens * Float(M_PI) //not correct, but prevents the intensity from changing as the angle changes.
            default:
                fatalError()
            }
        default:
            fatalError()
        }
    }
    
    public var value : Float {
        get {
            switch self {
            case let .LuminousIntensity(candelas):
                return candelas
            case let .Luminance(candelasPerMetreSq):
                return candelasPerMetreSq
            case let .LuminousPower(lumens):
                return lumens
            case let .Illuminance(lux):
                return lux
            }
        }
        set(newValue) {
            switch self {
            case .LuminousIntensity(_):
                self = .LuminousIntensity(newValue)
            case .Luminance(_):
                self = .Luminance(newValue)
            case .LuminousPower(_):
                self = .LuminousPower(newValue)
            case .Illuminance(_):
                self = .Illuminance(newValue)
            }
        }

    }
    
    
    func toStoredIntensity(forLightType lightType: LightType) -> Float {
        
        switch self {
        case let .Illuminance(lux):
            return lux
        default:
            return self.toLuminousIntensity(forLightType: lightType)
        }
    }
}

public enum LightType {
    case Point
    case Spot(innerCutoff: Float, outerCutoff: Float)
    case Directional
    case SphereArea(radius: Float)
    case DiskArea(radius: Float)
    
    private var lightTypeFlag : LightTypeFlag {
        switch self {
        case .Point:
            return .Point
        case .Spot(_, _):
            return .Spot
        case .Directional(_):
            return .Directional
        case .SphereArea(_):
            return .SphereArea
        case .DiskArea(_):
            return .DiskArea
        }
    }
    
    public var validUnits : [LightIntensity] {
        switch self {
        case .Point:
        fallthrough
        case .Spot(_, _):
            return [.LuminousPower(1.0)]
        case .DiskArea(_):
            fallthrough
        case .SphereArea(_):
            return [.LuminousPower(1.0), .Luminance(1.0)]
        case .Directional:
            return [.Illuminance(1.0)]
        }
    }
    
    func fillGPULight(gpuLight: inout GPULight) {
        gpuLight.lightTypeFlag = self.lightTypeFlag
        
        switch self {
        case let .Spot(innerCutoff, outerCutoff):
            let cosInner = cos(innerCutoff)
            let cosOuter = cos(outerCutoff)
            
            let lightAngleScale = 1.0 / max(0.001, (cosInner - cosOuter));
            let lightAngleOffset = -cosOuter * lightAngleScale;
            gpuLight.extraData = vec4(lightAngleScale, lightAngleOffset, 0, 0)
        case let .SphereArea(radius):
            gpuLight.extraData = vec4(radius, 0, 0, 0)
        case let .DiskArea(radius):
            gpuLight.extraData = vec4(radius, 0, 0, 0)
        default:
            break
        }
    }
    
    var surfaceArea : Float {
        switch self {
        case let .SphereArea(radius: radius):
            return 4 * Float(M_PI) * radius * radius
        case let .DiskArea(radius: radius):
            return Float(M_PI) * radius * radius
        default:
            fatalError()
        }
    }
}

public final class Light {
    public var sceneNode : SceneNode! = nil {
        didSet {
            self.transformDidChange()
        }
    }
    
    public var type : LightType {
        didSet {
            self.backingGPULight.withElement { self.type.fillGPULight(gpuLight: &$0) }
        }
    }
    
    public var colour : LightColourMode {
        didSet {
            self.backingGPULight.withElement { $0.colour = self.colour.rgbColour }
        }
    }
    
    
    public var intensity : LightIntensity {
        didSet {
            self.backingGPULight.withElement { gpuLight in
                gpuLight.intensity = self.intensity.toLuminousIntensity(forLightType: self.type)
            }
        }
    }
    
    public var falloffRadius : Float {
        didSet {
            self.backingGPULight.withElement { gpuLight in
                let radiusSquared = self.falloffRadius * self.falloffRadius
                let inverseRadiusSquared = 1.0 / radiusSquared
                gpuLight.inverseSquareAttenuationRadius = inverseRadiusSquared
            }
        }
    }
    
    public var isOn : Bool {
        return self.intensity.value > 0
    }
    
    var backingGPULight : GPUBufferElement<GPULight>
    
    init(type: LightType, colour: LightColourMode, intensity: LightIntensity, falloffRadius: Float, backingGPULight: GPUBufferElement<GPULight>) {
        self.type = type
        self.backingGPULight = backingGPULight
        self.colour = colour
        self.falloffRadius = falloffRadius
        self.intensity = intensity
        
        self.backingGPULight.withElement { gpuLight in
            let radiusSquared = self.falloffRadius * self.falloffRadius
            let inverseRadiusSquared = 1.0 / radiusSquared
            gpuLight.inverseSquareAttenuationRadius = inverseRadiusSquared
            
            gpuLight.colourAndIntensity = vec4(self.colour.rgbColour, intensity.toStoredIntensity(forLightType: self.type))
            self.type.fillGPULight(gpuLight: &gpuLight)
        }
    }
    
    func transformDidChange() {
        self.backingGPULight.withElement { gpuLight in
            gpuLight.worldSpacePosition  = self.sceneNode.transform.worldSpacePosition;
            gpuLight.worldSpaceDirection = self.sceneNode.transform.worldSpaceDirection;
        }
    }
}

enum LightTypeFlag : UInt32 {
    case Point = 0
    case Directional = 1
    case Spot = 2
    case SphereArea = 3
    case DiskArea = 4
}


struct GPULight {
    var colourAndIntensity : vec4
    var worldSpacePosition : vec4
    var worldSpaceDirection : vec4
    var extraData = vec4(0)
    var lightTypeFlag : LightTypeFlag
    var inverseSquareAttenuationRadius : Float
    var padding = vec2(0)
    
    var colour : vec3 {
        get {
            return self.colourAndIntensity.rgb
        }
        set (newColour) {
            self.colourAndIntensity.rgb = normalize(newColour)
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
