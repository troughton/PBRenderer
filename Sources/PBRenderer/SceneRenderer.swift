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
    let diffuseLDSampler = Sampler()
    let dfgSampler = Sampler()
    let specularLDSampler = Sampler()
    
    init(pixelDimensions: PBWindow.Size) {
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        
        let gBuffer = GBufferPass.gBufferFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height)
        
        let geometryPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "GeometryPass.vert"))
        
        let fragmentShaderName = OpenCLDepthTextureSupported ? "GeometryPass.frag" : "GeometryPassColourDepth.frag"
        let geometryPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: fragmentShaderName))
        
        let geometryShader = Shader(withVertexShader: geometryPassVertex, fragmentShader: geometryPassFragment)
        
        var pipelineState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height), framebuffer: gBuffer, shader: geometryShader, depthStencilState: depthState)
        pipelineState.cullMode = GL_BACK
        
        self.gBufferPassState = pipelineState
        
        self.diffuseLDSampler.minificationFilter = GL_LINEAR
        self.diffuseLDSampler.magnificationFilter = GL_LINEAR
        
        self.specularLDSampler.minificationFilter = GL_LINEAR_MIPMAP_LINEAR
        self.specularLDSampler.magnificationFilter = GL_LINEAR
        
        self.dfgSampler.minificationFilter = GL_LINEAR
        self.dfgSampler.wrapS = GL_CLAMP_TO_EDGE
        self.dfgSampler.wrapT = GL_CLAMP_TO_EDGE
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint) {
        self.gBufferPassState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
        self.gBufferPassState.framebuffer = GBufferPass.gBufferFramebuffer(width: width, height: height)
    }
    
    class func gBufferFramebuffer(width: GLint, height: GLint) -> Framebuffer {
        
        let r32Descriptor = TextureDescriptor(texture2DWithPixelFormat: GL_R32UI, width: Int(width), height: Int(height), mipmapped: false)
        let attachment1Texture = Texture(textureWithDescriptor: r32Descriptor)
        
        var attachment1 = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        attachment1.texture = attachment1Texture
        attachment1.loadAction = .Clear
        attachment1.storeAction = .Store
        
        let rgba8Descriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA8, width: Int(width), height: Int(height), mipmapped: false)
        
        let attachment2Texture = Texture(textureWithDescriptor: rgba8Descriptor)
        
        var attachment2 = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        attachment2.texture = attachment2Texture
        attachment2.loadAction = .Clear
        attachment2.storeAction = .Store
        
        let attachment3Texture = Texture(textureWithDescriptor: rgba8Descriptor)
        
        var attachment3 = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        attachment3.texture = attachment3Texture
        attachment3.loadAction = .Clear
        attachment3.storeAction = .Store
        
        let rgba16Descriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA16F, width: Int(width), height: Int(height), mipmapped: false)
        let attachment4Texture = Texture(textureWithDescriptor: rgba16Descriptor)
        
        var attachment4 = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        attachment4.texture = attachment4Texture
        attachment4.loadAction = .Clear
        attachment4.storeAction = .Store
        
        let depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT32F, width: Int(width), height: Int(height), mipmapped: false)
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor)
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.loadAction = .Clear
        depthAttachment.storeAction = .Store
        depthAttachment.texture = depthTexture
        
        var depthAttachmentAsColour : RenderPassColourAttachment? = nil
        if !OpenCLDepthTextureSupported {
            let colourDepthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_R32F, width: Int(width), height: Int(height), mipmapped: false)
            let colourDepthTexture = Texture(textureWithDescriptor: colourDepthDescriptor)
            
            depthAttachmentAsColour = RenderPassColourAttachment(clearColour: vec4(1));
            depthAttachmentAsColour?.texture = colourDepthTexture
            depthAttachmentAsColour?.loadAction = .Clear
            depthAttachmentAsColour?.storeAction = .Store
        }

        
        return Framebuffer(width: width, height: height, colourAttachments: [attachment1, attachment2, attachment3, attachment4, depthAttachmentAsColour], depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    func renderNode(_ node: SceneNode, camera: Camera, shader: Shader) {
        
        let worldToCamera = camera.sceneNode.transform.worldToNodeMatrix
        let cameraToClip = camera.projectionMatrix
        
        let modelToCamera = worldToCamera * node.transform.nodeToWorldMatrix
        let modelToClip = cameraToClip * modelToCamera
        let normalTransform = (node.transform.worldToNodeMatrix).upperLeft.transpose
        
        shader.setMatrix(modelToClip, forProperty: BasicShaderProperty.ModelToClipMatrix)
        shader.setMatrix(node.transform.nodeToWorldMatrix, forProperty: BasicShaderProperty.ModelToWorldMatrix)
        shader.setMatrix(normalTransform, forProperty: BasicShaderProperty.NormalModelToWorldMatrix)
        
        
        let materialBlockIndex = 0
        
        for mesh in node.meshes {
            if let materialName = mesh.materialName, let material = node.materials[materialName] {
                material.bindToUniformBlockIndex(materialBlockIndex)
            }
            
            mesh.render()
        }
        
        for child in node.children {
            self.renderNode(child, camera: camera, shader: shader)
        }
    }
    
    func renderScene(_ scene: Scene, camera: Camera, environmentMap: LDTexture?) -> (colourTextures: [Texture], depthTexture: Texture) {
        let dfg = DFGTexture.defaultTexture //this will generate it the first time, so we need to call it outside of the render pass method.
        
        self.gBufferPassState.renderPass { (framebuffer, shader) in
            
            shader.setUniform(GLint(environmentMap != nil ? 1 : 0), forProperty: GBufferShaderProperty.UseEnvironmentMap)
            
            let environmentMap = environmentMap ?? LDTexture.emptyTexture
                
                
                dfg.texture.bindToIndex(0)
                self.dfgSampler.bindToIndex(0)
                shader.setUniform(GLint(0), forProperty: GBufferShaderProperty.DFGTexture)
            
                environmentMap.diffuseTexture.bindToIndex(1)
                self.diffuseLDSampler.bindToIndex(1)
                shader.setUniform(GLint(1), forProperty: GBufferShaderProperty.DiffuseLDTexture)
            
                environmentMap.specularTexture.bindToIndex(2)
                self.specularLDSampler.bindToIndex(2)
                shader.setUniform(GLint(2), forProperty: GBufferShaderProperty.SpecularLDTexture)
                shader.setUniform(GLint(environmentMap.specularTexture.descriptor.mipmapLevelCount - 1), forProperty: GBufferShaderProperty.LDMipMaxLevel)
            
            
            let cameraPositionWorld = camera.sceneNode.transform.worldSpacePosition.xyz
            shader.setUniform(cameraPositionWorld.x, cameraPositionWorld.y, cameraPositionWorld.z, forProperty: BasicShaderProperty.CameraPositionWorld)
            
            for node in scene.nodes {
                self.renderNode(node, camera: camera, shader: shader)
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
    
    var lightGridBuffer = GPUBuffer<LightGridEntry>(capacity: 64 * 1024 * 32, bufferBinding: GL_ARRAY_BUFFER, accessFrequency: .Stream, accessType: .Draw) //32MB
    var lightGridBuilder = LightGridBuilder()
    
    init(pixelDimensions: PBWindow.Size, openCLContext: cl_context, openCLDevice: cl_device_id) {
        
        self.clContext = openCLContext
        
        self.lightAccumulationTexture = LightAccumulationPass.generateLightAccumulationTexture(width: pixelDimensions.width, height: pixelDimensions.height)
        self.lightAccumulationTextureCL = self.lightAccumulationTexture.openCLMemory(clContext: openCLContext, flags: cl_mem_flags(CL_MEM_WRITE_ONLY), mipLevel: 0)
        
        var err = Int32(0); // error code returned from api calls
        
        // Create a command commands
        self.commandQueue = clCreateCommandQueue(openCLContext, openCLDevice, UInt64(CL_QUEUE_PROFILING_ENABLE), &err);
        if err != CL_SUCCESS {
            fatalError("Error: Failed to create a command queue. \(OpenCLError(rawValue: err)!)\n");
        }
        
        do {
            let programName = OpenCLDepthTextureSupported ? "LightAccumulationPassDepth.cl" : "LightAccumulationPassColourDepth.cl"
           
            // Create the compute program from the source buffer
            let program = try OpenCLProgram(contentsOfFile: Resources.pathForResource(named: programName), clContext: openCLContext, deviceID: openCLDevice)
            
            self.kernel = program.kernelNamed("lightAccumulationPassKernel")!
            
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
        return Texture(textureWithDescriptor: descriptor)
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint) {
        self.lightAccumulationTexture = LightAccumulationPass.generateLightAccumulationTexture(width: width, height: height)
        self.lightAccumulationTextureCL = self.lightAccumulationTexture.openCLMemory(clContext: self.clContext, flags: cl_mem_flags(CL_MEM_WRITE_ONLY), mipLevel: 0)
    }
    
    //Calculates the size of a plane positioned at z = -1 (hence the divide by zNear)
    func calculateNearPlaneSize(zNear: Float, cameraAspect: Float, projectionMatrix: mat4) -> vec2 {
        let tanHalfFoV = 1/(projectionMatrix[0][0] * cameraAspect)
        let y = tanHalfFoV * zNear
        let x = y * cameraAspect
        return vec2(x, y) / zNear
    }
    
    func performPass(scene: Scene, camera: Camera, gBufferColours: [Texture], gBufferDepth: Texture) -> Texture {
        
        self.setupLightGrid(camera: camera, lights: scene.lights)
        
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
        let projectionA = camera.zFar / (camera.zFar - camera.zNear)
        let projectionB = (-camera.zFar * camera.zNear) / (camera.zFar - camera.zNear)
        let nearPlaneAndProjectionTerms = vec4(nearPlane.x, nearPlane.y, projectionA, projectionB)
        
        self.kernel.setArgument(nearPlaneAndProjectionTerms, index: kernelIndex)
        kernelIndex += 1
        
        let cameraNearAndFar = vec2(camera.zNear, camera.zFar)
        
        self.kernel.setArgument(cameraNearAndFar, index: kernelIndex)
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
        
        let lightCL = scene.lightBuffer.openCLMemory(clContext: clContext, flags: cl_mem_flags(CL_MEM_READ_ONLY))
        clRetainMemObject(lightCL.memory)
        glObjects.append(lightCL.memory)
        
        self.kernel.setArgument(lightCL.memory, index: kernelIndex)
        
        kernelIndex += 1
        
        let lightGridCL = self.lightGridBuffer.openCLMemory(clContext: clContext, flags: cl_mem_flags(CL_MEM_READ_ONLY))
        clRetainMemObject(lightGridCL.memory)
        glObjects.append(lightGridCL.memory)
        
        self.kernel.setArgument(lightGridCL.memory, index: kernelIndex)
        
        kernelIndex += 1
        
        let cameraToWorldMatrix = camera.sceneNode.transform.nodeToWorldMatrix;
        self.kernel.setArgument(cameraToWorldMatrix, index: kernelIndex)
        
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
    
    func setupLightGrid(camera: Camera, lights: [Light]) {
        let clusteredGridScale = 16
        self.lightGridBuilder.reset(dim: LightGridDimensions(width: 2 * clusteredGridScale, height: clusteredGridScale, depth: 8 * clusteredGridScale))
        
        self.lightGridBuilder.clearAllFragments()
        RasterizeLights(builder: self.lightGridBuilder, viewerCamera: camera, lights: lights)
        
        self.lightGridBuffer.asMappedBuffer({ (lightGridBuffer) -> Void in
            self.lightGridBuilder.buildAndUpload(gpuBuffer: lightGridBuffer!, bufferSize: self.lightGridBuffer.capacity * sizeof(LightGridEntry))
        }, usage: GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT | GL_MAP_INVALIDATE_RANGE_BIT)
    }
}

final class FinalPass {
    
    var finalPassState : PipelineState
    var sampler : Sampler
    
    init(pixelDimensions: PBWindow.Size) {
        let finalBuffer = Framebuffer.defaultFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height)
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_ALWAYS
        depthState.isDepthWriteEnabled = false
        
        let finalPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "PassthroughQuad.vert"))
        let finalPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "FinalPass.frag"))
        
        let finalPassShader = Shader(withVertexShader: finalPassVertex, fragmentShader: finalPassFragment)
        
        self.finalPassState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height), framebuffer: finalBuffer, shader: finalPassShader, depthStencilState: depthState)
        
        self.finalPassState.sRGBConversionEnabled = true
        
        self.sampler = Sampler()
        sampler.minificationFilter = GL_NEAREST
        sampler.magnificationFilter = GL_NEAREST
    }
    
    func performPass(lightAccumulationTexture: Texture) {
        
        self.finalPassState.renderPass { (framebuffer, shader) in
            shader.setUniform(GLint(0), forProperty: CompositionPassShaderProperty.LightAccumulationBuffer)
            lightAccumulationTexture.bindToIndex(0)
            self.sampler.bindToIndex(0)
            
            GLMesh.fullScreenQuad.render()
        }
    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint) {
        self.finalPassState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
    }
}

public final class SceneRenderer {
    
    var gBufferPass : GBufferPass
    var lightAccumulationPass : LightAccumulationPass
    var finalPass : FinalPass
    
    public init(window: PBWindow) {
        let (clContext, clDeviceID) = OpenCLGetContext(glfwWindow: window.glfwWindow)
        
        let pixelDimensions = window.pixelDimensions
        
        self.gBufferPass = GBufferPass(pixelDimensions: pixelDimensions)
        self.lightAccumulationPass = LightAccumulationPass(pixelDimensions: pixelDimensions, openCLContext: clContext, openCLDevice: clDeviceID)
        self.finalPass = FinalPass(pixelDimensions: pixelDimensions)
        
//       let envMapTexture = TextureLoader.textureFromVerticalCrossHDRCubeMapAtPath(Resources.pathForResource(named: "stpeters_cross.hdr"))
//        
//        self.envMapLD = LDTexture(resolution: 256)
//        LDTexture.fillLDTexturesFromCubeMaps(textures: [envMapLD], cubeMaps: [envMapTexture], valueMultipliers: [2.0])
        
        window.registerForFramebufferResize(onResize: self.framebufferDidResize)
    }
    
    func framebufferDidResize(width: Int32, height: Int32) {
        self.gBufferPass.resize(newPixelDimensions: width, height)
        self.lightAccumulationPass.resize(newPixelDimensions: width, height)
        self.finalPass.resize(newPixelDimensions: width, height)
    }
    
//    var timingQuery : GLuint? = nil
    
    public func renderScene(_ scene: Scene, camera: Camera) {
//        
//        var timeElapsed = GLuint(0)
//        
//        if let query = timingQuery {
//            glGetQueryObjectuiv(query, GL_QUERY_RESULT, &timeElapsed)
//            let timeElapsedMillis = Double(timeElapsed) * 1.0e-6
//            print(String(format: "Elapsed frame time: %.2fms", timeElapsedMillis))
//        } else {
//            var query : GLuint = 0
//            glGenQueries(1, &query)
//            self.timingQuery = query
//        }
        
//        glBeginQuery(GLenum(GL_TIME_ELAPSED), self.timingQuery!)
//
        
        let (gBuffers, gBufferDepth) = self.gBufferPass.renderScene(scene, camera: camera, environmentMap: nil)
        let lightAccumulationTexture = self.lightAccumulationPass.performPass(scene: scene, camera: camera, gBufferColours: [Texture](gBuffers[0..<4]), gBufferDepth: OpenCLDepthTextureSupported ? gBufferDepth : gBuffers.last!)
        self.finalPass.performPass(lightAccumulationTexture: lightAccumulationTexture)
        
        
//        glEndQuery(GLenum(GL_TIME_ELAPSED))
    }
    

    
}