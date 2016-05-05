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

/** multiple must be a power of two. http://stackoverflow.com/questions/3407012/c-rounding-up-to-the-nearest-multiple-of-a-number */
func roundUpToNearestMultiple(numToRound: Int, of multiple: Int) -> Int {
    assert(multiple > 0 && ((multiple & (multiple - 1)) == 0));
    return (numToRound + multiple - 1) & ~(multiple - 1);
}

struct VertexLayout {
    var size : Int = 0
    var attributes = [AttributeType : (lengthInBytes: Int, offset: Int, glType: GLint)]()
    
    func alignedOffsetForValueWithAlignment(_ alignment: Int, offset: Int) -> Int {
        return roundUpToNearestMultiple(numToRound: offset, of: alignment)
    }
    
    func alignedOffsetForValue<T>(_ value: T, offset: Int) -> Int {
        return alignedOffsetForValueWithAlignment(alignofValue(value), offset: offset)
    }
    
    func alignedOffsetForType<T>(_ type: T.Type, offset: Int) -> Int {
        return alignedOffsetForValueWithAlignment(alignof(type), offset: offset)
    }
    
    mutating func addAttribute(_ type : AttributeType, glType: GLint, alignment: Int, lengthInBytes: Int) {
        let offset = self.size
        let alignedOffset = self.alignedOffsetForValueWithAlignment(alignment, offset: offset)
        self.attributes[type] = (lengthInBytes, alignedOffset, glType)
        self.size = alignedOffset + lengthInBytes
    }
    
    var alignedSize : Int {
        return roundUpToNearestMultiple(numToRound: self.size, of: 16)
    }
}

class Vertex : Hashable {
    let layout : VertexLayout
    let data : UnsafeMutablePointer<UInt8>!
    
    init(layout: VertexLayout) {
        self.layout = layout
        self.data = UnsafeMutablePointer<UInt8>(calloc(1, layout.size))
    }
    
    func setAttribute<T>(attribute: AttributeType, value: UnsafePointer<T>) {
        guard let (lengthInBytes, offset, _) = layout.attributes[attribute] else {
            fatalError("No such attribute \(attribute) in layout.")
        }
        
        memcpy(self.data.advanced(by: offset), value, lengthInBytes)
    }
    
    var hashValue : Int {
        var h : Int = 2166136261;
        
        for i in 0..<layout.size {
            h = (h &* 16777619) ^ Int(self.data.advanced(by: i).pointee);
        }
        
        return h;
    }
    
    deinit {
        free(self.data)
    }
}

func ==(lhs: Vertex, rhs: Vertex) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

extension GLMesh {
    
    //Per vertex, we have:
    //an array of inputs
    //  each of which has a source
    
    
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
                attributeType = .Position
            case "NORMAL":
                attributeType = .Normal
            case "TEXCOORD":
                attributeType = .TextureCoordinate
            default:
                fatalError("Unknown attribute")
            }
        
        guard let source = root[input.source] as? SourceType else { fatalError("The source must be of type SourceType") }
        dictionary[attributeType] = (offset, source)

    }
    
    static func meshesFromCollada(_ colladaMesh: MeshType, root: Collada) -> [GLMesh] {
        var attributesToSources = [AttributeType : (offset: Int, source: SourceType)]()
        
        
        //TODO: Shared vertices between meshes. Requires a different buffer for each vertex layout and precomputing the size of the array for each layout to contain the vertices of every mesh.
        var meshes = [GLMesh]()
        
        for primitive in colladaMesh.choice0 {
            if case let .triangles(tris) = primitive {
                
                for input in tris.input {
                    self.classifySourcesFromInput(input, root: root, dictionary: &attributesToSources)
                }
                
                var vertexLayout = VertexLayout()
                
                for (type, value) in attributesToSources {
                    let stride = Int(value.source.techniqueCommon!.accessor.stride!)
                    let typeSize : Int
                    let glType : GLint
                    switch value.source.choice0! {
                    case .boolArray(_): typeSize = sizeof(Bool); glType = GL_BOOL
                    case .floatArray(_): typeSize = sizeof(Float); glType = GL_FLOAT
                    case .intArray(_): typeSize = sizeof(Int32); glType = GL_INT
                    default: fatalError("No valid type size for type \(value.source.choice0!)")
                    }
                    let sizeInBytes = typeSize * stride
                    
                    var alignment = Int(sizeInBytes)
                    if alignment > 4 {
                        alignment = roundUpToNearestMultiple(numToRound: alignment, of: 16)
                    }
                    
                    vertexLayout.addAttribute(type, glType: glType, alignment: alignment, lengthInBytes: sizeInBytes)
                }
                
                var vertices = [Vertex]()
                
                var indices = [UInt16]()
                
                let stride = tris.input.count
                for i in 0..<tris.count {
                    for j in 0..<3 {
                        let vertex = Vertex(layout: vertexLayout)
                        
                        let vertexIndex = Int(i * 3) + j
                        
                        for (type, offsetAndSource) in attributesToSources {
                            let indexInArray = Int(tris.p!.data[stride * vertexIndex + offsetAndSource.offset]) * Int(offsetAndSource.source.techniqueCommon!.accessor.stride!)
                            
                            var valuePtr : UnsafePointer<UInt8>!
                            
                            switch offsetAndSource.source.choice0! {
                            case let .boolArray(array):
                                array.data.withUnsafeBufferPointer { bufferPointer in
                                    valuePtr = UnsafePointer<UInt8>(bufferPointer.baseAddress?.advanced(by: indexInArray))
                                }
                            case let .floatArray(array):
                                array.data.withUnsafeBufferPointer { bufferPointer in
                                    valuePtr = UnsafePointer<UInt8>(bufferPointer.baseAddress?.advanced(by: indexInArray))
                                }
                            case let .intArray(array):
                                array.data.withUnsafeBufferPointer { bufferPointer in
                                    valuePtr = UnsafePointer<UInt8>(bufferPointer.baseAddress?.advanced(by: indexInArray))
                                }
                            default:
                                fatalError("Array type \(offsetAndSource.source.choice0!) not supported.")
                            }
                            
                            vertex.setAttribute(attribute: type, value: valuePtr)
                        }
                        
                    
                        if let existingIndex = vertices.index(of: vertex) {
                            indices.append(UInt16(existingIndex))
                            
                        } else {
                            indices.append(UInt16(vertices.count))
                            vertices.append(vertex)
                        }
                    }
                }
            
                let vertexBuffer = GPUBuffer<UInt8>(capacity: vertices.count * vertexLayout.alignedSize, data: nil, accessFrequency: .Static, accessType: .Draw)
                for (i, vertex) in vertices.enumerated() {
                    vertexBuffer.copyToIndex(i * vertexLayout.alignedSize, value: vertex.data, sizeInBytes: vertexLayout.size)
                }
                vertexBuffer.didModify()
                
                var attributeTypesToVertexAttributes = [AttributeType : VertexAttribute]()
                for (attribute, value) in vertexLayout.attributes {
                    let offset = value.offset
                    let source = attributesToSources[attribute]!.source
                    
                    attributeTypesToVertexAttributes[attribute] = VertexAttribute(data: vertexBuffer, glTypeName: value.glType, componentsPerAttribute: Int(source.techniqueCommon!.accessor.param.count), isNormalised: false, strideInBytes: vertexLayout.alignedSize, bufferOffsetInBytes: offset)
                }
                
                
                let indexBuffer = GPUBuffer<GLushort>(capacity: Int(tris.count * 3), data: indices, accessFrequency: .Static, accessType: .Draw)
                
                let drawCommand = DrawCommand(data: GPUBuffer<UInt8>(indexBuffer), glPrimitiveType: GL_TRIANGLES, elementCount: Int(tris.count * 3), glElementType: GL_UNSIGNED_SHORT, bufferOffsetInBytes: 0)
                meshes.append(GLMesh(drawCommand: drawCommand, attributes: attributeTypesToVertexAttributes))
            
            }
            
        }

        
        return meshes
    }
    
//    static func meshesFromCollada(_ colladaMesh: MeshType, root: Collada) -> [GLMesh] {
//        var sourcesToAttributes = [String : VertexAttribute]()
//
//        for source in colladaMesh.source {
//            let buffer : GPUBuffer<Void>
//            let glType : GLenum
//            let typeSizeInBytes : Int
//            if case let .floatArray(floatArray) = source.choice0! {
//                glType = GL_FLOAT
//                buffer = GPUBuffer<Void>(GPUBuffer<Float>(capacity: floatArray.data.count, data: floatArray.data, accessFrequency: .Static, accessType: .Draw))
//                typeSizeInBytes = sizeof(GLfloat)
//            } else  {
//                assertionFailure("No valid conversion for collada source data")
//                continue
//            }
//
//            sourcesToAttributes["#" + source.id] = VertexAttribute(data: buffer, glTypeName: glType, componentsPerAttribute: Int(source.techniqueCommon!.accessor.param.count), isNormalised: false, strideInBytes: Int(source.techniqueCommon!.accessor.stride!) * typeSizeInBytes, bufferOffsetInBytes: 0)
//        }
//        
//        var attributes = [AttributeType : VertexAttribute]()
//        
//        var meshes = [GLMesh]()
//        
//        for primitive in colladaMesh.choice0 {
//            if case let .triangles(tris) = primitive {
//                
//                for input in tris.input {
//                    let attributeType : AttributeType
//                    
//                    switch input.semantic {
//                    case "VERTEX":
//                        if let vertices = root[input.source] as? VerticesType {
//                            for input in vertices.input {
//                                
//                                let attributeType : AttributeType
//                                
//                                switch input.semantic {
//                                case "POSITION":
//                                    attributeType = .Position
//                                case "NORMAL":
//                                    attributeType = .Normal
//                                default:
//                                    continue
//                                }
//                                
//                                attributes[attributeType] = sourcesToAttributes[input.source]
//                            }
//                        }
//                        continue
//                        
//                    case "POSITION":
//                        attributeType = .Position
//                    case "NORMAL":
//                        attributeType = .Normal
//                    default:
//                        continue
//                    }
//                    
//                    attributes[attributeType] = sourcesToAttributes[input.source]
//                }
//                
//                let buffer = GPUBuffer<GLuint>(capacity: Int(tris.count * 3), data: tris.p!.data.enumerated().filter { $0.0 % 2 == 0 }.map { GLuint($1) }, accessFrequency: .Static, accessType: .Draw)
//                
//                
//                let drawCommand = DrawCommand(data: GPUBuffer<Void>(buffer), glPrimitiveType: GL_TRIANGLES, elementCount: Int(tris.count * 3), glElementType: GL_UNSIGNED_INT, bufferOffsetInBytes: 0)
//                meshes.append(GLMesh(drawCommand: drawCommand, attributes: attributes))
//            }
//        }
//        
//        
//        return meshes
//    }
}