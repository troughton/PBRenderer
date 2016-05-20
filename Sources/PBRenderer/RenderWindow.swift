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

final class GBufferPass {
    
    var gBufferPassState : PipelineState
    
    init(pixelDimensions: Window.Size) {
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        
        let gBuffer = GBufferPass.gBufferFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height)
        
        let geometryPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "GeometryPass.vert"))
        let geometryPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: "GeometryPass.frag")
        
        let geometryShader = Shader(withVertexShader: geometryPassVertex, fragmentShader: geometryPassFragment)
        
        let pipelineState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height), framebuffer: gBuffer, shader: geometryShader, depthStencilState: depthState)
        
        self.gBufferPassState = pipelineState
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint) {
        self.gBufferPassState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
        self.gBufferPassState.framebuffer = GBufferPass.gBufferFramebuffer(width: width, height: height)
    }
    
    class func gBufferFramebuffer(width: GLint, height: GLint) -> Framebuffer {
        
        let descriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA, width: Int(width), height: Int(height), mipmapped: false)
        
        let colourTexture = Texture(textureWithDescriptor: descriptor, data: nil as [Void]?)
        
        var colourAttachment = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        colourAttachment.texture = colourTexture
        colourAttachment.loadAction = .Clear
        colourAttachment.storeAction = .Store
        
        let normalTexture = Texture(textureWithDescriptor: descriptor, data: nil as [Void]?)
        
        var normalAttachment = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        normalAttachment.texture = normalTexture
        normalAttachment.loadAction = .Clear
        colourAttachment.storeAction = .Store
        
        let depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH24_STENCIL8, width: Int(width), height: Int(height), mipmapped: false)
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor, format: GL_DEPTH_STENCIL, type: GL_UNSIGNED_INT_24_8, data: nil as [Void]?)
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.loadAction = .Clear
        depthAttachment.texture = depthTexture
        
        return Framebuffer(width: width, height: height, colourAttachments: [colourAttachment, normalAttachment], depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    func renderNode(_ node: SceneNode, worldToCameraMatrix: mat4, cameraToClipMatrix: mat4, shader: Shader) {
        let modelToCamera = worldToCameraMatrix * node.transform.nodeToWorldMatrix
        let modelToClip = cameraToClipMatrix * modelToCamera
        let normalTransform = node.transform.worldToNodeMatrix.upperLeft.transpose
        
        shader.setMatrix(modelToClip, forProperty: BasicShaderProperty.ModelToClipMatrix)
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
    
    func renderScene(_ scene: Scene, camera: Camera) -> (colourTextures: [Texture], depthTexture: Texture) {
        
        self.gBufferPassState.renderPass { (framebuffer, shader) in
            
            let worldToCamera = camera.sceneNode.transform.worldToNodeMatrix
            let cameraToClip = camera.projectionMatrix
            
            for node in scene.nodes {
                self.renderNode(node, worldToCameraMatrix: worldToCamera, cameraToClipMatrix: cameraToClip, shader: shader)
            }
        }
        
        return (colourTextures: self.gBufferPassState.framebuffer.colourAttachments.flatMap { $0?.texture! }, depthTexture: self.gBufferPassState.framebuffer.depthAttachment.texture!)
    }
}

final class LightAccumulationPass {
    
    var lightAccumulationTexture : Texture
    var lightAccumulationTextureCL : OpenCLMemory
    let clContext : cl_context
    let commandQueue : cl_command_queue
    let kernel : OpenCLKernel
    
    init(pixelDimensions: Window.Size, openCLContext: cl_context, openCLDevice: cl_device_id) {
        
        self.clContext = openCLContext
        
        self.lightAccumulationTexture = LightAccumulationPass.generateLightAccumulationTexture(width: pixelDimensions.width, height: pixelDimensions.height)
        self.lightAccumulationTextureCL = self.lightAccumulationTexture.openCLMemory(clContext: openCLContext, flags: cl_mem_flags(CL_MEM_WRITE_ONLY), mipLevel: 0)
        
        var err = Int32(0); // error code returned from api calls
        
        // Create a command commands
        //
        self.commandQueue = clCreateCommandQueue(openCLContext, openCLDevice, 0, &err);
        if err != CL_SUCCESS {
            fatalError("Error: Failed to create a command queue. \(OpenCLError(rawValue: err)!)\n");
        }
        
        do {
            // Create the compute program from the source buffer
            //
            
            let program = try OpenCLProgram(contentsOfFile: Resources.pathForResource(named: "LightAccumulationPass.cl"), clContext: openCLContext, deviceID: openCLDevice)
            
            self.kernel = program.kernelNamed("lightAccumulationPass")!
            
        } catch let error {
            fatalError(String(error))
        }
    }
    
    deinit {
        clReleaseCommandQueue(self.commandQueue)
    }
    
    class func generateLightAccumulationTexture(width: GLint, height: GLint) -> Texture {
        let descriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA16F, width: Int(width), height: Int(height), mipmapped: false)
        return Texture(textureWithDescriptor: descriptor, format: GL_RGBA, type: GL_HALF_FLOAT, data: nil as [Void]?)
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint) {
        self.lightAccumulationTexture = LightAccumulationPass.generateLightAccumulationTexture(width: width, height: height)
        self.lightAccumulationTextureCL = self.lightAccumulationTexture.openCLMemory(clContext: self.clContext, flags: cl_mem_flags(CL_MEM_WRITE_ONLY), mipLevel: 0)
    }
    
    func performPass(gBufferColours: [Texture], gBufferDepth: Texture) -> Texture {
        
        var glObjects = [cl_mem?]()
        
        
        self.kernel.setArgument(&lightAccumulationTextureCL.memory, index: 0)
        glObjects.append(lightAccumulationTextureCL.memory)
        clRetainMemObject(lightAccumulationTextureCL.memory)
        
        var kernelIndex = 1
        for buffer in gBufferColours {
            let clTexture = buffer.openCLMemory(clContext: self.clContext, flags: cl_mem_flags(CL_MEM_READ_ONLY), mipLevel: 0)
            
            clRetainMemObject(clTexture.memory)
            glObjects.append(clTexture.memory)
            
            self.kernel.setArgument(&clTexture.memory, index: kernelIndex)
            
            kernelIndex += 1
        }
        
        let depthTexture = gBufferDepth.openCLMemory(clContext: self.clContext, flags: cl_mem_flags(CL_MEM_READ_ONLY), mipLevel: 0)
        
        clRetainMemObject(depthTexture.memory)
        glObjects.append(depthTexture.memory)
        
        self.kernel.setArgument(&depthTexture.memory, index: kernelIndex)
        
        
        clEnqueueAcquireGLObjects(self.commandQueue, cl_uint(glObjects.count), &glObjects, 0, nil, nil);
        
        let err = clEnqueueNDRangeKernel(self.commandQueue, kernel.clKernel, 2, nil, [lightAccumulationTexture.descriptor.width, lightAccumulationTexture.descriptor.height], nil, 0, nil, nil);
        if err != CL_SUCCESS {
            print("Error: Failed to execute kernel. \(OpenCLError(rawValue: err)!)");
        }
        
        clEnqueueReleaseGLObjects(self.commandQueue, cl_uint(glObjects.count), &glObjects, 0, nil, nil);
        
        for object in glObjects {
            clReleaseMemObject(object)
        }
        
        return self.lightAccumulationTexture
    }
}

final class FinalPass {
    
    var finalPassState : PipelineState
    
    init(pixelDimensions: Window.Size) {
        let finalBuffer = Framebuffer.defaultFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height)
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_ALWAYS
        depthState.isDepthWriteEnabled = false
        
        let finalPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughQuad.vert"))
        let finalPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "FinalPass.frag"))
        
        let finalPassShader = Shader(withVertexShader: finalPassVertex, fragmentShader: finalPassFragment)
        
        self.finalPassState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height), framebuffer: finalBuffer, shader: finalPassShader, depthStencilState: depthState)
        
        self.finalPassState.sRGBConversionEnabled = true
    }
    
    func performPass(lightAccumulationTexture: Texture) {
        
        self.finalPassState.renderPass { (framebuffer, shader) in
            shader.setUniform(GLint(0), forProperty: CompositionPassShaderProperty.LightAccumulationBuffer)
            lightAccumulationTexture.bindToIndex(0)
            
            GLMesh.fullScreenQuad.render()
        }
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint) {
        self.finalPassState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
    }
}

final class RenderWindow : Window {
    
    var gBufferPass : GBufferPass! = nil
    var lightAccumulationPass : LightAccumulationPass! = nil
    var finalPass : FinalPass! = nil
    
    override init(name: String, width: Int, height: Int) {
        
        super.init(name: name, width: width, height: height)
        
        let (clContext, clDeviceID) = OpenCLGetContext(glfwWindow: _glfwWindow)
        
        let pixelDimensions = self.pixelDimensions
        
        self.gBufferPass = GBufferPass(pixelDimensions: pixelDimensions)
        self.lightAccumulationPass = LightAccumulationPass(pixelDimensions: pixelDimensions, openCLContext: clContext, openCLDevice: clDeviceID)
        self.finalPass = FinalPass(pixelDimensions: pixelDimensions)
    }
    
    override func framebufferDidResize(width: Int32, height: Int32) {
        self.gBufferPass.resize(newPixelDimensions: width, height)
        self.lightAccumulationPass.resize(newPixelDimensions: width, height)
        self.finalPass.resize(newPixelDimensions: width, height)
    }
    
    func renderScene(_ scene: Scene, camera: Camera) {
        
        let (gBuffers, gBufferDepth) = self.gBufferPass.renderScene(scene, camera: camera)
        let lightAccumulationTexture = self.lightAccumulationPass.performPass(gBufferColours: gBuffers, gBufferDepth: gBufferDepth)
        self.finalPass.performPass(lightAccumulationTexture: lightAccumulationTexture)
    }
    
}