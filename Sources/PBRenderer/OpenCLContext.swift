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
private (set) var OpenCLDepthTextureSupported = false

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
            assertionFailure("Error creating context: \(OpenCLError(rawValue: error)!)")
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
        
        checkForSupportedExtensions(supportedExtensions: supportedExtensions)

        return (context!, devices[0]!)
    }
    
#else
    
var devices = [cl_device_id?](repeating: nil, count: 32) //Here be dragons if you put these lines inside the context retrieval method.
    
var platforms = [cl_platform_id?](repeating: nil, count: 32)
    func OpenCLGetContext(glfwWindow: OpaquePointer) -> (cl_context, cl_device_id) {
        
        var platformsSize = cl_uint(0);
        clGetPlatformIDs(UInt32(32 * sizeof(cl_platform_id)), &platforms, &platformsSize);
        
        
        typealias GLContextInfoFunc = @convention(c) (UnsafePointer<cl_context_properties>?, cl_gl_context_info, size_t, UnsafeMutablePointer<Void>?, UnsafeMutablePointer<size_t>?) -> cl_int
        
        let glContextExtensionName = "clGetGLContextInfoKHR".cString(using: NSASCIIStringEncoding)!
        
        let extensionAddress = clGetExtensionFunctionAddressForPlatform(platforms[0], glContextExtensionName)
        let clGetGLContextInfo = unsafeBitCast(extensionAddress, to: GLContextInfoFunc.self)
        
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
            assertionFailure("Error creating context: \(OpenCLError(rawValue: error)!)")
        }
        
        let extensionsString = UnsafeMutablePointer<CChar>(malloc(1024))
        var extensionsSize = 0
        clGetDeviceInfo(devices[0]!, cl_device_info(CL_DEVICE_EXTENSIONS), 1024, extensionsString, &extensionsSize)
        let supportedExtensions = String(cString: UnsafePointer<CChar>(extensionsString!))
        
        if !supportedExtensions.contains("cl_KHR_gl_sharing") {
            fatalError("OpenGL-OpenCL sharing is unsupported on this hardware")
        }
        
        checkForSupportedExtensions(supportedExtensions: supportedExtensions)
        
        return (context!, devices[0]!)
    }
#endif

private func checkForSupportedExtensions(supportedExtensions: String) {
    OpenCLDepthTextureSupported = isOpenCLDepthTextureSupported(supportedExtensions: supportedExtensions);
    _implicitCLSyncSupported = supportedExtensions.contains("cl_khr_gl_event")
}

private func isOpenCLDepthTextureSupported(supportedExtensions: String) -> Bool {
    return supportedExtensions.contains("cl_khr_gl_depth_images") && NSProcessInfo.processInfo().environment["UseColourBufferForDepthTexture"] == nil
}

enum OpenCLError : cl_int {
    case CL_SUCCESS = 0
    case CL_DEVICE_NOT_FOUND = -1
    case CL_DEVICE_NOT_AVAILABLE = -2
    case CL_COMPILER_NOT_AVAILABLE = -3
    case CL_MEM_OBJECT_ALLOCATION_FAILURE = -4
    case CL_OUT_OF_RESOURCES = -5
    case CL_OUT_OF_HOST_MEMORY = -6
    case CL_PROFILING_INFO_NOT_AVAILABLE = -7
    case CL_MEM_COPY_OVERLAP = -8
    case CL_IMAGE_FORMAT_MISMATCH = -9
    case CL_IMAGE_FORMAT_NOT_SUPPORTED = -10
    case CL_BUILD_PROGRAM_FAILURE = -11
    case CL_MAP_FAILURE = -12
    
    case CL_INVALID_VALUE = -30
    case CL_INVALID_DEVICE_TYPE = -31
    case CL_INVALID_PLATFORM = -32
    case CL_INVALID_DEVICE = -33
    case CL_INVALID_CONTEXT = -34
    case CL_INVALID_QUEUE_PROPERTIES = -35
    case CL_INVALID_COMMAND_QUEUE = -36
    case CL_INVALID_HOST_PTR = -37
    case CL_INVALID_MEM_OBJECT = -38
    case CL_INVALID_IMAGE_FORMAT_DESCRIPTOR = -39
    case CL_INVALID_IMAGE_SIZE = -40
    case CL_INVALID_SAMPLER = -41
    case CL_INVALID_BINARY = -42
    case CL_INVALID_BUILD_OPTIONS = -43
    case CL_INVALID_PROGRAM = -44
    case CL_INVALID_PROGRAM_EXECUTABLE = -45
    case CL_INVALID_KERNEL_NAME = -46
    case CL_INVALID_KERNEL_DEFINITION = -47
    case CL_INVALID_KERNEL = -48
    case CL_INVALID_ARG_INDEX = -49
    case CL_INVALID_ARG_VALUE = -50
    case CL_INVALID_ARG_SIZE = -51
    case CL_INVALID_KERNEL_ARGS = -52
    case CL_INVALID_WORK_DIMENSION = -53
    case CL_INVALID_WORK_GROUP_SIZE = -54
    case CL_INVALID_WORK_ITEM_SIZE = -55
    case CL_INVALID_GLOBAL_OFFSET = -56
    case CL_INVALID_EVENT_WAIT_LIST = -57
    case CL_INVALID_EVENT = -58
    case CL_INVALID_OPERATION = -59
    case CL_INVALID_GL_OBJECT = -60
    case CL_INVALID_BUFFER_SIZE = -61
    case CL_INVALID_MIP_LEVEL = -62
    case CL_INVALID_GLOBAL_WORK_SIZE = -63
}