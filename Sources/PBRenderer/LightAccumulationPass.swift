//
//  LightAccumulationPass.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 1/06/16.
//
//

import Foundation
import OpenCL
import SGLMath
import SGLOpenGL

final class LightAccumulationPass {
    
    var pipelineState : PipelineState
    
    let lightGridBuffer = GPUBuffer<LightGridEntry>(capacity: 64 * 1024 * 16, bufferBinding: GL_UNIFORM_BUFFER, accessFrequency: .Stream, accessType: .Draw) //16MB
    let lightGridBuilder = LightGridBuilder()
    let lightGridTexture : Texture
    
    init(pixelDimensions: PBWindow.Size, lightAccumulationTexture: Texture) {
        
        let framebuffer = LightAccumulationPass.lightAccumulationFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height, lightAccumulationTexture: lightAccumulationTexture)
        
        let vertexShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughQuad.vert"))
        let fragmentShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LightAccumulationPass.frag"))
        
        let lightAccumulationShader = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_ALWAYS
        depthState.isDepthWriteEnabled = false
        
        self.pipelineState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height),
                                           framebuffer: framebuffer,
                                           shader: lightAccumulationShader,
                                           depthStencilState: depthState)
        
        self.lightGridTexture = Texture(buffer: lightGridBuffer, internalFormat: GL_RGBA32UI)
        
    }
    
    deinit {
    }
    
    class func lightAccumulationFramebuffer(width: GLint, height: GLint, lightAccumulationTexture: Texture) -> Framebuffer {
        
        let blendState = BlendState(isBlendingEnabled: true, sourceRGBBlendFactor: GL_ONE, destinationRGBBlendFactor: GL_ONE, rgbBlendOperation: GL_FUNC_ADD, sourceAlphaBlendFactor: GL_ZERO, destinationAlphaBlendFactor: GL_ONE, alphaBlendOperation: GL_FUNC_ADD, writeMask: .All)
        
        var colourAttachment = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        colourAttachment.texture = lightAccumulationTexture
        colourAttachment.loadAction = .Load
        colourAttachment.storeAction = .Store
        colourAttachment.blendState = blendState
        
        var depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT16, width: Int(width), height: Int(height), mipmapped: false)
        depthDescriptor.usage = .RenderTarget
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor)
    
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.loadAction = .Clear
        depthAttachment.storeAction = .Store
        depthAttachment.texture = depthTexture
        
        return Framebuffer(width: width, height: height, colourAttachments: [colourAttachment], depthAttachment: depthAttachment, stencilAttachment: nil)
    }

    
    
    func resize(newPixelDimensions width: GLint, _ height: GLint, lightAccumulationTexture: Texture) {
        self.pipelineState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
        self.pipelineState.framebuffer = LightAccumulationPass.lightAccumulationFramebuffer(width: width, height: height, lightAccumulationTexture: lightAccumulationTexture)
    }
    
    //Calculates the size of a plane positioned at z = -1 (hence the divide by zNear)
    func calculateNearPlaneSize(zNear: Float, cameraAspect: Float, projectionMatrix: mat4) -> vec2 {
        let tanHalfFoV = 1/(projectionMatrix[0][0] * cameraAspect)
        let y = tanHalfFoV * zNear
        let x = y * cameraAspect
        return vec2(x, y) / zNear
    }
    
    func setupLightGrid(camera: Camera, lights: [Light]) {
        let clusteredGridScale = 16
        self.lightGridBuilder.reset(dim: LightGridDimensions(width: 2 * clusteredGridScale, height: clusteredGridScale, depth: 4 * clusteredGridScale))
        
        self.lightGridBuilder.clearAllFragments()
        RasterizeLights(builder: self.lightGridBuilder, viewerCamera: camera, lights: lights)
        
        self.lightGridBuffer.asMappedBuffer({ (lightGridBuffer) -> Void in
            self.lightGridBuilder.buildAndUpload(gpuBuffer: lightGridBuffer!, bufferSize: self.lightGridBuffer.capacity * sizeof(LightGridEntry))
            }, usage: GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT | GL_MAP_INVALIDATE_RANGE_BIT)
    }
    
    enum LightAccumulationShaderProperty : String, ShaderProperty {
        case LightGrid = "lightGrid"
        case NearPlaneAndProjectionTerms = "nearPlaneAndProjectionTerms"
        case CameraNearFar = "cameraNearFar"
        case GBuffer0Texture = "gBuffer0Texture"
        case GBuffer1Texture = "gBuffer1Texture"
        case GBuffer2Texture = "gBuffer2Texture"
        case GBufferDepthTexture = "gBufferDepthTexture"
        case Lights = "lights"
        case CameraToWorldMatrix = "cameraToWorldMatrix"
        case Exposure = "exposure"
        
        var name : String {
            return self.rawValue
        }
    }
    
    func performPass(scene: Scene, camera: Camera, gBufferColours: [Texture], gBufferDepth: Texture) -> Texture {
        
        self.setupLightGrid(camera: camera, lights: scene.lights)
        
        let lightTexture = Texture(buffer: scene.lightBuffer, internalFormat: GL_RGBA32F)
        
        self.pipelineState.renderPass { (framebuffer, shader) in
            
            gBufferColours[1].bindToIndex(1)
            defer { gBufferColours[1].unbindFromIndex(1) }
            shader.setUniform(GLint(1), forProperty: LightAccumulationShaderProperty.GBuffer1Texture)
            
            gBufferColours[2].bindToIndex(2)
            defer { gBufferColours[2].unbindFromIndex(2) }
            shader.setUniform(GLint(2), forProperty: LightAccumulationShaderProperty.GBuffer2Texture)
            
            gBufferDepth.bindToIndex(0)
            defer { gBufferColours[3].unbindFromIndex(0) }
            shader.setUniform(GLint(0), forProperty: LightAccumulationShaderProperty.GBufferDepthTexture)
            
            self.lightGridTexture.bindToIndex(4)
            defer { self.lightGridTexture.unbindFromIndex(4) }
            shader.setUniform(GLint(4), forProperty: LightAccumulationShaderProperty.LightGrid)
            
            
            gBufferColours[0].bindToIndex(5)
            defer { gBufferColours[0].unbindFromIndex(5) }
            shader.setUniform(GLint(5), forProperty: LightAccumulationShaderProperty.GBuffer0Texture)
            
            lightTexture.bindToIndex(6)
            defer { lightTexture.unbindFromIndex(6) }
            shader.setUniform(GLint(6), forProperty: LightAccumulationShaderProperty.Lights)
            
            
            shader.setUniform(camera.exposure, forProperty: LightAccumulationShaderProperty.Exposure)
            
            shader.setMatrix(camera.transform.nodeToWorldMatrix, forProperty: LightAccumulationShaderProperty.CameraToWorldMatrix)
            
            shader.setUniform(camera.zNear, camera.zFar, forProperty: LightAccumulationShaderProperty.CameraNearFar)
            
            let nearPlane = self.calculateNearPlaneSize(zNear: camera.zNear, cameraAspect: camera.aspectRatio, projectionMatrix: camera.projectionMatrix)
            let projectionA = camera.zFar / (camera.zFar - camera.zNear)
            let projectionB = (-camera.zFar * camera.zNear) / (camera.zFar - camera.zNear)
            
            shader.setUniform(nearPlane.x, nearPlane.y, projectionA, projectionB, forProperty: LightAccumulationShaderProperty.NearPlaneAndProjectionTerms)
            
            GLMesh.fullScreenQuad.render()
        }
        
        return self.pipelineState.framebuffer.colourAttachments[0]!.texture!
    }
}