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

private func typeSize<U>(_ type: U.Type) -> Int {
    var typeSize = sizeof(U)
    if typeSize == 0 { typeSize = 1 }
    return typeSize
}

private final class GPUBufferImpl {
    var bufferBinding : GLenum
    
    let capacityInBytes : Int
    
    private var _contents : UnsafeMutablePointer<UInt8>
    private let _glBuffer : GLuint
    
    init<T>(capacityInBytes: Int, data: [T]? = nil, bufferBinding : GLenum = GL_UNIFORM_BUFFER, accessFrequency: GPUBufferAccessFrequency, accessType: GPUBufferAccessType) {
        self.capacityInBytes = capacityInBytes
        self.bufferBinding = bufferBinding
        
        let contents = UnsafeMutablePointer<UInt8>(calloc(1, self.capacityInBytes))!
        _contents = contents
        
        data?.withUnsafeBufferPointer({ (buffer) -> Void in
            memcpy(contents, buffer.baseAddress, capacityInBytes)
        })
        
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

public final class GPUBuffer<T> {
    
    public let capacity : Int
    
    private let _internalBuffer : GPUBufferImpl
    
    init<U>(_ buffer: GPUBuffer<U>) {
        self.capacity = buffer._internalBuffer.capacityInBytes / typeSize(T)
        self._internalBuffer = buffer._internalBuffer
    }
    
    init(capacity: Int, data: [T]? = nil, bufferBinding : GLenum = GL_UNIFORM_BUFFER, accessFrequency: GPUBufferAccessFrequency, accessType: GPUBufferAccessType) {
        self.capacity = capacity
        
        _internalBuffer = GPUBufferImpl(capacityInBytes: sizeof(T) * capacity, data: data, bufferBinding: bufferBinding, accessFrequency: accessFrequency, accessType: accessType)
    }
    
    subscript(_ idx: Int) -> T {
        get {
            return UnsafePointer<T>(_internalBuffer._contents).advanced(by: idx).pointee
        }
        set(newValue) {
            UnsafeMutablePointer<T>(_internalBuffer._contents).advanced(by: idx).pointee = newValue
        }
    }
    
    func copyToIndex(_ index: Int, value: UnsafePointer<T>, sizeInBytes: Int) {
        let destinationPtr = UnsafeMutablePointer<T>(_internalBuffer._contents).advanced(by: index)
        memcpy(destinationPtr, value, sizeInBytes)
    }
    
    subscript(_ range: Range<Int>) -> [T] {
        get {
            return [T](UnsafeMutableBufferPointer(start: UnsafeMutablePointer<T>(_internalBuffer._contents).advanced(by: range.lowerBound), count: range.count))
        }
        set(newValue) {
            assert(range.count == newValue.count)
            
            newValue.withUnsafeBufferPointer { (toCopy) -> Void in
                let destination = UnsafeMutablePointer<T>(_internalBuffer._contents).advanced(by: range.lowerBound)
                memcpy(destination, toCopy.baseAddress, range.count * sizeof(T))
            }
        }
    }
    
    public func didModify() {
        self.didModifyRange(0..<self.capacity)
    }
    
    public func didModifyRange(_ range: Range<Int>) {
        _internalBuffer.didModifyRange(Range(uncheckedBounds: (range.lowerBound * sizeof(T), range.upperBound * sizeof(T))))
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
        _internalBuffer.bindToUniformBlockIndex(index, byteOffset: sizeof(T) * elementOffset)
    }
}