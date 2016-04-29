//
//  Mesh.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 29/04/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath

import Metal

protocol Mesh {
    func render()
}

enum AttributeType : Int {
    case Index = -1
    case Position = 0
    case Normal = 1
    case TextureCoordinate = 2
}

struct VertexAttribute {
    let data : UnsafePointer<Void>
    let glType : GLenum
    let stride : Int
    let typeSizeInBytes : Int
    let count : Int
    
    subscript(index: Int) -> UnsafePointer<Void> {
        return data.advanced(by: index * stride * typeSizeInBytes)
    }
}

class GLMesh : Mesh {
    
    struct VertexInput {
        let position : vec3
        let normal : vec3
        let textureCoordinate : vec2
    }
    
    let vertexArrayObject : GLuint
    let indexAttribute : VertexAttribute
    
    init(vertexCount: Int, attributes: [AttributeType : VertexAttribute]) {
        
        var vao = GLuint(0)
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        
        var vertexInputs = [VertexInput](repeating: VertexInput(position: vec3(0, 0, 0), normal: vec3(0, 0, 0), textureCoordinate: vec2(0, 0)), count: vertexCount)
        
        //populate buffer
        
        let positionAttribute = attributes[.Position]!
        let normalAttribute = attributes[.Normal]!
        let textureCoordinateAttribute = attributes[.TextureCoordinate]
        
        for i in 0..<vertexCount {
            let positionBase = UnsafePointer<Float>(positionAttribute[i])
            
            let position = vec3(positionBase.pointee, positionBase.successor().pointee, positionBase.advanced(by: 2).pointee)
            let normal = vec3(0, 0, 1)//unsafeBitCast(normalAttribute[i].pointee, to: vec3.self)
            let textureCoordinate = vec2(0, 0)//(textureCoordinateAttribute != nil) ? unsafeBitCast(textureCoordinateAttribute![i].pointee, to: vec2.self) : vec2(0, 0)
            
            vertexInputs[i] = VertexInput(position: position, normal: normal, textureCoordinate: textureCoordinate)
        }
        
        let buffer = GPUBuffer<VertexInput>(capacity: vertexCount, data: vertexInputs, bufferBinding: GL_ARRAY_BUFFER, accessFrequency: .Static, accessType: .Draw)
        buffer.bindToGL()
        
        self.indexAttribute = attributes[.Index]!
        let indicesBuffer = GPUBuffer<GLuint>(capacity: indexAttribute.count * 3, bufferBinding: GL_ELEMENT_ARRAY_BUFFER, accessFrequency: .Static, accessType: .Draw)
        for i in 0..<indexAttribute.count * 3  {
            indicesBuffer[i] = UnsafePointer<GLuint>(indexAttribute[i]).pointee
        }
        
        indicesBuffer.didModify()
        indicesBuffer.bindToGL()
        
        for (type, attribute) in attributes {
            if case .Index = type { continue }
         
            glEnableVertexAttribArray(GLuint(type.rawValue))
            glVertexAttribPointer(index: GLuint(type.rawValue), size: GLint(attribute.stride), type: attribute.glType, normalized: false, stride: GLsizei(sizeof(VertexInput)), pointer: nil)

        }
        
        glBindVertexArray(0);
        
        self.vertexArrayObject = vao
    }
    
    func render() {
        glBindVertexArray(self.vertexArrayObject);

        //glDrawArrays(GL_TRIANGLES, 0, 3)
        glDrawElements(GL_TRIANGLES, GLsizei(indexAttribute.count), indexAttribute.glType, nil);
        glBindVertexArray(0);
    }
}