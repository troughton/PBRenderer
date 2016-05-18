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

enum AttributeType : Int {
    case Position = 0
    case Normal = 1
    case TextureCoordinate = 2
}

struct VertexAttribute {
    let data : GPUBuffer<UInt8>
    let glTypeName : GLenum
    let componentsPerAttribute : Int
    let isNormalised : Bool
    let strideInBytes : Int
    let bufferOffsetInBytes : Int
}

struct DrawCommand {
    let data : GPUBuffer<UInt8>
    let glPrimitiveType : GLenum
    let elementCount : Int
    let glElementType : GLenum
    let bufferOffsetInBytes : Int
}

final class GLMesh {
    
    let materialName : String?
    
    private let _vertexArrayObject : GLuint
    private let _drawCommand : DrawCommand
    private let _attributes : [AttributeType : VertexAttribute]
    
    init(drawCommand: DrawCommand, attributes: [AttributeType : VertexAttribute], materialName: String? = nil) {
        _attributes = attributes
        
        var vao = GLuint(0)
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        
        _drawCommand = drawCommand
        
        _drawCommand.data.bindToGL(buffer: GL_ELEMENT_ARRAY_BUFFER)
        
        for (type, attribute) in attributes {
         
            attribute.data.bindToGL(buffer: GL_ARRAY_BUFFER)
            
            glEnableVertexAttribArray(GLuint(type.rawValue))
            glVertexAttribPointer(index: GLuint(type.rawValue), size: GLint(attribute.componentsPerAttribute), type: attribute.glTypeName, normalized: attribute.isNormalised, stride: GLsizei(attribute.strideInBytes), pointer: UnsafePointer<Void>(bitPattern: attribute.bufferOffsetInBytes))

        }
        
        glBindVertexArray(0);
        
        _vertexArrayObject = vao
        
        self.materialName = materialName
    }
    
    func render() {
        glBindVertexArray(_vertexArrayObject);

        glDrawElements(_drawCommand.glPrimitiveType, GLsizei(_drawCommand.elementCount), _drawCommand.glElementType, UnsafePointer<Void>(bitPattern: _drawCommand.bufferOffsetInBytes));
        glBindVertexArray(0);
    }
    
    static let fullScreenQuad : GLMesh = {
        let vertices = [vec4(-1, -1, 0, 1), vec4(-1, 1, 0, 1), vec4(1, -1, 0, 1), vec4(1, 1, 0, 1)]
        let indices : [UInt8] = [0, 2, 1, 3, 1, 2]
        let vertexBuffer = GPUBuffer(capacity: vertices.count, data: vertices, bufferBinding: GL_ARRAY_BUFFER, accessFrequency: .Static, accessType: .Draw)
        let indexBuffer = GPUBuffer(capacity: indices.count, data: indices, bufferBinding: GL_ELEMENT_ARRAY_BUFFER, accessFrequency: .Static, accessType: .Draw)
        
        let vertexAttributes = [AttributeType.Position : VertexAttribute(data: GPUBuffer<UInt8>(vertexBuffer), glTypeName: GL_FLOAT, componentsPerAttribute: 4, isNormalised: false, strideInBytes: 0, bufferOffsetInBytes: 0)]
        let drawCommand = DrawCommand(data: GPUBuffer<UInt8>(indexBuffer), glPrimitiveType: GL_TRIANGLES, elementCount: indices.count, glElementType: GL_UNSIGNED_BYTE, bufferOffsetInBytes: 0)
        
        return GLMesh(drawCommand: drawCommand, attributes: vertexAttributes)
    }()
    
    static let unitBox : GLMesh = {
        let vertices = [vec3(-0.5, -0.5, 0.5),
            vec3(-0.5, -0.5, -0.5),
            vec3(-0.5, 0.5, -0.5),
            vec3(-0.5, 0.5, 0.5),
            vec3(0.5, -0.5, 0.5),
            vec3(0.5, -0.5, -0.5),
            vec3(0.5, 0.5, -0.5),
            vec3(0.5, 0.5, 0.5)]
        let indices : [UInt8] = [ 3, 2, 1, 2, 1, 0, 1, 5, 4, 5, 4, 0, 2, 6, 5, 6, 5, 1, 7, 6, 2, 6, 2, 3, 4, 7, 3, 7, 3, 0, 5, 6, 7, 6, 7, 4]
        let vertexBuffer = GPUBuffer(capacity: vertices.count, data: vertices, bufferBinding: GL_ARRAY_BUFFER, accessFrequency: .Static, accessType: .Draw)
        let indexBuffer = GPUBuffer(capacity: indices.count, data: indices, bufferBinding: GL_ELEMENT_ARRAY_BUFFER, accessFrequency: .Static, accessType: .Draw)
        
        let vertexAttributes = [AttributeType.Position : VertexAttribute(data: GPUBuffer<UInt8>(vertexBuffer), glTypeName: GL_FLOAT, componentsPerAttribute: 3, isNormalised: false, strideInBytes: 0, bufferOffsetInBytes: 0)]
        let drawCommand = DrawCommand(data: GPUBuffer<UInt8>(indexBuffer), glPrimitiveType: GL_TRIANGLES, elementCount: indices.count, glElementType: GL_UNSIGNED_BYTE, bufferOffsetInBytes: 0)
        
        return GLMesh(drawCommand: drawCommand, attributes: vertexAttributes)
    }()
}