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
    case stream
    /// The data store contents will be modified once and used many times.
    case `static`
    /// The data store contents will be modified repeatedly and used many times.
    case dynamic
}

public enum GPUBufferAccessType {
    /// The data store contents are modified by the application, and used as the source for GL drawing and image specification commands.
    case draw
    /// The data store contents are modified by reading data from the GL, and used to return that data when queried by the application.
    case read
    /// The data store contents are modified by reading data from the GL, and used as the source for GL drawing and image specification commands.
    case copy
}

private let glOffsetAlignment : GLint = {
    var offsetAlignment = GLint(0)
    glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, &offsetAlignment)
    return offsetAlignment
}()

private func typeSize<U>(type: U.Type, bufferType: SGLOpenGL.GLenum) -> Int {
    var typeSize = MemoryLayout<U>.size

    if typeSize == 0 { typeSize = 1 }

    return typeSize
}

private final class GPUBufferImpl {
    let bufferBinding : SGLOpenGL.GLenum
    
    fileprivate(set) var capacityInBytes : Int
    
    fileprivate var _contents : UnsafeMutableRawPointer
    fileprivate let _glBuffer : GLuint
    fileprivate let usage : SGLOpenGL.GLenum
    
    init<T>(capacityInBytes: Int, data: [T]? = nil, bufferBinding : SGLOpenGL.GLenum, accessFrequency: GPUBufferAccessFrequency, accessType: GPUBufferAccessType) {
        self.capacityInBytes = capacityInBytes
        self.bufferBinding = bufferBinding
        
        let contents = calloc(1, self.capacityInBytes)
        _contents = contents!
        
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
        case (.stream, .draw):
            usage = GL_STREAM_DRAW
        case (.static, .draw):
            usage = GL_STATIC_DRAW
        case (.dynamic, .draw):
            usage = GL_DYNAMIC_DRAW
        case (.stream, .read):
            usage = GL_STREAM_READ
        case (.static, .read):
            usage = GL_STATIC_READ
        case (.dynamic, .read):
            usage = GL_DYNAMIC_READ
        case (.stream, .copy):
            usage = GL_STREAM_COPY
        case (.static, .copy):
            usage = GL_STATIC_COPY
        case (.dynamic, .copy):
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
    
    func asMappedBuffer<U>(_ function: (UnsafeMutableRawPointer?) throws -> U, range: Range<Int>, usage: GLbitfield) rethrows -> U {
        glBindBuffer(bufferBinding, _glBuffer)
        let pointer = glMapBufferRange(bufferBinding, GLintptr(range.lowerBound), GLsizeiptr(range.count), usage)
        
        let result = try function(pointer)
        
        _ = glUnmapBuffer(bufferBinding)
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
    
    func reserveCapacity(capacityInBytes: Int) {
        if capacityInBytes <= self.capacityInBytes {
            return
        }
        
        let tempBuffer = calloc(1, capacityInBytes)
        
        memcpy(tempBuffer, self._contents, self.capacityInBytes)
        free(self._contents)
        self._contents = tempBuffer!
        
        glBindBuffer(bufferBinding, _glBuffer);
        glBufferData(bufferBinding, capacityInBytes, self._contents, usage);
        glBindBuffer(bufferBinding, 0)
        
        self.capacityInBytes = capacityInBytes
    }
    
    func bindToUniformBlockIndex(_ index: Int, byteOffset: Int = 0) {

        assert(self.bufferBinding != GL_UNIFORM_BUFFER || byteOffset % Int(glOffsetAlignment) == 0, "For uniform blocks, the byte offset must be a multiple of GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT")
        glBindBufferRange(GL_UNIFORM_BUFFER, GLuint(index), _glBuffer, byteOffset, roundUpToNearestMultiple(numToRound: self.capacityInBytes - byteOffset, of: Int(glOffsetAlignment)))
    }

}

open class GPUBufferElement<T> {
    open let buffer : GPUBuffer<T>
    open let bufferIndex : Int
    
    fileprivate init(viewOfIndex index: Int, onBuffer buffer: GPUBuffer<T>) {
        bufferIndex = index
        self.buffer = buffer
    }
    
    open func withElement<U>(_ function: (inout T) throws -> U) rethrows -> U {
        var element = self.buffer[bufferIndex]
        
        let result = try function(&element)
        
        self.buffer[bufferIndex] = element
        self.buffer.didModifyRange(bufferIndex..<bufferIndex + 1)
        
        return result
    }
    
    open func withElementNoUpdate<U>(_ function: (inout T) throws -> U) rethrows -> U {
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
    
    fileprivate(set) public var capacity : Int
    
    fileprivate let _internalBuffer : GPUBufferImpl
    
    init<U>(_ buffer: GPUBuffer<U>) {
        self.capacity = buffer._internalBuffer.capacityInBytes / typeSize(type: T.self, bufferType: buffer._internalBuffer.bufferBinding)
        self._internalBuffer = buffer._internalBuffer
    }
    
    init(capacity: Int, data: [T]? = nil, bufferBinding : SGLOpenGL.GLenum, accessFrequency: GPUBufferAccessFrequency, accessType: GPUBufferAccessType) {
        self.capacity = capacity
        
        _internalBuffer = GPUBufferImpl(capacityInBytes: typeSize(type: T.self, bufferType: bufferBinding) * capacity, data: data, bufferBinding: bufferBinding, accessFrequency: accessFrequency, accessType: accessType)
    }
    
    subscript(_ idx: Int) -> T {
        get {
            let elementSize = typeSize(type: T.self, bufferType: _internalBuffer.bufferBinding)
            return _internalBuffer._contents.advanced(by: idx * elementSize).assumingMemoryBound(to: T.self).pointee
//            return UnsafePointer<T>(_internalBuffer._contents.advanced(by: idx * elementSize)).pointee
        }
        set(newValue) {
            let elementSize = typeSize(type: T.self, bufferType: _internalBuffer.bufferBinding)
            _internalBuffer._contents.advanced(by: idx * elementSize).assumingMemoryBound(to: T.self).pointee = newValue
        }
    }
    
    subscript(viewForIndex index: Int) -> GPUBufferElement<T> {
        get {
            return GPUBufferElement(viewOfIndex: index, onBuffer: self)
        }
    }
    
    var contents : UnsafeMutablePointer<T> {
        return self._internalBuffer._contents.assumingMemoryBound(to: T.self)
    }
    
    func copyToIndex(_ index: Int, value: UnsafePointer<T>, sizeInBytes: Int) {
        let elementSize = typeSize(type: T.self, bufferType: _internalBuffer.bufferBinding)
        let destinationPtr = _internalBuffer._contents.advanced(by: index * elementSize)
        memcpy(destinationPtr, value, sizeInBytes)
    }
    
    func asMappedBuffer<U>(_ function: (UnsafeMutableRawPointer?) throws -> U, range: CountableRange<Int>? = nil, usage: GLbitfield) rethrows -> U {
        let range = range ?? 0..<self.capacity
        let elementSize = typeSize(type: T.self, bufferType: _internalBuffer.bufferBinding)
        return try self._internalBuffer.asMappedBuffer(function, range: (range.lowerBound * elementSize)..<(range.upperBound * elementSize), usage: usage)
    }
    
    subscript(_ range: Range<Int>) -> [T] {
        get {
            return [T](UnsafeMutableBufferPointer(start: (_internalBuffer._contents.assumingMemoryBound(to: T.self)).advanced(by: range.lowerBound), count: range.count))
        }
        set(newValue) {
            assert(range.count == newValue.count)
                newValue.withUnsafeBufferPointer { (toCopy) -> Void in
                    let destination = _internalBuffer._contents.advanced(by: range.lowerBound * MemoryLayout<T>.size)
                    memcpy(destination, toCopy.baseAddress!, range.count * MemoryLayout<T>.size)
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
        let elementSize = typeSize(type: T.self, bufferType: _internalBuffer.bufferBinding)
        _internalBuffer.didModifyRange(Range(uncheckedBounds: (range.lowerBound * elementSize, range.upperBound * elementSize)))
    }
    
    public func updateFromGPU() {
        self.updateFromGPU(0..<self.capacity)
    }
    
    public func updateFromGPU(_ range: Range<Int>) {
        _internalBuffer.updateFromGPU(range: Range(uncheckedBounds: (range.lowerBound * MemoryLayout<T>.size, range.upperBound * MemoryLayout<T>.size)))
    }
    
    func bindToTexture(internalFormat: GLint) {
        glTexBuffer(GL_TEXTURE_BUFFER, internalFormat, _internalBuffer._glBuffer)
    }
    
    func bindToGL(buffer: SGLOpenGL.GLenum) {
        _internalBuffer.bindToGL(buffer: buffer)
    }
    
    func reserveCapacity(_ capacity: Int) {
        _internalBuffer.reserveCapacity(capacityInBytes: capacity * typeSize(type: T.self, bufferType: _internalBuffer.bufferBinding))
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
        let elementSize = typeSize(type: T.self, bufferType: _internalBuffer.bufferBinding)
        _internalBuffer.bindToUniformBlockIndex(index, byteOffset: elementSize * elementOffset)
    }
    
    var offsetAlignment : Int {
        return roundUpToNearestMultiple(numToRound: typeSize(type: T.self, bufferType: _internalBuffer.bufferBinding), of: Int(glOffsetAlignment))
    }
}
