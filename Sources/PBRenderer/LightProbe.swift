//
//  LocalLightProbe.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 2/06/16.
//
//

import Foundation
import SGLMath
import SGLOpenGL

struct GPULightProbe {
    var boundingVolumeWorldToLocal : mat4
    var cubeMapPosition : vec4
    var isEnvironmentMap : Int32
    var mipMaxLevel : Int32
    let padding2 = Int32(0)
    let padding3 = Int32(0)
};

public final class LightProbe {
    
    static let maxTotalLightProbes = 64
    static let maxLightProbesPerPass = 4 //because we're limited by the amount of available texture units.
    
    static let lightProbeBuffer = GPUBuffer<GPULightProbe>(capacity: maxTotalLightProbes, bufferBinding: GL_UNIFORM_BUFFER, accessFrequency: .Dynamic, accessType: .Draw)
    static var lightProbeCount = 0
    
    
    public var sceneNode : SceneNode! = nil {
        didSet {
            self.backingElement.withElement { (backingElement) -> Void in
                backingElement.boundingVolumeWorldToLocal = self.transform.worldToNodeMatrix
            }
        }
    }
    
    public var transform : Transform {
        return self.sceneNode.transform
    }
    
    var worldSpaceVertices : [vec3] {
        let vertices = [vec4(-1, -1, -1, 1), vec4(-1, -1, 1, 1), vec4(-1, 1, -1, 1), vec4(-1, 1, 1, 1), vec4(1, -1, -1, 1), vec4(1, -1, 1, 1), vec4(1, 1, -1, 1), vec4(1, 1, 1, 1)]
        return vertices.map { (self.transform.nodeToWorldMatrix * $0).xyz }
    }
    
    var boundingVolumeSize : Float {
        let minX = self.transform.nodeToWorldMatrix * vec4(-1, 0, 0, 1)
        let maxX = self.transform.nodeToWorldMatrix * vec4(1, 0, 0, 1)
        let minY = self.transform.nodeToWorldMatrix * vec4(0, -1, 0, 1)
        let maxY = self.transform.nodeToWorldMatrix * vec4(0, 1, 0, 1)
        let minZ = self.transform.nodeToWorldMatrix * vec4(0, 0, -1, 1)
        let maxZ = self.transform.nodeToWorldMatrix * vec4(0, 0, 1, 1)
        
        let width = distance(p0: minX, maxX)
        let height = distance(p0: minY, maxY)
        let depth = distance(p0: minZ, maxZ)
        
        return width * height * depth
    }
    
    var cubeMapWorldSpacePosition : vec3
    
    let localCubeMap : Texture
    public let ldTexture : LDTexture
    public let resolution : Int
    public let nearPlane : Float
    public let farPlane : Float
    
    private let colourAttachments : [RenderPassColourAttachment]
    private let sceneRenderers : [SceneRenderer]
    
    private let backingElement : GPUBufferElement<GPULightProbe>
    
    public var indexInBuffer : Int {
        return self.backingElement.bufferIndex
    }
    
    public init(localLightProbeWithResolution resolution: Int, position: vec3, nearPlane: Float, farPlane: Float) {
        
        let cubeMapDescriptor = TextureDescriptor(textureCubeWithPixelFormat: GL_RGBA16F, width: resolution, height: resolution, mipmapped: true)
        let localCubeMap = Texture(textureWithDescriptor: cubeMapDescriptor)
        self.localCubeMap = localCubeMap
        
        self.resolution = resolution
        self.ldTexture = LDTexture(specularResolution: resolution)
        
        self.colourAttachments = (0..<UInt(6)).map { (slice) -> RenderPassColourAttachment in
            let blendState = BlendState(isBlendingEnabled: true, sourceRGBBlendFactor: GL_ONE, destinationRGBBlendFactor: GL_ONE, rgbBlendOperation: GL_FUNC_ADD, sourceAlphaBlendFactor: GL_ZERO, destinationAlphaBlendFactor: GL_ONE, alphaBlendOperation: GL_FUNC_ADD, writeMask: .All)
            
            var colourAttachment = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
            colourAttachment.texture = localCubeMap
            colourAttachment.loadAction = .Load
            colourAttachment.storeAction = .Store
            colourAttachment.blendState = blendState
            colourAttachment.textureSlice = slice
            return colourAttachment
        }
        
        self.sceneRenderers = self.colourAttachments.map { SceneRenderer(lightProbeRendererWithLightAccumulationAttachment: $0) }
        
        self.backingElement = LightProbe.lightProbeBuffer[viewForIndex: LightProbe.lightProbeCount]
        LightProbe.lightProbeCount += 1
        
        self.cubeMapWorldSpacePosition = position ?? vec3(0)
        
        self.nearPlane = nearPlane
        self.farPlane = farPlane
        
        self.backingElement.withElement { (backingElement) -> Void in
            backingElement.cubeMapPosition = vec4(self.cubeMapWorldSpacePosition, 1)
            backingElement.isEnvironmentMap = 0
            backingElement.mipMaxLevel = Int32(self.ldTexture.specularTexture.descriptor.mipmapLevelCount - 1)
        }
    }
    
    /** If there's no position, we assume it's an environment map. */
    public init(environmentMapWithResolution resolution: Int, texture: Texture, exposureMultiplier: Float) {
        
        self.sceneNode = nil
        self.nearPlane = 0.0
        self.farPlane = Float.infinity
        
        self.localCubeMap = texture
        
        self.resolution = resolution
        self.ldTexture = LDTexture(specularResolution: resolution)
        
        self.colourAttachments = (0..<UInt(6)).map { (slice) -> RenderPassColourAttachment in
            let blendState = BlendState(isBlendingEnabled: true, sourceRGBBlendFactor: GL_ONE, destinationRGBBlendFactor: GL_ONE, rgbBlendOperation: GL_FUNC_ADD, sourceAlphaBlendFactor: GL_ZERO, destinationAlphaBlendFactor: GL_ONE, alphaBlendOperation: GL_FUNC_ADD, writeMask: .All)
            
            var colourAttachment = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
            colourAttachment.texture = texture
            colourAttachment.loadAction = .Load
            colourAttachment.storeAction = .Store
            colourAttachment.blendState = blendState
            colourAttachment.textureSlice = slice
            return colourAttachment
        }
        
        self.sceneRenderers = []
        
        self.backingElement = LightProbe.lightProbeBuffer[viewForIndex: LightProbe.lightProbeCount]
        LightProbe.lightProbeCount += 1
        
        self.cubeMapWorldSpacePosition = vec3(0)
        
        self.backingElement.withElement { (backingElement) -> Void in
            backingElement.isEnvironmentMap = 0
            backingElement.mipMaxLevel = Int32(self.ldTexture.specularTexture.descriptor.mipmapLevelCount - 1)
        }
        
        LDTexture.fillLDTexturesFromCubeMaps(textures: [self.ldTexture], cubeMaps: [self.localCubeMap], valueMultipliers: [exposureMultiplier])
    }
    
    func transformDidChange() {
        self.backingElement.withElement { (backingElement) -> Void in
            backingElement.boundingVolumeWorldToLocal = self.transform.worldToNodeMatrix
        }
    }
    
    func renderSceneToCubeMap(_ scene: Scene, atPosition worldSpacePosition: vec3, zNear: Float, zFar: Float) -> Float {
        
        let projectionMatrix = SGLMath.perspective(Float(M_PI_2), 1.0, zNear, zFar)
        
        let transform = Transform(parent: nil, translation: worldSpacePosition)
        let camera = Camera(id: nil, name: nil, projectionMatrix: projectionMatrix, zNear: zNear, zFar: zFar, aspectRatio: 1.0)
        
        camera.shutterTime = 1.0
        camera.aperture = 1.0
        
        let _ = SceneNode(id: nil, name: nil, transform: transform, cameras: [camera])
        
        for (i, sceneRenderer) in self.sceneRenderers.enumerated() {
            
            switch (i + GL_TEXTURE_CUBE_MAP_POSITIVE_X) {
            case GL_TEXTURE_CUBE_MAP_POSITIVE_X:
                transform.rotation = quat(angle: Float(-M_PI_2), axis: vec3(0, 1, 0))
                transform.rotation *= quat(angle: Float(M_PI), axis: vec3(0, 0, 1))
            case GL_TEXTURE_CUBE_MAP_NEGATIVE_X:
                transform.rotation = quat(angle: Float(M_PI_2), axis: vec3(0, 1, 0))
                transform.rotation *= quat(angle: Float(M_PI), axis: vec3(0, 0, 1))
                
            case GL_TEXTURE_CUBE_MAP_POSITIVE_Y:
                transform.rotation = quat(angle: Float(M_PI_2), axis: vec3(1, 0, 0))
            case GL_TEXTURE_CUBE_MAP_NEGATIVE_Y:
                transform.rotation = quat(angle: Float(-M_PI_2), axis: vec3(1, 0, 0))
            case GL_TEXTURE_CUBE_MAP_NEGATIVE_Z:
                transform.rotation = quat(angle: 0, axis: vec3(0, 1, 0))
                transform.rotation *= quat(angle: Float(M_PI), axis: vec3(0, 0, 1))
            case GL_TEXTURE_CUBE_MAP_POSITIVE_Z:
                transform.rotation = quat(angle: Float(M_PI), axis: vec3(0, 1, 0))
                transform.rotation *= quat(angle: Float(M_PI), axis: vec3(0, 0, 1))
            default:
                fatalError()
                break
            }
            
            sceneRenderer.renderScene(scene, camera: camera, useLightProbes: false)
        }
        
        self.localCubeMap.generateMipmaps()

        return camera.exposure
    }
    
    public func boxContainsPoint(_ point: vec3) -> Bool {
        let localSpacePoint = self.transform.worldToNodeMatrix * vec4(point, 1)
        return localSpacePoint.x >= -0.5 && localSpacePoint.y >= -0.5 && localSpacePoint.z >= -0.5 && localSpacePoint.x <= 0.5 && localSpacePoint.y <= 0.5 && localSpacePoint.z <= 0.5
    }
    
    public func render(scene: Scene) {
        
        let exposureUsed = self.renderSceneToCubeMap(scene, atPosition: cubeMapWorldSpacePosition, zNear: self.nearPlane, zFar: self.farPlane)
        
        LDTexture.fillLDTexturesFromCubeMaps(textures: [self.ldTexture], cubeMaps: [self.localCubeMap], valueMultipliers: [1.0 / exposureUsed])
    }
    
}