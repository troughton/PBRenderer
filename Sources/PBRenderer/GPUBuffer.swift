//
//  GPUBuffer.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 28/04/16.
//
//

import Foundation
import SGLOpenGL
import OpenCL

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

private func typeSize<U>(_ type: U.Type, bufferType: SGLOpenGL.GLenum) -> Int {
    var typeSize = sizeof(U)

    if typeSize == 0 { typeSize = 1 }

    return typeSize
}

private final class GPUBufferImpl {
    let bufferBinding : SGLOpenGL.GLenum
    
    let capacityInBytes : Int
    
    private var _contents : UnsafeMutablePointer<UInt8>
    private let _glBuffer : GLuint
    private let usage : SGLOpenGL.GLenum
    
    init<T>(capacityInBytes: Int, data: [T]? = nil, bufferBinding : SGLOpenGL.GLenum, accessFrequency: GPUBufferAccessFrequency, accessType: GPUBufferAccessType) {
        self.capacityInBytes = capacityInBytes
        self.bufferBinding = bufferBinding
        
        let contents = UnsafeMutablePointer<UInt8>(calloc(1, self.capacityInBytes))!
        _contents = contents
        
        if let data = data {
                data.withUnsafeBufferPointer({ (buffer) -> Void in
                    memcpy(contents, buffer.baseAddress!, capacityInBytes)
                })
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
        
        self.usage = usage
        
        glBufferData(bufferBinding, self.capacityInBytes, data, usage);
        
        glBindBuffer(bufferBinding, 0)
    }
    
    func orphanBuffer() {
        glBindBuffer(bufferBinding, _glBuffer);
        glBufferData(bufferBinding, self.capacityInBytes, nil, usage);
        glBindBuffer(bufferBinding, 0)
    }
    
    deinit {
        free(_contents)
            
        var glBuffer = _glBuffer
        glDeleteBuffers(1, &glBuffer)
    }
    
    func asMappedBuffer<U>(_ function: @noescape (UnsafeMutablePointer<Void>?) throws -> U, range: Range<Int>, usage: GLbitfield) rethrows -> U {
        glBindBuffer(bufferBinding, _glBuffer)
        let pointer = glMapBufferRange(bufferBinding, GLintptr(range.lowerBound), GLsizeiptr(range.count), usage)
        
        let result = try function(pointer)
        
        glUnmapBuffer(bufferBinding)
        glBindBuffer(bufferBinding, 0)
        
        return result
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
    
    func bindToGL(buffer: SGLOpenGL.GLenum) {
        glBindBuffer(buffer, _glBuffer)
    }
    
    func bindToUniformBlockIndex(_ index: Int, byteOffset: Int = 0) {

        assert(self.bufferBinding != GL_UNIFORM_BUFFER || byteOffset % Int(glOffsetAlignment) == 0, "For uniform blocks, the byte offset must be a multiple of GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT")
        glBindBufferRange(GL_UNIFORM_BUFFER, GLuint(index), _glBuffer, byteOffset, roundUpToNearestMultiple(numToRound: self.capacityInBytes - byteOffset, of: Int(glOffsetAlignment)))
    }

}

public class GPUBufferElement<T> {
    public let buffer : GPUBuffer<T>
    public let bufferIndex : Int
    
    private init(viewOfIndex index: Int, onBuffer buffer: GPUBuffer<T>) {
        bufferIndex = index
        self.buffer = buffer
    }
    
    public func withElement<U>(_ function: @noescape (inout T) throws -> U) rethrows -> U {
        var element = self.buffer[bufferIndex]
        
        let result = try function(&element)
        
        self.buffer[bufferIndex] = element
        self.buffer.didModifyRange(bufferIndex..<bufferIndex + 1)
        
        return result
    }
    
    public func withElementNoUpdate<U>(_ function: @noescape (inout T) throws -> U) rethrows -> U {
        var element = self.buffer[bufferIndex]
        
        let result = try function(&element)
        
        self.buffer[bufferIndex] = element
        
        return result
    }
    
    var readOnlyElement : T {
        return self.buffer[bufferIndex]
    }
    
    func bindToUniformBlockIndex(_ index: Int) {
        self.buffer.bindToUniformBlockIndex(index, elementOffset: bufferIndex)
    }
}

public final class GPUBuffer<T> {
    
    public let capacity : Int
    
    private let _internalBuffer : GPUBufferImpl
    
    init<U>(_ buffer: GPUBuffer<U>) {
        self.capacity = buffer._internalBuffer.capacityInBytes / typeSize(T.self, bufferType: buffer._internalBuffer.bufferBinding)
        self._internalBuffer = buffer._internalBuffer
    }
    
    init(capacity: Int, data: [T]? = nil, bufferBinding : SGLOpenGL.GLenum, accessFrequency: GPUBufferAccessFrequency, accessType: GPUBufferAccessType) {
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
    
    var contents : UnsafeMutablePointer<T> {
        return UnsafeMutablePointer<T>(self._internalBuffer._contents)
    }
    
    func copyToIndex(_ index: Int, value: UnsafePointer<T>, sizeInBytes: Int) {
        let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
        let destinationPtr = UnsafeMutablePointer<T>(_internalBuffer._contents.advanced(by: index * elementSize))
        memcpy(destinationPtr, value, sizeInBytes)
    }
    
    func asMappedBuffer<U>(_ function: @noescape (UnsafeMutablePointer<Void>?) throws -> U, range: Range<Int>? = nil, usage: GLbitfield) rethrows -> U {
        let range = range ?? 0..<self.capacity
        let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
        return try self._internalBuffer.asMappedBuffer(function, range: (range.lowerBound * elementSize)..<(range.upperBound * elementSize), usage: usage)
    }
    
    subscript(_ range: Range<Int>) -> [T] {
        get {
            return [T](UnsafeMutableBufferPointer(start: UnsafeMutablePointer<T>(_internalBuffer._contents).advanced(by: range.lowerBound), count: range.count))
        }
        set(newValue) {
            assert(range.count == newValue.count)
                newValue.withUnsafeBufferPointer { (toCopy) -> Void in
                    let destination = UnsafeMutablePointer<T>(_internalBuffer._contents).advanced(by: range.lowerBound)
                    memcpy(destination, toCopy.baseAddress!, range.count * sizeof(T))
                }
        }
    }
    
    public func orphanBuffer() {
        self._internalBuffer.orphanBuffer()
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
    
    func bindToGL(buffer: SGLOpenGL.GLenum) {
        _internalBuffer.bindToGL(buffer: buffer)
    }
    
    func openCLMemory(clContext: cl_context, flags: cl_mem_flags) -> OpenCLMemory {
        var error = cl_int(0)
        let mem = clCreateFromGLBuffer(clContext, flags, self._internalBuffer._glBuffer, &error)
        if error != CL_SUCCESS {
            assertionFailure("Error creating OpenCL buffer: \(OpenCLError(rawValue: error)!).")
        }
        return OpenCLMemory(memory: mem!)
    }
    
    public func bindToUniformBlockIndex(_ index: Int, elementOffset: Int = 0) {
        let elementSize = typeSize(T.self, bufferType: _internalBuffer.bufferBinding)
        _internalBuffer.bindToUniformBlockIndex(index, byteOffset: elementSize * elementOffset)
    }
    
    var offsetAlignment : Int {
        return roundUpToNearestMultiple(numToRound: typeSize(T.self, bufferType: _internalBuffer.bufferBinding), of: Int(glOffsetAlignment))
    }
}