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
import SGLMath

private struct VertexLayout {
    var size : Int = 0
    var attributes = [AttributeType : (lengthInBytes: Int, offset: Int, glType: GLint)]()
    
    func alignedOffsetForValueWithAlignment(_ alignment: Int, offset: Int) -> Int {
        return roundUpToNearestMultiple(numToRound: offset, of: alignment)
    }
    
    func alignedOffsetForValue<T>(_ value: T, offset: Int) -> Int {
        return alignedOffsetForValueWithAlignment(MemoryLayout.alignment(ofValue: value), offset: offset)
    }
    
    func alignedOffsetForType<T>(_ type: T.Type, offset: Int) -> Int {
        return alignedOffsetForValueWithAlignment(MemoryLayout<T>.alignment, offset: offset)
    }
    
    mutating func addAttribute(type : AttributeType, glType: GLint, alignment: Int, lengthInBytes: Int) {
        if let existingAttribute = self.attributes[type] {
            assert(existingAttribute.lengthInBytes == lengthInBytes && existingAttribute.glType == glType)
            return
        }
        
        let offset = self.size
        let alignedOffset = self.alignedOffsetForValueWithAlignment(alignment, offset: offset)
        self.attributes[type] = (lengthInBytes, alignedOffset, glType)
        self.size = alignedOffset + lengthInBytes
    }
    
    var alignedSize : Int {
        return roundUpToNearestMultiple(numToRound: self.size, of: 16)
    }
}

private class Vertex : Hashable {
    let layout : VertexLayout
    let data : UnsafeMutableRawPointer!
    
    lazy var hashValue : Int = {
        var h = 2166136261;
        
        for i in 0..<self.layout.size {
            h = (h &* 16777619) ^ Int(self.data.advanced(by: i).assumingMemoryBound(to: UInt8.self).pointee);
        }
        
        return h;
    }() //can guarantee that hashValue isn't accessed until the vertex has been fully initialised
    
    init(layout: VertexLayout) {
        self.layout = layout
        self.data = calloc(1, layout.size)
    }
    
    func setAttribute(_ attribute: AttributeType, value: UnsafeRawPointer) {
        guard let (lengthInBytes, offset, _) = layout.attributes[attribute] else {
            fatalError("No such attribute \(attribute) in layout.")
        }
        
        memcpy(self.data.advanced(by: offset), value, lengthInBytes)
    }
    
    //Note: this assumes that the data is in the form of floats, which may not always be the case.
    var position : vec3 {
        guard let (_, offset, _) = layout.attributes[.position] else {
            fatalError("No attribute for position in layout \(layout.attributes).")
        }
        
        let xPositionPointer = self.data.advanced(by: offset).assumingMemoryBound(to: Float.self)
        return vec3(xPositionPointer.pointee, xPositionPointer.successor().pointee, xPositionPointer.advanced(by: 2).pointee)
    }
    
    deinit {
        free(self.data)
    }
}

private func ==(lhs: Vertex, rhs: Vertex) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

extension GLMesh {
    
    static func classifySourcesFromInput(_ input: InputType, root: Collada, dictionary: inout [AttributeType : (offset: Int, source: SourceType)], offset inOffset: Int? = nil) {
            let attributeType : AttributeType
        let offset: Int
        
        if let input = input as? InputLocalOffsetType {
            offset = Int(input.offset)
        } else {
            offset = inOffset!
        }
        
            switch input.semantic {
            case "VERTEX":
                if let vertices = root[input.source] as? VerticesType {
                    for input in vertices.input {
                        GLMesh.classifySourcesFromInput(input, root: root, dictionary: &dictionary, offset: offset)
                    }
                }
                return
            case "POSITION":
                attributeType = .position
            case "NORMAL":
                attributeType = .normal
            case "TEXCOORD":
                attributeType = .textureCoordinate
            default:
                fatalError("Unknown attribute")
            }
        
        guard let source = root[input.source] as? SourceType else { fatalError("The source must be of type SourceType") }
        dictionary[attributeType] = (offset, source)
    }
    
    static func meshesFromCollada(_ colladaMesh: MeshType, root: Collada) -> ([GLMesh], boundingBox: BoundingBox) {
        var attributesToSources = [AttributeType : (offset: Int, source: SourceType)]()
        
        var meshes = [GLMesh]()
        var vertexLayout = VertexLayout()
        var vertices = [Vertex]()
        var vertexIndices = [Vertex : Int]()
        var materialNames = [String?]()
        
        for primitive in colladaMesh.choice0 { //Construct vertex layout.
            if case let .triangles(tris) = primitive {
                
                for input in tris.input {
                    self.classifySourcesFromInput(input, root: root, dictionary: &attributesToSources)
                }
                
                
                for (type, value) in attributesToSources {
                    let stride = Int(value.source.techniqueCommon!.accessor.stride!)
                    let typeSize : Int
                    let glType : GLint
                    switch value.source.choice0! {
                    case .boolArray(_): typeSize = MemoryLayout<Bool>.size; glType = GL_BOOL
                    case .floatArray(_): typeSize = MemoryLayout<Float>.size; glType = GL_FLOAT
                    case .intArray(_): typeSize = MemoryLayout<Int32>.size; glType = GL_INT
                    default: fatalError("No valid type size for type \(value.source.choice0!)")
                    }
                    let sizeInBytes = typeSize * stride
                    
                    var alignment = Int(sizeInBytes)
                    if alignment > 4 {
                        alignment = roundUpToNearestMultiple(numToRound: alignment, of: 16)
                    }
                    
                    vertexLayout.addAttribute(type: type, glType: glType, alignment: alignment, lengthInBytes: sizeInBytes)
                }
            }
        }
        
        var minVertex = vec3(Float.infinity)
        var maxVertex = vec3(-Float.infinity)
        
        let drawCommands = colladaMesh.choice0.flatMap { (primitive) -> DrawCommand? in
            if case let .triangles(tris) = primitive {
                var indices = [UInt32]()
                
                let stride = tris.input.count
                for i in 0..<tris.count {
                    for j in 0..<3 {
                        let vertex = Vertex(layout: vertexLayout)
                        
                        let vertexIndex = Int(i * 3) + j
                        
                        for (type, offsetAndSource) in attributesToSources {
                            let indexInArray = Int(tris.p!.data[stride * vertexIndex + offsetAndSource.offset]) * Int(offsetAndSource.source.techniqueCommon!.accessor.stride!)
                            
                            var valuePtr : UnsafeRawPointer!
                            
                            switch offsetAndSource.source.choice0! {
                            case let .boolArray(array):
                                array.data.withUnsafeBufferPointer { bufferPointer in
                                    valuePtr = UnsafeRawPointer(bufferPointer.baseAddress?.advanced(by: indexInArray))
                                }
                            case let .floatArray(array):
                                array.data.withUnsafeBufferPointer { bufferPointer in
                                    valuePtr = UnsafeRawPointer(bufferPointer.baseAddress?.advanced(by: indexInArray))
                                }
                            case let .intArray(array):
                                array.data.withUnsafeBufferPointer { bufferPointer in
                                    valuePtr = UnsafeRawPointer(bufferPointer.baseAddress?.advanced(by: indexInArray))
                                }
                            default:
                                fatalError("Array type \(offsetAndSource.source.choice0!) not supported.")
                            }
                            
                            vertex.setAttribute(type, value: valuePtr)
                        }
                        
                        
                        
                        if let existingIndex = vertexIndices[vertex] {
                            indices.append(UInt32(existingIndex))
                            
                        } else {
                            let position = vertex.position
                            minVertex = min(position, minVertex)
                            maxVertex = max(position, maxVertex)
                            
                            vertexIndices[vertex] = vertices.count
                            indices.append(UInt32(vertices.count))
                            vertices.append(vertex)
                        }
                    }
                }
                
                let indexBuffer = GPUBuffer<GLuint>(capacity: Int(tris.count * 3), data: indices, bufferBinding: GL_ELEMENT_ARRAY_BUFFER, accessFrequency: .static, accessType: .draw)
                
                materialNames.append(tris.material)
                
                return DrawCommand(data: GPUBuffer<UInt8>(indexBuffer), glPrimitiveType: GL_TRIANGLES, elementCount: Int(tris.count * 3), glElementType: GL_UNSIGNED_INT, bufferOffsetInBytes: 0)
            
            } else {
                print("Warning: mesh of type \(primitive) not supported.")
                return nil
            }
        }

            
        let vertexBuffer = GPUBuffer<UInt8>(capacity: vertices.count * vertexLayout.alignedSize, data: nil, bufferBinding: GL_ARRAY_BUFFER, accessFrequency: .static, accessType: .draw)
        for (i, vertex) in vertices.enumerated() {
                vertexBuffer.copyToIndex(i * vertexLayout.alignedSize, value: vertex.data.assumingMemoryBound(to: UInt8.self), sizeInBytes: vertexLayout.size)
        }
        
        vertexBuffer.didModify()
        
        var attributeTypesToVertexAttributes = [AttributeType : VertexAttribute]()
        for (attribute, value) in vertexLayout.attributes {
                let offset = value.offset
                let source = attributesToSources[attribute]!.source
                    
                attributeTypesToVertexAttributes[attribute] = VertexAttribute(data: vertexBuffer, glTypeName: value.glType, componentsPerAttribute: Int(source.techniqueCommon!.accessor.param.count), isNormalised: false, strideInBytes: vertexLayout.alignedSize, bufferOffsetInBytes: offset)
            }
        
        for (drawCommand, material) in zip(drawCommands, materialNames) {
            meshes.append(GLMesh(drawCommand: drawCommand, attributes: attributeTypesToVertexAttributes, materialName: material))
        }

        return (meshes, BoundingBox(minPoint: minVertex, maxPoint: maxVertex))
    }
}
