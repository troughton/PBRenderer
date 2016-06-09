//
//  PunctualLight.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 13/05/16.
//
//

import Foundation
import SGLMath
import SGLOpenGL

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
            case .SunArea(_):
                fallthrough
            case .SphereArea(_):
                fallthrough
            case .Point:
                return lumens / (4 * Float(M_PI))
            case .DiskArea(_):
                fallthrough
            case .Spot(innerCutoff: _, outerCutoff: _):
                return lumens * Float(M_PI) //not correct, but prevents the intensity from changing as the angle changes.
            case .TriangleArea(_, _):
                fallthrough
            case .RectangleArea(_, _):
                return lumens // TODO this is not correct at all.
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
    
    public func isSameTypeAs(_ other: LightIntensity) -> Bool {
        switch self {
        case .Illuminance(_):
            if case .Illuminance = other { return true } else { return false }
        case .Luminance(_):
            if case .Luminance = other { return true } else { return false }
        case .LuminousIntensity(_):
            if case .LuminousIntensity = other { return true } else { return false }
        case .LuminousPower(_):
            if case .LuminousPower = other { return true } else { return false }
        }
    }
    
}

public enum LightType {
    case Point
    case Spot(innerCutoff: Float, outerCutoff: Float)
    case Directional
    case SphereArea(radius: Float)
    case DiskArea(radius: Float)
    case RectangleArea(width: Float, height: Float)
    case TriangleArea(base: Float, height: Float)
    case SunArea(radius: Float)
    
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
        case .RectangleArea(_, _):
            return .RectangleArea
        case .TriangleArea(_, _):
            return .TriangleArea
        case .SunArea(_):
            return .SunArea
        }
    }
    
    public var validUnits : [LightIntensity] {
        switch self {
        case .Point:
            fallthrough
        case .Spot(_, _):
            return [.LuminousPower(1.0)]
        case .TriangleArea(_, _):
            fallthrough
        case .RectangleArea(_, _):
            fallthrough
        case .DiskArea(_):
            fallthrough
        case .SphereArea(_):
            return [.LuminousPower(1.0), .Luminance(1.0)]
        case .Directional:
            return [.Illuminance(1.0)]
        case .SunArea(_):
            return [.Illuminance(1.0)]
        }
    }
    
    func fillGPULight(gpuLight: inout GPULight, light: Light) {
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
        case .RectangleArea(_, _):
            let bufferIndex = unsafeBitCast(Int32(light.lightPointsBufferIndex), to: Float.self)
            gpuLight.extraData = vec4(bufferIndex, 0, 0, 0)
        case let .SunArea(radius):
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
        case let .RectangleArea(width: width, height: height):
            return width * height
        default:
            fatalError()
        }
    }
    
    public func isSameTypeAs(_ other: LightType) -> Bool {
        switch self {
        case .Point:
            if case .Point = other { return true } else { return false }
        case .Directional:
            if case .Directional = other { return true } else { return false }
        case .DiskArea(_):
            if case .DiskArea(_) = other {
                return true
            } else { return false }
        case .SphereArea(_):
            if case .SphereArea(_) = other {
                return true
            } else { return false }
        case .Spot(_, _):
            if case .Spot(_, _) = other {
                return true
            } else {
                return false
            }
        case .RectangleArea(_, _):
            if case .RectangleArea(_, _) = other {
                return true
            } else {
                return false
            }
        case .TriangleArea(_, _):
            if case .TriangleArea(_, _) = other {
                return true
            } else {
                return false
            }
        case .SunArea(_):
            if case .SunArea(_) = other {
                return true
            } else {
                return false
            }
        }
    }
}


public final class Light {
    
    private static let initialLightPointBufferCapacity = 128
    
    private static let maxPointsPerLight = 4
    
    private static var lightPointCount = 0
    private static var lightPointsGPUBuffer = GPUBuffer<vec4>(capacity: initialLightPointBufferCapacity, bufferBinding: GL_UNIFORM_BUFFER, accessFrequency: .Dynamic, accessType: .Draw)
    
    static let pointsTexture = Texture(buffer: Light.lightPointsGPUBuffer, internalFormat: GL_RGBA32F)
    
    public var sceneNode : SceneNode! = nil {
        didSet {
            self.transformDidChange()
        }
    }
    
    public var type : LightType {
        didSet {
            self.backingGPULight.withElement { self.type.fillGPULight(gpuLight: &$0, light: self) }
            self.lightPointsDidChange()
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
                gpuLight.intensity = self.intensity.toStoredIntensity(forLightType: self.type)
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
    var lightPointsBufferIndex : Int
    var shadowMapArrayIndex : Int?
    
    init(type: LightType, colour: LightColourMode, intensity: LightIntensity, falloffRadius: Float, backingGPULight: GPUBufferElement<GPULight>) {
        self.type = type
        self.backingGPULight = backingGPULight
        self.colour = colour
        self.falloffRadius = falloffRadius
        self.intensity = intensity
        
        // every light has space for points allocated to it even if it doesn't use it
        // TODO: wrap GPUBuffer in a dynamic array that can resize
        self.lightPointsBufferIndex = Light.lightPointCount
        Light.lightPointCount += Light.maxPointsPerLight
        
        // double the light points buffer if we run out of space
        if Light.lightPointCount > Light.lightPointsGPUBuffer.capacity {
            Light.lightPointsGPUBuffer.reserveCapacity(capacity: Light.lightPointsGPUBuffer.capacity * 2)
            print("Doubling light points capacity. (This may or may not work)")
        }
        
        // only the sun (and only the first sun in the scene) has a shadow map at the moment
        if type.isSameTypeAs(.SunArea(radius: 1.0)) {
            shadowMapArrayIndex = 1
        }
        
        self.backingGPULight.withElement { gpuLight in
            let radiusSquared = self.falloffRadius * self.falloffRadius
            let inverseRadiusSquared = 1.0 / radiusSquared
            gpuLight.inverseSquareAttenuationRadius = inverseRadiusSquared
            
            gpuLight.colourAndIntensity = vec4(self.colour.rgbColour, intensity.toStoredIntensity(forLightType: self.type))
            self.type.fillGPULight(gpuLight: &gpuLight, light: self)
        }
    }
    
    func transformDidChange() {
        self.backingGPULight.withElement { gpuLight in
            gpuLight.worldSpacePosition  = self.sceneNode.transform.worldSpacePosition;
            gpuLight.worldSpaceDirection = self.sceneNode.transform.worldSpaceDirection;
        }
        
        self.lightPointsDidChange()
    }
    
    
    private func lightPointsDidChange() {
        switch self.type {
        case let .RectangleArea(width, height):
            let upInWorldSpace = normalize(self.sceneNode.transform.nodeToWorldMatrix * vec4.up);
            let rightInWorldSpace = normalize(self.sceneNode.transform.nodeToWorldMatrix * vec4.right);
            
            let centre = self.sceneNode.transform.worldSpacePosition
            
            var topRight = centre + width * 0.5 * rightInWorldSpace
            topRight += height * 0.5 * upInWorldSpace
            
            var topLeft = centre - width * 0.5 * rightInWorldSpace
            topLeft += height * 0.5 * upInWorldSpace
            
            var bottomLeft = centre - width * 0.5 * rightInWorldSpace
            bottomLeft -= height * 0.5 * upInWorldSpace
            
            var bottomRight = centre + width * 0.5 * rightInWorldSpace
            bottomRight -= height * 0.5 * upInWorldSpace
            
            let range : Range<Int> = lightPointsBufferIndex..<lightPointsBufferIndex + 4 //4 vertices for a rectangle
            Light.lightPointsGPUBuffer[range] = [topRight, topLeft, bottomLeft, bottomRight]
            Light.lightPointsGPUBuffer.didModifyRange(range)
        case let .TriangleArea(base, height):
            let upInWorldSpace = normalize(self.sceneNode.transform.nodeToWorldMatrix * vec4.up);
            let rightInWorldSpace = normalize(self.sceneNode.transform.nodeToWorldMatrix * vec4.right);
            
            let centre = self.sceneNode.transform.worldSpacePosition
            
            let top = centre + height * 0.5 * upInWorldSpace
            
            var bottomLeft = centre - base * 0.5 * rightInWorldSpace
            bottomLeft -= height * 0.5 * upInWorldSpace
            
            var bottomRight = centre + base * 0.5 * rightInWorldSpace
            bottomRight -= height * 0.5 * upInWorldSpace
            
            let range : Range<Int> = lightPointsBufferIndex..<lightPointsBufferIndex + 3 // 3 vertices for triangle
            Light.lightPointsGPUBuffer[range] = [top, bottomLeft, bottomRight]
            Light.lightPointsGPUBuffer.didModifyRange(range)
        default:
            break
        }
    }
}

enum LightTypeFlag : UInt32 {
    case Point = 0
    case Directional = 1
    case Spot = 2
    case SphereArea = 3
    case DiskArea = 4
    case RectangleArea = 5
    case TriangleArea = 6
    case SunArea = 7
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
