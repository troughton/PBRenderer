//
//  OutlinePass.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 8/06/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath

final class OutlinePass {
    
    var pipelineState : PipelineState
    
    static let lightGridBuilder = LightGridBuilder()
    
    static let vertexShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "OutlinePass.vert"))
    static let fragmentShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "OutlinePass.frag"))
    
    static let outlineShader = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)
    
    
    init(pixelDimensions: Size, gBufferPassState: PipelineState, lightAccumulationAttachment: RenderPassColourAttachment) {
        
        let framebuffer = OutlinePass.outlinePassFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height, gBufferPassState: gBufferPassState, lightAccumulationAttachment: lightAccumulationAttachment)
        
        var pipelineState = gBufferPassState
        pipelineState.framebuffer = framebuffer
        pipelineState.polygonFillMode = GL_LINE
        pipelineState.cullMode = GL_NONE
        
        glEnable(GL_LINE_SMOOTH)
        
        self.pipelineState = pipelineState
        
    }
    
    deinit {
    }
    
    class func outlinePassFramebuffer(width: GLint, height: GLint, gBufferPassState: PipelineState, lightAccumulationAttachment: RenderPassColourAttachment) -> Framebuffer {
        
        var depthAttachment = gBufferPassState.framebuffer.depthAttachment
        depthAttachment.loadAction = .Load
        return Framebuffer(width: width, height: height, colourAttachments: [lightAccumulationAttachment], depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    
    func resize(newPixelDimensions width: GLint, _ height: GLint, gBufferPassState: PipelineState, lightAccumulationAttachment: RenderPassColourAttachment) {
        self.pipelineState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
        self.pipelineState.framebuffer = OutlinePass.outlinePassFramebuffer(width: width, height: height, gBufferPassState: gBufferPassState, lightAccumulationAttachment: lightAccumulationAttachment)
    }
    
    enum OutlinePassShaderProperty : String, ShaderProperty {
        case modelToClipMatrix
        
        var name: String {
            return self.rawValue
        }
    }
    
    func performPass(meshes: [(GLMesh, modelToWorld: mat4)], camera: Camera) -> Texture {
        
        self.pipelineState.renderPass { (framebuffer, shader) in
            
            let worldToClip = camera.projectionMatrix * camera.transform.worldToNodeMatrix
            
            for (mesh, modelToWorld) in meshes {
                let modelToClip = worldToClip * modelToWorld
                shader.setMatrix(modelToClip, forProperty: OutlinePassShaderProperty.modelToClipMatrix)
                
                mesh.render()
            }
            
        }
        
        return self.pipelineState.framebuffer.colourAttachments[0]!.texture!
    }
}