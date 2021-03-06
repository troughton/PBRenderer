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
    case temperature(Kelvin)
    case colour(vec3)
    
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
        case .colour(let colour):
            return colour
        case .temperature(let kelvin):
            return kelvinToRGB(kelvin)
        }
    }
}

public enum LightIntensity {
    case luminousPower(Lumens)
    case luminance(CandelasPerMetreSq)
    case luminousIntensity(Candelas)
    case illuminance(Lux)
    
    public init(unit: LightIntensity, value: Float) {
        switch unit {
        case .luminousPower(_):
            self = .luminousPower(value)
        case .illuminance(_):
            self = .illuminance(value)
        case .luminance(value):
            self = .luminance(value)
        case .luminousIntensity(_):
            self = .luminousIntensity(value)
        default:
            fatalError()
        }
    }
    
    public func toLuminousIntensity(forLightType lightType: LightType) -> Candelas {
        
        switch self {
        case let .luminousIntensity(candelas):
            return candelas
        case let .luminance(candelasPerMetreSq):
            return candelasPerMetreSq * lightType.surfaceArea
        case let .luminousPower(lumens):
            switch lightType {
            case .sunArea(_):
                fallthrough
            case .sphereArea(_):
                fallthrough
            case .point:
                return lumens / (4 * Float(M_PI))
            case .diskArea(_):
                fallthrough
            case .spot(innerCutoff: _, outerCutoff: _):
                return lumens * Float(M_PI) //not physically correct, but prevents the intensity from changing as the angle changes.
            case .triangleArea(_, _, _):
                fallthrough
            case .rectangleArea(_, _, _):
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
            case let .luminousIntensity(candelas):
                return candelas
            case let .luminance(candelasPerMetreSq):
                return candelasPerMetreSq
            case let .luminousPower(lumens):
                return lumens
            case let .illuminance(lux):
                return lux
            }
        }
        set(newValue) {
            switch self {
            case .luminousIntensity(_):
                self = .luminousIntensity(newValue)
            case .luminance(_):
                self = .luminance(newValue)
            case .luminousPower(_):
                self = .luminousPower(newValue)
            case .illuminance(_):
                self = .illuminance(newValue)
            }
        }
        
    }
    
    
    func toStoredIntensity(forLightType lightType: LightType) -> Float {
        
        switch self {
        case let .illuminance(lux):
            return lux
        default:
            return self.toLuminousIntensity(forLightType: lightType)
        }
    }
    
    public func isSameTypeAs(_ other: LightIntensity) -> Bool {
        switch self {
        case .illuminance(_):
            if case .illuminance = other { return true } else { return false }
        case .luminance(_):
            if case .luminance = other { return true } else { return false }
        case .luminousIntensity(_):
            if case .luminousIntensity = other { return true } else { return false }
        case .luminousPower(_):
            if case .luminousPower = other { return true } else { return false }
        }
    }
    
}

public enum LightType {
    case point
    case spot(innerCutoff: Float, outerCutoff: Float)
    case directional
    case sphereArea(radius: Float)
    case diskArea(radius: Float)
    case rectangleArea(width: Float, height: Float, twoSided: Bool)
    case triangleArea(base: Float, height: Float, twoSided: Bool)
    case sunArea(radius: Float)
    
    fileprivate var lightTypeFlag : LightTypeFlag {
        switch self {
        case .point:
            return .point
        case .spot(_, _):
            return .spot
        case .directional(_):
            return .directional
        case .sphereArea(_):
            return .sphereArea
        case .diskArea(_):
            return .diskArea
        case .rectangleArea(_, _, _):
            return .rectangleArea
        case .triangleArea(_, _, _):
            return .triangleArea
        case .sunArea(_):
            return .sunArea
        }
    }
    
    public var validUnits : [LightIntensity] {
        switch self {
        case .point:
            fallthrough
        case .spot(_, _):
            return [.luminousPower(1.0)]
        case .triangleArea(_, _, _):
            fallthrough
        case .rectangleArea(_, _, _):
            fallthrough
        case .diskArea(_):
            fallthrough
        case .sphereArea(_):
            return [.luminousPower(1.0), .luminance(1.0)]
        case .directional:
            return [.illuminance(1.0)]
        case .sunArea(_):
            return [.illuminance(1.0)]
        }
    }
    
    func fillGPULight(_ gpuLight: inout GPULight, light: Light) {
        gpuLight.lightTypeFlag = self.lightTypeFlag
        
        switch self {
        case let .spot(innerCutoff, outerCutoff):
            let cosInner = cos(innerCutoff)
            let cosOuter = cos(outerCutoff)
            
            let lightAngleScale = 1.0 / max(0.001, (cosInner - cosOuter));
            let lightAngleOffset = -cosOuter * lightAngleScale;
            gpuLight.extraData = vec4(lightAngleScale, lightAngleOffset, 0, 0)
        case let .sphereArea(radius):
            gpuLight.extraData = vec4(radius, 0, 0, 0)
        case let .diskArea(radius):
            gpuLight.extraData = vec4(radius, 0, 0, 0)
        case let .rectangleArea(_, _, isTwoSided):
            let bufferIndex = unsafeBitCast(Int32(light.lightPointsBufferIndex), to: Float.self)
            gpuLight.extraData = vec4(bufferIndex, isTwoSided ? 1 : 0, 0, 0)
        case let .triangleArea(_, _, isTwoSided):
            let bufferIndex = unsafeBitCast(Int32(light.lightPointsBufferIndex), to: Float.self)
            gpuLight.extraData = vec4(bufferIndex, isTwoSided ? 1 : 0, 0, 0)
        case let .sunArea(radius):
            gpuLight.extraData = vec4(radius, 0, 0, 0)
        default:
            break
        }
    }
    
    var surfaceArea : Float {
        switch self {
        case let .sphereArea(radius: radius):
            return 4 * Float(M_PI) * radius * radius
        case let .diskArea(radius: radius):
            return Float(M_PI) * radius * radius
        case let .rectangleArea(width: width, height: height, _):
            return width * height
        default:
            fatalError()
        }
    }
    
    public func isSameTypeAs(_ other: LightType) -> Bool {
        switch self {
        case .point:
            if case .point = other { return true } else { return false }
        case .directional:
            if case .directional = other { return true } else { return false }
        case .diskArea(_):
            if case .diskArea(_) = other {
                return true
            } else { return false }
        case .sphereArea(_):
            if case .sphereArea(_) = other {
                return true
            } else { return false }
        case .spot(_, _):
            if case .spot(_, _) = other {
                return true
            } else {
                return false
            }
        case .rectangleArea(_, _, _):
            if case .rectangleArea(_, _, _) = other {
                return true
            } else {
                return false
            }
        case .triangleArea(_, _, _):
            if case .triangleArea(_, _, _) = other {
                return true
            } else {
                return false
            }
        case .sunArea(_):
            if case .sunArea(_) = other {
                return true
            } else {
                return false
            }
        }
    }
}


public final class Light {
    
    fileprivate static let initialLightPointBufferCapacity = 128
    
    fileprivate static let maxPointsPerLight = 4
    
    fileprivate static var lightPointCount = 0
    fileprivate static var lightPointsGPUBuffer = GPUBuffer<vec4>(capacity: initialLightPointBufferCapacity, bufferBinding: GL_UNIFORM_BUFFER, accessFrequency: .dynamic, accessType: .draw)
    
    static let pointsTexture = Texture(buffer: Light.lightPointsGPUBuffer, internalFormat: GL_RGBA32F)
    
    public var sceneNode : SceneNode! = nil {
        didSet {
            self.transformDidChange()
        }
    }
    
    public var type : LightType {
        didSet {
            self.backingGPULight.withElement { self.type.fillGPULight(&$0, light: self) }
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
    
    public var falloffRadiusOrInfinity : Float {
        switch self.type {
        case .directional:
            fallthrough
        case .sunArea(radius: _):
            return 1048576 //a very large number (2^20 metres) since actual infinity causes issues.
        default:
            return self.falloffRadius
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
            Light.lightPointsGPUBuffer.reserveCapacity(Light.lightPointsGPUBuffer.capacity * 2)
            print("Doubling light points capacity. (This may or may not work)")
        }
        
        // only the sun (and only the first sun in the scene) has a shadow map at the moment
        if type.isSameTypeAs(.sunArea(radius: 1.0)) {
            shadowMapArrayIndex = 1
        }
        
        self.backingGPULight.withElement { gpuLight in
            let radiusSquared = self.falloffRadius * self.falloffRadius
            let inverseRadiusSquared = 1.0 / radiusSquared
            gpuLight.inverseSquareAttenuationRadius = inverseRadiusSquared
            
            gpuLight.colourAndIntensity = vec4(self.colour.rgbColour, intensity.toStoredIntensity(forLightType: self.type))
            self.type.fillGPULight(&gpuLight, light: self)
        }
    }
    
    func transformDidChange() {
        self.backingGPULight.withElement { gpuLight in
            gpuLight.worldSpacePosition  = self.sceneNode.transform.worldSpacePosition;
            gpuLight.worldSpaceDirection = self.sceneNode.transform.worldSpaceDirection;
        }
        
        self.lightPointsDidChange()
    }
    
    
    fileprivate func lightPointsDidChange() {
        if self.sceneNode == nil {
            return
        }
        switch self.type {
        case let .rectangleArea(width, height, _):
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
        case let .triangleArea(base, height, _):
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
    case point = 0
    case directional = 1
    case spot = 2
    case sphereArea = 3
    case diskArea = 4
    case rectangleArea = 5
    case triangleArea = 6
    case sunArea = 7
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
