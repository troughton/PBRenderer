//
//  Sampler.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 26/05/16.
//
//

import Foundation
import SGLOpenGL

final class Sampler {
    let glSampler : GLuint
    
    init() {
        var sampler = GLuint(0)
        glGenSamplers(1, &sampler)
        self.glSampler = sampler
    }
    
    deinit {
        var sampler = self.glSampler
        glDeleteSamplers(1, &sampler)
    }
    
    var minificationFilter : GLenum = GL_NEAREST_MIPMAP_LINEAR {
        didSet {
            glSamplerParameteri(self.glSampler, GL_TEXTURE_MIN_FILTER, self.minificationFilter)
        }
    }
    
    var magnificationFilter : GLenum = GL_LINEAR {
        didSet {
            glSamplerParameteri(self.glSampler, GL_TEXTURE_MAG_FILTER, self.magnificationFilter)
        }
    }
    
    var minLod : Float = -1000.0 {
        didSet {
            glSamplerParameterf(self.glSampler, GL_TEXTURE_MIN_LOD, self.minLod)
        }
    }
    
    var maxLod : Float = 1000.0 {
        didSet {
            glSamplerParameterf(self.glSampler, GL_TEXTURE_MAX_LOD, self.maxLod)
        }
    }
    
    var wrapS : GLenum = GL_REPEAT {
        didSet {
            glSamplerParameteri(self.glSampler, GL_TEXTURE_WRAP_S, self.wrapS)
        }
    }
    
    var wrapT : GLenum = GL_REPEAT {
        didSet {
            glSamplerParameteri(self.glSampler, GL_TEXTURE_WRAP_T, self.wrapT)
        }
    }
    
    var wrapR : GLenum = GL_REPEAT {
        didSet {
            glSamplerParameteri(self.glSampler, GL_TEXTURE_WRAP_R, self.wrapR)
        }
    }
    
    var textureCompareMode : GLenum = GL_NONE {
        didSet {
            glSamplerParameteri(self.glSampler, GL_TEXTURE_COMPARE_MODE, self.textureCompareMode)
        }
    }
    
    var textureCompareFunc : GLenum = GL_ALWAYS {
        didSet {
            glSamplerParameteri(self.glSampler, GL_TEXTURE_COMPARE_FUNC, self.textureCompareFunc)
        }
    }
    
    func bindToIndex(_ index: Int) {
        glBindSampler(GLuint(index), self.glSampler)
    }
    
    func unbindFromIndex(_ index: Int) {
        glBindSampler(GLuint(index), self.glSampler)
    }
}