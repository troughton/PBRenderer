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
    
    var name: String {
        return self.rawValue
    }
}

final class LDTexture {
    let resolution : Int
    let diffuseTexture : Texture
    let specularTexture : Texture
    
    private let depthTextures : [Texture]
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
    
    init(resolution: Int) {
        self.resolution = resolution
        
        let diffuseCubeDescriptor = TextureDescriptor(textureCubeWithPixelFormat: GL_RGB16F, width: resolution, height: resolution, mipmapped: false)
        self.diffuseTexture = Texture(textureWithDescriptor: diffuseCubeDescriptor)
        
        let specularMipMapCount = UInt(log2(Double(resolution)) - 3)
        let specularCubeDescriptor = TextureDescriptor(textureType: GL_TEXTURE_CUBE_MAP, pixelFormat: GL_RGB16F, width: resolution, height: resolution, depth: 1, mipmapLevelCount: specularMipMapCount, arrayLength: 1, multisampleCount: 1)
        self.specularTexture = Texture(textureWithDescriptor: specularCubeDescriptor)
        
        
        self.depthTextures = (0..<specularMipMapCount).map { (mipLevel) -> Texture in
            let mipLevelSize = resolution / Int(1 << mipLevel)
            
            let depthTextureDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT16, width: Int(mipLevelSize), height: Int(mipLevelSize), mipmapped: false)
            return Texture(textureWithDescriptor: depthTextureDescriptor)
        }
        
        let diffuseFramebuffer = self.generateDiffuseFramebuffer(resolution: resolution)
        let specularFramebuffers = self.generateSpecularFramebuffers(resolution: resolution)
        
        let depthStencilState = DepthStencilState()
        let viewport = Rectangle(x: 0, y: 0, width: GLint(resolution), height: GLint(resolution))
        
        self.diffusePipelineState = PipelineState(viewport: viewport, framebuffer: diffuseFramebuffer, shader: LDTexture.diffuseShader, depthStencilState: depthStencilState)
        
        var specularPipelineStates = [PipelineState]()
        specularPipelineStates.append(
            PipelineState(viewport: viewport, framebuffer: specularFramebuffers[0], shader: LDTexture.specularBaseLevelShader, depthStencilState: depthStencilState)
        )
        
        for framebuffer in specularFramebuffers.dropFirst() {
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
    
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.texture = self.depthTextures.first!
        
        return Framebuffer(width: Int32(resolution), height: Int32(resolution), colourAttachments: colourAttachments, depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    private func generateSpecularFramebuffers(resolution: Int) -> [Framebuffer] {
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
            depthAttachment.texture = self.depthTextures[Int(mipmapLevel)]
            
            return Framebuffer(width: Int32(mipLevelSize), height: Int32(mipLevelSize), colourAttachments: colourAttachments, depthAttachment: depthAttachment, stencilAttachment: nil)
        }
        return framebuffers
    }
    
    private func fillDiffuseFromCubeMap(_ texture: Texture) {
        //Algorithm: for each face, compute the terms.
        
        self.diffusePipelineState.renderPass { (framebuffer, shader) in
            shader.setUniform(GLint(0), forProperty: LDTextureShaderProperty.Image)
            texture.bindToIndex(0)
            
            GLMesh.fullScreenQuad.render()
        }
        
    }
    
    private func fillSpecularMipmapsFromCubeMap(_ texture: Texture) {
        //Algorithm: for each face, for each mip level, compute the terms.
        
        texture.bindToIndex(0)
        
        for (mipLevel, state) in self.specularPipelineStates.enumerated().dropFirst() {
            
            state.renderPass({ (framebuffer, shader) in
                shader.setUniform(GLint(0), forProperty: LDTextureShaderProperty.Image)
                shader.setUniform(framebuffer.width, forProperty: LDTextureShaderProperty.Resolution)
                
                let mip = Float(mipLevel) / Float(self.specularTexture.descriptor.mipmapLevelCount)
                let perceptuallyLinearRoughness = mip * mip
                let roughness = perceptuallyLinearRoughness * perceptuallyLinearRoughness
                
                shader.setUniform(roughness, forProperty: LDTextureShaderProperty.Roughness)
                
                GLMesh.fullScreenQuad.render()
            })
            
        }
    }
    
    private func fillSpecularBaseLevelFromCubeMap(_ texture: Texture) {
        
        self.specularPipelineStates[0].renderPass { (framebuffer, shader) in
            shader.setUniform(GLint(0), forProperty: LDTextureShaderProperty.Image)
            texture.bindToIndex(0)
            
            GLMesh.fullScreenQuad.render()
        }
    }
    
    static func fillLDTexturesFromCubeMaps(textures: [LDTexture], cubeMaps: [Texture]) {
        
        
        LDTexture.sampler.bindToIndex(0)
        
        for (texture, cubeMap) in zip(textures, cubeMaps) {
            texture.fillDiffuseFromCubeMap(cubeMap)
        }
        
        for (texture, cubeMap) in zip(textures, cubeMaps) {
            texture.fillSpecularBaseLevelFromCubeMap(cubeMap)
        }
        
        for (texture, cubeMap) in zip(textures, cubeMaps) {
            texture.fillSpecularMipmapsFromCubeMap(cubeMap)
        }
    }
    
//    func fillFromCubeMap(texture: Texture) {
//        assert(texture.descriptor.textureType == GL_TEXTURE_CUBE_MAP)
//        
//        self.fillDiffuseFromCubeMap(texture: texture)
//        self.fillSpecularFromCubeMap(texture: texture)
//    }
}