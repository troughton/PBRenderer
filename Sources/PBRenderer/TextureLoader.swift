//
//  TextureLoader.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 26/05/16.
//
//

import Foundation
import SGLOpenGL

public final class TextureLoader {
    fileprivate static var textureCache = [String : Texture]()
    
    public static func textureFromVerticalCrossHDRCubeMapAtPath(_ path: String) -> Texture {
        
        if let texture = textureCache[path] {
            return texture
        }
        
        var width = Int32(0)
        var height = Int32(0)
        var componentsPerPixel = Int32(0)
        guard let data = stbi_loadf(path, &width, &height, &componentsPerPixel, 0) else { fatalError("Couldn't load texture at path \(path)") }
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
        
        let backFace = UnsafeMutablePointer<Float>.allocate(capacity: cubeNumElements)
        defer { backFace.deallocate(capacity: cubeNumElements) }
        
        for i in 0..<cubeWidth {
            let row = Int(height - 1) - i
            let centreOffset = cubeWidth
            
            let sourceIndex = row * Int(width) + centreOffset
            let destinationIndex = cubeWidth * i
            
            memcpy(backFace.advanced(by: destinationIndex * Int(componentsPerPixel)), data.advanced(by: sourceIndex * Int(componentsPerPixel)), MemoryLayout<Float>.size * cubeWidth * Int(componentsPerPixel))
        }
        
        
        let frontFace = UnsafeMutablePointer<Float>.allocate(capacity: cubeNumElements)
        defer { frontFace.deallocate(capacity: cubeNumElements) }
        
        for i in 0..<cubeWidth {
            let row = cubeWidth + i
            let centreOffset = cubeWidth
            
            let sourceIndex = row * Int(width) + centreOffset
            let destinationIndex = cubeWidth * i
            for i in 0..<cubeWidth {
                memcpy(frontFace.advanced(by: (destinationIndex + cubeWidth - i - 1) * Int(componentsPerPixel)), data.advanced(by: (sourceIndex + i) * Int(componentsPerPixel)), MemoryLayout<Float>.size * Int(componentsPerPixel))
            }
        }
        
        let topFace = UnsafeMutablePointer<Float>.allocate(capacity: cubeNumElements)
        defer { topFace.deallocate(capacity: cubeNumElements) }
        
        for i in 0..<cubeWidth {
            let row = cubeWidth - 1 - i
            let centreOffset = cubeWidth
            
            let sourceIndex = row * Int(width) + centreOffset
            let destinationIndex = cubeWidth * i
            memcpy(topFace.advanced(by: destinationIndex * Int(componentsPerPixel)), data.advanced(by: sourceIndex * Int(componentsPerPixel)), MemoryLayout<Float>.size * cubeWidth * Int(componentsPerPixel))
        }
        
        let leftFace = UnsafeMutablePointer<Float>.allocate(capacity: cubeNumElements)
        defer { leftFace.deallocate(capacity: cubeNumElements) }
        
        for i in 0..<cubeWidth {
            let row = cubeWidth + i
            
            let sourceIndex = row * Int(width)
            let destinationIndex = cubeWidth * i
            
            for i in 0..<cubeWidth {
                memcpy(leftFace.advanced(by: (destinationIndex + cubeWidth - i - 1) * Int(componentsPerPixel)), data.advanced(by: (sourceIndex + i) * Int(componentsPerPixel)), MemoryLayout<Float>.size * Int(componentsPerPixel))
            }
        }
        
        let rightFace = UnsafeMutablePointer<Float>.allocate(capacity: cubeNumElements)
        defer { rightFace.deallocate(capacity: cubeNumElements) }
        
        for i in 0..<cubeWidth {
            let row = cubeWidth + i
            
            let sourceIndex = row * Int(width) + 2 * cubeWidth
            let destinationIndex = cubeWidth * i
            for i in 0..<cubeWidth {
                memcpy(rightFace.advanced(by: (destinationIndex + cubeWidth - i - 1) * Int(componentsPerPixel)), data.advanced(by: (sourceIndex + i) * Int(componentsPerPixel)), MemoryLayout<Float>.size * Int(componentsPerPixel))
            }
        }
        
        let bottomFace = UnsafeMutablePointer<Float>.allocate(capacity: cubeNumElements)
        defer { bottomFace.deallocate(capacity: cubeNumElements) }
        
        for i in 0..<cubeWidth {
            let row = 3 * cubeWidth - 1 - i
            let centreOffset = cubeWidth
            
            let sourceIndex = row * Int(width) + centreOffset
            let destinationIndex = cubeWidth * i
            memcpy(bottomFace.advanced(by: destinationIndex * Int(componentsPerPixel)), data.advanced(by: sourceIndex * Int(componentsPerPixel)), MemoryLayout<Float>.size * cubeWidth * Int(componentsPerPixel))
        }
        
        
        let textureDescriptor = TextureDescriptor(textureCubeWithPixelFormat: pixelFormat, width: cubeWidth, height: cubeWidth, mipmapped: true)
        let texture = Texture(textureWithDescriptor: textureDescriptor)
        
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_POSITIVE_X, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: rightFace)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_POSITIVE_Y, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: topFace)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_POSITIVE_Z, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: backFace)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_NEGATIVE_X, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: leftFace)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_NEGATIVE_Y, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: bottomFace)
        texture.fillSubImage(target: GL_TEXTURE_CUBE_MAP_NEGATIVE_Z, mipmapLevel: 0, width: cubeWidth, height: cubeWidth, type: GL_FLOAT, data: frontFace)
        
        texture.generateMipmaps()
        
        textureCache[path] = texture
        return texture
    }
    
    static func ltcTextureFromFile(_ path: String, numComponents : Int) -> Texture {
        if let texture = textureCache[path] {
            return texture
        }
        
        let dimensions = 64
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        
        var pixelFormat : GLenum
            
        switch numComponents {
        case 2:
            pixelFormat = GL_RG32F
        case 4:
            pixelFormat = GL_RGBA32F
        default:
            fatalError()
        }

        let textureDescriptor = TextureDescriptor(texture2DWithPixelFormat: pixelFormat, width: dimensions, height: dimensions, mipmapped: false)
        let texture = Texture(textureWithDescriptor: textureDescriptor)
        
        data?.withUnsafeBytes({ (bytes) -> Void in
            texture.fillSubImage(target: GL_TEXTURE_2D, mipmapLevel: 0, width: dimensions, height: dimensions, type: GL_FLOAT, data: bytes)
        })

        textureCache[path] = texture
        return texture
    }
    
    
}
