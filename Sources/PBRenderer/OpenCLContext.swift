//
//  OpenCLContext.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 20/05/16.
//
//

import Foundation
import OpenCL
import SGLOpenGL
import CGLFW3

private var _implicitCLSyncSupported = false

func OpenCLSyncContexts(commandQueue: cl_command_queue) {
    if !_implicitCLSyncSupported {
        glFinish()
        clFinish(commandQueue)
    }
}

extension cl_mem {
    var managed : OpenCLMemory {
        return OpenCLMemory(memory: self)
    }
}

final class OpenCLMemory {
    var memory : cl_mem
    
    init(memory: cl_mem) {
        self.memory = memory
    }
    
    deinit {
        clReleaseMemObject(self.memory)
    }
}

#if os(OSX)
    func OpenCLGetContext(glfwWindow: OpaquePointer) -> (cl_context, cl_device_id) {
        
        
        // Get current CGL Context and CGL Share group
        let kCGLContext = CGLGetCurrentContext();
        let kCGLShareGroup = CGLGetShareGroup(kCGLContext!);
        // Create CL context properties, add handle & share-group enum
        let properties : [cl_context_properties] =  [
                                                        cl_context_properties(CL_CONTEXT_PROPERTY_USE_CGL_SHAREGROUP_APPLE),
                                                        unsafeBitCast(kCGLShareGroup, to: cl_context_properties.self), 0
        ];
        // Create a context with device in the CGL share group
        var error = cl_int(0)
        let context = clCreateContext(properties, 0, nil, nil, nil, &error);
        if error != 0 {
            assertionFailure("Error creating context: \(error)")
        }
        
        
        var devices = [cl_device_id?](repeating: nil, count: 32)
        var size = size_t(0);
        clGetContextInfo(context, cl_context_info(CL_CONTEXT_DEVICES), 32 * sizeof(cl_device_id), &devices, &size);
        
        let extensionsString = UnsafeMutablePointer<CChar>(malloc(1024))
        var extensionsSize = 0
        clGetDeviceInfo(devices[0]!, cl_device_info(CL_DEVICE_EXTENSIONS), 1024, extensionsString, &extensionsSize)
        let supportedExtensions = String(cString: UnsafePointer<CChar>(extensionsString!))
        
        if !supportedExtensions.localizedCaseInsensitiveContains("cl_APPLE_gl_sharing") {
            fatalError("OpenGL-OpenCL sharing is unsupported on this hardware")
        }
        
        _implicitCLSyncSupported = supportedExtensions.contains("cl_khr_gl_event")
        
        return (context!, devices[0]!)
    }
    
#else
    
var devices = [cl_device_id?](repeating: nil, count: 32) //Here be dragons if you put these lines inside the context retrieval method.
    
var platforms = [cl_platform_id?](repeating: nil, count: 32)
    func OpenCLGetContext(glfwWindow: OpaquePointer) -> (cl_context, cl_device_id) {
        
        var platformsSize = cl_uint(0);
        clGetPlatformIDs(UInt32(32 * sizeof(cl_platform_id)), &platforms, &platformsSize);
        
        
        typealias GLContextInfoFunc = @convention(c) (UnsafePointer<cl_context_properties>!, cl_gl_context_info, size_t, UnsafeMutablePointer<Void>!, UnsafeMutablePointer<size_t>!) -> cl_int
        
        let clGetGLContextInfo = unsafeBitCast(clGetExtensionFunctionAddressForPlatform(platforms[0], "clGetGLContextInfoKHR"), to: GLContextInfoFunc.self)
        
        let properties : [cl_context_properties] = [
                                                       cl_context_properties(CL_GL_CONTEXT_KHR), unsafeBitCast(glfwGetGLXContext(glfwWindow), to: cl_context_properties.self), // GLX Context
            cl_context_properties(CL_GLX_DISPLAY_KHR), unsafeBitCast(glfwGetX11Display(), to: cl_context_properties.self), // GLX Display
            cl_context_properties(CL_CONTEXT_PLATFORM), unsafeBitCast(platforms[0]!, to: cl_context_properties.self),
            0
        ];
        
        // Find CL capable devices in the current GL context
        
        var size = size_t(0);
        
        var error = clGetGLContextInfo(properties, cl_gl_context_info(CL_DEVICES_FOR_GL_CONTEXT_KHR), 32 * sizeof(cl_device_id), &devices, &size);
        
        
        // OpenCL platform
        // Create a context using the supported devices
        let deviceCount = size / sizeof(cl_device_id);
        
        let context = clCreateContext(properties, cl_uint(deviceCount), devices, nil, nil, &error);
        
        if error != 0 {
            assertionFailure("Error creating context: \(error)")
        }
        
        let extensionsString = UnsafeMutablePointer<CChar>(malloc(1024))
        var extensionsSize = 0
        clGetDeviceInfo(devices[0]!, cl_device_info(CL_DEVICE_EXTENSIONS), 1024, extensionsString, &extensionsSize)
        let supportedExtensions = String(cString: UnsafePointer<CChar>(extensionsString!))
        
        if !supportedExtensions.contains("cl_KHR_gl_sharing") {
            fatalError("OpenGL-OpenCL sharing is unsupported on this hardware")
        }
        
        _implicitCLSyncSupported = supportedExtensions.contains("cl_khr_gl_event")
        
        return (context!, devices[0]!)
    }
#endif