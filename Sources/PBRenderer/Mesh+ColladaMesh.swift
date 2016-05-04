//
//  Mesh+ColladaMesh.swift
//  PBRenderer
//
//  Created by Joseph Bennett on 29/04/16.
//
//

import Foundation
import ColladaParser
import SGLOpenGL

extension GLMesh {
    
    static func meshesFromCollada(_ colladaMesh: MeshType, root: Collada) -> [GLMesh] {
        var sourcesToAttributes = [String : VertexAttribute]()
        
        for source in colladaMesh.source {
            let buffer : GPUBuffer<Void>
            let glType : GLenum
            let typeSizeInBytes : Int
            if case let .floatArray(floatArray) = source.choice0! {
                glType = GL_FLOAT
                buffer = GPUBuffer<Void>(GPUBuffer<Float>(capacity: floatArray.data.count, data: floatArray.data, accessFrequency: .Static, accessType: .Draw))
                typeSizeInBytes = sizeof(GLfloat)
            } else  {
                assertionFailure("No valid conversion for collada source data")
                continue
            }

            sourcesToAttributes["#" + source.id] = VertexAttribute(data: buffer, glTypeName: glType, componentsPerAttribute: Int(source.techniqueCommon!.accessor.param.count), isNormalised: false, strideInBytes: Int(source.techniqueCommon!.accessor.stride!) * typeSizeInBytes, bufferOffsetInBytes: 0)
        }
        
        var attributes = [AttributeType : VertexAttribute]()
        
        var meshes = [GLMesh]()
        
        for primitive in colladaMesh.choice0 {
            if case let .triangles(tris) = primitive {
                for input in tris.input {
                    let attributeType : AttributeType
                    
                    switch input.semantic {
                    case "VERTEX":
                        attributeType = .Position
                    case "POSITION":
                        attributeType = .Position
                    default:
                        continue
                    }
                    
                    var source = input.source
                    if root[source] is VerticesType {
                        source = (root[source] as! VerticesType).input.first!.source
                    }
                    
                    attributes[attributeType] = sourcesToAttributes[source]
                }
                
                let buffer = GPUBuffer<GLuint>(capacity: Int(tris.count), data: tris.p!.data.enumerated().filter { $0.0 % 2 == 0 }.map { GLuint($1) }, accessFrequency: .Static, accessType: .Draw)
                
                
                let drawCommand = DrawCommand(data: GPUBuffer<Void>(buffer), glPrimitiveType: GL_TRIANGLES, elementCount: Int(tris.count), glElementType: GL_UNSIGNED_INT, bufferOffsetInBytes: 0)
                meshes.append(GLMesh(drawCommand: drawCommand, attributes: attributes))
            }
        }
        
        
        return meshes
    }
}