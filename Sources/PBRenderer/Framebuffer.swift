//
//  Framebuffer.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 2/05/16.
//
//

import Foundation
import CGLFW3
import SGLMath
import SGLOpenGL

enum LoadAction : UInt {
    case DontCare = 0
    case Load = 1
    case Clear = 2
}

enum StoreAction {
    case DontCare
    case Store
    case MultisampleResolveColour(Framebuffer, attachmentIndex: Int)
    case MultisampleResolveDepth(Framebuffer)
    case MultisampleResolveStencil(Framebuffer)
}

protocol RenderPassAttachment {
    var texture : Texture? { get set } //If texture's nil, then we use the default framebuffer.
    var mipmapLevel : Int { get set }
    var textureSlice : UInt { get set }
    var depthPlane : Int { get set }
    
    var loadAction : LoadAction { get set }
    var storeAction : StoreAction { get set }
}

struct RenderPassColourAttachment : RenderPassAttachment {
    var clearColour : vec4
    
    var texture : Texture?
    var mipmapLevel : Int = 0
    var textureSlice : UInt = 0
    var depthPlane : Int = 0
    
    var loadAction : LoadAction = .DontCare
    var storeAction : StoreAction = .DontCare
    
    init(clearColour : vec4) {
        self.clearColour = clearColour
        self.texture = nil
    }
}

struct RenderPassDepthAttachment : RenderPassAttachment {
    var clearDepth : Double
    
    var texture : Texture?
    var mipmapLevel : Int = 0
    var textureSlice : UInt = 0
    var depthPlane : Int = 0
    
    var loadAction : LoadAction = .DontCare
    var storeAction : StoreAction = .DontCare
    
    init(clearDepth: Double) {
        self.clearDepth = clearDepth
        self.texture = nil
    }
}

struct RenderPassStencilAttachment : RenderPassAttachment {
    var clearStencil : UInt32
    
    var texture : Texture?
    var mipmapLevel : Int = 0
    var textureSlice : UInt = 0
    var depthPlane : Int = 0
    
    var loadAction : LoadAction = .DontCare
    var storeAction : StoreAction = .DontCare
    
    init(clearStencil: UInt32) {
        self.clearStencil = clearStencil
    }
}


public class Framebuffer {
    
    static func defaultFramebuffer(width: Int32, height: Int32) -> Framebuffer {
        return Framebuffer(defaultFramebufferWithWidth: width, height: height)
    }
    
    private let _glFramebuffer : GLuint!
    
    let width : Int32
    let height : Int32
    
    var colourAttachments: [RenderPassColourAttachment?]
    
    var depthAttachment: RenderPassDepthAttachment
    
    var stencilAttachment : RenderPassStencilAttachment?
    
    init(width: Int32, height: Int32, colourAttachments: [RenderPassColourAttachment?], depthAttachment: RenderPassDepthAttachment, stencilAttachment: RenderPassStencilAttachment?) {
        
        self.width = width
        self.height = height
        
        self.colourAttachments = colourAttachments
        self.depthAttachment = depthAttachment
        self.stencilAttachment = stencilAttachment
        
        if colourAttachments.first??.texture == nil {
            _glFramebuffer = nil
            return //No need to create a new framebuffer for the default framebuffer.
        }
        
        var framebuffer : GLuint = 0
        glGenFramebuffers(1, &framebuffer)
        _glFramebuffer = framebuffer
        
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, framebuffer)
        
        for (i, colourAttachment) in colourAttachments.enumerated() where colourAttachment?.texture != nil {
            let colourAttachment = colourAttachment!
            let texture = colourAttachment.texture!
            
            texture.bindToFramebuffer(GL_DRAW_FRAMEBUFFER, attachment: GL_COLOR_ATTACHMENT0 + i, mipmapLevel: colourAttachment.mipmapLevel, textureSlice: Int(colourAttachment.textureSlice), depthPlane: colourAttachment.depthPlane)
        }
        
        depthAttachment.texture!.bindToFramebuffer(GL_DRAW_FRAMEBUFFER, attachment: GL_DEPTH_ATTACHMENT, mipmapLevel: depthAttachment.mipmapLevel, textureSlice: Int(depthAttachment.textureSlice), depthPlane: depthAttachment.depthPlane)
        
        stencilAttachment?.texture!.bindToFramebuffer(GL_DRAW_FRAMEBUFFER, attachment: GL_STENCIL_ATTACHMENT, mipmapLevel: stencilAttachment!.mipmapLevel, textureSlice: Int(stencilAttachment!.textureSlice), depthPlane: stencilAttachment!.depthPlane)
        
        let completeness = glCheckFramebufferStatus(GL_DRAW_FRAMEBUFFER)
        
        if completeness != GL_FRAMEBUFFER_COMPLETE {
            fatalError("Error creating framebuffer: \(completeness)")
        }
        
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0)
    }
    
    private convenience init(defaultFramebufferWithWidth width: Int32, height: Int32) {
        let colourAttachments : [RenderPassColourAttachment?] = [ RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0)) ]
        let depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        
        self.init(width: width, height: height, colourAttachments:colourAttachments, depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    deinit {
        if var glFramebuffer = _glFramebuffer {
            glDeleteFramebuffers(1, &glFramebuffer)
        }
    }
    
    func beginRenderPass() {
        
        if let glFramebuffer = _glFramebuffer {
            glBindFramebuffer(GL_FRAMEBUFFER, glFramebuffer)
        }
        
        for (i, attachment) in self.colourAttachments.enumerated() where attachment != nil {
            
            if attachment!.loadAction == .Clear {
            
                if let _ = attachment!.texture {
                    glDrawBuffer(GL_COLOR_ATTACHMENT0 + i)
                } else {
                    glDrawBuffer(GL_BACK)
                }
                glClearColor(attachment!.clearColour.r, attachment!.clearColour.g, attachment!.clearColour.b, attachment!.clearColour.a)
                glClear(GL_COLOR_BUFFER_BIT)
            }
        }
        
        if _glFramebuffer != nil {
            let drawBuffers : [GLenum] = self.colourAttachments.enumerated().flatMap { (i, attachment) in
                if let _ = attachment {
                    return GL_COLOR_ATTACHMENT0 + i
                } else { return nil }
            }
            
            glDrawBuffers(GLsizei(drawBuffers.count), drawBuffers)
        } else {
            glDrawBuffer(GL_BACK)
        }
        
        if self.depthAttachment.loadAction == .Clear {
            glClearDepth(self.depthAttachment.clearDepth)
            glClear(GL_DEPTH_BUFFER_BIT)
        }
        
        if self.stencilAttachment?.loadAction == .Clear {
            glClearStencil(unsafeBitCast(self.stencilAttachment!.clearStencil, to: GLint.self))
            glClear(GL_STENCIL_BUFFER_BIT)
        }
        
    }
    
    func endRenderPass() {
        
        for attachment in colourAttachments where attachment?.texture != nil {
            if case let .MultisampleResolveColour(framebuffer, attachmentIndex) = attachment!.storeAction {
                    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, framebuffer._glFramebuffer ?? 0)   // Make sure no FBO is set as the draw framebuffer
                    glBindFramebuffer(GL_READ_FRAMEBUFFER, _glFramebuffer) // Make sure your multisampled FBO is the read framebuffer
                    glDrawBuffer(framebuffer._glFramebuffer != nil ? GL_COLOR_ATTACHMENT0 + attachmentIndex : GL_BACK);
                    glBlitFramebuffer(0, 0, self.width, self.height, 0, 0, framebuffer.width, framebuffer.height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
                }
            glBindFramebuffer(GL_FRAMEBUFFER, 0)
        }
        
        if case let .MultisampleResolveDepth(framebuffer) = self.depthAttachment.storeAction {
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, framebuffer._glFramebuffer ?? 0)   // Make sure no FBO is set as the draw framebuffer
            glBindFramebuffer(GL_READ_FRAMEBUFFER, _glFramebuffer) // Make sure your multisampled FBO is the read framebuffer
            glBlitFramebuffer(0, 0, self.width, self.height, 0, 0, framebuffer.width, framebuffer.height, GL_DEPTH_BUFFER_BIT, GL_NEAREST);
        }
        
        if self.stencilAttachment != nil, case let .MultisampleResolveStencil(framebuffer) = self.stencilAttachment!.storeAction {
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, framebuffer._glFramebuffer ?? 0)   // Make sure no FBO is set as the draw framebuffer
            glBindFramebuffer(GL_READ_FRAMEBUFFER, _glFramebuffer) // Make sure your multisampled FBO is the read framebuffer
            glBlitFramebuffer(0, 0, self.width, self.height, 0, 0, framebuffer.width, framebuffer.height, GL_STENCIL_BUFFER_BIT, GL_NEAREST);
        }
    }
}