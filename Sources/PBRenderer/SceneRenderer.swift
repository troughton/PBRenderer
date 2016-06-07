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
    static let diffuseLDSampler : Sampler = {
        let sampler = Sampler()
        sampler.minificationFilter = GL_LINEAR
        sampler.magnificationFilter = GL_LINEAR
        return sampler
    }()
    
    static let dfgSampler : Sampler = {
        let sampler = Sampler()
        sampler.minificationFilter = GL_LINEAR
        sampler.wrapS = GL_CLAMP_TO_EDGE
        sampler.wrapT = GL_CLAMP_TO_EDGE
        return sampler
    }()
    
    static let specularLDSampler : Sampler = {
        let sampler = Sampler()
        sampler.minificationFilter = GL_LINEAR_MIPMAP_LINEAR
        sampler.magnificationFilter = GL_LINEAR
        return sampler
    }()
    
    enum GBufferShaderProperty : String, ShaderProperty {
        case Materials = "materials"
        case GBuffer0 = "gBuffer0Texture"
        case GBuffer1 = "gBuffer1Texture"
        case GBuffer2 = "gBuffer2Texture"
        case GBuffer3 = "gBuffer3Texture"
        case GBufferDepth = "gBufferDepthTexture"
        
        case MaterialIndex = "materialIndex"
        
        case DFGTexture = "dfg"
        case LDMipMaxLevel = "ldMipMaxLevel"
        
        case lightProbes = "LightProbes"
        case lightProbeIndices;
        case lightProbeDiffuseTextures;
        case lightProbeSpecularTextures;
        
        case Exposure = "exposure"
        
        var name : String {
            return self.rawValue
        }
    }
    
    init(pixelDimensions: Size, lightAccumulationAttachment: RenderPassColourAttachment) {
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        
        let gBuffer = GBufferPass.gBufferFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height, lightAccumulationAttachment: lightAccumulationAttachment)
        
        let geometryPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "GeometryPass.vert"))
        
        let geometryPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "GeometryPass.frag"))
        
        let geometryShader = Shader(withVertexShader: geometryPassVertex, fragmentShader: geometryPassFragment)
        
        var pipelineState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height), framebuffer: gBuffer, shader: geometryShader, depthStencilState: depthState)
        pipelineState.cullMode = GL_BACK
        
        self.gBufferPassState = pipelineState

    }
    
    func resize(newPixelDimensions width: GLint, _ height: GLint, lightAccumulationAttachment: RenderPassColourAttachment) {
        self.gBufferPassState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
        self.gBufferPassState.framebuffer = GBufferPass.gBufferFramebuffer(width: width, height: height, lightAccumulationAttachment: lightAccumulationAttachment)
    }
    
    class func gBufferFramebuffer(width: GLint, height: GLint, lightAccumulationAttachment: RenderPassColourAttachment) -> Framebuffer {
        
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
        
        let depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT32F, width: Int(width), height: Int(height), mipmapped: false)
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor)
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.loadAction = .Clear
        depthAttachment.storeAction = .Store
        depthAttachment.texture = depthTexture

        var lightAccumulationAttachment = lightAccumulationAttachment
        lightAccumulationAttachment.loadAction = .Clear
        lightAccumulationAttachment.blendState = BlendState()
        
        return Framebuffer(width: width, height: height, colourAttachments: [attachment1, attachment2, attachment3, lightAccumulationAttachment], depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    func lightProbesAffectingPoint(_ point: vec3, sortedLightProbes : [LightProbe], environmentMap : LightProbe?) -> [LightProbe] {
        let filteredLightProbes = sortedLightProbes.lazy.filter { $0.boxContainsPoint(point) }
        let lightProbesToUse = [LightProbe](filteredLightProbes.prefix(LightProbe.maxLightProbesPerPass - ((environmentMap != nil) ? 1 : 0)))
        var result = lightProbesToUse
        if let environmentMap = environmentMap {
            result.append(environmentMap)
        }
        return result
    }
    
    func renderNode(_ node: SceneNode, camera: Camera, shader: Shader, sortedLightProbes : [LightProbe], environmentMap: LightProbe? = nil) {
        
        let worldToCamera = camera.sceneNode.transform.worldToNodeMatrix
        let cameraToClip = camera.projectionMatrix
        
        let modelToCamera = worldToCamera * node.transform.nodeToWorldMatrix
        let modelToClip = cameraToClip * modelToCamera
        let normalTransform = (node.transform.worldToNodeMatrix).upperLeft.transpose
        
        shader.setMatrix(modelToClip, forProperty: BasicShaderProperty.ModelToClipMatrix)
        shader.setMatrix(node.transform.nodeToWorldMatrix, forProperty: BasicShaderProperty.ModelToWorldMatrix)
        shader.setMatrix(normalTransform, forProperty: BasicShaderProperty.NormalModelToWorldMatrix)
        
        for mesh in node.meshes {
            if let materialName = mesh.materialName, let material = node.materials[materialName] {
                
                shader.setUniform(GLint(material.bufferIndex), forProperty: GBufferShaderProperty.MaterialIndex)
            }
            
            let lightProbes = self.lightProbesAffectingPoint(node.transform.worldSpacePosition.xyz, sortedLightProbes: sortedLightProbes, environmentMap: environmentMap)
            let lightProbeIndices = lightProbes.map { GLint($0.indexInBuffer) }
            
            //Find the indices for the light probes (available texture indices start from 8)
            shader.setUniformArray([GLint(lightProbeIndices.count)] + lightProbeIndices, forProperty: GBufferShaderProperty.lightProbeIndices)
            
            
            for (i, lightProbe) in lightProbes.enumerated() {
                let ldTexture = lightProbe.ldTexture
                
                let diffuseIndex = 8 + i * 2
                ldTexture.diffuseTexture.bindToIndex(diffuseIndex)
                
                let specularIndex = diffuseIndex + 1
                ldTexture.specularTexture.bindToIndex(specularIndex)
            }
            
            mesh.render()
        }
        
        for child in node.children {
            self.renderNode(child, camera: camera, shader: shader, sortedLightProbes: sortedLightProbes, environmentMap: environmentMap)
        }
    }
    
    func renderScene(_ scene: Scene, camera: Camera) -> (colourTextures: [Texture], depthTexture: Texture) {
        let dfg = DFGTexture.defaultTexture //this will generate it the first time, so we need to call it outside of the render pass method.
        
        let sortedLightProbes = scene.lightProbesSorted
        
        self.gBufferPassState.renderPass { (framebuffer, shader) in
            
            shader.setUniformBlockBindingPoints(forProperties: [GBufferShaderProperty.lightProbes])
            LightProbe.lightProbeBuffer.bindToUniformBlockIndex(0)
                
            dfg.texture.bindToIndex(0)
            defer { dfg.texture.unbindFromIndex(0) }
            GBufferPass.dfgSampler.bindToIndex(0)
            defer { GBufferPass.dfgSampler.unbindFromIndex(0) }
            shader.setUniform(GLint(0), forProperty: GBufferShaderProperty.DFGTexture)
            
            
            scene.materialTexture.bindToIndex(1)
            shader.setUniform(GLint(1), forProperty: GBufferShaderProperty.Materials)
            
            shader.setUniform(camera.exposure, forProperty: GBufferShaderProperty.Exposure)
            
            var specularTextureIndices = [GLint]()
            var diffuseTextureIndices = [GLint]()
            
            for i in 0..<LightProbe.maxLightProbesPerPass {
                
                let ldTexture = LDTexture.emptyTexture
                
                let diffuseIndex = 8 + i * 2
                ldTexture.diffuseTexture.bindToIndex(diffuseIndex)
                GBufferPass.diffuseLDSampler.bindToIndex(diffuseIndex)
                diffuseTextureIndices.append(GLint(diffuseIndex))
                
                let specularIndex = diffuseIndex + 1
                ldTexture.specularTexture.bindToIndex(specularIndex)
                GBufferPass.specularLDSampler.bindToIndex(diffuseIndex)
                specularTextureIndices.append(GLint(specularIndex))
            }
            
            defer {
                for index in specularTextureIndices {
                    GBufferPass.specularLDSampler.unbindFromIndex(Int(index))
                }
                
                for index in diffuseTextureIndices {
                    GBufferPass.diffuseLDSampler.unbindFromIndex(Int(index))
                }
            }
            
            shader.setUniformArray(specularTextureIndices, forProperty: GBufferShaderProperty.lightProbeSpecularTextures)
            shader.setUniformArray(diffuseTextureIndices, forProperty: GBufferShaderProperty.lightProbeDiffuseTextures)
            
            
            let cameraPositionWorld = camera.sceneNode.transform.worldSpacePosition.xyz
            shader.setUniform(cameraPositionWorld.x, cameraPositionWorld.y, cameraPositionWorld.z, forProperty: BasicShaderProperty.CameraPositionWorld)
            
            for node in scene.nodes {
                self.renderNode(node, camera: camera, shader: shader, sortedLightProbes: sortedLightProbes)
            }
        }
        
        return (colourTextures: self.gBufferPassState.framebuffer.colourAttachments.flatMap { $0?.texture! }, depthTexture: self.gBufferPassState.framebuffer.depthAttachment.texture!)
    }
}

final class FinalPass {
    
    var finalPassState : PipelineState
    var sampler : Sampler
    
    init(pixelDimensions: Size) {
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
    var screenSpaceReflectionPasses : ScreenSpaceReflectionsPasses?
    var finalPass : FinalPass?
    
    public init(window: PBWindow) {
        
        let pixelDimensions = window.pixelDimensions
        
        let lightAccumulationAttachment = SceneRenderer.lightAccumulationAttachment(width: pixelDimensions.width, height: pixelDimensions.height)
        
        self.gBufferPass = GBufferPass(pixelDimensions: pixelDimensions, lightAccumulationAttachment: lightAccumulationAttachment)
        self.lightAccumulationPass = LightAccumulationPass(pixelDimensions: pixelDimensions, lightAccumulationAttachment: lightAccumulationAttachment)
        self.screenSpaceReflectionPasses = ScreenSpaceReflectionsPasses(pixelDimensions: pixelDimensions, lightAccumulationAttachment: lightAccumulationAttachment)
        self.finalPass = FinalPass(pixelDimensions: pixelDimensions)
        
        window.registerForFramebufferResize(onResize: self.framebufferDidResize)
        
    }
    
    init(lightProbeRendererWithLightAccumulationAttachment lightAccumulationAttachment: RenderPassColourAttachment) {
        
        let pixelDimensions = Size(Int32(lightAccumulationAttachment.texture!.descriptor.width), Int32(lightAccumulationAttachment.texture!.descriptor.height))
        
        self.gBufferPass = GBufferPass(pixelDimensions: pixelDimensions, lightAccumulationAttachment: lightAccumulationAttachment)
        self.lightAccumulationPass = LightAccumulationPass(pixelDimensions: pixelDimensions, lightAccumulationAttachment: lightAccumulationAttachment, hasSpecularAndReflections: true)
        self.screenSpaceReflectionPasses = nil
        self.finalPass = nil
    }
    
    class func lightAccumulationAttachment(width: Int32, height: Int32) -> RenderPassColourAttachment {
        let rgba16Descriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA16F, width: Int(width), height: Int(height), mipmapped: true)
        let texture = Texture(textureWithDescriptor: rgba16Descriptor)
        texture.setMipRange(0..<1)
        
        let blendState = BlendState(isBlendingEnabled: true, sourceRGBBlendFactor: GL_ONE, destinationRGBBlendFactor: GL_SRC_ALPHA, rgbBlendOperation: GL_FUNC_ADD, sourceAlphaBlendFactor: GL_ZERO, destinationAlphaBlendFactor: GL_ONE, alphaBlendOperation: GL_FUNC_ADD, writeMask: .All)
        
        var colourAttachment = RenderPassColourAttachment(clearColour: vec4(0, 0, 0, 0));
        colourAttachment.texture = texture
        colourAttachment.loadAction = .Load
        colourAttachment.storeAction = .Store
        colourAttachment.blendState = blendState
        return colourAttachment
    }
    
    func framebufferDidResize(width: Int32, height: Int32) {
        let lightAccumulationAttachment = SceneRenderer.lightAccumulationAttachment(width: width, height: height)
        
        self.gBufferPass.resize(newPixelDimensions: width, height, lightAccumulationAttachment: lightAccumulationAttachment)
        self.lightAccumulationPass.resize(newPixelDimensions: width, height, lightAccumulationAttachment: lightAccumulationAttachment)
        self.screenSpaceReflectionPasses?.resize(newPixelDimensions: width, height, lightAccumulationAttachment: lightAccumulationAttachment)
        self.finalPass?.resize(newPixelDimensions: width, height)
    }
    
//    var timingQuery : GLuint? = nil
    
    public func renderScene(_ scene: Scene, camera: Camera, environmentMap: LDTexture? = nil) {
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
        
        let (gBuffers, gBufferDepth) = self.gBufferPass.renderScene(scene, camera: camera)
        let (lightAccumulationTexture, _) = self.lightAccumulationPass.performPass(scene: scene, camera: camera, gBufferColours: gBuffers, gBufferDepth: gBufferDepth)
       // let lightAccumulationAndReflections = self.screenSpaceReflectionPasses?.render(camera: camera, lightAccumulationBuffer: lightAccumulationTexture, rayTracingBuffer: rayTracingTexture!, gBuffers: gBuffers, gBufferDepth: gBufferDepth)
        self.finalPass?.performPass(lightAccumulationTexture: lightAccumulationTexture)
        
        
//        glEndQuery(GLenum(GL_TIME_ELAPSED))
    }
    

    
}