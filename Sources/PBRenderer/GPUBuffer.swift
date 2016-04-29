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

public final class GPUBuffer<T> {
    
    private let _bufferToBindTo : GLenum
    
    public let capacity : Int
    
    private let _contents : UnsafeMutableBufferPointer<T>
    private let _glBuffer : GLuint
    
    public var capacityInBytes : Int {
        return self.capacity * sizeof(T)
    }
    
    init(capacity: Int, data: [T]? = nil, bufferBinding : GLenum = GL_UNIFORM_BUFFER, accessFrequency: GPUBufferAccessFrequency, accessType: GPUBufferAccessType) {
        self.capacity = capacity
        _bufferToBindTo = bufferBinding
        
        let baseAddress = UnsafeMutablePointer<T>(calloc(sizeof(T), capacity))
        _contents = UnsafeMutableBufferPointer(start: baseAddress, count: capacity)
        
        
        var uniformBlockRef = GLuint(0)
        glGenBuffers(1, &uniformBlockRef);
        glBindBuffer(_bufferToBindTo, uniformBlockRef);
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
        
        glBufferData(_bufferToBindTo, self.capacityInBytes, data, usage);
        
        glBindBuffer(_bufferToBindTo, 0)
    }
    
    subscript(_ idx: Int) -> T {
        get {
            return _contents[idx]
        }
        set(newValue) {
            _contents[idx] = newValue
        }
    }
    
    subscript(_ range: Range<Int>) -> [T] {
        get {
            return [T](UnsafeMutableBufferPointer(start: _contents.baseAddress?.advanced(by: range.startIndex), count: range.count))
        }
        set(newValue) {
            assert(range.count == newValue.count)
            
            newValue.withUnsafeBufferPointer { (toCopy) -> Void in
                let destination = _contents.baseAddress?.advanced(by: range.startIndex)
                memcpy(destination, toCopy.baseAddress, range.count * sizeof(T))
            }
        }
    }
    
    deinit {
        free(_contents.baseAddress)
        
        var glBuffer = _glBuffer
        glDeleteBuffers(1, &glBuffer)
    }
    
    public func didModify() {
        self.didModifyRange(0..<self.capacity)
    }
    
    public func didModifyRange(_ range: Range<Int>) {
        glBindBuffer(_bufferToBindTo, _glBuffer)
        glBufferSubData(target: _bufferToBindTo, offset: range.startIndex, size: range.count, data: _contents.baseAddress?.advanced(by: range.startIndex))
        glBindBuffer(_bufferToBindTo, 0)
    }
    
    public func updateFromGPU() {
        self.updateFromGPU(range: 0..<self.capacity)
    }
    
    public func updateFromGPU(range: Range<Int>) {
        glBindBuffer(_bufferToBindTo, _glBuffer)
        glGetBufferSubData(_bufferToBindTo, range.startIndex, range.count, _contents.baseAddress?.advanced(by: range.startIndex))
        glBindBuffer(_bufferToBindTo, 0)
    }
    
    func bindToGL() {
        glBindBuffer(_bufferToBindTo, _glBuffer)
    }
    
    public func bindToUniformBlockIndex(_ index: Int, elementOffset: Int = 0) {
        let offset = elementOffset * sizeof(T)
        glBindBufferRange(GL_UNIFORM_BUFFER, GLuint(index), _glBuffer, offset, self.capacityInBytes - offset)
    }
}