//
//  LightAccumulationPass.swift
//  PBRenderer
//
//  Created by Thomas Roughton on 1/06/16.
//
//

import Foundation
import OpenCL
import SGLMath
import SGLOpenGL

final class LightAccumulationPass {
    
    var pipelineState : PipelineState

    static let lightGridBuilder = LightGridBuilder()
    
    static let vertexShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "CameraSpacePositionVertexShader.vert"))
    static let fragmentShader = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LightAccumulationPass.frag"))
    static let fragmentShaderNoSpecular = try! Shader.shaderTextByExpandingIncludes(fromFile: Resources.pathForResource(named: "LightAccumulationPassDiffuseOnly.frag"))
    
    static let lightAccumulationShader = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)
    static let lightAccumulationShaderNoSpecular = Shader(withVertexShader: vertexShader, fragmentShader: fragmentShader)
    
    let hasSpecularAndReflections : Bool
    
    init(pixelDimensions: Size, lightAccumulationAttachment: RenderPassColourAttachment, hasSpecularAndReflections: Bool = true) {
        
        let framebuffer = LightAccumulationPass.lightAccumulationFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height, lightAccumulationAttachment: lightAccumulationAttachment, includeReflectionBuffer: hasSpecularAndReflections)
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_ALWAYS
        depthState.isDepthWriteEnabled = false
        
        self.hasSpecularAndReflections = hasSpecularAndReflections
        
        self.pipelineState = PipelineState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height),
                                           framebuffer: framebuffer,
                                           shader: hasSpecularAndReflections ? LightAccumulationPass.lightAccumulationShader : LightAccumulationPass.lightAccumulationShaderNoSpecular,
                                           depthStencilState: depthState)
        
    }
    
    deinit {
    }
    
    class func lightAccumulationFramebuffer(width: GLint, height: GLint, lightAccumulationAttachment: RenderPassColourAttachment, includeReflectionBuffer: Bool) -> Framebuffer {
        
        var reflectionAttachment : RenderPassColourAttachment? = nil
        if includeReflectionBuffer {
            let reflectionBufferDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA16F, width: Int(width), height: Int(height), mipmapped: false)
            let reflectionTexture = Texture(textureWithDescriptor: reflectionBufferDescriptor)
            
            reflectionAttachment = RenderPassColourAttachment(clearColour: vec4(0))
            reflectionAttachment!.loadAction = .Clear
            reflectionAttachment!.storeAction = .Store
            reflectionAttachment!.texture = reflectionTexture
        }
        
        
        var depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH_COMPONENT16, width: Int(width), height: Int(height), mipmapped: false)
        depthDescriptor.usage = .RenderTarget
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor)
    
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.loadAction = .Clear
        depthAttachment.storeAction = .Store
        depthAttachment.texture = depthTexture
        
        return Framebuffer(width: width, height: height, colourAttachments: [lightAccumulationAttachment, reflectionAttachment], depthAttachment: depthAttachment, stencilAttachment: nil)
    }
    
    
    func resize(newPixelDimensions width: GLint, _ height: GLint, lightAccumulationAttachment: RenderPassColourAttachment) {
        self.pipelineState.viewport = Rectangle(x: 0, y: 0, width: width, height: height)
        self.pipelineState.framebuffer = LightAccumulationPass.lightAccumulationFramebuffer(width: width, height: height, lightAccumulationAttachment: lightAccumulationAttachment, includeReflectionBuffer: hasSpecularAndReflections)
    }
    
    //Calculates the size of a plane positioned at z = -1 (hence the divide by zNear)
    func calculateNearPlaneSize(zNear: Float, cameraAspect: Float, projectionMatrix: mat4) -> vec2 {
        let tanHalfFoV = 1/(projectionMatrix[0][0] * cameraAspect)
        let y = tanHalfFoV * zNear
        let x = y * cameraAspect
        return vec2(x, y) / zNear
    }
    
    func setupLightGrid(camera: Camera, lights: [Light]) {
        let clusteredGridScale = 16
        LightAccumulationPass.lightGridBuilder.reset(dim: LightGridDimensions(width: 2 * clusteredGridScale, height: clusteredGridScale, depth: 4 * clusteredGridScale))
        
        LightAccumulationPass.lightGridBuilder.clearAllFragments()
        RasterizeLights(builder: LightAccumulationPass.lightGridBuilder, viewerCamera: camera, lights: lights)
        
        LightAccumulationPass.lightGridBuilder.buildAndUpload()
    }
    
    enum LightAccumulationShaderProperty : String, ShaderProperty {
        case LightGrid = "lightGrid"
        case NearPlane = "nearPlane"
        case ProjectionTerms = "projectionTerms"
        case CameraNearFar = "cameraNearFar"
        case GBuffer0Texture = "gBuffer0Texture"
        case GBuffer1Texture = "gBuffer1Texture"
        case GBuffer2Texture = "gBuffer2Texture"
        case GBufferDepthTexture = "gBufferDepthTexture"
        case Lights = "lights"
        case CameraToWorldMatrix = "cameraToWorldMatrix"
        case WorldToCameraMatrix = "worldToCameraMatrix"
        case CameraToPixelClipMatrix = "cameraToPixelClipMatrix"
        case DepthBufferSize = "depthBufferSize"
        case Exposure = "exposure"
        
        case ReflectionTraceMaxDistance = "reflectionTraceMaxDistance"
        
        var name : String {
            return self.rawValue
        }
    }
    
    func performPass(scene: Scene, camera: Camera, gBufferColours: [Texture], gBufferDepth: Texture) -> Texture {
        
        self.setupLightGrid(camera: camera, lights: scene.lights)
        
        let lightTexture = scene.lightTexture
        
        self.pipelineState.renderPass { (framebuffer, shader) in
            
            gBufferColours[1].bindToIndex(1)
            defer { gBufferColours[1].unbindFromIndex(1) }
            shader.setUniform(GLint(1), forProperty: LightAccumulationShaderProperty.GBuffer1Texture)
            
            gBufferColours[2].bindToIndex(2)
            defer { gBufferColours[2].unbindFromIndex(2) }
            shader.setUniform(GLint(2), forProperty: LightAccumulationShaderProperty.GBuffer2Texture)
            
            gBufferDepth.bindToIndex(0)
            defer { gBufferColours[3].unbindFromIndex(0) }
            shader.setUniform(GLint(0), forProperty: LightAccumulationShaderProperty.GBufferDepthTexture)
            
            LightAccumulationPass.lightGridBuilder.lightGridTexture.bindToIndex(4)
            defer { LightAccumulationPass.lightGridBuilder.lightGridTexture.unbindFromIndex(4) }
            shader.setUniform(GLint(4), forProperty: LightAccumulationShaderProperty.LightGrid)
            
            
            gBufferColours[0].bindToIndex(5)
            defer { gBufferColours[0].unbindFromIndex(5) }
            shader.setUniform(GLint(5), forProperty: LightAccumulationShaderProperty.GBuffer0Texture)
            
            lightTexture.bindToIndex(6)
            defer { lightTexture.unbindFromIndex(6) }
            shader.setUniform(GLint(6), forProperty: LightAccumulationShaderProperty.Lights)
            
            
            shader.setUniform(camera.exposure, forProperty: LightAccumulationShaderProperty.Exposure)
            
            shader.setMatrix(camera.transform.nodeToWorldMatrix, forProperty: LightAccumulationShaderProperty.CameraToWorldMatrix)
            
            shader.setUniform(camera.zNear, camera.zFar, forProperty: LightAccumulationShaderProperty.CameraNearFar)
            
            let nearPlane = self.calculateNearPlaneSize(zNear: camera.zNear, cameraAspect: camera.aspectRatio, projectionMatrix: camera.projectionMatrix)
            let projectionA = camera.zFar / (camera.zFar - camera.zNear)
            let projectionB = (-camera.zFar * camera.zNear) / (camera.zFar - camera.zNear)
            
            shader.setUniform(nearPlane.x, nearPlane.y, forProperty: LightAccumulationShaderProperty.NearPlane)
            shader.setUniform(projectionA, projectionB, forProperty: LightAccumulationShaderProperty.ProjectionTerms)
            
            if self.hasSpecularAndReflections {
                shader.setMatrix(camera.transform.worldToNodeMatrix, forProperty: LightAccumulationShaderProperty.WorldToCameraMatrix)
                
                
                let width = gBufferDepth.descriptor.width
                let height = gBufferDepth.descriptor.height
                
                let projectionMatrix = camera.projectionMatrix
                let scaleMatrix = mat4(pixelScaleMatrixWithWidth: Float(width), height: Float(height)) * projectionMatrix
                let invertedYMatrix = scaleMatrix //SGLMath.scale(scaleMatrix, vec3(1, -1, 1))
                
                shader.setMatrix(invertedYMatrix, forProperty: LightAccumulationShaderProperty.CameraToPixelClipMatrix)
                
                shader.setUniform(Float(width - 1), Float(height - 1), forProperty: LightAccumulationShaderProperty.DepthBufferSize)
                
                let traceDistance = 10.0 //(camera.zFar - camera.zNear) * 0.5
                shader.setUniform(Float(traceDistance), forProperty: LightAccumulationShaderProperty.ReflectionTraceMaxDistance)
    
            }
            
            GLMesh.fullScreenQuad.render()
        }
        
        return self.pipelineState.framebuffer.colourAttachments[1]?.texture! ?? self.pipelineState.framebuffer.colourAttachments[0]!.texture!
    }
}