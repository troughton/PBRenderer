//
//  RenderPass.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 30/04/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath

//This is mainly a reimplementation of Metal's state-object based pipeline for OpenGL.

struct ColourWriteMask : OptionSet {
    
    let rawValue : UInt

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    static let None = ColourWriteMask(rawValue: 0)
    static let Red   = ColourWriteMask(rawValue: 0x1 << 3)
    static let Green = ColourWriteMask(rawValue: 0x1 << 2)
    static let Blue  = ColourWriteMask(rawValue: 0x1 << 1)
    static let Alpha = ColourWriteMask(rawValue: 0x1 << 0)
    static let All   = ColourWriteMask(rawValue: 0xf)
}

struct BlendState {
    
    /*! Enable blending.  Defaults to NO. */
    var isBlendingEnabled: Bool = false
    
    /*! Defaults to GL_ONE */
    var sourceRGBBlendFactor: GLint = GL_ONE
    
    
    /*! Defaults to GL_ZERO */
    var destinationRGBBlendFactor: GLint = GL_ZERO
    
    
    /*! Defaults to GL_ADD */
    var rgbBlendOperation: GLint = GL_FUNC_ADD
    
    
    /*! Defaults to GL_ONE */
    var sourceAlphaBlendFactor: GLint = GL_ONE
    
    
    /*! Defaults to GL_ZERO */
    var destinationAlphaBlendFactor: GLint = GL_ZERO
    
    
    /*! Defaults to GL_ADD */
    var alphaBlendOperation: GLint = GL_FUNC_ADD
    
    
    /*! Defaults to ColourWriteMaskAll */
    var writeMask: ColourWriteMask = .All
    
    func applyState(bufferIndex: GLuint) {
        if isBlendingEnabled {
            glEnablei(GL_BLEND, bufferIndex)
        } else {
            glDisablei(GL_BLEND, bufferIndex)
        }
        
        glBlendFuncSeparatei(bufferIndex, sourceRGBBlendFactor, destinationRGBBlendFactor, sourceAlphaBlendFactor, destinationAlphaBlendFactor)
        glBlendEquationSeparatei(buf: bufferIndex, modeRGB: rgbBlendOperation, modeAlpha: alphaBlendOperation)
        
        glColorMaski(bufferIndex, writeMask.contains(.Red), writeMask.contains(.Green), writeMask.contains(.Blue), writeMask.contains(.Alpha))
    }
}

struct StencilState {
    
    var stencilCompareFunction: GLint
    
    /*! Stencil is tested first. stencilFailureOperation declares how the stencil buffer is updated when the stencil test fails. */
    var stencilFailureOperation: GLint
    
    
    /*! If stencil passes, depth is tested next.  Declare what happens when the depth test fails. */
    var depthFailureOperation: GLint
    
    
    /*! If both the stencil and depth tests pass, declare how the stencil buffer is updated. */
    var depthStencilPassOperation: GLint
    
    var readMask: UInt32
    
    var writeMask: UInt32
    
    var referenceValue : Int32
    
    func applyState(face: GLenum) {
        glStencilFuncSeparate(face, stencilCompareFunction, referenceValue, readMask)
        glStencilMaskSeparate(face, writeMask)
        
        glStencilOpSeparate(face: face, sfail: stencilFailureOperation, dpfail: depthFailureOperation, dppass: depthStencilPassOperation)
    }
}

struct DepthStencilState {
    /* Defaults to GL_ALWAYS, which effectively skips the depth test */
    var depthCompareFunction: GLint = GL_ALWAYS
    
    /* Defaults to NO, so no depth writes are performed */
    var isDepthWriteEnabled: Bool = false
    
    var frontFaceStencil: StencilState? = nil
    
    var backFaceStencil: StencilState? = nil
    
    func applyState() {
        
        if isDepthWriteEnabled || depthCompareFunction != GL_ALWAYS {
            glEnable(GL_DEPTH_TEST)
        } else {
            glDisable(GL_DEPTH_TEST)
        }
        
        glDepthMask(isDepthWriteEnabled)
        
        glDepthFunc(depthCompareFunction)
        
        if frontFaceStencil != nil || backFaceStencil != nil {
            glEnable(GL_STENCIL_TEST)
            
            if let frontFaceStencil = frontFaceStencil {
                frontFaceStencil.applyState(face: GL_FRONT)
            } else {
                glStencilFuncSeparate(GL_FRONT, GL_ALWAYS, 0, GLuint.max)
                glStencilMaskSeparate(GL_FRONT, GLuint.max)
                glStencilOpSeparate(face: GL_FRONT, sfail: GL_KEEP, dpfail: GL_KEEP, dppass: GL_KEEP)
            }
            
            if let backFaceStencil = backFaceStencil {
                backFaceStencil.applyState(face: GL_BACK)
            } else {
                glStencilFuncSeparate(GL_BACK, GL_ALWAYS, 0, GLuint.max)
                glStencilMaskSeparate(GL_BACK, GLuint.max)
                glStencilOpSeparate(face: GL_BACK, sfail: GL_KEEP, dpfail: GL_KEEP, dppass: GL_KEEP)
            }
            
        } else {
            glDisable(GL_STENCIL_TEST)
        }
        
        var error = glGetError()
        while error != 0 {
            print("OpenGL Error: \(error)")
            error = glGetError()
        }
    }
}

struct Rectangle {
    let x: GLint
    let y: GLint
    let width: GLint
    let height: GLint
}

struct PipelineState {
    
    var cullMode : GLenum = GL_NONE
    
    var blendColour : vec4 = vec4(0)
    
    enum DepthClipMode {
        case Clip
        case Clamp
    }
    
    var depthClipMode : DepthClipMode = .Clip
    
    var frontFaceWinding : GLint = GL_CCW
    
    var scissorRect : Rectangle? = nil
    
    var polygonFillMode : GLenum = GL_FILL
        
    var viewport : Rectangle
    
    var alphaToCoverageEnabled : Bool = false
    var alphaToOneEnabled : Bool = false
    var rasterisationEnabled : Bool = true
    
    var multisamplingEnabled : Bool = false
    
    var framebuffer : Framebuffer
    var shader : Shader
    var depthStencilState : DepthStencilState
    
    init(viewport: Rectangle, framebuffer: Framebuffer, shader: Shader, depthStencilState: DepthStencilState) {
        self.viewport = viewport
        self.framebuffer = framebuffer
        self.shader = shader
        self.depthStencilState = depthStencilState
    }
    
    func applyState() {
        if cullMode == GL_NONE {
            glDisable(GL_CULL_FACE)
        } else {
            glEnable(GL_CULL_FACE)
            glCullFace(cullMode)
        }
        
        glBlendColor(blendColour.r, blendColour.g, blendColour.b, blendColour.a)
        
        switch depthClipMode {
        case .Clip:
            glDisable(GL_DEPTH_CLAMP)
        case .Clamp:
            glEnable(GL_DEPTH_CLAMP)
        }
        
        glFrontFace(frontFaceWinding)
        
        if let scissorRect = scissorRect {
            glEnable(GL_SCISSOR_TEST)
            glScissor(GLint(scissorRect.x), GLint(scissorRect.y), GLsizei(scissorRect.width), GLsizei(scissorRect.height))
        } else {
            glDisable(GL_SCISSOR_TEST)
        }
        
        glPolygonMode(GL_FRONT_AND_BACK, polygonFillMode)
     
        glViewport(GLint(viewport.x), GLint(viewport.y), GLsizei(viewport.width), GLsizei(viewport.height))
        
        if multisamplingEnabled {
            glEnable(GL_MULTISAMPLE)
        } else {
            glDisable(GL_MULTISAMPLE)
        }
        
        if alphaToCoverageEnabled {
            glEnable(GL_SAMPLE_ALPHA_TO_COVERAGE)
        } else {
            glDisable(GL_SAMPLE_ALPHA_TO_COVERAGE)
        }
        
        if alphaToOneEnabled {
            glEnable(GL_SAMPLE_ALPHA_TO_ONE)
        } else {
            glDisable(GL_SAMPLE_ALPHA_TO_ONE)
        }
        
        if rasterisationEnabled {
            glDisable(GL_RASTERIZER_DISCARD)
        } else {
            glEnable(GL_RASTERIZER_DISCARD)
        }
        
        self.depthStencilState.applyState()
        
        var error = glGetError()
        while error != 0 {
            print("OpenGL Error: \(error)")
            error = glGetError()
        }
    }
    
    func renderPass(_ function: @noescape (Framebuffer, Shader) -> ()) {
        self.applyState()
        
        self.framebuffer.renderPass { 
            self.shader.withProgram({ (shader) in
                function(self.framebuffer, shader)
            })
        }
    }
}