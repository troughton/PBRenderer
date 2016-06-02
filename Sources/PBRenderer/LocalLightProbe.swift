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


public final class LocalLightProbe {
    
    let localCubeMap : Texture
    public let ldTexture : LDTexture
    public let resolution : Int
    
    private let colourAttachments : [RenderPassColourAttachment]
    private let sceneRenderers : [SceneRenderer]
    
    public init(resolution: Int) {
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
            
            sceneRenderer.renderScene(scene, camera: camera, environmentMap: nil)
        }
        
        self.localCubeMap.generateMipmaps()

        return camera.exposure
    }
    
    public func render(scene: Scene, atPosition position: vec3, zNear: Float, zFar: Float) {
        let exposureUsed = self.renderSceneToCubeMap(scene, atPosition: position, zNear: zNear, zFar: zFar)
        
        LDTexture.fillLDTexturesFromCubeMaps(textures: [self.ldTexture], cubeMaps: [self.localCubeMap], valueMultipliers: [1.0 / exposureUsed])
    }
    
}