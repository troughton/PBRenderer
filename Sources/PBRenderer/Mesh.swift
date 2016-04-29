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
    case Position = 0
    case Normal = 1
    case TextureCoordinate = 2
}

struct VertexAttribute {
    let data : GPUBuffer<Void>
    let glTypeName : GLenum
    let componentsPerAttribute : Int
    let isNormalised : Bool
    let stride : Int
    let bufferOffsetInBytes : Int
}

struct DrawCommand {
    let data : GPUBuffer<Void>
    let glPrimitiveType : GLenum
    let elementCount : Int
    let glElementType : GLenum
    let bufferOffsetInBytes : Int
}

class GLMesh : Mesh {
    
    private let _vertexArrayObject : GLuint
    private let _drawCommand : DrawCommand
    
    init(drawCommand: DrawCommand, attributes: [AttributeType : VertexAttribute]) {
        
        var vao = GLuint(0)
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        
        _drawCommand = drawCommand
        
        _drawCommand.data.bufferBinding = GL_ELEMENT_ARRAY_BUFFER
        _drawCommand.data.bindToGL()
        
        for (type, attribute) in attributes {
         
            attribute.data.bufferBinding = GL_ARRAY_BUFFER
            attribute.data.bindToGL()
            
            glEnableVertexAttribArray(GLuint(type.rawValue))
            glVertexAttribPointer(index: GLuint(type.rawValue), size: GLint(attribute.componentsPerAttribute), type: attribute.glTypeName, normalized: attribute.isNormalised, stride: GLsizei(attribute.stride), pointer: UnsafePointer<Void>(bitPattern: attribute.bufferOffsetInBytes))

        }
        
        glBindVertexArray(0);
        
        _vertexArrayObject = vao
    }
    
    func render() {
        glBindVertexArray(_vertexArrayObject);

        glDrawElements(_drawCommand.glPrimitiveType, GLsizei(_drawCommand.elementCount), _drawCommand.glElementType, UnsafePointer<Void>(bitPattern: _drawCommand.bufferOffsetInBytes));
        glBindVertexArray(0);
    }
}