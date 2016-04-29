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
            if let floatArray = source.data as? Collada.FloatArrayNode {
                glType = GL_FLOAT
                buffer = GPUBuffer<Void>(GPUBuffer<Float>(capacity: floatArray.values.count, data: floatArray.values, accessFrequency: .Static, accessType: .Draw))
            } else  {
                assertionFailure("No valid conversion for collada source data")
                continue
            }

            sourcesToAttributes[source] = VertexAttribute(data: buffer, glTypeName: glType, componentsPerAttribute: source.techniqueCommon!.accessor.params.count, isNormalised: false, stride: source.techniqueCommon!.accessor.stride, bufferOffsetInBytes: 0)
        }
        
        var attributes = [AttributeType : VertexAttribute]()
        
        let meshes = colladaMesh.drawCommands.flatMap { (drawCommand) -> GLMesh? in
            if let primitive = drawCommand as? Collada.TrianglesNode {
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
                    default:
                        assertionFailure("Missing attribute conversion")
                        return nil
                    }
                    
                    var source = input.source
                    if source is Collada.VerticesNode {
                        source = (source as! Collada.VerticesNode).inputs.first!.source
                    }
                    
                    attributes[attributeType] = sourcesToAttributes[(source as! Collada.SourceNode)]
                }
                
                let buffer = GPUBuffer<GLuint>(capacity: primitive.count, data: primitive.indices.values, accessFrequency: .Static, accessType: .Draw)
                
                
                let drawCommand = DrawCommand(data: GPUBuffer<Void>(buffer), glPrimitiveType: GL_TRIANGLES, elementCount: primitive.count, glElementType: GL_UNSIGNED_INT, bufferOffsetInBytes: 0)
                return GLMesh(drawCommand: drawCommand, attributes: attributes)
            }
            assertionFailure("Missing primitive")
            return nil
        }
        
        return meshes
    }
}