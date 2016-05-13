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

class RenderWindow : Window {
    
    var lightAccumulationBuffer : Framebuffer! = nil
    var gBuffer : Framebuffer! = nil
    
    var renderContextState : RenderContextState! = nil {
        didSet {
            renderContextState?.applyState()
        }
    }
    var pipelineState : PipelineState! = nil {
        didSet {
            pipelineState?.applyState()
        }
    }
    var depthStencilState : DepthStencilState! = nil {
        didSet {
            depthStencilState?.applyState()
        }
    }
    
    var geometryShader : Shader! = nil
    var lightPassShader : Shader! = nil
    
    var scene : Scene! = nil
    
    var projectionMatrix: mat4 = SGLMath.perspectiveFov(Float(M_PI_4), 600, 800, 0.1, 100.0)
    var cameraNear: Float = 0.1
    
    override init(name: String, width: Int, height: Int) {
        
        super.init(name: name, width: width, height: height)
        
        let pixelDimensions = self.pixelDimensions
        self.lightAccumulationBuffer = Framebuffer.defaultFramebuffer(width: pixelDimensions.width, height: pixelDimensions.height)
        self.renderContextState = RenderContextState(viewport: Rectangle(x: 0, y: 0, width: pixelDimensions.width, height: pixelDimensions.height))
        self.renderContextState.applyState()
        
        var depthState = DepthStencilState()
        depthState.depthCompareFunction = GL_LESS
        depthState.isDepthWriteEnabled = true
        self.depthStencilState = depthState
        self.depthStencilState.applyState()
        
        self.lightAccumulationBuffer.colourAttachments[0]?.clearColour = vec4(0, 0, 0, 0)
        self.lightAccumulationBuffer.colourAttachments[0]?.loadAction = .Clear
        self.lightAccumulationBuffer.depthAttachment.clearDepth = 1.0
        self.lightAccumulationBuffer.depthAttachment.loadAction = .Clear
        
        self.setupGBuffer()
        
        let geometryPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: "GeometryPass.vert")
        let geometryPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: "GeometryPass.frag")
        
        self.geometryShader = Shader(withVertexShader: geometryPassVertex, fragmentShader: geometryPassFragment)
        
        let lightPassVertex = try! Shader.shaderTextByExpandingIncludes(fromFile: "LightPass.vert")
        let lightPassFragment = try! Shader.shaderTextByExpandingIncludes(fromFile: "LightPass.frag")
        
        self.lightPassShader = Shader(withVertexShader: lightPassVertex, fragmentShader: lightPassFragment)
        
        let firstColourAttachment = ColourAttachment()
        self.pipelineState = PipelineState(colourAttachments: [firstColourAttachment])
        self.pipelineState.applyState()
        
        guard let collada = Collada(contentsOfFile: Process.arguments[1]) else { fatalError("Couldn't load Collada file") }
        
        self.scene = Scene(fromCollada: collada)
        
    }
    
    func setupGBuffer() {
        let pixelDimensions = self.pixelDimensions
        
        let descriptor = TextureDescriptor(texture2DWithPixelFormat: GL_RGBA, width: Int(pixelDimensions.width), height: Int(pixelDimensions.height), mipmapped: false)
        
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
        
        let depthDescriptor = TextureDescriptor(texture2DWithPixelFormat: GL_DEPTH24_STENCIL8, width: Int(pixelDimensions.width), height: Int(pixelDimensions.height), mipmapped: false)
        let depthTexture = Texture(textureWithDescriptor: depthDescriptor, format: GL_DEPTH_STENCIL, type: GL_UNSIGNED_INT_24_8, data: nil as [Void]?)
        var depthAttachment = RenderPassDepthAttachment(clearDepth: 1.0)
        depthAttachment.loadAction = .Clear
        depthAttachment.texture = depthTexture
        
        self.gBuffer = Framebuffer(width: pixelDimensions.width, height: pixelDimensions.height, colourAttachments: [colourAttachment, normalAttachment], depthAttachment: depthAttachment, stencilAttachment: nil)
        
    }
    
    func calculateNearPlaneSize(zNear: Float, windowDimensions : Size, projectionMatrix: mat4) -> vec3 {
        let cameraAspect = windowDimensions.aspect;
        let tanHalfFoV = 1/(projectionMatrix[0][0] * cameraAspect);
        let y = tanHalfFoV * zNear;
        let x = y * cameraAspect;
        return vec3(x, y, -zNear)
    }
    
    override func preRender() {
        super.preRender()
    }
    
    func renderNode(_ node: SceneNode, worldToCameraMatrix: mat4, cameraToClipMatrix: mat4, shader: Shader) {
        let transform = cameraToClipMatrix * worldToCameraMatrix * node.transform.nodeToWorldMatrix
        shader.setMatrix(transform, forProperty: BasicShaderProperty.mvp)
        
        for mesh in node.meshes {
            mesh.render()
        }
        
        for child in node.children {
            self.renderNode(child, worldToCameraMatrix: worldToCameraMatrix, cameraToClipMatrix: cameraToClipMatrix, shader: shader)
        }
    }
    
    override func render() {
        
        self.gBuffer.renderPass {
            self.geometryShader.withProgram { shader in
                let worldToCamera = SGLMath.translate(mat4(1), vec3(0, 0, 12.0))
                let cameraToClip = SGLMath.perspectiveFov(Float(M_PI_4), 600, 800, 0.1, 100.0)
            
                for node in scene.nodes {
                    self.renderNode(node, worldToCameraMatrix: worldToCamera, cameraToClipMatrix: cameraToClip, shader: shader)
                }
            }
        }
        
        self.lightAccumulationBuffer.renderPass {
            self.lightPassShader.withProgram { shader in
                self.gBuffer.colourAttachments[0]?.texture!.bindToIndex(0)
                shader.setUniform(GLint(0), forProperty: StringShaderProperty("gBuffer0"))
                self.gBuffer.depthAttachment.texture!.bindToIndex(1)
                shader.setUniform(GLint(1), forProperty: StringShaderProperty("gBufferDepth"))
                
                let nearPlaneSize = self.calculateNearPlaneSize(zNear: self.cameraNear, windowDimensions: self.pixelDimensions, projectionMatrix: projectionMatrix)
                shader.setUniform(nearPlaneSize.x, nearPlaneSize.y, nearPlaneSize.z, forProperty: StringShaderProperty("nearPlane"))
                
                shader.setUniform(0.0, 1.0, forProperty: StringShaderProperty("depthRange"))
                
                shader.setUniform(projectionMatrix[3][2], projectionMatrix[2][3], projectionMatrix[2][2], forProperty: StringShaderProperty("matrixTerms"))
                
                GLMesh.fullScreenQuad.render()
            }
        }
    }
    
    override func postRender() {
        super.postRender()
    }
    
}