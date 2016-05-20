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
    var clTexture : Texture! = nil
    
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
        
        let envMapTextureDescriptor = TextureDescriptor(texture2DWithPixelFormat: numComponents == 3 ? GL_RGB16F : GL_RGBA16F, width: Int(imageX), height: Int(imageY), mipmapped: false)
        self.envMapTexture = Texture(textureWithDescriptor: envMapTextureDescriptor, type: GL_FLOAT, format: numComponents == 3 ? GL_RGB : GL_RGBA, data: hdrEnvMap)
        self.envMapTexture.generateMipmaps()
        
        stbi_image_free(hdrEnvMap)
        
        let clTextureDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA8, width: 512, height: 512, mipmapped: false)
        self.clTexture = Texture(textureWithDescriptor: clTextureDescriptor, format: GL_RGBA, type: GL_UNSIGNED_BYTE, data: nil as [Void]?)
        
        let (context, deviceId) = OpenCLGetContext(glfwWindow: _glfwWindow)
        
        self.clTest(context: context, device_id: deviceId, texture: self.clTexture)
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
            shader.setUniform(GLint(0), forProperty: StringShaderProperty("clTexture"))
            self.clTexture.bindToIndex(0)
            
            shader.setUniformBlockBindingPoints(forProperties: [BasicShaderProperty.Material, StringShaderProperty("Light")])
            
            for node in scene.nodes {
                self.renderNode(node, worldToCameraMatrix: worldToCamera, cameraToClipMatrix: cameraToClip, shader: shader)
            }
        }
    }
    
    override func postRender() {
        super.postRender()
    }
    
    func clTest(context: cl_context, device_id: cl_device_id, texture: Texture) {
        
        do {
            
            var err = Int32(0);                            // error code returned from api calls
            
            var correct = UInt32(0);               // number of correct results returned
            
            var global = size_t(0);                      // global domain size for our calculation
            
            var commands : cl_command_queue! = nil          // compute command queue
            
            
            // Fill our data set with random float values
            //
            
            // Create a command commands
            //
            commands = clCreateCommandQueue(context, device_id, 0, &err);
            if (commands == nil) {
                print("Error: Failed to create a command commands! \(err)\n");
                exit(EXIT_FAILURE)
            }
            
            
            // Create the compute program from the source buffer
            //
            
            let program = try OpenCLProgram(contentsOfFile: Resources.pathForResource(named: "kernel.cl"), clContext: context, deviceID: device_id)
            
            
            let kernel = program.kernelNamed("imageColourChange")!
            
            let image = texture.openCLMemory(clContext: context, flags: cl_mem_flags(CL_MEM_WRITE_ONLY), mipLevel: 0)
            kernel.setArgument(&image.memory, index: 0)
            
            var imageMemory : cl_mem? = image.memory

            clEnqueueAcquireGLObjects(commands, 1, &imageMemory, 0, nil, nil);
            
            err = clEnqueueNDRangeKernel(commands, kernel.clKernel, 2, nil, [texture.descriptor.width, texture.descriptor.height], nil, 0, nil, nil);
            if (err != 0)
            {
                print("Error: Failed to execute kernel!\n");
                exit(EXIT_FAILURE)
            }
            
            clEnqueueReleaseGLObjects(commands, 1, &imageMemory, 0, nil, nil);
            
            // Shutdown and cleanup
            //
            clReleaseCommandQueue(commands);
            clReleaseContext(context);
            
        } catch let error {
            fatalError(String(error))
        }
    }
    
    
}