//
//  TextureLoader.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 26/05/16.
//
//

import Foundation
import CPBRendererLibs
import SGLOpenGL

final class TextureLoader {
    private static var textureCache = [String : Texture]()
    
    static func textureFromVerticalCrossHDRCubeMapAtPath(_ path: String) -> Texture {
        if let texture = textureCache[path] {
            return texture
        }
        
        var width = Int32(0)
        var height = Int32(0)
        var componentsPerPixel = Int32(0)
        let data = stbi_loadf(path, &width, &height, &componentsPerPixel, 0)
        defer { stbi_image_free(data) }
        
        let pixelFormat : GLenum
        switch componentsPerPixel {
        case 1:
            pixelFormat = GL_R16F
        case 2:
            pixelFormat = GL_RG16F
        case 3:
            pixelFormat = GL_RGB16F
        case 4:
            pixelFormat = GL_RGBA16F
        default:
            fatalError()
        }
        
        let cubeWidth = Int(width)/3
        assert(Int(height)/4 == cubeWidth, "Each cube face should be square")
        
        
        let cubeNumElements = Int(cubeWidth * cubeWidth * Int(componentsPerPixel))
        
        let backFace = UnsafeMutablePointer<Float>(calloc(sizeof(Float), cubeNumElements))
        defer { free(backFace) }
        
        for i in 0..<cubeWidth {
            let row = Int(height - 1) - i
            let centreOffset = cubeWidth
            
            let sourceIndex = row * Int(width) + centreOffset
            let destinationIndex = cubeWidth * i
            
            memcpy(backFace?.advanced(by: destinationIndex * Int(componentsPerPixel)), data?.advanced(by: sourceIndex * Int(componentsPerPixel)), sizeof(Float) * cubeWidth * Int(componentsPerPixel))
        }
        
        
        let frontFace = UnsafeMutablePointer<Float>(calloc(sizeof(Float), cubeNumElements))
        defer { free(frontFace) }
        
        for i in 0..<cubeWidth {
            let row = cubeWidth + i
            let centreOffset = cubeWidth
            
            let sourceIndex = row * Int(width) + centreOffset
            let destinationIndex = cubeWidth * i
            memcpy(frontFace?.advanced(by: destinationIndex * Int(componentsPerPixel)), data?.advanced(by: sourceIndex * Int(componentsPerPixel)), sizeof(Float) * cubeWidth * Int(componentsPerPixel))
        }
        
        let topFace = UnsafeMutablePointer<Float>(calloc(sizeof(Float), cubeNumElements))
        defer { free(topFace) }
        
        for i in 0..<cubeWidth {
            let row = i
            let centreOffset = cubeWidth
            
            let sourceIndex = row * Int(width) + centreOffset
            let destinationIndex = cubeWidth * i
            memcpy(topFace?.advanced(by: destinationIndex * Int(componentsPerPixel)), data?.advanced(by: sourceIndex * Int(componentsPerPixel)), sizeof(Float) * cubeWidth * Int(componentsPerPixel))
        }
        
        let leftFace = UnsafeMutablePointer<Float>(calloc(sizeof(Float), cubeNumElements))
        defer { free(leftFace) }
        
        for i in 0..<cubeWidth {
            let row = cubeWidth + i
            
            let sourceIndex = row * Int(width)
            let destinationIndex = cubeWidth * i
            memcpy(leftFace?.advanced(by: destinationIndex * Int(componentsPerPixel)), data?.advanced(by: sourceIndex * Int(componentsPerPixel)), sizeof(Float) * cubeWidth * Int(componentsPerPixel))
        }
        
        let rightFace = UnsafeMutablePointer<Float>(calloc(sizeof(Float), cubeNumElements))
        defer { free(rightFace) }
        
        for i in 0..<cubeWidth {
            let row = cubeWidth + i
            
            let sourceIndex = row * Int(width) + 2 * cubeWidth
            let destinationIndex = cubeWidth * i
            memcpy(rightFace?.advanced(by: destinationIndex * Int(componentsPerPixel)), data?.advanced(by: sourceIndex * Int(componentsPerPixel)), sizeof(Float) * cubeWidth * Int(componentsPerPixel))
        }
        
        let bottomFace = UnsafeMutablePointer<Float>(calloc(sizeof(Float), cubeNumElements))
        defer { free(bottomFace) }
        
        for i in 0..<cubeWidth {
            let row = 2 * cubeWidth + i
            let centreOffset = cubeWidth
            
            let sourceIndex = row * Int(width) + centreOffset
            let destinationIndex = cubeWidth * i
            memcpy(bottomFace?.advanced(by: destinationIndex * Int(componentsPerPixel)), data?.advanced(by: sourceIndex * Int(componentsPerPixel)), sizeof(Float) * cubeWidth * Int(componentsPerPixel))
        }
        
        
        let textureDescriptor = TextureDescriptor(textureCubeWithPixelFormat: GL_RGBA16F, width: cubeWidth, height: cubeWidth, mipmapped: true)
        let texture = Texture(textureWithDescriptor: textureDescriptor)
        
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_POSITIVE_X, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: rightFace!)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_POSITIVE_Y, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: topFace!)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_POSITIVE_Z, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: backFace!)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_NEGATIVE_X, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: leftFace!)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_NEGATIVE_Y, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: bottomFace!)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_NEGATIVE_Z, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: frontFace!)
        
        texture.generateMipmaps()
        
        textureCache[path] = texture
        return texture
        
    }
    
    
}