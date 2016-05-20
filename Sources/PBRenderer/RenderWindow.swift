//
//  RenderWindow.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 12/05/16.
//
//

import Foundation
import SGLOpenGL
import SGLMath
import CGLFW3
import ColladaParser
import CPBRendererLibs
import OpenCL

final class RenderWindow : Window {
    
    var forwardPassState : PipelineState! = nil
    
    var scene : Scene! = nil
    
    var projectionMatrix: mat4 = SGLMath.perspectiveFov(Float(M_PI_4), 600, 800, 0.1, 100.0)
    var cameraNear: Float = 0.1
    
    var envMapTexture : Texture! = nil
    
    override init(name: String, width: Int, height: Int) {
        
        super.init(name: name, width: width, height: height)
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        
        let pixelDimensions = self.pixelDimensions
        
        let lightAccumulationBuffer = Framebuffer.defaultFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height)
        
        lightAccumulationBuffer.colourAttachments[0]?.clearColour = vec4(0, 0, 0, 0)
        lightAccumulationBuffer.colourAttachments[0]?.loadAction = .Clear
        lightAccumulationBuffer.depthAttachment.clearDepth = 1.0
        lightAccumulationBuffer.depthAttachment.loadAction = .Clear
        
        let lightPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "ForwardPass.vert"))
        let lightPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "ForwardPass.frag"))
        
        let forwardPassShader = Shader(withVertexShader: lightPassVertex, fragmentShader: lightPassFragment)
        
        self.forwardPassState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height), framebuffer: lightAccumulationBuffer, shader: forwardPassShader, depthStencilState: depthState)
        
        guard let collada = Collada(contentsOfFile: Process.arguments[1]) else { fatalError("Couldn't load Collada file") }
        
        self.scene = Scene(fromCollada: collada)
        
        var imageX = Int32(0)
        var imageY = Int32(0)
        var numComponents = Int32(0)
        let hdrEnvMap = stbi_loadf("stpeters_probe.hdr", &imageX, &imageY, &numComponents, 0)
        
        let envMapTextureDescriptor = TextureDescriptor(texture2DWithPixelFormat: numComponents == 3 ? GL_RGB16F : GL_RGBA16F, width: Int(imageX), height: Int(imageY), mipmapped: true)
        self.envMapTexture = Texture(textureWithDescriptor: envMapTextureDescriptor, type: GL_FLOAT, format: numComponents == 3 ? GL_RGB : GL_RGBA, data: hdrEnvMap)
        self.envMapTexture.generateMipmaps()
        
        stbi_image_free(hdrEnvMap)
        
        let (context, deviceId) = OpenCLGetContext(glfwWindow: _glfwWindow)
        self.clTest(context: context, device_id: deviceId)
    }
    
    override func framebufferDidResize(width: Int32, height: Int32) {
        self.forwardPassState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
    }
    
    override func preRender() {
        super.preRender()
    }
    
    func renderNode(_ node: SceneNode, worldToCameraMatrix: mat4, cameraToClipMatrix: mat4, shader: Shader) {
        let modelToCamera = worldToCameraMatrix * node.transform.nodeToWorldMatrix
        let modelToClip = cameraToClipMatrix * modelToCamera
        let normalTransform = node.transform.worldToNodeMatrix.upperLeft.transpose
        
        shader.setMatrix(modelToCamera, forProperty: BasicShaderProperty.ModelToCameraMatrix)
        shader.setMatrix(modelToClip, forProperty: BasicShaderProperty.mvp)
        shader.setMatrix(normalTransform, forProperty: BasicShaderProperty.NormalModelToCameraMatrix)
        
        let materialBlockIndex = 0
        
        for mesh in node.meshes {
            if let materialName = mesh.materialName, let material = node.materials[materialName] {
                material.bindToUniformBlockIndex(materialBlockIndex)
            }
            
            mesh.render()
        }
        
        for child in node.children {
            self.renderNode(child, worldToCameraMatrix: worldToCameraMatrix, cameraToClipMatrix: cameraToClipMatrix, shader: shader)
        }
    }
    
    override func render() {
        
        self.forwardPassState.renderPass { (framebuffer, shader) in
            let camera = self.scene.flattenedScene.flatMap { $0.cameras.first }.first!
            
            let worldToCamera = camera.sceneNode.transform.worldToNodeMatrix
            let cameraToClip = camera.projectionMatrix
            
            shader.setUniform(GLint(1), forProperty: StringShaderProperty("lightCount"))
            scene.lightBuffer.bindToUniformBlockIndex(1)
            shader.setMatrix(worldToCamera, forProperty: StringShaderProperty("worldToCameraMatrix"))
            
            
            shader.setUniformBlockBindingPoints(forProperties: [BasicShaderProperty.Material, StringShaderProperty("Light")])
            
            for node in scene.nodes {
                self.renderNode(node, worldToCameraMatrix: worldToCamera, cameraToClipMatrix: cameraToClip, shader: shader)
            }
        }
    }
    
    override func postRender() {
        super.postRender()
    }
    
    let DATA_SIZE = 1024000
    let KernelSource = "\n" +
        "__kernel void square(                                                       \n" +
        "   __global float* input,                                              \n" +
        "   __global float* output,                                             \n" +
        "   const unsigned int count)                                           \n" +
        "{                                                                      \n" +
        "   int i = get_global_id(0);                                           \n" +
        "   if(i < count)                                                       \n" +
        "       output[i] = input[i] * input[i];                                \n" +
        "}                                                                      \n" +
    "\n";
    
    func clTest(context: cl_context, device_id: cl_device_id) {
        
        do {
            
        var err = Int32(0);                            // error code returned from api calls
        
        var data = [Float](repeating: 0, count: DATA_SIZE);              // original data set given to device
        var results = [Float](repeating: 0, count: DATA_SIZE)        // results returned from device
        var correct = UInt32(0);               // number of correct results returned
        
        var global = size_t(0);                      // global domain size for our calculation
        
        var commands : cl_command_queue! = nil          // compute command queue
        
        
        // Fill our data set with random float values
        //
        
        for i in 0..<DATA_SIZE {
            data[i] = Float(rand()) / Float(RAND_MAX);
        }
        
        // Create a command commands
        //
        commands = clCreateCommandQueue(context, device_id, 0, &err);
        if (commands == nil) {
            print("Error: Failed to create a command commands! \(err)\n");
            exit(EXIT_FAILURE)
        }
        
        
        // Create the compute program from the source buffer
        //
        
            let program = try OpenCLProgram(withText: KernelSource, clContext: context, deviceID: device_id)
        
        
        let kernel = program.kernelNamed("square")!
        
        
        var count = DATA_SIZE
        // Create the input and output arrays in device memory for our calculation
        //
        let input = clCreateBuffer(context, cl_mem_flags(CL_MEM_READ_ONLY),  sizeof(Float) * count, nil, nil).managed;
        let output = clCreateBuffer(context, cl_mem_flags(CL_MEM_WRITE_ONLY), sizeof(Float) * count, nil, nil).managed;
        
        // Write our data set into the input array in device memory
        //
        err = clEnqueueWriteBuffer(commands, input.memory, cl_bool(CL_TRUE), 0, sizeof(Float) * count, data, 0, nil, nil);
        if (err != CL_SUCCESS)
        {
            print("Error: Failed to write to source array!\n");
            exit(1);
        }
        
        var count32 = UInt32(count)
        
        kernel.setArgument(&input.memory, index: 0)
        kernel.setArgument(&output.memory, index: 1)
        kernel.setArgument(&count32, index: 2)
        
        // Get the maximum work group size for executing the kernel on the device
        //
        var local = kernel.maxWorkGroupSize(onDevice: device_id)
        
        // Execute the kernel over the entire range of our 1d input data set
        // using the maximum number of work group items for this device
        //
        global = count;
        err = clEnqueueNDRangeKernel(commands, kernel.clKernel, 1, nil, &global, &local, 0, nil, nil);
        if (err != 0)
        {
            print("Error: Failed to execute kernel!\n");
            exit(EXIT_FAILURE)
        }
        
        // Wait for the command commands to get serviced before reading back results
        //
        clFinish(commands);
        
        // Read back the results from the device to verify the output
        //
        results.withUnsafeBufferPointer { (bufferPtr) -> Void in
            let pointer = UnsafeMutablePointer<Void>(bufferPtr.baseAddress)!
            
            err = clEnqueueReadBuffer(commands, output.memory, cl_bool(CL_TRUE), 0, sizeof(Float) * count, pointer, 0, nil, nil );
        }
        if (err != CL_SUCCESS)
        {
            print("Error: Failed to read output array! %d\n", err);
            exit(1);
        }
        
        // Validate our results
        //
        correct = 0;
        for i in 0..<count {
            if(results[i] == data[i] * data[i]) {
                correct += 1;
            }
        }
        
        // Print a brief summary detailing the results
        //
        print("Computed '\(correct)/\(count)' correct values!\n");
        
        // Shutdown and cleanup
        //
        clReleaseCommandQueue(commands);
        clReleaseContext(context);
            
        } catch let error {
            fatalError(String(error))
        }
    }

    
}