//
//  OpenCLContext.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 20/05/16.
//
//

import Foundation
import OpenCL
import CGLFW3

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
    
    return (context!, devices[0]!)
}

#else
    
func OpenCLGetContext(glfwWindow: OpaquePointer) -> (cl_context, cl_device_id) {
        
        // Create CL context properties, add GLX context & handle to DC
    let properties : [cl_context_properties] = [
            cl_context_properties(CL_GL_CONTEXT_KHR), cl_context_properties(glfwGetGLXContext()), // GLX Context
            cl_context_properties(CL_GLX_DISPLAY_KHR), cl_context_properties(glfwGetX11Display()), // GLX Display
            cl_context_properties(CL_CONTEXT_PLATFORM), cl_context_properties(platform),
            0
            ];
            // Find CL capable devices in the current GL context
            var devices = [cl_device_id?](repeating: nil, count: 32)
            var size = size_t(0);
            clGetGLContextInfoKHR(properties, CL_DEVICES_FOR_GL_CONTEXT_KHR, 32 * sizeof(cl_device_id), devices, &size);
            // OpenCL platform
            // Create a context using the supported devices
            let count = size / sizeof(cl_device_id);
            var error = cl_int(0)
            
            let context = clCreateContext(properties, devices, UnsafePointer<Void>(bitPattern: count), nil, 0, &error);
            
            if error != 0 {
                assertionFailure("Error creating context: \(error)")
            }
    
    // Get string containing supported device extensions
    var ext_size = 1024;
    let ext_string = malloc(ext_size);
    let err = clGetDeviceInfo(devices[0]!, cl_device_info(CL_DEVICE_EXTENSIONS), ext_size, ext_string, &ext_size);
    // Search for GL support in extension string (space delimited)
    print("Supported extensions: " + String(cString: UnsafePointer<CChar>(ext_string!)!, encoding: NSUTF8StringEncoding))
    
            return (context!, devices[0]!)
}
    #endif