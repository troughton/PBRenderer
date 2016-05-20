//
//  OpenCLProgram.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 20/05/16.
//
//

import Foundation
import OpenCL

final class OpenCLKernel {
    
    let clKernel : cl_kernel
    
    init(kernel: cl_kernel) {
        self.clKernel = kernel
    }
    
    func setArgument<T>(_ argument: inout T, size: Int? = nil, index: Int) {
        let argSize = size ?? sizeofValue(argument)
        let result = clSetKernelArg(self.clKernel, cl_uint(index), argSize, &argument)
        if result != CL_SUCCESS {
            print("Error: Failed to set kernel argument at index \(index) to value \(argument)")
        }
    }
    
    func maxWorkGroupSize(onDevice device: cl_device_id) -> size_t {
        var size = size_t(0)
        let err = clGetKernelWorkGroupInfo(self.clKernel, device, cl_kernel_work_group_info(CL_KERNEL_WORK_GROUP_SIZE), sizeof(size_t), &size, nil);
        if (err != CL_SUCCESS) {
            print("Error: Failed to retrieve kernel work group info. (%d)", err);
        }
        return size
    }
    
    deinit {
        clReleaseKernel(self.clKernel)
    }
    
}

enum OpenCLProgramError : ErrorProtocol {
    case FailedProgramCreation(cl_int)
    case FailedProgramBuild(String, cl_int)
}

final class OpenCLProgram {
    let clProgram : cl_program
    
    init(withText text: String, clContext: cl_context, deviceID: cl_device_id) throws {
        
        var err = cl_int(0)
        
        self.clProgram = text.withCString { (cString) -> cl_program in
            var string : UnsafePointer<Int8>? = cString
            return clCreateProgramWithSource(clContext, 1, &string, nil, &err);
        }
        
        if err != CL_SUCCESS {
            throw OpenCLProgramError.FailedProgramCreation(err)
        }
        
        // Build the program executable
        //
        err = clBuildProgram(self.clProgram, 0, nil, nil, nil, nil);
        if (err != CL_SUCCESS) {
            
            var len = size_t(0);
            clGetProgramBuildInfo(self.clProgram, deviceID, cl_program_build_info(CL_PROGRAM_BUILD_LOG), 0, nil, &len);
            
            var buffer = [CChar](repeating: 0, count: len);
            
            print("Error: Failed to build program executable!\n");
            clGetProgramBuildInfo(self.clProgram, deviceID, cl_program_build_info(CL_PROGRAM_BUILD_LOG), buffer.count, &buffer, &len);
            throw OpenCLProgramError.FailedProgramBuild(String(cString: buffer), err)
        }
        
    }
    
    convenience init(contentsOfFile filePath: String, clContext: cl_context, deviceID: cl_device_id) throws {
        
        let contents = try String(contentsOfFile: filePath, encoding: NSUTF8StringEncoding)
        
        try self.init(withText: contents, clContext: clContext, deviceID: deviceID)
    }
    
    func kernelNamed(_ name: String) -> OpenCLKernel? {
        var err = cl_int(0)
        let kernel = clCreateKernel(self.clProgram, name, &err)
        
        if kernel == nil || err != CL_SUCCESS {
            print("Error: failed to create compute kernel. (\(err))")
            return nil
        }
        return OpenCLKernel(kernel: kernel!)
    }
    
    deinit {
        clReleaseProgram(clProgram)
    }
}