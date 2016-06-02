//
//  LDTexture.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 25/05/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath

enum LDTextureShaderProperty : String, ShaderProperty {
    case Image = "image"
    case Resolution = "resolution"
    case Roughness = "roughness"
    case ValueMultiplier = "valueMultiplier"
    
    var name: String {
        return self.rawValue
    }
}

public final class LDTexture {
    
    static let emptyTexture = LDTexture(specularResolution: 128)
    
    let diffuseResolution = 16
    let specularResolution : Int
    let diffuseTexture : Texture
    let specularTexture : Texture
    
    private var diffusePipelineState : PipelineState! = nil
    private var specularPipelineStates : [PipelineState]! = nil
    
    private static let diffuseShader : Shader = {
       let vertexText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughQuad.vert"))
        let fragmentText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LDDiffuseTexture.frag"))
        return Shader(withVertexShader: vertexText, fragmentShader: fragmentText)
    }()
    
    private static let specularMipmapShader : Shader = {
        let vertexText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughQuad.vert"))
        let fragmentText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LDSpecularTexture.frag"))
        return Shader(withVertexShader: vertexText, fragmentShader: fragmentText)
    }()
    
    private static let specularBaseLevelShader : Shader = {
        let vertexText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughQuad.vert"))
        let fragmentText = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LDSpecularTexturePassthrough.frag"))
        return Shader(withVertexShader: vertexText, fragmentShader: fragmentText)
    }()
    
    private static let sampler : Sampler = {
        let sampler = Sampler()
        sampler.minificationFilter = GL_LINEAR_MIPMAP_NEAREST
        return sampler
    }()
    
    init(specularResolution: Int) {
        self.specularResolution = specularResolution
        
        let diffuseCubeDescriptor = TextureDescriptor(textureCubeWithPixelFormat: GL_RGB16F, width: self.diffuseResolution, height: self.diffuseResolution, mipmapped: false)
        self.diffuseTexture = Texture(textureWithDescriptor: diffuseCubeDescriptor)
        
        let specularMipMapCount = UInt(log2(Double(specularResolution)) - 3)
        let specularCubeDescriptor = TextureDescriptor(textureType: GL_TEXTURE_CUBE_MAP, pixelFormat: GL_RGB16F, width: specularResolution, height: specularResolution, depth: 1, mipmapLevelCount: specularMipMapCount, arrayLength: 1, multisampleCount: 1)
        self.specularTexture = Texture(textureWithDescriptor: specularCubeDescriptor)
        
        
        let diffuseFramebuffer = self.generateDiffuseFramebuffer(resolution: diffuseResolution)
        let specularFramebuffers = self.generateSpecularFramebuffers(resolution: specularResolution)
        
        let depthStencilState = DepthStencilState()
        let diffuseViewport = Rectangle(x: 0, y: 0, width: GLint(diffuseResolution), height: GLint(diffuseResolution))
        
        self.diffusePipelineState = PipelineState(viewport: diffuseViewport, framebuffer: diffuseFramebuffer, shader: LDTexture.diffuseShader, depthStencilState: depthStencilState)
        
        let specularViewport = Rectangle(x: 0, y: 0, width: GLint(specularResolution), height: GLint(specularResolution))
        
        var specularPipelineStates = [PipelineState]()
        specularPipelineStates.append(
            PipelineState(viewport: specularViewport, framebuffer: specularFramebuffers[0], shader: LDTexture.specularBaseLevelShader, depthStencilState: depthStencilState)
        )
        
        for (i, framebuffer) in specularFramebuffers.enumerated().dropFirst() {
            let mipLevelSize = specularResolution / Int(1 << i)
            let viewport = Rectangle(x: 0, y: 0, width: GLint(mipLevelSize), height: GLint(mipLevelSize))
            specularPipelineStates.append(
                PipelineState(viewport: viewport, framebuffer: framebuffer, shader: LDTexture.specularMipmapShader, depthStencilState: depthStencilState)
            )
        }
        self.specularPipelineStates = specularPipelineStates
    }
    
    private func generateDiffuseFramebuffer(resolution: Int) -> Framebuffer {

        let colourAttachments = (0..<UInt(6)).map { (i) -> RenderPassColourAttachment? in
            var attachment = RenderPassColourAttachment(clearColour: vec4(0))
            attachment.texture = self.diffuseTexture
            attachment.textureSlice = i
            attachment.storeAction = .Store
            return attachment
        }
    
        var depthTextureDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT16, width: Int(diffuseResolution), height: Int(diffuseResolution), mipmapped: false)
        depthTextureDescriptor.usage = .RenderTarget
        let diffuseDepthTexture = Texture(textureWithDescriptor: depthTextureDescriptor)
        
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.texture = diffuseDepthTexture
        
        return Framebuffer(width: Int32(resolution), height: Int32(resolution), colourAttachments: colourAttachments, depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    private func generateSpecularFramebuffers(resolution: Int) -> [Framebuffer] {
        
        var depthTextureDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT16, width: specularResolution, height: specularResolution, mipmapped: true)
        depthTextureDescriptor.usage = .RenderTarget
        let specularDepthTexture = Texture(textureWithDescriptor: depthTextureDescriptor)
        
        let framebuffers = (0..<specularTexture.descriptor.mipmapLevelCount).map { (mipmapLevel) -> Framebuffer in
            
            let mipLevelSize = resolution / Int(1 << mipmapLevel)
            
            let colourAttachments = (0..<UInt(6)).map { (i) -> RenderPassColourAttachment? in
                var attachment = RenderPassColourAttachment(clearColour: vec4(0))
                attachment.texture = self.specularTexture
                attachment.textureSlice = i
                attachment.mipmapLevel = Int(mipmapLevel)
                attachment.storeAction = .Store
                return attachment
            }
            var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
            depthAttachment.texture = specularDepthTexture
            depthAttachment.mipmapLevel = Int(mipmapLevel)
            
            return Framebuffer(width: Int32(mipLevelSize), height: Int32(mipLevelSize), colourAttachments: colourAttachments, depthAttachment: depthAttachment, stencilAttachment: nil)
        }
        return framebuffers
    }
    
    private func fillDiffuseFromCubeMap(_ texture: Texture, valueMultiplier: Float) {
        //Algorithm: for each face, compute the terms.
        
        texture.bindToIndex(0)
        defer { texture.unbindFromIndex(0) }
        self.diffusePipelineState.renderPass { (framebuffer, shader) in
            shader.setUniform(GLint(0), forProperty: LDTextureShaderProperty.Image)
            shader.setUniform(valueMultiplier, forProperty: LDTextureShaderProperty.ValueMultiplier)
            
            GLMesh.fullScreenQuad.render()
        }
        
    }
    
    private func fillSpecularMipmapsFromCubeMap(_ texture: Texture, valueMultiplier: Float) {
        //Algorithm: for each face, for each mip level, compute the terms.
        
        texture.bindToIndex(0)
        defer { texture.unbindFromIndex(0) }
        
        for (mipLevel, state) in self.specularPipelineStates.enumerated().dropFirst() {
            
            state.renderPass({ (framebuffer, shader) in
                shader.setUniform(GLint(0), forProperty: LDTextureShaderProperty.Image)
                shader.setUniform(GLint(texture.descriptor.width), forProperty: LDTextureShaderProperty.Resolution)
                shader.setUniform(valueMultiplier, forProperty: LDTextureShaderProperty.ValueMultiplier)
                
                let mip = Float(mipLevel) / Float(self.specularTexture.descriptor.mipmapLevelCount)
                let perceptuallyLinearRoughness = mip * mip
                let roughness = perceptuallyLinearRoughness * perceptuallyLinearRoughness
                
                shader.setUniform(roughness, forProperty: LDTextureShaderProperty.Roughness)
                
                GLMesh.fullScreenQuad.render()
            })
            
        }
    }
    
    private func fillSpecularBaseLevelFromCubeMap(_ texture: Texture, valueMultiplier: Float) {
        
        
        texture.bindToIndex(0)
        defer { texture.unbindFromIndex(0) }
        
        self.specularPipelineStates[0].renderPass { (framebuffer, shader) in
            shader.setUniform(GLint(0), forProperty: LDTextureShaderProperty.Image)
            shader.setUniform(valueMultiplier, forProperty: LDTextureShaderProperty.ValueMultiplier)
            
            GLMesh.fullScreenQuad.render()
        }
    }
    
    static func fillLDTexturesFromCubeMaps(textures: [LDTexture], cubeMaps: [Texture], valueMultipliers: [Float]) {
        
        
        LDTexture.sampler.bindToIndex(0)
        defer { LDTexture.sampler.unbindFromIndex(0) }
        
        for ((texture, valueMultiplier), cubeMap) in zip(zip(textures, valueMultipliers), cubeMaps) {
            texture.fillDiffuseFromCubeMap(cubeMap, valueMultiplier: valueMultiplier)
        }
        
        for ((texture, valueMultiplier), cubeMap) in zip(zip(textures, valueMultipliers), cubeMaps)  {
            texture.fillSpecularBaseLevelFromCubeMap(cubeMap, valueMultiplier: valueMultiplier)
        }
        
        for ((texture, valueMultiplier), cubeMap) in zip(zip(textures, valueMultipliers), cubeMaps)  {
            texture.fillSpecularMipmapsFromCubeMap(cubeMap, valueMultiplier: valueMultiplier)
        }
    }
    
//    func fillFromCubeMap(texture: Texture) {
//        assert(texture.descriptor.textureType == GL_TEXTURE_CUBE_MAP)
//        
//        self.fillDiffuseFromCubeMap(texture: texture)
//        self.fillSpecularFromCubeMap(texture: texture)
//    }
}