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
        
        let attachment1Texture = Texture(textureWithDescriptor: descriptor, data: nil as [Void]?)
        
        var attachment1 = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        attachment1.texture = attachment1Texture
        attachment1.loadAction = .Clear
        attachment1.storeAction = .Store
        
        let attachment2Texture = Texture(textureWithDescriptor: descriptor, data: nil as [Void]?)
        
        var attachment2 = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        attachment2.texture = attachment2Texture
        attachment2.loadAction = .Clear
        attachment2.storeAction = .Store
        
        let attachment3Texture = Texture(textureWithDescriptor: descriptor, data: nil as [Void]?)
        
        var attachment3 = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        attachment3.texture = attachment3Texture
        attachment3.loadAction = .Clear
        attachment3.storeAction = .Store
        
        let depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH24_STENCIL8, width: Int(width), height: Int(height), mipmapped: false)
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor, format: GL_DEPTH_STENCIL, type: GL_UNSIGNED_INT_24_8, data: nil as [Void]?)
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.loadAction = .Clear
        depthAttachment.storeAction = .Store
        depthAttachment.texture = depthTexture
        
        return Framebuffer(width: width, height: height, colourAttachments: [attachment1, attachment2, attachment3], depthAttachment: depthAttachment, stencilAttachment: nil)
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
            
        } catch let OpenCLProgramError.FailedProgramBuild(text, clError) {
            fatalError(text + String(clError))
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
    
    func calculateNearPlaneSize(zNear: Float, cameraAspect: Float, projectionMatrix: mat4) -> vec3 {
        let tanHalfFoV = 1/(projectionMatrix[0][0] * cameraAspect)
        let y = tanHalfFoV * zNear
        let x = y * cameraAspect
        return vec3(x, y, -zNear)
    }
    
    func performPass(lights: GPUBuffer<GPULight>, camera: Camera, gBufferColours: [Texture], gBufferDepth: Texture) -> Texture {

        var glObjects = [cl_mem?]()
        var kernelIndex = 0
        
        self.kernel.setArgument(lightAccumulationTextureCL.memory, index: kernelIndex)
        glObjects.append(lightAccumulationTextureCL.memory)
        clRetainMemObject(lightAccumulationTextureCL.memory)
        
        kernelIndex += 1
        
        let inverseImageDimensions = vec2(1.0 / Float(self.lightAccumulationTexture.descriptor.width), 1.0 / Float(self.lightAccumulationTexture.descriptor.height))
        self.kernel.setArgument(inverseImageDimensions, index: kernelIndex)
        
        kernelIndex += 1
        
        let nearPlane = self.calculateNearPlaneSize(zNear: camera.zNear, cameraAspect: camera.aspectRatio, projectionMatrix: camera.projectionMatrix)
        let depthRange = vec2(0, 1)
        let matrixTerms = vec3(camera.projectionMatrix[3][2], camera.projectionMatrix[2][3], camera.projectionMatrix[2][2])
        
        self.kernel.setArgument(nearPlane, index: kernelIndex)
        kernelIndex += 1
        
        self.kernel.setArgument(depthRange, index: kernelIndex)
        kernelIndex += 1
        
        self.kernel.setArgument(matrixTerms, index: kernelIndex)
        kernelIndex += 1
        
        let worldToCameraMatrix = camera.sceneNode.transform.worldToNodeMatrix
        self.kernel.setArgument(worldToCameraMatrix, index: kernelIndex)
        kernelIndex += 1
        
        for buffer in gBufferColours {
            let clTexture = buffer.openCLMemory(clContext: self.clContext, flags: cl_mem_flags(CL_MEM_READ_ONLY), mipLevel: 0)
            
            clRetainMemObject(clTexture.memory)
            glObjects.append(clTexture.memory)
            
            self.kernel.setArgument(clTexture.memory, index: kernelIndex)
            
            kernelIndex += 1
        }
        
        let depthTexture = gBufferDepth.openCLMemory(clContext: self.clContext, flags: cl_mem_flags(CL_MEM_READ_ONLY), mipLevel: 0)
        
        clRetainMemObject(depthTexture.memory)
        glObjects.append(depthTexture.memory)
        
        self.kernel.setArgument(depthTexture.memory, index: kernelIndex)
        
        kernelIndex += 1
        
        let lightCL = lights.openCLMemory(clContext: clContext, flags: cl_mem_flags(CL_MEM_READ_ONLY))
        clRetainMemObject(lightCL.memory)
        glObjects.append(lightCL.memory)
        
        self.kernel.setArgument(lightCL.memory, index: kernelIndex)
        
        kernelIndex += 1
        
        let lightCount = lights.capacity
        self.kernel.setArgument(lightCount, index: kernelIndex)
        
        var err = clEnqueueAcquireGLObjects(self.commandQueue, cl_uint(glObjects.count), &glObjects, 0, nil, nil);
        
        if err != CL_SUCCESS {
            print("Error: Error acquiring GL Objects. \(OpenCLError(rawValue: err)!)");
        }
        
        err = clEnqueueNDRangeKernel(self.commandQueue, kernel.clKernel, 2, nil, [lightAccumulationTexture.descriptor.width, lightAccumulationTexture.descriptor.height], nil, 0, nil, nil);
        if err != CL_SUCCESS {
            print("Error: Failed to execute kernel. \(OpenCLError(rawValue: err)!)");
        }
        
        err = clEnqueueReleaseGLObjects(self.commandQueue, cl_uint(glObjects.count), &glObjects, 0, nil, nil);
        if err != CL_SUCCESS {
            print("Error: Error releasing GL Objects. \(OpenCLError(rawValue: err)!)");
        }
        
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
        let lightAccumulationTexture = self.lightAccumulationPass.performPass(lights: scene.lightBuffer, camera: camera, gBufferColours: gBuffers, gBufferDepth: gBufferDepth)
        self.finalPass.performPass(lightAccumulationTexture: lightAccumulationTexture)
    }
    
}