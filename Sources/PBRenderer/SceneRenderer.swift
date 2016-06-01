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

final class GBufferPass {
    
    var gBufferPassState : PipelineState
    let diffuseLDSampler = Sampler()
    let dfgSampler = Sampler()
    let specularLDSampler = Sampler()
    
    init(pixelDimensions: PBWindow.Size, lightAccumulationTexture: Texture) {
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        
        let gBuffer = GBufferPass.gBufferFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height, lightAccumulationTexture: lightAccumulationTexture)
        
        let geometryPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "GeometryPass.vert"))
        
        let geometryPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "GeometryPass.frag"))
        
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
    
    func resize(newPixelDimensions width: GLint, _ height: GLint, lightAccumulationTexture: Texture) {
        self.gBufferPassState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
        self.gBufferPassState.framebuffer = GBufferPass.gBufferFramebuffer(width: width, height: height, lightAccumulationTexture: lightAccumulationTexture)
    }
    
    class func gBufferFramebuffer(width: GLint, height: GLint, lightAccumulationTexture: Texture) -> Framebuffer {
        
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
        
        var attachment4 = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        attachment4.texture = lightAccumulationTexture
        attachment4.loadAction = .Clear
        attachment4.storeAction = .Store
        
        let depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT32F, width: Int(width), height: Int(height), mipmapped: false)
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor)
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.loadAction = .Clear
        depthAttachment.storeAction = .Store
        depthAttachment.texture = depthTexture

        
        return Framebuffer(width: width, height: height, colourAttachments: [attachment1, attachment2, attachment3, attachment4], depthAttachment: depthAttachment, stencilAttachment: nil)
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
                let materialBuffer = material.buffer
                
                
                let materialBufferOffset = material.bufferIndex / 16 //material is 48 bytes, we need 256 byte alignment, lowest common multiple is 768 bytes, and we can fit 16 materials into 768 bytes
                let indexInBuffer = material.bufferIndex % 16
                
                materialBuffer.bindToUniformBlockIndex(materialBlockIndex, elementOffset: materialBufferOffset)
                shader.setUniform(GLint(indexInBuffer), forProperty: GBufferShaderProperty.MaterialIndex)
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
                defer { dfg.texture.unbindFromIndex(0) }
                self.dfgSampler.bindToIndex(0)
            defer { self.dfgSampler.unbindFromIndex(0) }
                shader.setUniform(GLint(0), forProperty: GBufferShaderProperty.DFGTexture)
            
                environmentMap.diffuseTexture.bindToIndex(1)
            defer { environmentMap.diffuseTexture.unbindFromIndex(1) }
                self.diffuseLDSampler.bindToIndex(1)
            defer { self.diffuseLDSampler.unbindFromIndex(1) }
                shader.setUniform(GLint(1), forProperty: GBufferShaderProperty.DiffuseLDTexture)
            
                environmentMap.specularTexture.bindToIndex(2)
            defer { environmentMap.specularTexture.unbindFromIndex(2) }
                self.specularLDSampler.bindToIndex(2)
            defer { self.specularLDSampler.unbindFromIndex(2) }
                shader.setUniform(GLint(2), forProperty: GBufferShaderProperty.SpecularLDTexture)
                shader.setUniform(GLint(environmentMap.specularTexture.descriptor.mipmapLevelCount - 1), forProperty: GBufferShaderProperty.LDMipMaxLevel)
            
            shader.setUniform(camera.exposure, forProperty: GBufferShaderProperty.Exposure)
            
            
            let cameraPositionWorld = camera.sceneNode.transform.worldSpacePosition.xyz
            shader.setUniform(cameraPositionWorld.x, cameraPositionWorld.y, cameraPositionWorld.z, forProperty: BasicShaderProperty.CameraPositionWorld)
            
            for node in scene.nodes {
                self.renderNode(node, camera: camera, shader: shader)
            }
        }
        
        return (colourTextures: self.gBufferPassState.framebuffer.colourAttachments.flatMap { $0?.texture! }, depthTexture: self.gBufferPassState.framebuffer.depthAttachment.texture!)
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
            defer { lightAccumulationTexture.unbindFromIndex(0) }
            self.sampler.bindToIndex(0)
            defer { self.sampler.unbindFromIndex(0) }
            
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
        
        let pixelDimensions = window.pixelDimensions
        
        let lightAccumulationTexture = SceneRenderer.lightAccumulationTexture(width: pixelDimensions.width, height: pixelDimensions.height)
        
        self.gBufferPass = GBufferPass(pixelDimensions: pixelDimensions, lightAccumulationTexture: lightAccumulationTexture)
        self.lightAccumulationPass = LightAccumulationPass(pixelDimensions: pixelDimensions, lightAccumulationTexture: lightAccumulationTexture)
        self.finalPass = FinalPass(pixelDimensions: pixelDimensions)
        
//       let envMapTexture = TextureLoader.textureFromVerticalCrossHDRCubeMapAtPath(Resources.pathForResource(named: "stpeters_cross.hdr"))
//        
//        self.envMapLD = LDTexture(resolution: 256)
//        LDTexture.fillLDTexturesFromCubeMaps(textures: [envMapLD], cubeMaps: [envMapTexture], valueMultipliers: [2.0])
        
        window.registerForFramebufferResize(onResize: self.framebufferDidResize)
    }
    
    class func lightAccumulationTexture(width: Int32, height: Int32) -> Texture {
        let rgba16Descriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA16F, width: Int(width), height: Int(height), mipmapped: false)
        return Texture(textureWithDescriptor: rgba16Descriptor)
    }
    
    func framebufferDidResize(width: Int32, height: Int32) {
        let lightAccumulationTexture = SceneRenderer.lightAccumulationTexture(width: width, height: height)
        
        self.gBufferPass.resize(newPixelDimensions: width, height, lightAccumulationTexture: lightAccumulationTexture)
        self.lightAccumulationPass.resize(newPixelDimensions: width, height, lightAccumulationTexture: lightAccumulationTexture)
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
        let lightAccumulationTexture = self.lightAccumulationPass.performPass(scene: scene, camera: camera, gBufferColours: gBuffers, gBufferDepth: gBufferDepth)
        self.finalPass.performPass(lightAccumulationTexture: lightAccumulationTexture)
        
        
//        glEndQuery(GLenum(GL_TIME_ELAPSED))
    }
    

    
}