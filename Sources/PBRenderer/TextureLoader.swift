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

//extension Texture {
//    convenience init<T>(cubeMapWithWidth width: Int, height: Int, internalFormat: GLenum, format: GLenum, type: GLenum, data: UnsafePointer<T>) {
//        
//    }
//}
//
//final class TextureLoader {
//    private static let textureCache = [String : Texture]()
//    
//    static func textureFromVerticalCrossHDRCubeMapAtPath(_ path: String) -> Texture {
//        if let texture = textureCache[path] {
//            return texture
//        }
//        
//        
//        var width = Int32(0)
//        var height = Int32(0)
//        var componentsPerPixel = Int32(0)
//        let data = stbi_loadf(path, &width, &height, &componentsPerPixel, 0)
//        
//        
//    }
//    
//    
//}