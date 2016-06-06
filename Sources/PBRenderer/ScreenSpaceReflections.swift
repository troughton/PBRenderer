//
//  ScreenSpaceReflectionPass.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 3/06/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath

final class LightBlurPass {
    
    static let vertexShaderPassthrough = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughQuad.vert"))
    static let fragmentShaderHorizontalBlur = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LinearBlurHorizontal.frag"))
    static let fragmentShaderVerticalBlur = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LinearBlurVertical.frag"))
    
    static let horizontalBlurShader = Shader(withVertexShader: vertexShaderPassthrough, fragmentShader: fragmentShaderHorizontalBlur)
    static let verticalBlurShader = Shader(withVertexShader: vertexShaderPassthrough, fragmentShader: fragmentShaderVerticalBlur)
    
    static let blurSampler : Sampler = {
       let sampler = Sampler()
        
        sampler.minificationFilter = GL_LINEAR_MIPMAP_NEAREST
        sampler.magnificationFilter = GL_LINEAR
        
        return sampler
    }()
    
    private var pipelineStates : [(PipelineState, PipelineState)]! = nil
    
    init(pixelDimensions: Size, lightAccumulationAttachment: RenderPassColourAttachment) {
        self.resize(newPixelDimensions: pixelDimensions.width, pixelDimensions.height, lightAccumulationAttachment: lightAccumulationAttachment)
    }
    
    static func generatePipelineStates(lightAccumulationAttachment: RenderPassColourAttachment) -> [(PipelineState, PipelineState)] {
        let baseWidth = lightAccumulationAttachment.texture!.descriptor.width
        let baseHeight = lightAccumulationAttachment.texture!.descriptor.height
        
        let depthTexture = Texture(textureWithDescriptor: TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT16, width: baseWidth, height: baseHeight, mipmapped: false))
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.texture = depthTexture
        depthAttachment.loadAction = .Clear
        
        var depthStencilState = DepthStencilState()
        depthStencilState.isDepthWriteEnabled = false
        
        return (1..<lightAccumulationAttachment.texture!.descriptor.mipmapLevelCount).map { mipLevel in
            
            let width = baseWidth >> Int(mipLevel)
            let height = baseHeight >> Int(mipLevel)
            
            var attachment = lightAccumulationAttachment
            attachment.mipmapLevel = Int(mipLevel)
            
            let framebuffer = Framebuffer(width: Int32(width), height: Int32(height), colourAttachments: [attachment], depthAttachment: depthAttachment, stencilAttachment: nil)
            
            let viewport = Rectangle(x: 0, y: 0, width: Int32(width), height: Int32(height))
            let pipelineStateHorizontal = PipelineState(viewport: viewport, framebuffer: framebuffer, shader: horizontalBlurShader, depthStencilState: depthStencilState)
            let pipelineStateVertical = PipelineState(viewport: viewport, framebuffer: framebuffer, shader: verticalBlurShader, depthStencilState: depthStencilState)
            return (pipelineStateHorizontal, pipelineStateVertical)
        }
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint, lightAccumulationAttachment: RenderPassColourAttachment) {
        self.pipelineStates = LightBlurPass.generatePipelineStates(lightAccumulationAttachment: lightAccumulationAttachment)
    }
    
    func render(lightAccumulationTexture: Texture) {
        for (sampleMipLevel, (horizontalState, verticalState)) in self.pipelineStates.enumerated() {
            lightAccumulationTexture.setMipRange(UInt(sampleMipLevel)..<UInt(sampleMipLevel + 1))
            lightAccumulationTexture.bindToIndex(0)
            LightBlurPass.blurSampler.bindToIndex(0)
            defer { LightBlurPass.blurSampler.unbindFromIndex(0) }
            
            horizontalState.renderPass({ (framebuffer, shader) in
                GLMesh.fullScreenQuad.render()
            })
            
            verticalState.renderPass({ (framebuffer, shader) in
                GLMesh.fullScreenQuad.render()
            })
            
        }
        
        lightAccumulationTexture.setMipRange(0..<lightAccumulationTexture.descriptor.mipmapLevelCount)
//      /  lightAccumulationTexture.generateMipmaps();
    }
}

final class ScreenSpaceReflectionConeTracePass {
    
    static let vertexShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "CameraSpacePositionVertexShader.vert"))
    static let fragmentShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "ConeTracing.frag"))
    
    static let shader = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)
    
    static let lightAccumulationSampler : Sampler = {
        let sampler = Sampler()
        sampler.minificationFilter = GL_LINEAR_MIPMAP_LINEAR
        sampler.magnificationFilter = GL_LINEAR
        sampler.wrapS = GL_CLAMP_TO_EDGE
        sampler.wrapT = GL_CLAMP_TO_EDGE
        return sampler
    }()
    
    private var _pipelineState : PipelineState
    
    init(pixelDimensions: Size) {
        
        let framebuffer = ScreenSpaceReflectionConeTracePass.generateFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height)
        var depthStencilState = DepthStencilState()
        depthStencilState.isDepthWriteEnabled = false
        
        _pipelineState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height), framebuffer: framebuffer, shader: ScreenSpaceReflectionConeTracePass.shader, depthStencilState: depthStencilState)
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint) {
        _pipelineState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
        _pipelineState.framebuffer = ScreenSpaceReflectionConeTracePass.generateFramebuffer(width: width, height: height)
    }
    
    static func generateFramebuffer(width: GLint, height: GLint) -> Framebuffer {
        
        let depthTexture = Texture(textureWithDescriptor: TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT16, width: Int(width), height: Int(height), mipmapped: false))
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.texture = depthTexture
        depthAttachment.loadAction = .Clear
        
        let colourTexture = Texture(textureWithDescriptor: TextureDescriptor(texture2DWithPixelFormat: GL_RGBA16F, width: Int(width), height: Int(height), mipmapped: false))
        var colourAttachment = RenderPassColourAttachment(clearColour: vec4(0))
        colourAttachment.loadAction = .Clear
        colourAttachment.storeAction = .Store
        colourAttachment.texture = colourTexture
        
        return Framebuffer(width: width, height: height, colourAttachments: [colourAttachment], depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    enum ConeTracingPassShaderProperty : String, ShaderProperty {
        case lightAccumulationBuffer; // convolved color buffer - all mip levels
        case rayTracingBuffer; // ray-tracing buffer
        
        case gBuffer0Texture;
        case gBuffer1Texture;
        case gBuffer2Texture;
        case gBufferDepthTexture;
        
        case worldToCameraMatrix;
        
        case depthBufferSize;
        case mipCount;
        case reflectionTraceMaxDistance;
        case nearPlane
        case projectionTerms
        
        var name: String {
            return self.rawValue
        }
    }
    
    func render(camera: Camera, lightAccumulationBuffer: Texture, rayTracingBuffer: Texture, gBuffers: [Texture], gBufferDepth: Texture) -> Texture {
        
        _pipelineState.renderPass { (framebuffer, shader) in
            
            lightAccumulationBuffer.bindToIndex(0)
            ScreenSpaceReflectionConeTracePass.lightAccumulationSampler.bindToIndex(0)
            defer { ScreenSpaceReflectionConeTracePass.lightAccumulationSampler.unbindFromIndex(0) }
            shader.setUniform(GLint(0), forProperty: ConeTracingPassShaderProperty.lightAccumulationBuffer)
            
            rayTracingBuffer.bindToIndex(1)
            shader.setUniform(GLint(1), forProperty: ConeTracingPassShaderProperty.rayTracingBuffer)
            
            
            gBuffers[0].bindToIndex(5)
            shader.setUniform(GLint(5), forProperty: ConeTracingPassShaderProperty.gBuffer0Texture)
            
            gBuffers[1].bindToIndex(2)
            shader.setUniform(GLint(2), forProperty: ConeTracingPassShaderProperty.gBuffer1Texture)
            
            gBuffers[2].bindToIndex(3)
            shader.setUniform(GLint(3), forProperty: ConeTracingPassShaderProperty.gBuffer2Texture)
            
            gBufferDepth.bindToIndex(4)
            shader.setUniform(GLint(4), forProperty: ConeTracingPassShaderProperty.gBufferDepthTexture)
            
            
            shader.setMatrix(camera.transform.worldToNodeMatrix, forProperty: ConeTracingPassShaderProperty.worldToCameraMatrix)
            
            shader.setUniform(Float(gBufferDepth.descriptor.width), Float(gBufferDepth.descriptor.height), forProperty: ConeTracingPassShaderProperty.depthBufferSize)
            lightAccumulationBuffer.setMipRange(0..<lightAccumulationBuffer.descriptor.mipmapLevelCount)
            shader.setUniform(GLint(lightAccumulationBuffer.descriptor.mipmapLevelCount), forProperty: ConeTracingPassShaderProperty.mipCount)
            
            shader.setUniform(ScreenSpaceReflectionsPasses.traceMaxDistance(camera: camera), forProperty: ConeTracingPassShaderProperty.reflectionTraceMaxDistance)
            
            let nearPlane = camera.nearPlaneSize
            shader.setUniform(nearPlane.x, nearPlane.y, forProperty: ConeTracingPassShaderProperty.nearPlane)
            
            let projectionA = camera.zFar / (camera.zFar - camera.zNear)
            let projectionB = (-camera.zFar * camera.zNear) / (camera.zFar - camera.zNear)
            shader.setUniform(projectionA, projectionB, forProperty: ConeTracingPassShaderProperty.projectionTerms)
            
            GLMesh.fullScreenQuad.render()
        }
        
        
        return self._pipelineState.framebuffer.colourAttachments[0]!.texture!
    }
}

final class ScreenSpaceReflectionsPasses {
    
    private let _lightBlurPass : LightBlurPass
    private let _ssrConeTracePass : ScreenSpaceReflectionConeTracePass
    
    init(pixelDimensions: Size, lightAccumulationAttachment: RenderPassColourAttachment) {
        _lightBlurPass = LightBlurPass(pixelDimensions: pixelDimensions, lightAccumulationAttachment: lightAccumulationAttachment)
        _ssrConeTracePass = ScreenSpaceReflectionConeTracePass(pixelDimensions: pixelDimensions)
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint, lightAccumulationAttachment: RenderPassColourAttachment) {
        self._lightBlurPass.resize(newPixelDimensions: width, height, lightAccumulationAttachment: lightAccumulationAttachment)
        self._ssrConeTracePass.resize(newPixelDimensions: width, height)
    }
    
       
    func render(camera: Camera, lightAccumulationBuffer: Texture, rayTracingBuffer: Texture, gBuffers: [Texture], gBufferDepth: Texture) -> Texture {
        self._lightBlurPass.render(lightAccumulationTexture: lightAccumulationBuffer)
        return self._ssrConeTracePass.render(camera: camera, lightAccumulationBuffer: lightAccumulationBuffer, rayTracingBuffer: rayTracingBuffer, gBuffers: gBuffers, gBufferDepth: gBufferDepth)
    }
    
    static func traceMaxDistance(camera: Camera) -> Float {
        let traceDistance = (camera.zFar - camera.zNear) * 0.5
        return traceDistance
    }
}


