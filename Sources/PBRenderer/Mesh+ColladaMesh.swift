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
    
    static func meshesFromCollada(_ colladaMesh: Collada.MeshNode) -> [GLMesh] {
        var sourcesToAttributes = Dictionary<Collada.SourceNode, VertexAttribute>()
        
        for source in colladaMesh.sources {
            let buffer : GPUBuffer<Void>
            let glType : GLenum
            let typeSizeInBytes : Int
            if let floatArray = source.data as? Collada.FloatArrayNode {
                glType = GL_FLOAT
                buffer = GPUBuffer<Void>(GPUBuffer<Float>(capacity: floatArray.values.count, data: floatArray.values, accessFrequency: .Static, accessType: .Draw))
                typeSizeInBytes = sizeof(GLfloat)
            } else  {
                assertionFailure("No valid conversion for collada source data")
                continue
            }

            sourcesToAttributes[source] = VertexAttribute(data: buffer, glTypeName: glType, componentsPerAttribute: source.techniqueCommon!.accessor.params.count, isNormalised: false, strideInBytes: source.techniqueCommon!.accessor.stride * typeSizeInBytes, bufferOffsetInBytes: 0)
        }
        
        var attributes = [AttributeType : VertexAttribute]()
        
        var meshes = [GLMesh]()
        
        for primitive in colladaMesh.primitives {
            if let primitive = primitive as? Collada.TrianglesNode {
                for input in primitive.inputs {
                    let attributeType : AttributeType
                    
                    switch input.semantic {
                    case .Normal:
                        attributeType = .Normal
                    case .TexCoord:
                        attributeType = .TextureCoordinate
                    case .Vertex:
                        attributeType = .Position
                    case .Position:
                        attributeType = .Position
                    case .TexTangent:
                        continue
                    }
                    
                    var source = input.source
                    if source is Collada.VerticesNode {
                        source = (source as! Collada.VerticesNode).inputs.first!.source
                    }
                    
                    attributes[attributeType] = sourcesToAttributes[(source as! Collada.SourceNode)]
                }
                
                let buffer = GPUBuffer<GLuint>(capacity: primitive.count, data: primitive.indices.values, accessFrequency: .Static, accessType: .Draw)
                
                
                let drawCommand = DrawCommand(data: GPUBuffer<Void>(buffer), glPrimitiveType: GL_TRIANGLES, elementCount: primitive.count, glElementType: GL_UNSIGNED_INT, bufferOffsetInBytes: 0)
                meshes.append(GLMesh(drawCommand: drawCommand, attributes: attributes))
            }
        }
        
        
        return meshes
    }
}