//
//  GPUBuffer.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 28/04/16.
//
//

import Foundation
import SGLOpenGL

public enum GPUBufferAccessFrequency {
    /// The data store contents will be modified once and used at most a few times.
    case Stream
    /// The data store contents will be modified once and used many times.
    case Static
    /// The data store contents will be modified repeatedly and used many times.
    case Dynamic
}

public enum GPUBufferAccessType {
    /// The data store contents are modified by the application, and used as the source for GL drawing and image specification commands.
    case Draw
    /// The data store contents are modified by reading data from the GL, and used to return that data when queried by the application.
    case Read
    /// The data store contents are modified by reading data from the GL, and used as the source for GL drawing and image specification commands.
    case Copy
}

private let glOffsetAlignment : GLint = {
    var offsetAlignment = GLint(0)
    glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, &offsetAlignment)
    return offsetAlignment
}()

private func typeSize<U>(_ type: U.Type, bufferType: GLenum) -> Int {
    var typeSize = sizeof(U)
    if bufferType == GL_UNIFORM_BUFFER {
        typeSize = roundUpToNearestMultiple(numToRound: typeSize, of: Int(glOffsetAlignment))
    } else {
        if typeSize == 0 { typeSize = 1 }
    }
    return typeSize
}

private final class GPUBufferImpl {
    let bufferBinding : GLenum
    
    let capacityInBytes : Int
    
    private var _contents : UnsafeMutablePointer<UInt8>
    private let _glBuffer : GLuint
    
    init<T>(capacityInBytes: Int, data: [T]? = nil, bufferBinding : GLenum, accessFrequency: GPUBufferAccessFrequency, accessType: GPUBufferAccessType) {
        self.capacityInBytes = capacityInBytes
        self.bufferBinding = bufferBinding
        
        let contents = UnsafeMutablePointer<UInt8>(calloc(1, self.capacityInBytes))!
        _contents = contents
        
        let elementSize = typeSize(T.self, bufferType: bufferBinding)
        
        if let data = data {
            if bufferBinding == GL_UNIFORM_BUFFER {
                
                for (i, value) in data.enumerated() {
                    UnsafeMutablePointer<T>(_contents.advanced(by: i * elementSize)).pointee = value
                }
            } else {
                data.withUnsafeBufferPointer({ (buffer) -> Void in
                    memcpy(contents, buffer.baseAddress!, capacityInBytes)
                })
            }
        }
        
        var uniformBlockRef = GLuint(0)
        glGenBuffers(1, &uniformBlockRef);
        glBindBuffer(bufferBinding, uniformBlockRef);
        _glBuffer = uniformBlockRef
        
        let usage : GLint
        
        switch (accessFrequency, accessType) {
        case (.Stream, .Draw):
            usage = GL_STREAM_DRAW
        case (.Static, .Draw):
            usage = GL_STATIC_DRAW
        case (.Dynamic, .Draw):
            usage = GL_DYNAMIC_DRAW
        case (.Stream, .Read):
            usage = GL_STREAM_READ
        case (.Static, .Read):
            usage = GL_STATIC_READ
        case (.Dynamic, .Read):
            usage = GL_DYNAMIC_READ
        case (.Stream, .Copy):
            usage = GL_STREAM_COPY
        case (.Static, .Copy):
            usage = GL_STATIC_COPY
        case (.Dynamic, .Copy):
            usage = GL_DYNAMIC_COPY
        }
        
        glBufferData(bufferBinding, self.capacityInBytes, data, usage);
        
        glBindBuffer(bufferBinding, 0)
    }
    
    deinit {
        free(_contents)
            
        var glBuffer = _glBuffer
        glDeleteBuffers(1, &glBuffer)
    }
    
    func didModifyRange(_ range: Range<Int>) {
        glBindBuffer(bufferBinding, _glBuffer)
        glBufferSubData(target: bufferBinding, offset: range.lowerBound, size: range.count, data: _contents.advanced(by: range.lowerBound))
        glBindBuffer(bufferBinding, 0)
    }
    
    func updateFromGPU(range: Range<Int>) {
        glBindBuffer(bufferBinding, _glBuffer)
        glGetBufferSubData(bufferBinding, range.lowerBound, range.count, _contents.advanced(by: range.lowerBound))
        glBindBuffer(bufferBinding, 0)
    }
    
    func bindToGL(buffer: GLenum) {
        glBindBuffer(buffer, _glBuffer)
    }
    
    func bindToUniformBlockIndex(_ index: Int, byteOffset: Int = 0) {
        glBindBufferRange(GL_UNIFORM_BUFFER, GLuint(index), _glBuffer, byteOffset, self.capacityInBytes - byteOffset)
    }

}

public class GPUBufferElement<T> {
    public let buffer : GPUBuffer<T>
    private let _bufferIndex : Int
    
    private init(viewOfIndex index: Int, onBuffer buffer: GPUBuffer<T>) {
        _bufferIndex = index
        self.buffer = buffer
    }
    
    public func withElement<U>(_ function: @noescape (inout T) throws -> U) rethrows -> U {
        var element = self.buffer[_bufferIndex]
        
        let result = try function(&element)
        
        self.buffer[_bufferIndex] = element
        self.buffer.didModifyRange(_bufferIndex..<_bufferIndex + 1)
        
        return result
    }
    
    var readOnlyElement : T {
        return self.buffer[_bufferIndex]
    }
    
    func bindToUniformBlockIndex(_ index: Int) {
        self.buffer.bindToUniformBlockIndex(index, elementOffset: _bufferIndex)
    }
}

public final class GPUBuffer<T> {
    
    public let capacity : Int
    
    private let _internalBuffer : GPUBufferImpl
    
    init<U>(_ buffer: GPUBuffer<U>) {
        self.capacity = buffer._internalBuffer.capacityInBytes / typeSize(T.self, bufferType: buffer._internalBuffer.bufferBinding)
        self._internalBuffer = buffer._internalBuffer
    }
    
    init(capacity: Int, data: [T]? = nil, bufferBinding : GLenum, accessFrequency: GPUBufferAccessFrequency, accessType: GPUBufferAccessType) {
        self.capacity = capacity
        
        _internalBuffer = GPUBufferImpl(capacityInBytes: typeSize(T.self, bufferType: bufferBinding) * capacity, data: data, bufferBinding: bufferBinding, accessFrequency: accessFrequency, accessType: accessType)
    }
    
    subscript(_ idx: Int) -> T {
        get {
            let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
            return UnsafePointer<T>(_internalBuffer._contents.advanced(by: idx * elementSize)).pointee
        }
        set(newValue) {
            let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
            UnsafeMutablePointer<T>(_internalBuffer._contents.advanced(by: idx * elementSize)).pointee = newValue
        }
    }
    
    subscript(viewForIndex index: Int) -> GPUBufferElement<T> {
        get {
            return GPUBufferElement(viewOfIndex: index, onBuffer: self)
        }
    }
    
    func copyToIndex(_ index: Int, value: UnsafePointer<T>, sizeInBytes: Int) {
        let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
        let destinationPtr = UnsafeMutablePointer<T>(_internalBuffer._contents.advanced(by: index * elementSize))
        memcpy(destinationPtr, value, sizeInBytes)
    }
    
    subscript(_ range: Range<Int>) -> [T] {
        get {
            if _internalBuffer.bufferBinding == GL_UNIFORM_BUFFER {
                let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
                var data = [T]()
                
                for index in range.lowerBound..<range.upperBound {
                    data.append(UnsafeMutablePointer<T>(_internalBuffer._contents.advanced(by: index * elementSize)).pointee)
                }
                
                return data
                
            } else {
                return [T](UnsafeMutableBufferPointer(start: UnsafeMutablePointer<T>(_internalBuffer._contents).advanced(by: range.lowerBound), count: range.count))
            }
        }
        set(newValue) {
            assert(range.count == newValue.count)
            
            if _internalBuffer.bufferBinding == GL_UNIFORM_BUFFER {
                let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
               
                let base = _internalBuffer._contents.advanced(by: elementSize * range.lowerBound)
                
                for (i, value) in newValue.enumerated() {
                    UnsafeMutablePointer<T>(base.advanced(by: i * elementSize)).pointee = value
                }
                
            } else {
            
                newValue.withUnsafeBufferPointer { (toCopy) -> Void in
                    let destination = UnsafeMutablePointer<T>(_internalBuffer._contents).advanced(by: range.lowerBound)
                    memcpy(destination, toCopy.baseAddress!, range.count * sizeof(T))
                }
            }
        }
    }
    
    public func didModify() {
        self.didModifyRange(0..<self.capacity)
    }
    
    public func didModifyRange(_ range: Range<Int>) {
        let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
        _internalBuffer.didModifyRange(Range(uncheckedBounds: (range.lowerBound * elementSize, range.upperBound * elementSize)))
    }
    
    public func updateFromGPU() {
        self.updateFromGPU(range: 0..<self.capacity)
    }
    
    public func updateFromGPU(range: Range<Int>) {
        _internalBuffer.updateFromGPU(range: Range(uncheckedBounds: (range.lowerBound * sizeof(T), range.upperBound * sizeof(T))))
    }
    
    func bindToTexture(internalFormat: GLint) {
        glTexBuffer(GL_TEXTURE_BUFFER, internalFormat, _internalBuffer._glBuffer)
    }
    
    func bindToGL(buffer: GLenum) {
        _internalBuffer.bindToGL(buffer: buffer)
    }
    
    public func bindToUniformBlockIndex(_ index: Int, elementOffset: Int = 0) {
        let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
        _internalBuffer.bindToUniformBlockIndex(index, byteOffset: elementSize * elementOffset)
    }
}