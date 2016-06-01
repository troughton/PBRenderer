//
//  Texture.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 1/05/16.
//
//

import Foundation
import SGLOpenGL
import OpenCL

struct TextureUsage : OptionSet {
    let rawValue : UInt
    init(rawValue: UInt) { self.rawValue = rawValue }
    
    static let Unknown         = TextureUsage(rawValue: 0x0000)
    static let ShaderRead      = TextureUsage(rawValue: 0x0001)
    static let ShaderWrite     = TextureUsage(rawValue: 0x0002)
    static let RenderTarget    = TextureUsage(rawValue: 0x0004)
  //  static let PixelFormatView = 0x0010
}

struct TextureDescriptor {
    
    ///The dimension and arrangement of the texture image data.
    let textureType : SGLOpenGL.GLenum
    
    ///Format that determines how a pixel is written to, stored as, and read from the storage allocation of the texture.
    let pixelFormat : SGLOpenGL.GLenum
    
    ///The width of the texture image for the base level mipmap, in pixels.
    let width : Int
    
    ///The height of the texture image for the base level mipmap, in pixels. For a 1D texture, the value is 1.
    let height : Int
    
    ///The depth of the texture image for the base level mipmap, in pixels. For 1D, 2D, and cube textures, the value is 1.
    let depth : Int
    
    ///The number of mipmap levels for this texture. For a buffer-backed or multisample texture, the value is 1.
    let mipmapLevelCount : UInt
    
    ///The number of array elements for a 1DArray, 2DArray, or CubeArray type texture object. The value is between 1 and 2048, inclusive. If the texture has a non-array type, the value is 1.
    let arrayLength : Int
    
    ///The number of samples in each pixel. If textureType is not GL_TEXTURE_2D_MULTISAMPLE, the value is 1.
    let multisampleCount : Int
    
    /** The description of the texture usage.
     When configuring a Texture object you should always aim to determine and set specific texture usages; do not rely on the .Unknown value for the best performance.
     For example, set the descriptor’s usage value to .RenderTarget if you already know that you intend to use the resulting texture as a render target. This may significantly improve your app’s performance (with certain hardware). */
    let usage : TextureUsage
    
    init(textureType: SGLOpenGL.GLenum, pixelFormat: SGLOpenGL.GLenum, width: Int, height: Int, depth: Int = 1, mipmapLevelCount: UInt = 1, arrayLength: Int = 1, multisampleCount: Int = 1, usage : TextureUsage = .ShaderRead) {
        self.textureType = textureType
        self.pixelFormat = pixelFormat
        self.width = width
        self.height = height
        self.depth = depth
        self.mipmapLevelCount = mipmapLevelCount
        self.arrayLength = arrayLength
        self.multisampleCount = multisampleCount
        self.usage = usage
    }
    
    init(texture2DWithPixelFormat pixelFormat: SGLOpenGL.GLenum, width: Int, height: Int, mipmapped: Bool) {
        let mipmapLevels = mipmapped ? UInt(log2(Double(max(width, height)))) : 1
        self.init(textureType: GL_TEXTURE_2D, pixelFormat: pixelFormat, width: width, height: height, depth: 1, mipmapLevelCount: mipmapLevels, arrayLength: 1, multisampleCount: 1)
    }
    
    init(textureCubeWithPixelFormat pixelFormat: SGLOpenGL.GLenum, width: Int, height: Int, mipmapped: Bool) {
        let mipmapLevels = mipmapped ? UInt(log2(Double(max(width, height)))) : 1
        self.init(textureType: GL_TEXTURE_CUBE_MAP, pixelFormat: pixelFormat, width: width, height: height, depth: 1, mipmapLevelCount: mipmapLevels, arrayLength: 1, multisampleCount: 1)
    }
}

class Texture {
    
    static func formatForInternalFormat(_ pixelFormat: SGLOpenGL.GLenum) -> SGLOpenGL.GLenum {
        switch pixelFormat {
        case GL_R8:	return GL_RED
        case GL_R8_SNORM: return GL_RED
        case GL_R16:	return 	GL_RED
        case GL_R16_SNORM:	return 	GL_RED
        case GL_RG8:	return 	GL_RG
        case GL_RG8_SNORM:	return 	GL_RG
        case GL_RG16:	return 	GL_RG
        case GL_RG16_SNORM:	return 	GL_RG
        case GL_R3_G3_B2:	return 	GL_RGB
        case GL_RGB4:	return 	GL_RGB
        case GL_RGB5:	return 	GL_RGB
        case GL_RGB8:	return 	GL_RGB
        case GL_RGB8_SNORM:	return 	GL_RGB
        case GL_RGB10:	return 	GL_RGB
        case GL_RGB12:	return 	GL_RGB
        case GL_RGB16_SNORM: return GL_RGB
        case GL_RGBA2: return 	GL_RGB
        case GL_RGBA4: return 	GL_RGB
        case GL_RGB5_A1: return 	GL_RGBA
        case GL_RGBA8: return 	GL_RGBA
        case GL_RGBA8_SNORM: return GL_RGBA
        case GL_RGB10_A2: return GL_RGBA
        case GL_RGB10_A2UI: return 	GL_RGBA
        case GL_RGBA12: return 	GL_RGBA
        case GL_RGBA16: return 	GL_RGBA
        case GL_SRGB8: return 	GL_RGB
        case GL_SRGB8_ALPHA8: return GL_RGBA
        case GL_R16F: return GL_RED
        case GL_RG16F: return GL_RG
        case GL_RGB16F: return GL_RGB
        case GL_RGBA16F: return GL_RGBA
        case GL_R32F: return GL_RED
        case GL_RG32F: return GL_RG
        case GL_RGB32F: return GL_RGB
        case GL_RGBA32F: return GL_RGBA
        case GL_R11F_G11F_B10F: return GL_RGB
        case GL_RGB9_E5: return GL_RGB
        case GL_R8I: return GL_RED_INTEGER
        case GL_R8UI: return GL_RED_INTEGER
        case GL_R16I: return GL_RED_INTEGER
        case GL_R16UI: return GL_RED_INTEGER
        case GL_R32I: return GL_RED_INTEGER
        case GL_R32UI: return GL_RED_INTEGER
        case GL_RG8I: return GL_RG_INTEGER
        case GL_RG8UI: return GL_RG_INTEGER
        case GL_RG16I: return GL_RG_INTEGER
        case GL_RG16UI: return GL_RG_INTEGER
        case GL_RG32I: return GL_RG_INTEGER
        case GL_RG32UI: return GL_RG_INTEGER
        case GL_RGB8I: return GL_RGB_INTEGER
        case GL_RGB8UI: return GL_RGB_INTEGER
        case GL_RGB16I: return GL_RGB_INTEGER
        case GL_RGB16UI: return GL_RGB_INTEGER
        case GL_RGB32I: return GL_RGB_INTEGER
        case GL_RGB32UI: return GL_RGB_INTEGER
        case GL_RGBA8I: return GL_RGBA_INTEGER
        case GL_RGBA8UI: return GL_RGBA_INTEGER
        case GL_RGBA16I: return GL_RGBA_INTEGER
        case GL_RGBA16UI: return GL_RGBA_INTEGER
        case GL_RGBA32I: return GL_RGBA_INTEGER
        case GL_RGBA32UI: return GL_RGBA_INTEGER
        case GL_DEPTH_COMPONENT16: return GL_DEPTH_COMPONENT
        case GL_DEPTH_COMPONENT24: return GL_DEPTH_COMPONENT
        case GL_DEPTH_COMPONENT32F: return GL_DEPTH_COMPONENT
        case GL_DEPTH24_STENCIL8: return GL_DEPTH_STENCIL
        case GL_DEPTH32F_STENCIL8: return GL_DEPTH_STENCIL
        case GL_COMPRESSED_RED: return GL_RED
        case GL_COMPRESSED_RG: return GL_RG
        case GL_COMPRESSED_RGB: return GL_RGB
        case GL_COMPRESSED_RGBA: return GL_RGBA
        case GL_COMPRESSED_SRGB: return GL_RGB
        case GL_COMPRESSED_SRGB_ALPHA: return GL_RGBA
        case GL_COMPRESSED_RED_RGTC1: return GL_RED
        case GL_COMPRESSED_SIGNED_RED_RGTC1: return GL_RED
        case GL_COMPRESSED_RG_RGTC2: return GL_RG
        case GL_COMPRESSED_SIGNED_RG_RGTC2: return GL_RG
        case GL_COMPRESSED_RGBA_BPTC_UNORM: return GL_RGBA
        case GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM: return GL_RGBA
        case GL_COMPRESSED_RGB_BPTC_SIGNED_FLOAT: return GL_RGB
        case GL_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT: return GL_RGB
        default: return pixelFormat
        }
    }
    
    static func validTypesForInternalFormat(_ pixelFormat: SGLOpenGL.GLenum) -> [SGLOpenGL.GLenum] {
        switch pixelFormat {
            case GL_RGB: return [GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT_5_6_5]
            case GL_RGBA: return [GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT_4_4_4_4, GL_UNSIGNED_SHORT_5_5_5_1]
            case GL_LUMINANCE_ALPHA: return [GL_UNSIGNED_BYTE]
            case GL_LUMINANCE: return [GL_UNSIGNED_BYTE]
            case GL_ALPHA: return [GL_UNSIGNED_BYTE]
            case GL_R8: return [GL_UNSIGNED_BYTE]
            case GL_R8_SNORM: return [GL_BYTE]
            case GL_R16F: return [GL_HALF_FLOAT,GL_FLOAT]
            case GL_R32F: return [GL_FLOAT]
            case GL_R8UI: return [GL_UNSIGNED_BYTE]
            case GL_R8I: return [GL_BYTE]
            case GL_R16UI: return [GL_UNSIGNED_SHORT]
            case GL_R16I: return [GL_SHORT]
            case GL_R32UI: return [GL_UNSIGNED_INT]
            case GL_R32I: return [GL_INT]
            case GL_RG8: return [GL_UNSIGNED_BYTE]
            case GL_RG8_SNORM: return [GL_BYTE]
            case GL_RG16F: return [GL_HALF_FLOAT,GL_FLOAT]
            case GL_RG32F: return [GL_FLOAT]
            case GL_RG8UI: return [GL_UNSIGNED_BYTE]
            case GL_RG8I: return [GL_BYTE]
            case GL_RG16UI: return [GL_UNSIGNED_SHORT]
            case GL_RG16I: return [GL_SHORT]
            case GL_RG32UI: return [GL_UNSIGNED_INT]
            case GL_RG32I: return [GL_INT]
            case GL_RGB8: return [GL_UNSIGNED_BYTE]
            case GL_SRGB8: return [GL_UNSIGNED_BYTE]
            case GL_RGB565: return [GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT_5_6_5]
            case GL_RGB8_SNORM: return [GL_BYTE]
            case GL_R11F_G11F_B10F: return [GL_UNSIGNED_INT_10F_11F_11F_REV, GL_HALF_FLOAT, GL_FLOAT]
            case GL_RGB9_E5: return [GL_UNSIGNED_INT_5_9_9_9_REV, GL_HALF_FLOAT, GL_FLOAT]
            case GL_RGB16F: return [GL_HALF_FLOAT, GL_FLOAT]
            case GL_RGB32F: return [GL_FLOAT]
            case GL_RGB8UI: return [GL_UNSIGNED_BYTE]
            case GL_RGB8I: return [GL_BYTE]
            case GL_RGB16UI: return [GL_UNSIGNED_SHORT]
            case GL_RGB16I: return [GL_SHORT]
            case GL_RGB32UI: return [GL_UNSIGNED_INT]
            case GL_RGB32I: return [GL_INT]
            case GL_RGBA8: return [GL_UNSIGNED_BYTE]
            case GL_SRGB8_ALPHA8: return [GL_UNSIGNED_BYTE]
            case GL_RGBA8_SNORM: return [GL_BYTE]
            case GL_RGB5_A1: return [GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT_5_5_5_1, GL_UNSIGNED_INT_2_10_10_10_REV]
            case GL_RGBA4: return [GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT_4_4_4_4]
            case GL_RGB10_A2: return [GL_UNSIGNED_INT_2_10_10_10_REV]
            case GL_RGBA16F: return [GL_HALF_FLOAT, GL_FLOAT]
            case GL_RGBA32F: return [GL_FLOAT]
            case GL_RGBA8UI: return [GL_UNSIGNED_BYTE]
            case GL_RGBA8I: return [GL_BYTE]
            case GL_RGB10_A2UI: return [GL_UNSIGNED_INT_2_10_10_10_REV]
            case GL_RGBA16UI: return [GL_UNSIGNED_SHORT]
            case GL_RGBA16I: return [GL_SHORT]
            case GL_RGBA32I: return [GL_INT]
            case GL_RGBA32UI: return [GL_UNSIGNED_INT]
            case GL_DEPTH_COMPONENT16: return [GL_UNSIGNED_SHORT, GL_UNSIGNED_INT]
            case GL_DEPTH_COMPONENT24: return [GL_UNSIGNED_INT]
            case GL_DEPTH_COMPONENT32F: return [GL_FLOAT]
            case GL_DEPTH24_STENCIL8: return [GL_UNSIGNED_INT_24_8]
            case GL_DEPTH32F_STENCIL8: return [GL_FLOAT_32_UNSIGNED_INT_24_8_REV]
            default: fatalError("Invalid internal format \(pixelFormat)")
        }
    }
    
    private let _glTexture : GLuint!
    private let _renderBuffer : GLuint!
    
    let descriptor : TextureDescriptor
    
    let buffer : GPUBuffer<UInt8>?
    
    //Note: data is assumed to be for the first mipmap level.
    init(textureWithDescriptor descriptor: TextureDescriptor) {
        
        self.descriptor = descriptor
        self.buffer = nil
        
        if descriptor.usage == .RenderTarget {
            _glTexture = nil
            
            var texture : GLuint = 0
            glGenRenderbuffers(1, &texture)
            _renderBuffer = texture
            
            glBindBuffer(GL_RENDERBUFFER, _renderBuffer)
            
            glRenderbufferStorageMultisample(GL_RENDERBUFFER, descriptor.multisampleCount == 1 ? 0 : GLsizei(descriptor.multisampleCount), descriptor.pixelFormat, GLsizei(descriptor.width), GLsizei(descriptor.height))
            glBindBuffer(GL_RENDERBUFFER, 0)
            return
        } else {
            _renderBuffer = nil
        }
        
        var texture : GLuint = 0
        glGenTextures(1, &texture)
        _glTexture = texture
        
        glBindTexture(descriptor.textureType, _glTexture)
        
        let texCreationFunction : (target: SGLOpenGL.GLenum, levels: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, depth: GLsizei) -> ()
        
        switch descriptor.textureType {
        case GL_TEXTURE_1D:
            texCreationFunction = { (target, levelCount, internalformat, width, height, depth) in glTexStorage1D(target, levelCount, internalformat, width) }
        case GL_TEXTURE_1D_ARRAY:
            fallthrough
        case GL_TEXTURE_RECTANGLE:
            fallthrough
        case GL_TEXTURE_CUBE_MAP:
            fallthrough
        case GL_TEXTURE_2D:
            texCreationFunction = { (target, levels, internalformat, width, height, depth) in glTexStorage2D(target, levels, internalformat, width, height) }
        case GL_TEXTURE_2D_ARRAY:
            fallthrough
        case GL_TEXTURE_CUBE_MAP_ARRAY:
            fallthrough
        case GL_TEXTURE_3D:
            texCreationFunction = { (target, levels, internalformat, width, height, depth) in glTexStorage3D(target, levels, internalformat, width, height, depth) }
        case GL_TEXTURE_2D_MULTISAMPLE:
            texCreationFunction = { (target, level, internalformat, width, height, depth) in glTexStorage2DMultisample(target, GLsizei(descriptor.multisampleCount), internalformat, width, height, false) }
        default:
            fatalError("Invalid texture format for descriptor \(descriptor)")
        }
        
        
        texCreationFunction(target: descriptor.textureType,
                            levels: GLint(descriptor.mipmapLevelCount),
                            internalformat: descriptor.pixelFormat,
                            width: GLsizei(descriptor.width),
                            height: GLsizei(descriptor.height),
                            depth: GLsizei(descriptor.depth))
        
        glTexParameteri(descriptor.textureType, GL_TEXTURE_BASE_LEVEL, 0)
        glTexParameteri(descriptor.textureType, GL_TEXTURE_MAX_LEVEL, Int32(descriptor.mipmapLevelCount - 1))
        
        glTexParameteri(descriptor.textureType, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(descriptor.textureType, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexParameteri(descriptor.textureType, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
        glTexParameteri(descriptor.textureType, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
        
        glBindTexture(descriptor.textureType, 0)
    }
    
    init<T>(buffer: GPUBuffer<T>, internalFormat: SGLOpenGL.GLenum) {
        var texture : GLuint = 0
        glGenTextures(1, &texture)
        _glTexture = texture
        
        glBindTexture(GL_TEXTURE_BUFFER, _glTexture)
        buffer.bindToTexture(internalFormat: internalFormat)
        
        self.buffer = GPUBuffer<UInt8>(buffer)
        
        let descriptor = TextureDescriptor(textureType: GL_TEXTURE_BUFFER, pixelFormat: internalFormat, width: buffer.capacity, height: 1)
        self.descriptor = descriptor
        
        _renderBuffer = nil
    }
    
    func generateMipmaps() {
        glBindTexture(descriptor.textureType, _glTexture)
        glGenerateMipmap(descriptor.textureType)
        glBindTexture(descriptor.textureType, 0)
    }
    
    func fillSubImage(target: SGLOpenGL.GLenum, mipmapLevel: Int, width: Int, height: Int, type: SGLOpenGL.GLenum, data: UnsafePointer<Void>) {
        glBindTexture(descriptor.textureType, _glTexture)
        glTexSubImage2D(target, GLint(mipmapLevel), 0, 0, GLint(width), GLint(height), Texture.formatForInternalFormat(descriptor.pixelFormat), type, data)
        glBindTexture(descriptor.textureType, 0)
    }
    
    func bindToIndex(_ index: Int) {
        glActiveTexture(GL_TEXTURE0 + index)
        glBindTexture(descriptor.textureType, _glTexture)
    }
    
    func unbindFromIndex(_ index: Int) {
        glActiveTexture(GL_TEXTURE0 + index)
        glBindTexture(descriptor.textureType, 0)
    }
    
    func bindToFramebuffer(_ framebuffer: SGLOpenGL.GLenum, attachment: SGLOpenGL.GLenum, mipmapLevel: Int, textureSlice: Int, depthPlane: Int) {
        
        if let glTexture = _glTexture {
            
            switch descriptor.textureType {
            case GL_TEXTURE_1D_ARRAY:
                fallthrough
            case GL_TEXTURE_2D_ARRAY:
                fallthrough
            case GL_TEXTURE_3D:
                glFramebufferTextureLayer(framebuffer, attachment, glTexture, GLint(mipmapLevel), GLint(max(textureSlice, depthPlane)))
            case GL_TEXTURE_CUBE_MAP:
                glFramebufferTexture2D(framebuffer, attachment, GL_TEXTURE_CUBE_MAP_POSITIVE_X + GLenum(textureSlice), glTexture, GLint(mipmapLevel))
            default:
                glFramebufferTexture(framebuffer, attachment, glTexture, GLint(mipmapLevel))
            }
            
        } else if let renderBuffer = _renderBuffer {
            glFramebufferRenderbuffer(framebuffer, attachment, GL_RENDERBUFFER, renderBuffer)
        }
    }
    
    func openCLMemory(clContext: cl_context, flags: cl_mem_flags, mipLevel: GLint, cubeMapFace: SGLOpenGL.GLenum? = nil) -> OpenCLMemory {
        var error = cl_int(0)
        let mem = clCreateFromGLTexture(clContext, flags, cl_GLenum(cubeMapFace ?? self.descriptor.textureType), mipLevel, _glTexture, &error)
        if error != CL_SUCCESS {
            assertionFailure("Error creating OpenCL texture: \(error).")
        }
        return OpenCLMemory(memory: mem!)
    }
    
    
    deinit {
        if var glTexture = _glTexture {
            glDeleteTextures(1, &glTexture)
        }
        if var renderbuffer = _renderBuffer {
            glDeleteRenderbuffers(1, &renderbuffer)
        }
    }
}