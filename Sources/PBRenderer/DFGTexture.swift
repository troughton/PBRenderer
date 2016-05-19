//
//  DFGTexture.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 18/05/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath

final class DFGTexture {
    let resolution : Int
    let texture : Texture
    
    init(resolution: Int) {
        self.resolution = resolution
        
        let textureDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA, width: resolution, height: resolution, mipmapped: false)
        
        self.texture = Texture(textureWithDescriptor: textureDescriptor, type: nil, format: nil, data: nil as [UInt8]?)
        
        var colourAttachment = RenderPassColourAttachment(clearColour: vec4(0))
        colourAttachment.texture = self.texture
        colourAttachment.storeAction = .Store
        
        let depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH24_STENCIL8, width: resolution, height: resolution, mipmapped: false)
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor, format: GL_DEPTH_STENCIL, type: GL_UNSIGNED_INT_24_8, data: nil as [Void]?)
        
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.texture = depthTexture
        
        let framebuffer = Framebuffer(width: Int32(resolution), height: Int32(resolution), colourAttachments: [colourAttachment], depthAttachment: depthAttachment, stencilAttachment: nil)
        
        let vertexShader = try! Shader.shaderTextByExpandingIncludes(fromFile: "PassthroughQuad.vert")
        let fragmentShader = try! Shader.shaderTextByExpandingIncludes(fromFile: "DFGTexture.frag")
        let shader = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)
        
        let depthStencilState = DepthStencilState()
        let pipelineState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: Int32(resolution), height: Int32(resolution)), framebuffer: framebuffer, shader: shader, depthStencilState: depthStencilState)
        
            pipelineState.renderPass { (framebuffer, shader) in
            shader.setUniform(GLint(resolution), forProperty: StringShaderProperty("textureSize"))
            
            GLMesh.fullScreenQuad.render()
        }
    }
    
    static let defaultTexture = DFGTexture(resolution: 128)
}